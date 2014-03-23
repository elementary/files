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

namespace Marlin.View {
    public class ViewContainer : Gtk.Overlay {
        public Gtk.Widget? content_item;
        public bool content_shown = false;
        public Gtk.Label label;
        private Marlin.View.Window window;
        public GOF.Window.Slot? slot = null;
        public Marlin.Window.Columns? mwcol = null;
        Browser browser;
        public int view_mode = 0;
        public OverlayBar overlay_statusbar;

        //private ulong file_info_callback;
        private GLib.List<GLib.File> select_childs = null;

        public signal void path_changed (File file);
        public signal void up ();
        public signal void back (int n=1);
        public signal void forward (int n=1);
        public signal void tab_name_changed (string tab_name);

        public ViewContainer (Marlin.View.Window win, GLib.File location, int _view_mode = 0) {
            window = win;
            overlay_statusbar = new OverlayBar (win);
            view_mode = _view_mode;

            /* set active tab */
            browser = new Browser ();
            label = new Gtk.Label ("Loading...");
            change_view (view_mode, location);
            label.set_ellipsize (Pango.EllipsizeMode.END);
            label.set_single_line_mode (true);
            label.set_alignment (0.0f, 0.5f);
            label.set_padding (0, 0);
            update_location_state (true);
            window.button_back.fetcher = get_back_menu;
            window.button_forward.fetcher = get_forward_menu;

            //add(content_item);
            this.show_all ();

            // Override background color to support transparency on overlay widgets
            Gdk.RGBA transparent = {0, 0, 0, 0};
            override_background_color (0, transparent);

            /* overlay statusbar */
            set_events (Gdk.EventMask.ENTER_NOTIFY_MASK | Gdk.EventMask.LEAVE_NOTIFY_MASK);
            add_overlay (overlay_statusbar);
            overlay_statusbar.showbar = view_mode != ViewMode.LIST;

            path_changed.connect ((myfile) => {
                /* location didn't change, do nothing */
                if (slot != null && myfile != null && slot.directory.file.exists
                    && slot.location.equal (myfile))
                    return;
                change_view(view_mode, myfile);
                update_location_state (true);
            });

            up.connect (() => {
                if (slot.directory.has_parent ()) {
                    change_view (view_mode, slot.directory.get_parent ());
                    update_location_state (true);
                }
            });

            back.connect ((n) => {
                change_view (view_mode, File.new_for_commandline_arg (browser.go_back (n)));
                update_location_state (false);
            });

            forward.connect ((n) => {
                change_view (view_mode, File.new_for_commandline_arg (browser.go_forward (n)));
                update_location_state (false);
            });
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

        private void plugin_directory_loaded () {
            Object[] data = new Object[3];
            data[0] = window;
            (mwcol != null) ? data[1] = mwcol : data[1] = slot;
            //data[2] = GOF.File.get(slot.location);
            data[2] = slot.directory.file;
            plugins.directory_loaded ((void*) data);
        }

        private void connect_available_info () {
            //file_info_callback = slot.directory.file.info_available.connect((gof) => {
                if (window.current_tab == this)
                    window.loading_uri (slot.directory.file.uri);

                /*Source.remove((uint) file_info_callback);
            });*/
        }

        public void refresh_slot_info () {
            var aslot = get_active_slot ();
            var slot_path = aslot.directory.file.location.get_path ();
            if (slot_path == Environment.get_home_dir ())
                tab_name = _("Home");
            else if (slot_path == "/")
                tab_name = _("File System");
            else if (slot.directory.file.exists && (aslot.directory.file.info is FileInfo))
                tab_name = aslot.directory.file.info.get_attribute_string (FileAttribute.STANDARD_DISPLAY_NAME);
            else
                tab_name = _("This folder does not exist");

            if (Posix.getuid() == 0)
                tab_name = tab_name + " " + _("(as Administrator)");

            /* update window title */
            if (window.current_tab == this) {
                window.set_title (tab_name);
                if (window.top_menu.location_bar != null)
                    window.top_menu.location_bar.path = aslot.directory.file.location.get_parse_name ();
            }

        }

        /* handle directory not found */
        public void directory_done_loading () {
            if (!slot.directory.file.exists) {
                content = new DirectoryNotFound (slot.directory, this);
            } else if (slot.directory.permission_denied) {
                content = new Granite.Widgets.Welcome (_("This does not belong to you."),
                                                       _("You don't have permission to view this folder."));
            } else {
                content_shown = false;
                if (select_childs != null)
                    ((FM.Directory.View) slot.view_box).select_glib_files (select_childs);
            }

            warning ("directory done loading");

            slot.directory.done_loading.disconnect (directory_done_loading);
        }

        public void change_view (int nview, GLib.File? location) {
            /* if location is null then we have a user change view request */
            bool user_change_rq = location == null;
            select_childs = null;
            if (location == null) {
                /* we re just changing view keep the same location */
                location = get_active_slot ().location;
                /* store the old selection to restore it */
                if (slot != null && !content_shown) {
                    unowned List<GOF.File> list = ((FM.Directory.View) slot.view_box).get_selection ();
                    foreach (var elem in list)
                        select_childs.prepend (elem.location);
                }
            } else {
                /* check if the requested location is a parent of the previous one */
                if (slot != null) {
                    var parent = slot.location.get_parent ();
                    if (parent != null && parent.equal (location))
                        select_childs.prepend (slot.directory.file.location);
                }
            }
            if (slot != null && slot.directory != null && slot.directory.file.exists) {
                slot.directory.cancel ();
                slot.directory.track_longest_name = false;
            }

            if (nview == ViewMode.MILLER) {
                mwcol = new Marlin.Window.Columns (location, this);
                slot = mwcol.active_slot;
            } else {
                mwcol = null;
                slot = new GOF.Window.Slot (location, this);
            }

            /* automagicly enable icon view for icons keypath */
            if (!user_change_rq && slot.directory.uri_contain_keypath_icons)
                nview = 0; /* icon view */

            /* Setting up view_mode and its button */
            view_mode = nview;
            if (window.top_menu.view_switcher != null)
                window.top_menu.view_switcher.mode = (ViewMode) view_mode;

            connect_available_info ();
            if (slot != null) {
                slot.directory.done_loading.connect (directory_done_loading);
                slot.directory.need_reload.connect (reload);
            }
            plugin_directory_loaded ();

            switch (nview) {
            case ViewMode.LIST:
                slot.make_list_view ();
                break;
            case ViewMode.MILLER:
                mwcol.make_view ();
                break;
            default:
                slot.make_icon_view ();
                break;
            }

            overlay_statusbar.showbar = nview != ViewMode.LIST;
        }

        public GOF.Window.Slot? get_active_slot () {
            if (mwcol != null)
                return mwcol.active_slot;
            else
                return slot;
        }

        public void reload () {
            GOF.Directory.Async dir = slot.directory;
            dir.cancel ();
            dir.need_reload.disconnect (reload);
            dir.remove_dir_from_cache ();
            change_view (view_mode, null);
        }

        public void update_location_state (bool save_history) {
            if (!slot.directory.file.exists)
                return;

            if (save_history)
                browser.record_uri (slot.directory.location.get_parse_name ());

            window.can_go_up = slot.directory.has_parent ();
            window.can_go_back = browser.can_go_back ();
            window.can_go_forward = browser.can_go_forward ();
            /* update ModeButton */
            if (window.top_menu.view_switcher != null)
                window.top_menu.view_switcher.mode = (ViewMode) view_mode;
        }

        public Gtk.Menu get_back_menu () {
            /* Clear the back menu and re-add the correct entries. */
            var back_menu = new Gtk.Menu ();
            var list = browser.go_back_list ();
            var n = 1;
            foreach (var path in list) {
                int cn = n++; // No i'm not mad, thats just how closures work in vala (and other langs).
                              // You see if I would just use back(n) the reference to n would be passed
                              // in the clusure, restulting in a value of n which would always be n=1. So
                              // by introducting a new variable I can bypass this anoyance.
                var item = new Gtk.MenuItem.with_label (path);
                item.activate.connect (() => { back(cn); });
                back_menu.insert (item, -1);
            }

            back_menu.show_all ();
            return back_menu;
        }

        public Gtk.Menu get_forward_menu () {
            /* Same for the forward menu */
            var forward_menu = new Gtk.Menu ();
            var list = browser.go_forward_list ();
            var n = 1;
            foreach (var path in list) {
                int cn = n++; // For explenation look up
                var item = new Gtk.MenuItem.with_label (path);
                item.activate.connect (() => forward (cn));
                forward_menu.insert (item, -1);
            }

            forward_menu.show_all ();
            return forward_menu;
        }

        public new Gtk.Widget get_window ()
        {
            return ((Gtk.Widget) window);
        }

    }
}
