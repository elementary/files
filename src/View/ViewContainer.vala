//
//  ViewContainer.vala
//
//  Authors:
//       Mathijs Henquet <mathijs.henquet@gmail.com>
//       ammonkey <am.monkeyd@gmail.com>
//
//  Copyright (c) 2010 Mathijs Henquet
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
//

using Marlin;

namespace Marlin.View {
    public class ViewContainer : Gtk.Overlay {
        public Gtk.Widget? content_item;
        public bool can_show_folder = true;
        public string label = "";
        public Marlin.View.Window window;
        public GOF.AbstractSlot? view = null;
        Browser browser;
        public Marlin.ViewMode view_mode = Marlin.ViewMode.INVALID;
        public GLib.File? location {
            get {
//message ("VC get location");
                var slot = get_current_slot ();
                return slot != null ? slot.location : null;
            }
        }
        public string uri {
            get {
                var slot = get_current_slot ();
                return slot != null ? slot.uri : null;
            }
        }
        public OverlayBar overlay_statusbar;

        private GLib.List<GLib.File>? selected_locations = null;

        public signal void tab_name_changed (string tab_name);
        public signal void loading (bool is_loading);

        /* Initial location now set by Window.make_tab after connecting signals */
        public ViewContainer (Marlin.View.Window win, Marlin.ViewMode mode, GLib.File loc) {
//message ("New ViewContainer");
            window = win;
            overlay_statusbar = new OverlayBar (win, this);
            browser = new Browser ();

            this.show_all ();

            /* Override background color to support transparency on overlay widgets */
            Gdk.RGBA transparent = {0, 0, 0, 0};
            override_background_color (0, transparent);

            /* overlay statusbar */
            set_events (Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);
            /* The overlay is already added in the constructor of the statusbar */
            //overlay_statusbar.showbar = view_mode != Marlin.ViewMode.LIST;
            change_view_mode (mode, loc);
        }

        public Gtk.Widget content {
            set {
                if (content_item != null)
                    remove (content_item);
                add (value);
                content_item = value;
                content_item.show_all ();
            }
            get {
                return content_item;
            }
        }

        public string tab_name {
            set {
                label = value;
                tab_name_changed (value);
            }
            get {
                return label;
            }
        }

        public void go_up () {
//message ("VC go up");
            if (view.directory.has_parent ())
                user_path_change_request (view.directory.get_parent ());
        }

        public void go_back (int n = 1) {
            string? loc = browser.go_back (n);
            if (loc != null)
                user_path_change_request (File.new_for_commandline_arg (loc));
        }

        public void go_forward (int n = 1) {
//message ("VC go forward");
            string? loc = browser.go_forward (n);
            if (loc != null)
                user_path_change_request (File.new_for_commandline_arg (loc));
        }


        public void change_view_mode (Marlin.ViewMode mode, GLib.File? loc = null) {
//message ("change view mode.  Mode is %i,  View mode is %i", (int)mode, (int)view_mode);
            if (mode != view_mode) {

                if (loc == null) /* Only untrue on container creation */
                    loc = this.location;

                if (view != null)
                    store_selection ();

                /* the following 2 lines delays destruction of the old view until this function returns
                 * and allows the processor to display or update the window more quickly
                 */    
                GOF.AbstractSlot temp;
                temp = view; 

                if (mode == Marlin.ViewMode.MILLER_COLUMNS)
                    view = new Miller (loc, this, mode);
                else
                    view = new Slot (loc, this, mode);

                view_mode = mode;
                slot_path_changed (loc);
                overlay_statusbar.showbar = view_mode != Marlin.ViewMode.LIST;
                overlay_statusbar.reset_selection ();
            }
        }

        public void user_path_change_request (GLib.File loc) {
//message ("VC user path changed request");
            view.user_path_change_request (loc);
        }

        public void new_container_request (GLib.File loc, int flag = 1) {
//message ("VC new container request");
            switch ((Marlin.OpenFlag)flag) {
                case Marlin.OpenFlag.NEW_TAB:
                    this.window.add_tab (loc, view_mode);
                    break;

                case Marlin.OpenFlag.NEW_WINDOW:
                    this.window.add_window (loc, view_mode);
                    break;

                default:
                    assert_not_reached ();
            }
        }

        public void slot_path_changed (GLib.File loc) {
//message ("VC slot path changed");
#if 0 
            /* automagicly enable icon view for icons keypath */
            if (get_current_slot ().directory.uri_contain_keypath_icons && view_mode != Marlin.ViewMode.ICON)
                change_view_mode (Marlin.ViewMode.ICON, null);
            else
#endif
            set_up_current_slot ();
        }

        private void set_up_current_slot () {
//message ("set up current slot");
            var slot = get_current_slot ();
            assert (slot != null);
            assert (slot.directory != null);

            content = view.get_content_box ();
            plugin_directory_loaded ();
            load_slot_directory (slot);
        }

