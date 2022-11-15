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

namespace Files {
public class Slot : Files.AbstractSlot {
    public Files.ViewContainer ctab { get; construct; }
    public ViewMode mode { get; construct; }
    public Gtk.Paned hpaned { get; construct; }
    public int width { get; private set; }
    public Files.ViewInterface? view_widget { get; set; }
    public bool is_active {get; protected set; default = false;}
    public int displayed_files_count {
        get {
            if (directory != null && directory.state == Directory.State.LOADED) {
                return (int)(directory.displayed_files_count);
            }

            return -1;
        }
    }

    public Files.Window window {
        get {
            return ctab.window;
        }
    }

    private int preferred_column_width;
    private uint reload_timeout_id = 0;
    private uint path_change_timeout_id = 0;
    private bool original_reload_request = false;
    private Gtk.Label empty_label;
    private const string EMPTY_MESSAGE = _("This Folder Is Empty");
    private const string EMPTY_TRASH_MESSAGE = _("Trash Is Empty");
    private const string EMPTY_RECENT_MESSAGE = _("There Are No Recent Files");
    private const string DENIED_MESSAGE = _("Access Denied");

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
    // public signal void miller_slot_request (GLib.File file, bool make_root);
    public signal void size_change ();

    public Slot (GLib.File? _location, ViewContainer _ctab, ViewMode _mode) {
        Object (
            ctab: _ctab,
            mode: _mode
        );
warning ("Create slot mode %s", _mode.to_string ());
        set_up_directory (_location ?? GLib.File.new_for_commandline_arg (Environment.get_home_dir ()));
        //Directory is initialized by ctab
        // is_frozen = true;
    }

    ~Slot () {
        debug ("Slot %i destruct", slot_number);
        while (hpaned.get_last_child () != null) {
            hpaned.get_last_child ().unparent ();
        }
    }

    construct {
        empty_label = new Gtk.Label ("") {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER
        };
        empty_label.add_css_class (Granite.STYLE_CLASS_H2_LABEL);

        hpaned = new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
            wide_handle = true
        };

        switch (mode) {
            case ViewMode.ICON:
                view_widget = new Files.GridView (this);
                break;
            case ViewMode.LIST:
                view_widget = new Files.GridView (this);
                break;
            case ViewMode.MULTI_COLUMN:
                var gv = new Files.GridView (this);
                gv.grid_view.max_columns = 1;
                view_widget = gv;
                break;

            default:
                view_widget = new Files.GridView (this);
                break;
        }

        add_main_child (view_widget);
        hpaned.start_child = content_box;

        if (mode == ViewMode.MULTI_COLUMN) {
            preferred_column_width = Files.column_view_settings.get_int ("preferred-column-width");
            width = preferred_column_width;
            view_widget.width_request = preferred_column_width;

            var end_child = new Gtk.Label ("");
            end_child.width_request = preferred_column_width;
            hpaned.end_child = end_child;
            hpaned.shrink_end_child = false;
            hpaned.resize_end_child = true;
            hpaned.shrink_start_child = false;
            hpaned.resize_start_child = false;
            hpaned.position = preferred_column_width;
        }

        view_widget.path_change_request.connect (on_view_path_change_request);
        view_widget.selection_changed.connect (on_view_widget_selection_changed);

        //AbstractSlot signal
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

    uint selection_changed_timeout_id = 0;
    List<Files.File> selected_files = null; // Maintain a reference for overlaybar
    private void on_view_widget_selection_changed () {
        ctab.on_slot_selection_changing ();
        // selection_changing ();

        if (selection_changed_timeout_id > 0) {
            Source.remove (selection_changed_timeout_id);
        }

        selection_changed_timeout_id = Timeout.add (100, () => {
            selection_changed_timeout_id = 0;
            view_widget.get_selected_files (out selected_files);
            ctab.on_slot_update_selection (selected_files);
            // update_selection (selected_files); // Updates properties overlay
            return Source.REMOVE;
        });
    }

    // Signal could be from subdirectory as well as slot directory
    private void connect_directory_handlers (Directory dir) {
        dir.file_added.connect (on_directory_file_added);
        dir.file_changed.connect (on_directory_file_changed);
        dir.file_deleted.connect (on_directory_file_deleted);
        connect_directory_loading_handlers (dir);
        dir.need_reload.connect (on_directory_need_reload);
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
        // dir.done_loading.disconnect (on_directory_done_loading);
        dir.need_reload.disconnect (on_directory_need_reload);
    }

    private void connect_directory_loading_handlers (Directory dir) {
        dir.file_loaded.connect (on_directory_file_loaded);
        // dir.done_loading.connect (on_directory_done_loading);
    }

    private void disconnect_directory_loading_handlers (Directory dir) {
        dir.file_loaded.disconnect (on_directory_file_loaded);
        // dir.done_loading.disconnect (on_directory_done_loading);
    }


