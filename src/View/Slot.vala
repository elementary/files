/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

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

namespace Files {
public class Slot : Files.AbstractSlot {
    private unowned Files.ViewContainer ctab;
    private ViewMode mode;
    private int preferred_column_width;

    private uint reload_timeout_id = 0;
    private uint path_change_timeout_id = 0;
    private bool original_reload_request = false;

    private Gtk.Label empty_label;
    private const string EMPTY_MESSAGE = _("This Folder Is Empty");
    private const string EMPTY_TRASH_MESSAGE = _("Trash Is Empty");
    private const string EMPTY_RECENT_MESSAGE = _("There Are No Recent Files");
    private const string DENIED_MESSAGE = _("Access Denied");

    public Files.ViewInterface? view_widget { get; set; }
    public bool is_active {get; protected set;}
    public int displayed_files_count {
        get {
            if (directory != null && directory.state == Directory.State.LOADED) {
                return (int)(directory.displayed_files_count);
            }

            return -1;
        }
    }

    public unowned Files.Window window {
        get {return ctab.window;}
    }

    //TODO Needed in Gtk4 version?
    // public override bool is_frozen {
    //     set {
    //         // dir_view.is_frozen = value;
    //         frozen_changed (value);
    //     }

    //     get {
    //         return dir_view == null || dir_view.is_frozen;
    //     }
    // }

    // TODO Gtk4 version needed?
    // public override bool locked_focus {
    //     get {
    //         return view_widget.renaming;
    //     }
    // }

    // public signal void frozen_changed (bool freeze);
    public signal void folder_deleted (Files.File file, Directory parent);

    /* Support for multi-slot view (Miller)*/
    public Gtk.Box colpane;
    public Gtk.Paned hpane;
    public signal void miller_slot_request (GLib.File file, bool make_root);
    public signal void size_change ();

    public Slot (GLib.File _location, ViewContainer _ctab, ViewMode _mode) {
        ctab = _ctab;
        mode = _mode;
        is_active = false;
        preferred_column_width = Files.column_view_settings.get_int ("preferred-column-width");
        width = preferred_column_width;

        set_up_directory (_location); /* Connect dir signals before making view */
        make_view ();
        // connect_dir_view_signals ();
        connect_view_widget_signals ();
        connect_slot_signals ();

        is_frozen = true;
    }

    ~Slot () {
        debug ("Slot %i destruct", slot_number);
        // Ensure dir view does not redraw with invalid slot, causing a crash
        view_widget.unparent ();
        view_widget.destroy ();
    }

    construct {
        empty_label = new Gtk.Label ("") {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER
        };
        empty_label.add_css_class (Granite.STYLE_CLASS_H2_LABEL);
    }

    private void connect_slot_signals () {
        active.connect (() => {
            if (is_active) {
                return;
            }

            is_active = true;
            if (view_widget != null) {
                view_widget.grab_focus ();
            }
        });

        inactive.connect (() => {
            is_active = false;
        });

        folder_deleted.connect ((file, dir) => {
           ((Files.Application)(window.application)).folder_deleted (file.location);
        });
    }

    private void connect_view_widget_signals () {
        view_widget.path_change_request.connect (path_change_requested);
        view_widget.selection_changed.connect (on_view_widget_selection_changed);
    }

    private void disconnect_view_widget_signals () {
        view_widget.selection_changed.disconnect (on_view_widget_selection_changed);
        view_widget.path_change_request.disconnect (path_change_requested);
    }

    private void on_view_widget_selection_changed () {
warning ("selection changed");
        List<Files.File> selected_files = null;
        view_widget.get_selected_files (out selected_files);
        selection_changed (selected_files); // Updates properties overlay
    }

    // Signal could be from subdirectory as well as slot directory
    private void connect_directory_handlers (Directory dir) {
        dir.file_added.connect (on_directory_file_added);
        dir.file_changed.connect (on_directory_file_changed);
        dir.file_deleted.connect (on_directory_file_deleted);
        connect_directory_loading_handlers (dir);
        dir.need_reload.connect (on_directory_need_reload);
    }

    private void connect_directory_loading_handlers (Directory dir) {
warning ("connect directory loading");
        dir.file_loaded.connect (on_directory_file_loaded);
        dir.done_loading.connect (on_directory_done_loading);
    }

    private void disconnect_directory_handlers (Directory dir) {
        /* If the directory is still loading the file_loaded signal handler
        /* will not have been disconnected */
        if (dir.is_loading ()) {
            disconnect_directory_loading_handlers (dir);
        }

        dir.file_added.disconnect (on_directory_file_added);
        dir.file_changed.disconnect (on_directory_file_changed);
        dir.file_deleted.disconnect (on_directory_file_deleted);
        dir.done_loading.disconnect (on_directory_done_loading);
        dir.need_reload.disconnect (on_directory_need_reload);
    }