        public void load_slot_directory (GOF.AbstractSlot slot) {
            can_show_folder = true;
            loading (true);
            /* Allow time for the window to update before starting to load directory so that
             * the window is displayed more quickly with the "Loading ... " message
             * when starting the application in, or switching view to, a folder that contains
             * a large number of files.
             */           
            Timeout.add (100, () => {
                slot.directory.load ();
                return false;
            });
        }

        private void plugin_directory_loaded () {
//message ("plugin directory loaded");
            var slot = get_current_slot ();
            Object[] data = new Object[3];
            data[0] = window;
            data[1] = slot;
            data[2] = slot.directory.file;

            plugins.directory_loaded ((void*) data);
        }

        public void refresh_slot_info (GOF.AbstractSlot aslot) {
            var loc = aslot.directory.file.location;
            var slot_path = loc.get_path ();
//message ("refresh slot info - path is %s", slot_path);
            if (slot_path == Environment.get_home_dir ())
                tab_name = _("Home");
            else if (slot_path == "/")
                tab_name = _("File System");
            else if (aslot.directory.file.exists && (aslot.directory.file.info is FileInfo))
                tab_name = aslot.directory.file.info.get_attribute_string (FileAttribute.STANDARD_DISPLAY_NAME);
            else {
                tab_name = _("This folder does not exist");
                can_show_folder = false;
            }
            if (Posix.getuid() == 0)
                tab_name = tab_name + " " + _("(as Administrator)");

            window.loading_uri (loc.get_uri ());
            window.update_top_menu ();
            window.update_labels (loc.get_parse_name (), tab_name);
            browser.record_uri (loc.get_parse_name ()); /* will ignore null changes */
            window.set_can_go_back (browser.get_can_go_back ());
            window.set_can_go_forward (browser.get_can_go_forward ());
        }

        public void directory_done_loading (GOF.AbstractSlot slot) {
//message ("directory done loading");
            FileInfo file_info;

            loading (false);
            refresh_slot_info (slot);
            try {
                file_info = slot.location.query_info ("standard::*,access::*", FileQueryInfoFlags.NONE);

                /* If not readable, alert the user */
                if (slot.directory.permission_denied) {
                    content = new Granite.Widgets.Welcome (_("This does not belong to you."),
                                                           _("You don't have permission to view this folder."));
                    can_show_folder = false;
                }
                else if (file_info.get_file_type () == FileType.DIRECTORY && selected_locations != null) {
                    view.select_glib_files (selected_locations, null);
                    selected_locations = null;
                }

            } catch (Error err) {
                /* query_info will throw an exception if it cannot find the file */
                if (err is IOError.NOT_MOUNTED)
                    slot.reload ();
                else {
                    content = new DirectoryNotFound (slot.directory, this);
                    can_show_folder = false;
                }
            }
        }

        private void store_selection () {
//message ("Storing selection");
            unowned GLib.List<unowned GOF.File> selected_files = view.get_selected_files ();
            selected_locations = null;
            if (selected_files.length () >= 1) {
                selected_files.@foreach ((file) => {
                    selected_locations.prepend (GLib.File.new_for_uri (file.uri));
                });
            }
        }

        public unowned GOF.AbstractSlot? get_current_slot () {
//debug ("VC get current slot");
           return view.get_current_slot ();
        }

        public void set_active_state (bool is_active) {
//message ("VC set slot active to %s", is_active ? "true" : "false");
            get_current_slot ().set_active_state (is_active);
        }

        public void focus_location (GLib.File file) {
//message ("focus file %s", file.get_uri ());
            GLib.File? loc = null;
            if (file.query_file_type (0) == FileType.DIRECTORY) {
                if (location.equal (file))
                    return;

                loc = file;
                user_path_change_request (loc);
            } else {
                if (location.equal (file.get_parent ())) {
                    var list = new List<File> ();
                    list.prepend (file);
                    get_current_slot ().select_glib_files (list, file);
                } else {
                    loc = file.get_parent ();
                    user_path_change_request (loc);
                }
            }

            if (loc != null) {
                slot_path_changed (loc);
                refresh_slot_info (get_current_slot ());
            }
        }

        public string? get_root_uri () {
            return view.get_root_uri ();
        }

        public string? get_tip_uri () {
            return view.get_tip_uri ();
        }

        public void reload () {
//message ("VC reload");
            if (!can_show_folder) /* Try to display folder again */
                content = view.get_content_box ();

            loading (true);
            /* Allow time for the signal to propagate and the tab label to redraw */
            Timeout.add (10, () => {
                var slot = view.get_current_slot ();
                slot.reload ();
                load_slot_directory (slot);
                return false;
            });
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
//message ("VC grab focus");
            if (can_show_folder)
                view.grab_focus ();
            else
                content.grab_focus ();
        }

    }
}
