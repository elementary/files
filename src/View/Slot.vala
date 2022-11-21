/***
    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

public class Files.Slot : Gtk.Box, SlotInterface {
    public ViewMode view_mode { get; construct; }
    public int width { get; private set; }
    public Directory? directory { get; set; }
    public Files.File? file { get { return directory != null ? directory.file : null; }}
    public string uri { get { return file != null ? file.uri : ""; }}
    public Files.ViewInterface? view_widget { get; private set; }
    public int displayed_files_count {
        get {
            if (directory != null && directory.state == Directory.State.LOADED) {
                return (int)(directory.displayed_files_count);
            }

            return -1;
        }
    }

    private Gtk.Overlay overlay;
    private Gtk.Box extra_location_widgets;
    private Gtk.Box extra_action_widgets;
    private Gtk.Label empty_label;

    private int preferred_column_width;
    private uint reload_timeout_id = 0;
    private uint path_change_timeout_id = 0;
    private bool original_reload_request = false;

    private const string EMPTY_MESSAGE = _("This Folder Is Empty");
    private const string EMPTY_TRASH_MESSAGE = _("Trash Is Empty");
    private const string EMPTY_RECENT_MESSAGE = _("There Are No Recent Files");
    private const string DENIED_MESSAGE = _("Access Denied");

    public signal void folder_deleted (Files.File file, Directory parent);

    public Slot (GLib.File? _location, ViewMode _mode) {
        Object (
            view_mode: _mode,
            orientation: Gtk.Orientation.VERTICAL,
            vexpand: true,
            hexpand: _mode != ViewMode.MULTICOLUMN
        );

        set_up_directory (_location ?? GLib.File.new_for_commandline_arg (Environment.get_home_dir ()));
    }

    ~Slot () {
        warning ("Slot %s destruct", file.basename);
        while (get_last_child () != null) {
            get_last_child ().unparent ();
        }
    }

    construct {
        extra_location_widgets = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        overlay = new Gtk.Overlay () {
            hexpand = true,
            vexpand = true
        };
        extra_action_widgets = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        empty_label = new Gtk.Label ("") {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            focusable = false,
            margin_start = 48,
            margin_end = 48
        };
        empty_label.add_css_class (Granite.STYLE_CLASS_H2_LABEL);
        switch (view_mode) {
            case ViewMode.ICON:
                view_widget = new Files.GridView (this);
                break;
            case ViewMode.LIST:
                view_widget = new Files.GridView (this);
                break;
            case ViewMode.MULTICOLUMN:
                var gv = new Files.GridView (this);
                gv.grid_view.max_columns = 1;
                view_widget = gv;
                break;

            default:
                view_widget = new Files.GridView (this);
                break;
        }

        overlay.child = view_widget;
        if (view_mode == ViewMode.MULTICOLUMN) {
            preferred_column_width = Files.column_view_settings.get_int ("preferred-column-width");
            width = preferred_column_width;
            view_widget.width_request = preferred_column_width;
        }

        view_widget.selection_changed.connect (on_view_widget_selection_changed);

        append (extra_location_widgets);
        append (overlay);
        append (extra_action_widgets);
    }

    public void add_extra_widget (Gtk.Widget widget) {
        extra_location_widgets.append (widget);
    }

    public void add_extra_action_widget (Gtk.Widget widget) {
        extra_action_widgets.append (widget);
    }

    uint selection_changed_timeout_id = 0;
    List<Files.File> selected_files = null; // Maintain a reference for overlaybar
    private void on_view_widget_selection_changed () {
        activate_action ("win.selection-changing", null);

        if (selection_changed_timeout_id > 0) {
            Source.remove (selection_changed_timeout_id);
        }

        selection_changed_timeout_id = Timeout.add (100, () => {
            selection_changed_timeout_id = 0;
            activate_action ("win.update-selection", null);
            selection_changed (selected_files); // Trash plughin listens to this.
            return Source.REMOVE;
        });
    }

    // Signal could be from subdirectory as well as slot directory
    private void connect_directory_handlers (Directory dir) {
        dir.file_added.connect (on_directory_file_added);
        dir.file_changed.connect (on_directory_file_changed);
        dir.file_deleted.connect (on_directory_file_deleted);
        dir.need_reload.connect (on_directory_need_reload);
    }

    private void disconnect_directory_handlers (Directory dir) {
        dir.file_added.disconnect (on_directory_file_added);
        dir.file_changed.disconnect (on_directory_file_changed);
        dir.file_deleted.disconnect (on_directory_file_deleted);
        dir.need_reload.disconnect (on_directory_need_reload);
    }

    // * Directory signal handlers moved from DirectoryView not requiring changes
    // to Window
    private void on_directory_file_added (Directory dir, Files.File? file) {
        if (file != null) {
            view_widget.add_file (file);
        }

        //TODO Determine whether dir is loading or freespace update required.
    }

    private void on_directory_file_changed (Directory dir, Files.File file) {
        if (file.location.equal (dir.file.location)) {
            /* The slot directory has changed - it can only be the properties */
        } else {
            view_widget.file_changed (file);
        }
    }

    public void on_directory_file_deleted (Directory dir, Files.File file) {
        /* The deleted file could be the whole directory */
        file.exists = false;
        view_widget.file_deleted (file);

        if (file.get_thumbnail_path () != null) {
            FileUtils.remove_thumbnail_paths_for_uri (file.uri);
        }

        // if (plugins != null) {
        //     plugins.update_file_info (file); //TODO Reimplement in Gtk4
        // }

        if (file.is_folder ()) {
            /* Check whether the deleted file is the directory */
            var file_dir = Directory.cache_lookup (file.location);
            if (file_dir != null) {
                Directory.purge_dir_from_cache (file_dir); //Needed?
                this.folder_deleted (file, file_dir);
            }
        }

        // handle_free_space_change (); //TODO Reimplement in Gtk4
    }

    private void on_directory_need_reload (Directory dir, bool original_request) {
        view_widget.clear ();
        activate_action ("win.loading-uri", "s", dir.file.uri);
        if (original_request) {
            original_reload_request = true;
        }
        /* Only need to initialise directory once - the slot that originally received the
         * reload request does this */
        if (original_reload_request) {
            schedule_reload ();
            original_reload_request = false;
        }
    }

    private void schedule_reload () {
        /* Allow time for other slots showing this directory to prepare for reload.
         * Also a delay is needed when a mount is added and trash reloads. */
        if (reload_timeout_id > 0) {
            warning ("Path change request received too rapidly");
            return;
        }

        reload_timeout_id = Timeout.add (100, () => {
            directory.reload ();
            reload_timeout_id = 0;
            return GLib.Source.REMOVE;
        });
    }

    private void set_up_directory (GLib.File loc) {
        if (directory != null) {
            disconnect_directory_handlers (directory);
        }

        directory = Directory.from_gfile (loc);
        connect_directory_handlers (directory);
    }

    //TODO Cancel timeouts when destroyed.
