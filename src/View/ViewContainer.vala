/***
    ViewContainer.vala

    Authors:
       Mathijs Henquet <mathijs.henquet@gmail.com>
       ammonkey <am.monkeyd@gmail.com>

    Copyright (c) 2010 Mathijs Henquet
                  2017–2020 elementary, Inc. <https://elementary.io>

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor, Boston, MA 02110-1335 USA.
***/

public class Files.ViewContainer : Gtk.Box {
    private static int container_id;

    protected static int get_next_container_id () {
        return ++container_id;
    }

    static construct {
        container_id = -1;
    }

    private Gtk.Widget? _content;
    public Gtk.Widget? content {
        set {
            if (_content != null) {
                _content.unparent ();
                _content.destroy ();
            }

            _content = value;
            if (_content != null) {
                append (_content);
            }
        }

        get {
            return _content;
        }
    }

    private string label = "";
    public string tab_name {
        private set {
            if (label != value) { /* Do not signal if no change */
                label = value;
                tab_name_changed (value);
            }
        }
        get {
            return label;
        }
    }

    public int id { get; construct; }
    public bool can_show_folder { get; private set; default = false; }
    // private Files.Window? _window = null;
    public bool working { get; set; }
    public Files.Window window {
        get {
            return (Files.Window)(get_ancestor (typeof (Files.Window)));
        }
    }
    //     set {
    //         if (_window != null) {
    //             disconnect_window_signals ();
    //         }

    //         _window = value;
    //         connect_window_signals ();
    //     }
    // }

    public Files.MultiSlot multi_slot { get; construct; }
    public ViewMode view_mode {
        get {
            return multi_slot.view_mode;
        }
    }

    public GLib.File? location {
        get {
            return slot != null ? slot.location : null;
        }
    }

    public string uri {
        get {
            return slot != null ? slot.uri : "";
        }
    }

    public Files.Slot? slot {
        get {
            return  multi_slot.get_current_slot ();
        }
    }

    public bool locked_focus {
        get {
            return slot != null && slot.locked_focus;
        }
    }

    public bool can_go_back {
        get {
            return browser.get_can_go_back ();
        }
    }

    public bool can_go_forward {
        get {
            return browser.get_can_go_forward ();
        }
    }

    // public bool is_frozen {
    //     get {
    //         return slot == null || slot.is_frozen;
    //     }

    //     set {
    //         if (slot != null) {
    //             slot.is_frozen = value;
    //         }
    //     }
    // }

    public bool is_loading {get; private set; default = false;}

    private OverlayBar overlay_statusbar;
    private Browser browser;
    private GLib.List<GLib.File>? selected_locations = null;

    public signal void tab_name_changed (string tab_name);
    // public signal void loading (bool is_loading);
    public signal void active ();


    ~ViewContainer () {
        debug ("ViewContainer destruct");
    }

    construct {
        browser = new Browser ();
        id = ViewContainer.get_next_container_id ();
        multi_slot = new MultiSlot (this);
        overlay_statusbar = new OverlayBar (multi_slot.overlay); // Adds itself to overlay
    }

