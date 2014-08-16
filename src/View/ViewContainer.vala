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
        public bool content_shown = false;
        public bool can_show_folder = true;
        public Gtk.Label label;
        public Marlin.View.Window window;
        public GOF.AbstractSlot? view = null;
        Browser browser;
        public Marlin.ViewMode view_mode;
        public GLib.File location;
        public OverlayBar overlay_statusbar;

        private GLib.List<GLib.File> select_childs = null;
        private ulong directory_done_loading_handler_id = 0;
        private ulong reload_handler_id = 0;

        /* The path_changed signal is listened to by Slot, Miller as well as ViewContainer */
        /* The path_changed signal is emitted by :
         * Window (go to actions)
         * LocationBar (context menu - directory itens)
         * TopMenu, ViewContainer, DirectoryView Sidebar*/
        /* LocationBar has a different signal named "path_changed" */

        public signal void path_changed (GLib.File? file, int flag = 0, Slot? source_slot = null);
        public signal void up ();
        public signal void back (int n=1);
        public signal void forward (int n=1);
        public signal void tab_name_changed (string tab_name);

        /* Initial location now set by Window.make_tab after connecting signals */
        public ViewContainer (Marlin.View.Window win, Marlin.ViewMode viewmode, GLib.File location) {
message ("New ViewContainer");
            window = win;
            overlay_statusbar = new OverlayBar (win, this);
            this.view_mode = viewmode;
            this.location = location;

            browser = new Browser ();

            if (viewmode == Marlin.ViewMode.MILLER_COLUMNS)
                view = new Miller (location, this);
            else
                view = new Slot (location, this);

            label = new Gtk.Label ("Loading...");
            label.set_ellipsize (Pango.EllipsizeMode.END);
            label.set_single_line_mode (true);
            label.set_alignment (0.0f, 0.5f);
            label.set_padding (0, 0);

            this.show_all ();

            /* Override background color to support transparency on overlay widgets */
            Gdk.RGBA transparent = {0, 0, 0, 0};
            override_background_color (0, transparent);

            /* overlay statusbar */
            set_events (Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);
            /* The overlay is already added in the constructor of the statusbar */
            overlay_statusbar.showbar = view_mode != Marlin.ViewMode.LIST;

            connect_signals ();
            change_view_mode (view_mode);
        }

        public Gtk.Widget content {
            set {
                if (content_item != null)
                    remove (content_item);
                add (value);
                content_item = value;
                content_item.show_all ();
                content_shown = true;
            }
            get {
                return content_item;
            }
        }

        public string tab_name {
            set {
                label.label = value;
                tab_name_changed (value);
            }
            get {
                return label.label;
            }
        }

        private void connect_signals () {

            path_changed.connect (on_path_changed);

            up.connect (() => {
                if (view.directory.has_parent ())
                    path_changed (view.directory.get_parent ());
            });

            back.connect ((n) => {
                string? loc = browser.go_back (n);
                if (loc != null)
                    path_changed (File.new_for_commandline_arg (loc));
            });

            forward.connect ((n) => {
                string? loc = browser.go_forward (n);
                if (loc != null)
                    path_changed (File.new_for_commandline_arg (loc));
            });
        }

        private void on_path_changed (GLib.File? location, int flag) {
        /* ViewContainer only handles new tab and new window - otherwise just updates appearance*/
message ("VC on path changed");

//            /* automagicly enable icon view for icons keypath */
//            if (!user_change_rq && slot.directory.uri_contain_keypath_icons)
//                mode = 0; /* icon view */

            switch ((Marlin.OpenFlag)flag) {
                case Marlin.OpenFlag.NEW_TAB:
                    this.window.add_tab (location, view_mode);
                    return;

                case Marlin.OpenFlag.NEW_WINDOW:
                    this.window.add_window (location, view_mode);
                    return;

                default:
                    this.location = location;
                    browser.record_uri (location.get_parse_name ());

                    set_up_slot ();  /*  ?? */
                    refresh_slot_info (location);
                    window.loading_uri (location.get_uri ());
                    window.update_top_menu ();
                    plugin_directory_loaded ();
                    break;
            }
        }

        /* This is called whenever a slot is created or displays a new location*/
        private void set_up_slot () {
message ("set up slot");
            var slot = get_current_slot ();
            if (slot != null) {
                /* synchronise sidebar */
//message ("Slot uri is %s", slot.location.get_uri ());
                //if (window.current_tab == this)
                  //  window.loading_uri (slot.location.get_uri ());

                directory_done_loading_handler_id = slot.directory.done_loading.connect (() => {
                    directory_done_loading (slot);
                });

                reload_handler_id = slot.directory.need_reload.connect (() => {
                    reload_slot (slot);
                });
//message ("plugins load");
                //plugin_directory_loaded ();
            } else
                critical ("Tried to set up null slot");
message ("leaving");
        }

        private void plugin_directory_loaded () {
            var slot = get_current_slot ();
            Object[] data = new Object[3];
            data[0] = window;
            data[1] = slot;
            data[2] = slot.directory.file;
            plugins.directory_loaded ((void*) data);
        }

        public void refresh_slot_info (GLib.File location) {
message ("refresh slot info for %s", location.get_uri ());
            var slot_path = location.get_path ();

            if (slot_path == Environment.get_home_dir ())
                tab_name = _("Home");
            else if (slot_path == "/")
                tab_name = _("File System");
            else
                tab_name = location.get_basename ();
                
           

            if (Posix.getuid() == 0)
                tab_name = tab_name + " " + _("(as Administrator)");

            window.update_labels (location.get_parse_name (), tab_name);
        }

        /* Handle nonexistent, non-directory, and unpermitted location */
        public void directory_done_loading (GOF.AbstractSlot slot) {
            FileInfo file_info;
            
            try {
                file_info = slot.location.query_info ("standard::*,access::*", FileQueryInfoFlags.NONE);

                /* If not readable, alert the user */
                if (slot.directory.permission_denied) {
                    content = new Granite.Widgets.Welcome (_("This does not belong to you."),
                                                           _("You don't have permission to view this folder."));
                    can_show_folder = false;
                }


                if (file_info.get_file_type () == FileType.DIRECTORY) {
message ("loaded directory");
                    content_shown = false;
                    if (select_childs != null) {
message ("THere are selected childs");
                        slot.select_glib_files (select_childs);
                    }

                } else {
                    /* If not a directory, then change the location to the parent */
                    path_changed (slot.location.get_parent ());
                }
            } catch (Error err) {
                /* query_info will throw an expception if it cannot find the file */
                content = new DirectoryNotFound (slot.directory, this);
                tab_name = _("This folder does not exist");
                can_show_folder = false;
            }
            //slot.directory.done_loading.disconnect (directory_done_loading);
            slot.directory.disconnect (directory_done_loading_handler_id);
        }

        public void change_view_mode (Marlin.ViewMode mode) {

            store_selection ();
            if (mode == Marlin.ViewMode.MILLER_COLUMNS)
                view = new Miller (location, this);
            else
                view = new Slot (location, this);

            content = view.make_view (mode);
            set_up_slot ();
            update_view (mode);
            restore_selection ();
        }

        private void store_selection () {}
        private void restore_selection () {}

        private void update_view (Marlin.ViewMode mode) {
            overlay_statusbar.showbar = mode != Marlin.ViewMode.LIST;
            view_mode = mode;
        }

        public GOF.AbstractSlot get_current_slot () {
           return view.get_current_slot ();
        }

        public string? get_root_uri () {
            return view.get_root_uri ();
        }

        public string? get_tip_uri () {
            return view.get_tip_uri ();
        }

        public void reload () {
            reload_slot (view.get_current_slot ());
        }

        private void reload_slot (GOF.AbstractSlot slot) {
message ("reload");
//            GOF.Directory.Async dir = slot.directory;
//            dir.cancel ();
//            dir.disconnect (reload_handler_id);
//            dir.remove_dir_from_cache ();
            slot.reload ();
        }


        public Gee.List<string> get_go_back_path_list () {
            return browser.go_back_list ();
        }

        public Gee.List<string> get_go_forward_path_list () {
            return browser.go_forward_list ();
        }

//        public new Gtk.Widget get_window () {
//            return ((Gtk.Widget) window);
//        }
    }
}