//     private void on_view_path_change_request (GLib.File loc, Files.OpenFlag flag) {
// warning ("SLOT view path change req");
//         cancel_timeouts ();
//         activate_action ("win.path-change-request", "(su)", loc.get_uri (), flag);
//     }

    public async bool initialize_directory () {
        if (directory.is_loading ()) {
            warning ("Slot.initialize_directory () called when directory already loading - ignoring");
            return false;
        }

        //NOTE activate_action does not work in async function ??
        yield directory.init (view_widget.add_file);
        if (directory.can_load) {
            if (file.is_recent_uri_scheme ()) {
                view_widget.sort_type = Files.SortType.MODIFIED;
                view_widget.sort_reversed = false;
            } else if (this.directory.file.info != null) {
                view_widget.sort_type = this.directory.file.sort_type;
                view_widget.sort_reversed = this.directory.file.sort_reversed;
            }
        } else {
            return false;
        }

        if (directory.is_empty ()) { /* No files in the file cache */
            empty_label.label = get_empty_message ();
            if (empty_label.parent == null) {
                overlay.add_overlay (empty_label);
                overlay.set_measure_overlay (empty_label, true); //Expand column to accomodate label
            }
        } else {
            if (empty_label.parent == overlay) {
                overlay.remove_overlay (empty_label);
            }
        }

        return true;
    }

    public void reload (bool non_local_only = false) {
        if (!non_local_only || !directory.is_local) {
            original_reload_request = true;
            /* Propagate reload signal to any other slot showing this directory indicating it is not
             * the original signal */
            directory.need_reload (false);
        }
    }

    public override bool set_all_selected (bool select_all) {
        if (view_widget != null) {
            if (select_all) {
                view_widget.select_all ();
            } else {
                view_widget.unselect_all ();
            }
            return true;
        } else {
            return false;
        }
    }

    public List<Files.File> get_selected_files () {
        List<Files.File> selected_files = null;
        if (view_widget != null) {
            view_widget.get_selected_files (out selected_files);
        }

        return (owned)selected_files;
    }

    public void select_glib_files (GLib.List<GLib.File> locations, GLib.File? focus_location) {
        if (view_widget != null) {
            var files_to_select = new List<Files.File> ();
            locations.@foreach ((loc) => {
                files_to_select.prepend (Files.File.@get (loc));
            });

            var focus_after_select = focus_location != null ? focus_location.dup () : null;

            view_widget.select_files (files_to_select);
            if (focus_location != null) {
                view_widget.show_and_select_file (Files.File.@get (focus_location), false, false, true);
            }
        }
    }

    public void select_gof_file (Files.File gof) {
        if (view_widget != null) {
            view_widget.show_and_select_file (gof, true, false, false);
        }
    }

    public void show_first_item () {
        if (view_widget != null) {
            view_widget.show_and_select_file (null, false, false);
        }
    }

    public void set_active_state (bool set_active, bool animate = true) {
        //TODO Reimplement if needed
    }

    public void grab_focus () {
        if (view_widget != null) {
            view_widget.grab_focus ();
        }
    }

    public void zoom_in () {
        view_widget.zoom_in ();
    }

    public void zoom_out () {
        view_widget.zoom_out ();
    }

    public void zoom_normal () {
        view_widget.zoom_normal ();
    }

    public void close () {
        // Need to reduce references to one if poss
        cancel_timeouts ();
        if (directory != null) {
            directory.cancel ();
            disconnect_directory_handlers (directory);
        }

        view_widget.unparent ();
        view_widget.destroy ();
        view_widget = null;
    }

    public void refresh_files () {
        if (directory != null) {
            directory.update_files ();
        }
    }

    public FileInfo? lookup_file_info (GLib.File loc) {
        Files.File? gof = directory.file_hash_lookup_location (loc);
        if (gof != null) {
            return gof.info;
        } else {
            return null;
        }
    }

    private void cancel_timeouts () {
        cancel_timeout (ref reload_timeout_id);
        cancel_timeout (ref path_change_timeout_id);
        cancel_timeout (ref selection_changed_timeout_id);
    }

    private void cancel_timeout (ref uint id) {
        if (id > 0) {
            Source.remove (id);
            id = 0;
        }
    }

    public string get_empty_message () {
        string msg = EMPTY_MESSAGE;
        if (directory.is_recent) {
            msg = EMPTY_RECENT_MESSAGE;
        } else if (directory.is_trash && (uri == Files.TRASH_URI + Path.DIR_SEPARATOR_S)) {
            msg = EMPTY_TRASH_MESSAGE;
        } else if (directory.permission_denied) {
            msg = DENIED_MESSAGE;
        }

        return msg;
    }
}