    public void folder_deleted (GLib.File deleted_file) {
        if (deleted_file.equal (this.location)) {
            if (!go_up ()) {
                close ();
                activate_action ("win.remove-content", "i", id);
            }
        }
    }
    /** By default changes the view mode to @mode at the same location.
        @loc - new location to show.
    **/
    public void set_location_and_mode (
        ViewMode mode,
        GLib.File? loc = null,
        GLib.File[]? to_select = null
    ) {
        // var aslot = get_current_slot ();
        if (mode != multi_slot.view_mode) { //Always the case on creation
            if (to_select != null) {
                selected_locations = null;
                foreach (GLib.File f in to_select) {
                    selected_locations.prepend (f);
                }
            } else {
                var selected_files = multi_slot.get_selected_files ();
                selected_locations = null;

                if (selected_files != null) {
                    selected_files.@foreach ((file) => {
                        selected_locations.prepend (file.location);
                    });
                }
            }
            if (slot != null) {
                slot.close ();
            }
            // multi_slot.clear ();
            multi_slot.view_mode = mode;
            is_loading = false;
        }

        if (mode != ViewMode.MULTI_COLUMN) {
            multi_slot.clear ();
        }

        multi_slot.add_location (loc ?? location);
        // connect_slot_signals (this.view);
        directory_is_loading (location);
        is_loading = true;

        slot.initialize_directory.begin ((obj, res) => {
            if (!slot.initialize_directory.end (res)) {
                return;
            }

            var dir = slot.directory;
            can_show_folder = dir.can_load;
            /* First deal with all cases where directory could not be loaded */
            if (!can_show_folder) {
                if (dir.is_recent && !Files.Preferences.get_default ().remember_history) {
                    content = new PrivacyModeOn (this);
                } else if (!dir.file.exists) {
                    if (!dir.is_trash) {
                        content = new DirectoryNotFound (slot.directory, this);
                    } else {
                        content = new Welcome (_("This Folder Does Not Exist"),
                                                    _("You cannot create a folder here."));
                    }
                } else if (!dir.network_available) {
                    content = new Welcome (_("The network is unavailable"),
                                                _("A working network is needed to reach this folder") + "\n\n" +
                                                dir.last_error_message);
                } else if (dir.permission_denied) {
                    content = new Welcome (_("This Folder Does Not Belong to You"),
                                                _("You don't have permission to view this folder."));
                } else if (!dir.file.is_connected) {
                    content = new Welcome (_("Unable to Mount Folder"),
                                                _("Could not connect to the server for this folder.") + "\n\n" +
                                                dir.last_error_message);
                } else if (slot.directory.state == Directory.State.TIMED_OUT) {
                    content = new Welcome (_("Unable to Display Folder Contents"),
                                                _("The operation timed out.") + "\n\n" + dir.last_error_message);
                } else {
                    content = new Welcome (_("Unable to Show Folder"),
                                                _("The server for this folder could not be located.") + "\n\n" +
                                                dir.last_error_message);
                }
            /* Now deal with cases where file (s) within the loaded folder has to be selected */
            } else if (selected_locations != null) {
                slot.select_glib_files (selected_locations, selected_locations.first ().data);
                selected_locations = null;
            } else if (dir.selected_file != null) {
                if (dir.selected_file.query_exists ()) {
                    focus_location_if_in_current_directory (dir.selected_file);
                } else {
                    content = new Welcome (_("File not Found"),
                                                _("The file selected no longer exists."));
                    can_show_folder = false;
                }
            } else {
                slot.show_first_item ();
            }

            if (can_show_folder) {
                content = multi_slot;
                var directory = dir.file;

                /* Only record valid folders (will also log Zeitgeist event) */
                browser.record_uri (directory.uri); /* will ignore null changes i.e reloading*/

                /* Notify plugins */
                /* infobars are added to the view, not the active slot */
                // plugins.directory_loaded (window, view, directory);
            } else {
                /* Save previous uri but do not record current one */
                browser.record_uri (null);
            }

            is_loading = false; /* Will cause topmenu to update */
        });

        set_active_state (true);
    }

    public void close () {
        // disconnect_signals ();
        multi_slot.clear ();
    }

    public bool go_up () {
        selected_locations = null;
        selected_locations.append (this.location);
        GLib.File parent = location;
        if (slot.directory.has_parent ()) { /* May not work for some protocols */
            parent = slot.directory.get_parent ();
        } else {
            var parent_path = FileUtils.get_parent_path_from_path (location.get_uri ());
            parent = FileUtils.get_file_for_path (parent_path);
        }

        /* Certain parents such as ftp:// will be returned as null as they are not browsable */
        if (parent != null) {
            open_location (parent, Files.OpenFlag.DEFAULT);
            return true;
        } else {
            return false;
        }
    }

