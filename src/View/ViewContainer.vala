/***
    ViewContainer.vala

    Authors:
       Mathijs Henquet <mathijs.henquet@gmail.com>
       ammonkey <am.monkeyd@gmail.com>

    Copyright (c) 2010 Mathijs Henquet

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

using Marlin;

namespace Marlin.View {
    public class ViewContainer : Gtk.Overlay {

        public Gtk.Widget? content_item;
        public bool can_show_folder { get; private set; default = false; }
        private Marlin.View.Window? _window = null;
        public Marlin.View.Window window {
            get {
                return _window;
            }

            set {
                if (_window != null) {
                    disconnect_window_signals ();
                }

                _window = value;
                connect_window_signals ();
            }
        }

        public GOF.AbstractSlot? view = null;
        public Marlin.ViewMode view_mode = Marlin.ViewMode.INVALID;

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

        public GOF.AbstractSlot? slot {
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

        public bool is_loading {get; private set; default = false;}

        public OverlayBar overlay_statusbar;
        private Browser browser;
        private GLib.List<GLib.File>? selected_locations = null;

        public signal void tab_name_changed (string tab_name);
        public signal void loading (bool is_loading);
        public signal void active ();
        /* path-changed signal no longer used */

        /* Initial location now set by Window.make_tab after connecting signals */
        public ViewContainer (Marlin.View.Window win) {
            window = win;
            overlay_statusbar = new OverlayBar (this);
            browser = new Browser ();

            /* Override background color to support transparency on overlay widgets */
            Gdk.RGBA transparent = {0, 0, 0, 0};
            override_background_color (0, transparent);

            set_events (Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);
            connect_signals ();
        }

        ~ViewContainer () {
            debug ("ViewContainer destruct");
        }

        private void connect_signals () {
            enter_notify_event.connect (on_enter_notify_event);
            loading.connect ((loading) => {
                is_loading = loading;
            });
        }

        private void connect_window_signals () {
            if (window != null) {
                window.folder_deleted.connect (on_folder_deleted);
            }
        }

        private void disconnect_signals () {
            disconnect_window_signals ();
        }

        private void disconnect_window_signals () {
            if (window != null) {
                window.folder_deleted.disconnect (on_folder_deleted);
            }
        }

        private void on_folder_deleted (GLib.File deleted) {
            if (deleted.equal (this.location)) {
                if (!go_up ()) {
                    close ();
                    window.remove_tab (this);
                }
            }
        }

        public void close () {
            disconnect_signals ();
            view.close ();
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

        public bool go_up () {
            selected_locations = null;
            selected_locations.append (this.location);
            GLib.File parent = location;
            if (view.directory.has_parent ()) { /* May not work for some protocols */
                parent = view.directory.get_parent ();
            } else {
                var parent_path = PF.FileUtils.get_parent_path_from_path (location.get_uri ());
                parent = PF.FileUtils.get_file_for_path (parent_path);
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
                open_location (File.new_for_commandline_arg (path));
            }
        }

        public void go_forward (int n = 1) {
            string? path = browser.go_forward (n);

            if (path != null) {
                open_location (File.new_for_commandline_arg (path));
            }
        }

        public void add_view (Marlin.ViewMode mode, GLib.File loc) {
            assert (view == null);
            assert (loc != null);

            overlay_statusbar.cancel ();
            view_mode = mode;
            overlay_statusbar.showbar = view_mode != Marlin.ViewMode.LIST;

            if (mode == Marlin.ViewMode.MILLER_COLUMNS) {
                this.view = new Miller (loc, this, mode);
            } else {
                this.view = new Slot (loc, this, mode);
            }

            connect_slot_signals (this.view);
            directory_is_loading (loc);
            slot.initialize_directory ();
            show_all ();
            /* NOTE: slot is created inactive to avoid bug during restoring multiple tabs
             * The slot becomes active when the tab becomes current */
        }

        /** By default changes the view mode to @mode at the same location.
            @loc - new location to show.
        **/
        public void change_view_mode (Marlin.ViewMode mode, GLib.File? loc = null) {
            var aslot = get_current_slot ();
            assert (aslot != null);
            if (loc == null) {
                loc = location;
            }

            if (mode != view_mode) {
                before_mode_change ();
                add_view (mode, loc);
                after_mode_change ();
            }
        }

        private void before_mode_change () {
            store_selection ();
            /* Make sure async loading and thumbnailing are cancelled and signal handlers disconnected */
            view.close ();
            disconnect_slot_signals (view);
            content = null; /* Make sure old slot and directory view are destroyed */
            view = null; /* Pre-requisite for add view */
            loading (false);
        }

        private void after_mode_change () {
            /* Slot is created inactive so we activate now since we must be the current tab
             * to have received a change mode instruction */
            set_active_state (true);
            /* Do not update top menu (or record uri) unless folder loads successfully */
        }

        private void connect_slot_signals (GOF.AbstractSlot aslot) {
            aslot.active.connect (on_slot_active);
            aslot.path_changed.connect (on_slot_path_changed);
            aslot.new_container_request.connect (on_slot_new_container_request);
            aslot.selection_changed.connect (on_slot_selection_changed);
            aslot.directory_loaded.connect (on_slot_directory_loaded);
            aslot.item_hovered.connect (on_slot_item_hovered);
        }

        private void disconnect_slot_signals (GOF.AbstractSlot aslot) {
            aslot.active.disconnect (on_slot_active);
            aslot.path_changed.disconnect (on_slot_path_changed);
            aslot.new_container_request.disconnect (on_slot_new_container_request);
            aslot.selection_changed.disconnect (on_slot_selection_changed);
            aslot.directory_loaded.disconnect (on_slot_directory_loaded);
            aslot.item_hovered.disconnect (on_slot_item_hovered);
        }

        private void on_slot_active (GOF.AbstractSlot aslot, bool scroll, bool animate) {
            refresh_slot_info (slot.location);
        }

        private void open_location (GLib.File loc,
                                    Marlin.OpenFlag flag = Marlin.OpenFlag.NEW_ROOT) {

            switch ((Marlin.OpenFlag)flag) {
                case Marlin.OpenFlag.NEW_TAB:
                    this.window.add_tab (loc, view_mode);
                    break;

                case Marlin.OpenFlag.NEW_WINDOW:
                    this.window.add_window (loc, view_mode);
                    break;

                default:
                        view.user_path_change_request (loc,
                                                       flag == Marlin.OpenFlag.NEW_ROOT);

                    break;
            }
        }

        private void on_slot_new_container_request (GLib.File loc, Marlin.OpenFlag flag = Marlin.OpenFlag.NEW_ROOT) {
            open_location (loc, flag);
        }

        public void on_slot_path_changed (GOF.AbstractSlot slot) {
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
            window.loading_uri (loc.get_uri ());
            window.update_labels (loc.get_parse_name (), tab_name);
            /* Do not update top menu (or record uri) unless folder loads successfully */
        }

       private void update_tab_name () {
            string? slot_path = Uri.unescape_string (this.uri);
            string? tab_name = null;

            if (slot_path != null) {
                if (this.location.get_path () == null) {
                    tab_name = Marlin.protocol_to_name (this.uri);
                } else {
                    try {
                        var fn = Filename.from_uri (slot_path);
                        if (fn == Environment.get_home_dir ()) {
                            tab_name = _("Home");
                        } else if (fn == "/") {
                            tab_name = _("File System");
                        }
                    } catch (ConvertError e) {}

                    if (tab_name == null) {
                        tab_name = Path.get_basename (slot_path);
                    }
                }
            }

            if (tab_name == null) {
                tab_name = Marlin.INVALID_TAB_NAME;
            } else if (Posix.getuid () == 0) {
                    tab_name = tab_name + " " + _("(as Administrator)");
            }

            this.tab_name = tab_name;

            overlay_statusbar.hide ();
        }


        public void on_slot_directory_loaded (GOF.Directory.Async dir) {
            can_show_folder = dir.can_load;

            /* First deal with all cases where directory could not be loaded */
            if (!can_show_folder) {
                if (!dir.file.exists) {
                    if (!dir.is_trash) {
                        content = new DirectoryNotFound (slot.directory, this);
                    } else {
                        content = new Marlin.View.Welcome (_("This Folder Does Not Exist"),
                                                           _("You cannot create a folder here."));
                    }
                } else if (!dir.network_available) {
                    content = new Marlin.View.Welcome (_("The network is unavailable"),
                                                       _("A working network is needed to reach this folder") + "\n\n" + dir.last_error_message);
                } else if (dir.permission_denied) {
                    content = new Marlin.View.Welcome (_("This Folder Does Not Belong to You"),
                                                       _("You don't have permission to view this folder."));
                } else if (!dir.file.is_connected) {
                    content = new Marlin.View.Welcome (_("Unable to Mount Folder"),
                                                       _("Could not connect to the server for this folder.") + "\n\n" + dir.last_error_message);
                } else if (slot.directory.state == GOF.Directory.Async.State.TIMED_OUT) {
                    content = new Marlin.View.Welcome (_("Unable to Display Folder Contents"),
                                                       _("The operation timed out.") + "\n\n" + dir.last_error_message);
                } else {
                    content = new Marlin.View.Welcome (_("Unable to Show Folder"),
                                                       _("The server for this folder could not be located.") + "\n\n" + dir.last_error_message);
                }
            /* Now deal with cases where file (s) within the loaded folder has to be selected */
            } else if (selected_locations != null) {
                view.select_glib_files (selected_locations, selected_locations.first ().data);
                selected_locations = null;
            } else if (dir.selected_file != null) {
                if (dir.selected_file.query_exists ()) {
                    focus_location_if_in_current_directory (dir.selected_file);
                } else {
                    content = new Marlin.View.Welcome (_("File not Found"),
                                                       _("The file selected no longer exists."));
                    can_show_folder = false;
                }
            }

            if (can_show_folder) {
                assert (view != null);
                content = view.get_content_box ();

                /* Only record valid folders (will also log Zeitgeist event) */
                browser.record_uri (dir.file.uri); /* will ignore null changes i.e reloading*/

                /* Notify plugins */
                Object[] data = new Object[3];
                data[0] = window;
                /* infobars are added to the view, not the active slot */
                data[1] = view;
                data[2] = dir.file;

                plugins.directory_loaded ((void*) data);
            } else {
                /* Save previous uri but do not record current one */
                browser.record_uri (null);
            }

            loading (false); /* Will cause topmenu to update */
            overlay_statusbar.update_hovered (null); /* Prevent empty statusbar showing */
        }

        private void store_selection () {
            unowned GLib.List<unowned GOF.File> selected_files = view.get_selected_files ();
            selected_locations = null;

            if (selected_files != null) {
                selected_files.@foreach ((file) => {
                    selected_locations.prepend (GLib.File.new_for_uri (file.uri));
                });
            }
        }

        public unowned GOF.AbstractSlot? get_current_slot () {
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

            if (location.equal (loc)) {
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
                    var list = new List<File> ();
                    list.prepend (loc);
                    aslot.select_glib_files (list, loc);
                    return;
                }
            } else if (no_path_change) { /* not in current, do not navigate to it*/
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
            if (view != null)
                path = view.get_root_uri () ?? "";

            return path;
        }

        public string get_tip_uri () {
            string path = "";
            if (view != null)
                path = view.get_tip_uri () ?? "";

            return path;
        }

        public void reload () {
            var slot = get_current_slot ();
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
            is_frozen = false;
            if (can_show_folder && view != null)
                view.grab_focus ();
            else
                content.grab_focus ();
        }

        private void on_slot_item_hovered (GOF.File? file) {
            overlay_statusbar.update_hovered (file);
        }

        private void on_slot_selection_changed (GLib.List<GOF.File> files) {
            overlay_statusbar.selection_changed (files);
        }

        private bool on_enter_notify_event () {
            /* Before the status bar is entered a leave event is triggered on the view, which
             * causes the statusbar to disappear. To block this we just cancel the update.
             */
            overlay_statusbar.cancel ();
            return false;
        }
    }
}