    // * Directory signal handlers moved from DirectoryView not requiring changes
    // to Window
    private void on_directory_file_added (Directory dir, Files.File? file) {
        if (file != null) {
            view_widget.add_file (file); //FIXME Should we select files added after load?
        }
    }

    private void on_directory_file_loaded (Directory dir, Files.File file) {
        if (file != null) {
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

    // Called by ViewContainer after handling loading directory
    public void after_directory_done_loading (Directory dir) {
        /* Should only be called on directory creation or reload */
        disconnect_directory_loading_handlers (dir); //Necessary?
        if (this.directory.can_load) {
            if (in_recent) {
                view_widget.sort_type = Files.SortType.MODIFIED;
                view_widget.sort_reversed = false;
            } else if (this.directory.file.info != null) {
                view_widget.sort_type = this.directory.file.sort_type;
                view_widget.sort_reversed = this.directory.file.sort_reversed;
            }
        }

        // ctab.on_slot_directory_loaded (dir); // Signal to ViewContainer //TODO Replace with direct call
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
        if (mode == ViewMode.MULTI_COLUMN) {
            if (dir.is_empty ()) { /* No files in the file cache */
                int min, nat;
                empty_label.measure (Gtk.Orientation.HORIZONTAL, 100, out min, out nat, null, null);
                width = nat + 48;
            } else {
                width = preferred_column_width;
            }

            // width += view_widget.zoom_level.to_icon_size () + 64; /* allow some extra room for icon padding and right margin*/

            // /* Allow extra room for MESSAGE_CLASS styling of special messages */
            // if (dir.is_empty () || dir.permission_denied) {
            //     width += width;
            // }

            size_change ();
            hpaned.set_position (width);

            // if (colpane.get_realized ()) {
            //     colpane.queue_draw ();
            // }
        }
    }

    private void on_directory_need_reload (Directory dir, bool original_request) {
        view_widget.clear ();
        connect_directory_loading_handlers (dir);
        /* view and slot are unfrozen when done loading signal received */
        // path_changed ();
        ctab.on_slot_path_changed (this);
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
warning ("creating directory %s", loc.get_uri ());
        directory = Directory.from_gfile (loc);
        // assert (directory != null);
        connect_directory_handlers (directory);
    }

    private void on_view_path_change_request (GLib.File loc, Files.OpenFlag flag) {
        cancel_timeouts ();
        ctab.open_location (loc, flag);
        // switch (flag) {
        //     case Files.OpenFlag.DEFAULT:
        //         // if (mode == ViewMode.MULTI_COLUMN) {
        //         //     miller_slot_request (loc, false); /* signal to parent MillerView */
        //         // } else {
        //         //     user_path_change_request (loc); /* Handle ourselves */
        //         // }
        //         ctab.open_location (loc, flag);
        //         break;
        //     case Files.OpenFlag.NEW_TAB:
        //     case Files.OpenFlag.NEW_WINDOW:
        //         ctab.open_location (loc, flag);
        //         // ctab.on_slot_new_container_request (loc, flag);
        //         // new_container_request (loc, flag);
        //         break;
        //     case Files.OpenFlag.NEW_ROOT:
        //         // if (mode == ViewMode.MULTI_COLUMN) {
        //         //     miller_slot_request (loc, true); /* signal to parent MillerView */
        //         // } else {
        //         //     user_path_change_request (loc); /* Handle ourselves */
        //         // }
        //         ctab.open_location (loc, flag);
        //         break;
        //     case Files.OpenFlag.APP:
        //         warning ("Unexpected flag");
        //         break;
        // }
    }

    // public override void user_path_change_request (GLib.File loc) {
    // /** Only this function must be used to change or reload the path **/
    //     view_widget.clear ();
    //     var old_dir = directory;
    //     disconnect_directory_handlers (old_dir);
    //     set_up_directory (loc); // Connects signals
    //     initialize_directory ();

    //     ctab.on_slot_path_changed (this);
    // }

    public async bool initialize_directory () {
warning ("initialising %s", directory.file.basename);
        if (directory.is_loading ()) {
            /* This can happen when restoring duplicate tabs */
            warning ("Slot.initialize_directory () called when directory already loading - ignoring");
            return false;
        }
        // /* view and slot are unfrozen when done loading signal received */
        // is_frozen = true;
        yield directory.init ();
        return true;
    }

    public override void reload (bool non_local_only = false) {
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

    public override List<Files.File> get_selected_files () {
        List<Files.File> selected_files = null;
        if (view_widget != null) {
            view_widget.get_selected_files (out selected_files);
        }

        return (owned)selected_files;
    }

    public override void select_glib_files (GLib.List<GLib.File> locations, GLib.File? focus_location) {
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
}