    public void go_back (uint n) {
        string? path = browser.go_back (n);

        if (path != null) {
            selected_locations = null;
            selected_locations.append (this.location);
            open_location (GLib.File.new_for_commandline_arg (path), Files.OpenFlag.DEFAULT);
        }
    }

    public void go_forward (uint n) {
        string? path = browser.go_forward (n);

        if (path != null) {
            open_location (GLib.File.new_for_commandline_arg (path), Files.OpenFlag.DEFAULT);
        }
    }



    // private void connect_slot_signals (Files.AbstractSlot aslot) {
    //     aslot.active.connect (on_slot_active);
    //     aslot.path_changed.connect (on_slot_path_changed);
    //     aslot.new_container_request.connect (on_slot_new_container_request);
    //     aslot.selection_changing.connect (on_slot_selection_changing);
    //     aslot.update_selection.connect (on_slot_update_selection);
    //     aslot.directory_loaded.connect (on_slot_directory_loaded);
    // }

    // private void disconnect_slot_signals (Files.AbstractSlot aslot) {
    //     aslot.active.disconnect (on_slot_active);
    //     aslot.path_changed.disconnect (on_slot_path_changed);
    //     aslot.new_container_request.disconnect (on_slot_new_container_request);
    //     aslot.selection_changing.disconnect (on_slot_selection_changing);
    //     aslot.update_selection.disconnect (on_slot_update_selection);
    //     aslot.directory_loaded.disconnect (on_slot_directory_loaded);
    // }

    // private void on_slot_active (Files.AbstractSlot aslot, bool scroll, bool animate) {
    //     refresh_slot_info (slot.location);
    // }

    public void open_location (GLib.File loc, Files.OpenFlag flag) {
        switch (flag) {
            case Files.OpenFlag.NEW_TAB:
            case Files.OpenFlag.NEW_WINDOW:
                /* Must pass through this function in order to properly handle
                 * unusual characters properly */
                 activate_action ("win.path-change-request", "(su)", loc.get_uri (), flag);
                break;

            case Files.OpenFlag.NEW_ROOT:
                multi_slot.clear ();
                set_location_and_mode (view_mode, loc, null);
                break;

            case Files.OpenFlag.DEFAULT:
                set_location_and_mode (view_mode, loc, null);
                break;

            case Files.OpenFlag.APP:
                warning ("View Container cannot handle Files.OpenFlag.APP - ignoring");
                break;
        }
    }

    // public void on_slot_new_container_request (GLib.File loc, Files.OpenFlag flag) {
    //     switch (flag) {
    //         case Files.OpenFlag.NEW_TAB:
    //         case Files.OpenFlag.NEW_WINDOW:
    //             /* Must pass through this function in order to properly handle
    //              * unusual characters properly */
    //             activate_action ("win.path-change-request", "(su)", loc.get_uri (), flag);
    //             // window.uri_path_change_request (loc.get_uri (), flag);
    //             break;

    //         case Files.OpenFlag.DEFAULT:
    //         case Files.OpenFlag.NEW_ROOT:
    //         case Files.OpenFlag.APP:
    //             //Should already have been handled by Slot
    //             warning ("Unexpected File.OpenFlag - ignoring");
    //             break;
    //     }
    // }

    public void on_slot_path_changed (Files.AbstractSlot slot) {
        directory_is_loading (slot.location);
    }

    private void directory_is_loading (GLib.File loc) {
        overlay_statusbar.cancel ();
        overlay_statusbar.halign = Gtk.Align.END;
        refresh_slot_info (loc);

        can_show_folder = false;
        is_loading = true;
    }

    public void refresh_slot_info (GLib.File loc) {
        update_tab_name ();
        activate_action ("win.loading-uri", "s", loc.get_uri ());
        /* Do not update top menu (or record uri) unless folder loads successfully */
    }

