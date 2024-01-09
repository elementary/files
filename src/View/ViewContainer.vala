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

namespace Files.View {
    public class ViewContainer : Gtk.Box {
        public Gtk.Widget? content_item;
        public bool can_show_folder { get; private set; default = false; }
        private View.Window? _window = null;
        public View.Window window {
            get {
                return _window;
            }

            set construct {
                if (_window != null) {
                    disconnect_window_signals ();
                }

                _window = value;
                _window.folder_deleted.connect (on_folder_deleted);
            }
        }

        public Files.AbstractSlot? view = null;
        public ViewMode view_mode = ViewMode.INVALID;

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

        public Files.AbstractSlot? slot {
            get {
                return view != null ? view.get_current_slot () : null;
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

        public bool is_frozen {
            get {
                return slot == null || slot.is_frozen;
            }

            set {
                if (slot != null) {
                    slot.is_frozen = value;
                }
            }
        }

        public Gtk.Widget? content {
            set {
                if (content_item != null) {
                    remove (content_item);
                }

                content_item = value;

                if (content_item != null) {
                    add (content_item);
                    content_item.show_all ();
                }
            }
            get {
                return content_item;
            }
        }

        // Either the path or a special name or fallback if invalid
        // Window will use as little as possible to distinguish tabs
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

        public bool is_loading {get; private set; default = false;}

        private View.OverlayBar overlay_statusbar;
        private Browser browser;
        private GLib.List<GLib.File>? selected_locations = null;

        public signal void tab_name_changed (string tab_name);
        public signal void loading (bool is_loading);
        public signal void active ();

        /* Initial location now set by Window.make_tab after connecting signals */
        public ViewContainer (View.Window win) {
            Object (
                window: win
            );
        }

        construct {
            browser = new Browser ();
            loading.connect ((loading) => {
                is_loading = loading;
            });

            var button_controller = new Gtk.GestureMultiPress (this) {
                button = 0,
                propagation_phase = CAPTURE
            };
            button_controller.pressed.connect ((n_press, x, y) => {
                Gdk.ModifierType state;
                Gtk.get_current_event_state (out state);
                var button = button_controller.get_button ();
                var mods = state & Gtk.accelerator_get_default_mod_mask ();
                switch (button) {
                    /* Extra mouse button actions */
                    case 6:
                    case 8:
                        if (mods == 0) {
                            button_controller.set_state (CLAIMED);
                            go_back ();
                        }
                        break;

                    case 7:
                    case 9:
                        if (mods == 0) {
                            button_controller.set_state (CLAIMED);
                            go_forward ();
                        }
                        break;

                    default:
                        break;
                }
            });
        }

        ~ViewContainer () {
            debug ("ViewContainer destruct");
        }

        private void disconnect_window_signals () {
            if (window != null) {
                window.folder_deleted.disconnect (on_folder_deleted);
            }
        }

        private void on_folder_deleted (GLib.File deleted) {
            if (deleted.equal (this.location) && !go_up ()) {
                close ();
                window.remove_content (this);
            }
        }

        public void close () {
            disconnect_slot_signals (view);
            disconnect_window_signals ();
            view.close ();
        }

        public bool go_up () {
            selected_locations = null;
            selected_locations.append (this.location);
            GLib.File parent = location;
            if (view.directory.has_parent ()) { /* May not work for some protocols */
                parent = view.directory.get_parent ();
            } else {
                var parent_path = FileUtils.get_parent_path_from_path (location.get_uri ());
                parent = FileUtils.get_file_for_path (parent_path);
            }

            /* Certain parents such as ftp:// will be returned as null as they are not browsable */
            if (parent != null) {
                open_location (parent);
                return true;
            } else {
                return false;
            }
        }

        public void go_back (int n = 1) {
            string? path = browser.go_back (n);

            if (path != null) {
                selected_locations = null;
                selected_locations.append (this.location);
                open_location (GLib.File.new_for_commandline_arg (path));
            }
        }

        public void go_forward (int n = 1) {
            string? path = browser.go_forward (n);

            if (path != null) {
                open_location (GLib.File.new_for_commandline_arg (path));
            }
        }

        // the locations in @to_select must be children of @loc
        public void add_view (ViewMode mode, GLib.File loc, GLib.File[]? to_select = null) {
            view_mode = mode;

            if (to_select != null) {
                selected_locations = null;
                foreach (GLib.File f in to_select) {
                    selected_locations.prepend (f);
                }
            }

            if (mode == ViewMode.MILLER_COLUMNS) {
                this.view = new Miller (loc, this, mode);
            } else {
                this.view = new Slot (loc, this, mode);
            }

            overlay_statusbar = new View.OverlayBar (view.overlay) {
                no_show_all = true
            };

            view.active.connect (on_slot_active);
            view.path_changed.connect (on_slot_path_changed);
            view.new_container_request.connect (on_slot_new_container_request);
            view.selection_changed.connect (on_slot_selection_changed);
            view.directory_loaded.connect (on_slot_directory_loaded);

            directory_is_loading (loc);
            slot.initialize_directory ();
            show_all ();

            /* NOTE: slot is created inactive to avoid bug during restoring multiple tabs
             * The slot becomes active when the tab becomes current */
        }

        /** By default changes the view mode to @mode at the same location.
            @loc - new location to show.
        **/
        public void change_view_mode (ViewMode mode, GLib.File? loc = null) {
            var aslot = get_current_slot ();
            if (aslot == null || mode == view_mode) {
                return;
            }

            aslot.close ();
            view_mode = mode;
            loading (false);
            store_selection ();
            /* Make sure async loading and thumbnailing are cancelled and signal handlers disconnected */
            disconnect_slot_signals (view);
            add_view (mode, loc ?? location);
            /* Slot is created inactive so we activate now since we must be the current tab
             * to have received a change mode instruction */
            set_active_state (true);
            /* Do not update top menu (or record uri) unless folder loads successfully */
        }


        private void disconnect_slot_signals (Files.AbstractSlot aslot) {
            aslot.active.disconnect (on_slot_active);
            aslot.path_changed.disconnect (on_slot_path_changed);
            aslot.new_container_request.disconnect (on_slot_new_container_request);
            aslot.selection_changed.disconnect (on_slot_selection_changed);
            aslot.directory_loaded.disconnect (on_slot_directory_loaded);
        }

        private void on_slot_active (Files.AbstractSlot aslot, bool scroll, bool animate) {
            refresh_slot_info (slot.location);
        }

        private void open_location (GLib.File loc,
                                    Files.OpenFlag flag = Files.OpenFlag.NEW_ROOT) {

            switch ((Files.OpenFlag)flag) {
                case Files.OpenFlag.NEW_TAB:
                case Files.OpenFlag.NEW_WINDOW:
                    /* Must pass through this function in order to properly handle unusual characters properly */
                    window.uri_path_change_request (loc.get_uri (), flag);
                    break;

                case Files.OpenFlag.NEW_ROOT:
                    view.user_path_change_request (loc, true);
                    break;

                default:
                    view.user_path_change_request (loc, false);
                    break;
            }
        }

        private void on_slot_new_container_request (GLib.File loc, Files.OpenFlag flag = Files.OpenFlag.NEW_ROOT) {
            open_location (loc, flag);
        }

        public void on_slot_path_changed (Files.AbstractSlot slot) {
            directory_is_loading (slot.location);
        }

        private void directory_is_loading (GLib.File loc) {
            overlay_statusbar.cancel ();
            overlay_statusbar.halign = Gtk.Align.END;
            refresh_slot_info (loc);

            can_show_folder = false;
            loading (true);
        }

        private void refresh_slot_info (GLib.File loc) {
            update_tab_name ();
            window.loading_uri (loc.get_uri ()); /* Updates labels as well */
            /* Do not update top menu (or record uri) unless folder loads successfully */
        }

       private void update_tab_name () {
            var tab_name = Files.INVALID_TAB_NAME;

            string protocol, path;
            FileUtils.split_protocol_from_path (this.uri, out protocol, out path);
            if (path == "" || path == Path.DIR_SEPARATOR_S) {
                tab_name = Files.protocol_to_name (protocol);
            } else if (protocol == "" && path == Environment.get_home_dir ()) {
                tab_name = _("Home");
            } else {
                tab_name = Uri.unescape_string (path);
            }

            this.tab_name = tab_name;
            overlay_statusbar.hide ();
        }


        public void on_slot_directory_loaded (Directory dir) {
            can_show_folder = dir.can_load;
            /* First deal with all cases where directory could not be loaded */
            if (!can_show_folder) {
                if (dir.is_recent && !Files.Preferences.get_default ().remember_history) {
                    content = new View.PrivacyModeOn (this);
                } else if (!dir.file.exists) {
                    if (!dir.is_trash) {
                        content = new DirectoryNotFound (slot.directory, this);
                    } else {
                        content = new Welcome (
                            _("This Folder Does Not Exist"),
                            _("You cannot create a folder here.")
                        );
                    }
                } else if (!dir.network_available) {
                    content = new Welcome (
                        _("The network is unavailable"),
                        "%s\n\n%s".printf (
                            _("A working network is needed to reach this folder"),
                            dir.last_error_message
                        )
                    );
                } else if (dir.permission_denied) {
                    content = new Welcome (
                        _("This Folder Does Not Belong to You"),
                        _("You don't have permission to view this folder.")
                    );
                } else if (!dir.file.is_connected) {
                    content = new Welcome (
                        _("Unable to Mount Folder"),
                        "%s\n\n%s".printf (
                            _("Could not connect to the server for this folder."),
                            dir.last_error_message
                        )
                    );
                } else if (slot.directory.state == Directory.State.TIMED_OUT) {
                    content = new Welcome (
                        _("Unable to Display Folder Contents"),
                        "%s\n\n%s".printf (
                            _("The operation timed out."),
                            dir.last_error_message
                        )
                    );
                } else {
                    content = new Welcome (
                        _("Unable to Show Folder"),
                        "%s\n\n%s".printf (
                            _("The server for this folder could not be located."),
                            dir.last_error_message
                        )
                    );
                }
            /* Now deal with cases where file (s) within the loaded folder has to be selected */
            } else if (selected_locations != null) {
                view.select_glib_files (selected_locations, selected_locations.first ().data);
                selected_locations = null;
            } else if (dir.selected_file != null) {
                if (dir.selected_file.query_exists ()) {
                    focus_location_if_in_current_directory (dir.selected_file);
                } else {
                    content = new Welcome (
                        _("File not Found"),
                        _("The file selected no longer exists.")
                    );
                    can_show_folder = false;
                }
            } else {
                view.focus_first_for_empty_selection (false); /* Does not select */
            }

            if (can_show_folder) {
                content = view.get_content_box ();
                var directory = dir.file;

                /* Only record valid folders (will also log Zeitgeist event) */
                browser.record_uri (directory.uri); /* will ignore null changes i.e reloading*/

                /* Notify plugins */
                /* infobars are added to the view, not the active slot */
                plugins.directory_loaded (window, view, directory);
            } else {
                /* Save previous uri but do not record current one */
                browser.record_uri (null);
            }

            loading (false); /* Will cause topmenu to update */
        }

        private void store_selection () {
            unowned GLib.List<Files.File> selected_files = view.get_selected_files ();
            selected_locations = null;

            if (selected_files != null) {
                selected_files.@foreach ((file) => {
                    selected_locations.prepend (file.location);
                });
            }
        }

        public unowned Files.AbstractSlot? get_current_slot () {
           return view != null ? view.get_current_slot () : null;
        }

        public void set_active_state (bool is_active, bool animate = true) {
            var aslot = get_current_slot ();
            if (aslot != null) {
                /* Since async loading it may not have been determined whether slot is loadable */
                aslot.set_active_state (is_active, animate);
                if (is_active) {
                    active ();
                }
            }
        }

        private void set_all_selected (bool select_all) {
            var aslot = get_current_slot ();
            if (aslot != null) {
                aslot.set_all_selected (select_all);
            }
        }

        public void focus_location (GLib.File? loc,
                                    bool no_path_change = false,
                                    bool unselect_others = false) {

            /* This function navigates to another folder if necessary if
             * select_in_current_only is not set to true.
             */
            var aslot = get_current_slot ();
            if (aslot == null) {
                return;
            }
            /* Search can generate null focus requests if no match - deselect previous search selection */
            if (loc == null) {
                set_all_selected (false);
                return;
            }

            /* Using file_a.equal (file_b) can fail to detect equivalent locations */
            if (!(view is Miller) && FileUtils.same_location (uri, loc.get_uri ())) {
                return;
            }

            FileInfo? info = aslot.lookup_file_info (loc);
            FileType filetype = FileType.UNKNOWN;
            if (info != null) { /* location is in the current folder */
                filetype = info.get_file_type ();
                if (filetype != FileType.DIRECTORY || no_path_change) {
                    if (unselect_others) {
                        aslot.set_all_selected (false);
                        selected_locations = null;
                    }

                    var list = new List<GLib.File> ();
                    list.prepend (loc);
                    aslot.select_glib_files (list, loc);
                    return;
                }
            } else if (no_path_change) { /* not in current, do not navigate to it*/
                view.focus_first_for_empty_selection (false); /* Just focus first file */
                return;
            }
            /* Attempt to navigate to the location */
            if (loc != null) {
                open_location (loc);
            }
        }

        public void focus_location_if_in_current_directory (GLib.File? loc,
                                                            bool unselect_others = false) {
            focus_location (loc, true, unselect_others);
        }

        public string get_root_uri () {
            string path = "";
            if (view != null) {
                path = view.get_root_uri () ?? "";
            }

            return path;
        }

        public string get_tip_uri () {
            string path = "";
            if (view != null) {
                path = view.get_tip_uri () ?? "";
            }

            return path;
        }

        // Saves selected locations to be restored after reloading
        // Called by all slots that will reload
        public AbstractSlot? prepare_reload () {
            var slot = get_current_slot ();
            if (slot != null) {
                selected_locations = null;
                foreach (Files.File file in slot.get_selected_files ()) {
                    selected_locations.prepend (file.location);
                }
            }

            return slot;
        }

        public Gee.List<string> get_go_back_path_list () {
            return browser.go_back_list ();
        }

        public Gee.List<string> get_go_forward_path_list () {
            return browser.go_forward_list ();
        }

        public new void grab_focus () {
            is_frozen = false;
            if (can_show_folder && view != null) {
                view.grab_focus ();
            } else {
                content.grab_focus ();
            }
        }

        private void on_slot_selection_changed (GLib.List<unowned Files.File> files) {
            overlay_statusbar.selection_changed (files);
        }
    }
}