    private void disconnect_directory_loading_handlers (Directory dir) {
warning ("disconnect directory loading");
        dir.file_loaded.disconnect (on_directory_file_loaded);
        dir.done_loading.disconnect (on_directory_done_loading);
    }

    // * Directory signal handlers moved from DirectoryView.
    private void on_directory_file_added (Directory dir, Files.File? file) {
        if (file != null) {
            warning ("add file %s", file.basename);
            view_widget.add_file (file); //FIXME Should we select files added after load?
        }
    }

    private void on_directory_file_loaded (Directory dir, Files.File file) {
        if (file != null) {
            warning ("load file %s", file.basename);
            view_widget.add_file (file); //FIXME Should we select files added after load?
        }
        /* no freespace change signal required */
    }

    private void on_directory_file_changed (Directory dir, Files.File file) {
        if (file.location.equal (dir.file.location)) {
            /* The slot directory has changed - it can only be the properties */
        } else {
            view_widget.file_changed (file);
        }
    }

    private void on_directory_file_deleted (Directory dir, Files.File file) {
        /* The deleted file could be the whole directory, which is not in the model but that
         * that does not matter.  */

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
                Directory.purge_dir_from_cache (file_dir);
                this.folder_deleted (file, file_dir);
            }
        }

        // handle_free_space_change (); //TODO Reimplement in Gtk4
    }

    private void on_directory_done_loading (Directory dir) {
        /* Should only be called on directory creation or reload */
warning ("done loading %s", dir.file.basename);
        disconnect_directory_loading_handlers (dir);
        if (this.directory.can_load) {
            if (in_recent) {
                view_widget.sort_type = Files.SortType.MODIFIED;
                view_widget.sort_reversed = false;
            } else if (this.directory.file.info != null) {
                view_widget.sort_type = this.directory.file.sort_type;
                view_widget.sort_reversed = this.directory.file.sort_reversed;
            }
        }

        directory_loaded (dir); // Signal to ViewContainer //TODO Replace with direct call
        if (dir.is_empty ()) { /* No files in the file cache */
            empty_label.label = get_empty_message ();
            if (empty_label.parent == null) {
                overlay.add_overlay (empty_label);
            }
        } else {
            if (empty_label.parent == overlay) {
                overlay.remove_overlay (empty_label);
            }
        }
        /*  Column View requires slots to determine their own width (other views' width determined by Window */
        if (mode == ViewMode.MILLER_COLUMNS) {
        //TODO Reimplement in Gtk4 version if required for MILLER
            // if (dir.is_empty ()) { /* No files in the file cache */
            //     Pango.Rectangle extents;
            //     var layout = dir_view.create_pango_layout (null);
            //     layout.set_markup (get_empty_message (), -1);
            //     layout.get_extents (null, out extents);
            //     width = (int) Pango.units_to_double (extents.width);
            // } else {
            //     width = preferred_column_width;
            // }

            // width += view_widget.zoom_level.to_icon_size () + 64; /* allow some extra room for icon padding and right margin*/

            // /* Allow extra room for MESSAGE_CLASS styling of special messages */
            // if (dir.is_empty () || dir.permission_denied) {
            //     width += width;
            // }

            // size_change ();
            // hpane.set_position (width);

            // if (colpane.get_realized ()) {
            //     colpane.queue_draw ();
            // }
        }
    }

    private void on_directory_need_reload (Directory dir, bool original_request) {
warning ("directory reload");
        view_widget.clear ();
        connect_directory_loading_handlers (dir);
        /* view and slot are unfrozen when done loading signal received */
        path_changed ();
        /* if original_request false, leave original_load_request as it is (it may already be true
         * if reloading in response to reload button press). */
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
        assert (directory != null);
        connect_directory_handlers (directory);
    }

    public override void path_change_requested (GLib.File loc, Files.OpenFlag flag) {
        switch (flag) {
            case Files.OpenFlag.DEFAULT:
                if (mode == ViewMode.MILLER_COLUMNS) {
                    miller_slot_request (loc, false); /* signal to parent MillerView */
                } else {
                    user_path_change_request (loc); /* Handle ourselves */
                }
                break;
            case Files.OpenFlag.NEW_TAB:
            case Files.OpenFlag.NEW_WINDOW:
                new_container_request (loc, flag);
                break;
            case Files.OpenFlag.NEW_ROOT:
                if (mode == ViewMode.MILLER_COLUMNS) {
                    miller_slot_request (loc, true); /* signal to parent MillerView */
                } else {
                    user_path_change_request (loc); /* Handle ourselves */
                }
                break;
            case Files.OpenFlag.APP:
                warning ("Unexpected flag");
                break;
        }
    }

    private void on_dir_view_path_change_request (GLib.File loc, Files.OpenFlag flag, bool make_root) {
        if (flag == 0) { /* make view in existing container */
            if (mode == ViewMode.MILLER_COLUMNS) {
                miller_slot_request (loc, make_root); /* signal to parent MillerView */
            } else {
                user_path_change_request (loc); /* Handle ourselves */
            }
        } else {
            new_container_request (loc, flag);
        }
    }

    private void user_path_change_request (GLib.File loc) {
    /** Only this function must be used to change or reload the path **/
        view_widget.clear ();
        var old_dir = directory;
        disconnect_directory_handlers (old_dir);
        set_up_directory (loc); // Connects signals
        initialize_directory ();

        /* ViewContainer listens to this signal takes care of updating appearance */
        path_changed ();
    }

    public override void initialize_directory () {
        if (directory.is_loading ()) {
            /* This can happen when restoring duplicate tabs */
            debug ("Slot.initialize_directory () called when directory already loading - ignoring");
            return;
        }
        // /* view and slot are unfrozen when done loading signal received */
        // is_frozen = true;
        directory.init ();
    }

    public override void reload (bool non_local_only = false) {
        if (!non_local_only || !directory.is_local) {
            original_reload_request = true;
            /* Propagate reload signal to any other slot showing this directory indicating it is not
             * the original signal */
            directory.need_reload (false);
        }
    }

    protected override void make_view () {
        assert (view_widget == null);
        switch (mode) {
            case ViewMode.ICON:
                view_widget = new Files.GridView (this);
                break;
            case ViewMode.LIST:
                view_widget = new Files.GridView (this);
                break;
            case ViewMode.MILLER_COLUMNS:
                view_widget = new Files.GridView (this);
                break;

            default:
                view_widget = new Files.GridView (this);
                break;
        }

        /* Miller View creates its own overlay and handles packing of the directory view */
        if (view_widget != null && mode != ViewMode.MILLER_COLUMNS) {
            add_main_child (view_widget);
        }

        assert (view_widget != null);
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

    public override List<Files.File> get_selected_files () {
        List<Files.File> selected_files = null;
        if (view_widget != null) {
            view_widget.get_selected_files (out selected_files);
        }

        return (owned)selected_files;
    }

    public override void select_glib_files (GLib.List<GLib.File> locations, GLib.File? focus_location) {
// warning ("Slot select glib files");
        if (view_widget != null) {
            var files_to_select = new List<Files.File> ();
            locations.@foreach ((loc) => {
                warning ("select %s", loc.get_basename ());
                files_to_select.prepend (Files.File.@get (loc));
            });

            var focus_after_select = focus_location != null ? focus_location.dup () : null;

            view_widget.select_files (files_to_select);
            if (focus_location != null) {
                warning ("focus_location %s", focus_location.get_basename ());
                view_widget.show_and_select_file (Files.File.@get (focus_location), false, false, true);
            }
        }
    }

    public void select_gof_file (Files.File gof) {
        if (view_widget != null) {
            view_widget.show_and_select_file (gof, true, false, false);
        }
    }

    public override void show_first_item () {
        if (view_widget != null) {
            view_widget.show_and_select_file (null, false, false);
        }
    }

    public override void set_active_state (bool set_active, bool animate = true) {
        if (set_active) {
            active (true, animate);
        } else {
            inactive ();
        }
    }

    public override unowned Files.AbstractSlot? get_current_slot () {
        return this as Files.AbstractSlot;
    }

    public override void grab_focus () {
        if (view_widget != null) {
            view_widget.grab_focus ();
        }
    }

    public override void zoom_in () {
        view_widget.zoom_in ();
    }

    public override void zoom_out () {
        view_widget.zoom_out ();
    }

    public override void zoom_normal () {
        view_widget.zoom_normal ();
    }

    public override void close () {
        cancel_timeouts ();

        if (directory != null) {
            directory.cancel ();
            disconnect_directory_handlers (directory);
        }

        if (view_widget != null) {
            disconnect_view_widget_signals ();
        }
    }

    public void refresh_files () {
        if (directory != null) {
            directory.update_files ();
        }
    }

    public override FileInfo? lookup_file_info (GLib.File loc) {
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
}