   private void update_tab_name () {
        string? slot_path = Uri.unescape_string (this.uri);
        string tab_name = Files.INVALID_TAB_NAME;

        if (slot_path != null) {
            string protocol, path;
            FileUtils.split_protocol_from_path (slot_path, out protocol, out path);
            if (path == "" || path == Path.DIR_SEPARATOR_S) {
                tab_name = Files.protocol_to_name (protocol);
            } else if (protocol == "" && path == Environment.get_home_dir ()) {
                tab_name = _("Home");
            } else {
                tab_name = Path.get_basename (path);
            }
        }

        this.tab_name = tab_name;
        overlay_statusbar.hide ();
    }

    public void set_active_state (bool is_active, bool animate = true) {
        // var aslot = get_current_slot ();
        if (slot != null) {
            /* Since async loading it may not have been determined whether slot is loadable */
            slot.set_active_state (is_active, animate);
            if (is_active) {
                active ();
            }
        }
    }

    public void focus_location (GLib.File? loc,
                                bool no_path_change = false,
                                bool unselect_others = false) {

        /* This function navigates to another folder if necessary if
         * select_in_current_only is not set to true.
         */
        if (slot == null) {
            return;
        }
        /* Search can generate null focus requests if no match - deselect previous search selection */
        if (loc == null) {
            slot.set_all_selected (false);
            return;
        }

        /* Using file_a.equal (file_b) can fail to detect equivalent locations */
        // if (!(view is MultiSlot) && FileUtils.same_location (uri, loc.get_uri ())) {
        if (FileUtils.same_location (uri, loc.get_uri ())) {
            return;
        }

        var info = slot.lookup_file_info (loc);
        var filetype = FileType.UNKNOWN;
        if (info != null) { /* location is in the current folder */
            filetype = info.get_file_type ();
            if (filetype != FileType.DIRECTORY || no_path_change) {
                if (unselect_others) {
                    slot.set_all_selected (false);
                    selected_locations = null;
                }

                var list = new List<GLib.File> ();
                list.prepend (loc);
                slot.select_glib_files (list, loc);
                return;
            }
        } else if (no_path_change) { /* not in current, do not navigate to it*/
            slot.show_first_item (); /* Focus does not work with Gtk4 GridView */
            return;
        }
        /* Attempt to navigate to the location */
        if (loc != null) {
            open_location (loc, Files.OpenFlag.DEFAULT);
        }
    }

    public void focus_location_if_in_current_directory (GLib.File? loc,
                                                        bool unselect_others = false) {
        focus_location (loc, true, unselect_others);
    }

    public string get_root_uri () {
        return multi_slot.get_root_uri () ?? "";
    }

    public string get_tip_uri () {
        return multi_slot.get_tip_uri () ?? "";
    }

    public void reload () {
        if (slot != null) {
            slot.reload ();
        }
    }

    public Gee.List<string> get_go_back_path_list () {
        assert (browser != null);
        return browser.go_back_list ();
    }

    public Gee.List<string> get_go_forward_path_list () {
        assert (browser != null);
        return browser.go_forward_list ();
    }

    public new void grab_focus () {
        // is_frozen = false;
        if (can_show_folder && slot != null) {
            slot.grab_focus ();
        } else if (content != null) {
            content.grab_focus ();
        }
    }

    public void on_slot_selection_changing () {
        overlay_statusbar.selection_changing ();
    }

    public void on_slot_update_selection (List<Files.File> selected_files) {
        overlay_statusbar.update_selection (selected_files);
    }

//TODO Use EventController
//     private bool on_button_press_event (Gdk.EventButton event) {
//         Gdk.ModifierType state;
//         event.get_state (out state);
//         uint button;
//         event.get_button (out button);
//         var mods = state & Gtk.accelerator_get_default_mod_mask ();
//         bool result = false;
//         switch (button) {
//             /* Extra mouse button actions */
//             case 6:
//             case 8:
//                 if (mods == 0) {
//                     result = true;
//                     go_back ();
//                 }
//                 break;

//             case 7:
//             case 9:
//                 if (mods == 0) {
//                     result = true;
//                     go_forward ();
//                 }
//                 break;

//             default:
//                 break;
//         }

//         return result;
//     }
// }
}
