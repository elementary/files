//
//  TopMenu.cs
//
//  Authors:
//       mathijshenquet <mathijs.henquet@gmail.com>
//       ammonkey <am.monkeyd@gmail.com>
//
//  Copyright (c) 2010 mathijshenquet
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.

namespace Marlin.View.Chrome
{
    public class TopMenu : Gtk.HeaderBar {
        public ViewSwitcher? view_switcher;
        public LocationBar? location_bar;
        public Marlin.View.Window win;
        public Chrome.ButtonWithMenu button_forward;
        public Chrome.ButtonWithMenu button_back;

        public signal void forward (int steps);
        public signal void back (int steps);  /* TODO combine using negative step */

        public void set_can_go_back (bool can) {
           button_back.set_sensitive (can);
        }
        public void set_can_go_forward (bool can) {
           button_forward.set_sensitive (can);
        }

        public TopMenu (Marlin.View.Window window) {
//message ("New TopMenu");
            win = window;

            button_back = new Marlin.View.Chrome.ButtonWithMenu.from_icon_name ("go-previous", Gtk.IconSize.LARGE_TOOLBAR);
            button_forward = new Marlin.View.Chrome.ButtonWithMenu.from_icon_name ("go-next", Gtk.IconSize.LARGE_TOOLBAR);

//            win.button_back.tooltip_text = _("Previous");
//            win.button_back.show_all ();
//            pack_start (win.button_back);


//            win.button_forward.tooltip_text = _("Next");
//            win.button_forward.show_all ();
//            pack_start (win.button_forward);

            button_back.tooltip_text = _("Previous");
            button_back.show_all ();
            pack_start (button_back);


            button_forward.tooltip_text = _("Next");
            button_forward.show_all ();
            pack_start (button_forward);


            button_forward.slow_press.connect (() => {
                //current_tab.forward ();
                forward (1);
            });

            button_back.slow_press.connect (() => {
                //current_tab.back ();
                back (1);
            });


            view_switcher = new ViewSwitcher (win.win_actions.lookup_action ("view_mode") as GLib.SimpleAction);
            view_switcher.show_all ();
            pack_start (view_switcher);

            location_bar = new LocationBar (win);

            /* init the path if we got a curent tab with a valid slot
               and a valid directory loaded */
            if (win.current_tab != null &&
                //win.current_tab.slot != null
                win.current_tab.view != null
                //&& win.current_tab.slot.directory != null) {
                && win.current_tab.view.directory != null) {
                /* TODO should not need to know deep details of other widgets*/
                //location_bar.path = win.current_tab.slot.directory.location.get_parse_name ();
                location_bar.path = win.current_tab.location.get_parse_name ();
                //debug ("topmenu test path %s", location_bar.path);
            }

            location_bar.escape.connect (() => {
                if (win.current_tab.content_shown)
                    win.current_tab.content.grab_focus ();
                else {
message ("TopMenu- view grab focus 1");

                   // win.current_tab.slot.view_box.grab_focus ();
                    win.current_tab.view.grab_focus ();
                }
            });

            location_bar.activate.connect ((file) => {
                win.current_tab.path_changed (file);
            });

            location_bar.activate_alternate.connect ((file) => {
                win.add_tab (file, Marlin.ViewMode.CURRENT);
            });

            
            location_bar.show_all ();
            view_switcher.margin_right = 20;
            pack_start (location_bar);

            show ();
        }

        public void set_back_menu (Gee.List<string> path_list) {
            /* Clear the back menu and re-add the correct entries. */
            var back_menu = new Gtk.Menu ();
            var n = 1;
            foreach (string path in path_list) {
                int cn = n++; // No i'm not mad, thats just how closures work in vala (and other langs).
                              // You see if I would just use back(n) the reference to n would be passed
                              // in the clusure, restulting in a value of n which would always be n=1. So
                              // by introducting a new variable I can bypass this anoyance.
                var item = new Gtk.MenuItem.with_label (GLib.Uri.unescape_string (path));
                item.activate.connect (() => {
                    back(cn);
                });
                back_menu.insert (item, -1);
            }

            back_menu.show_all ();
            button_back.menu = back_menu;
        }

        public void set_forward_menu (Gee.List<string> path_list) {
            /* Same for the forward menu */
            var forward_menu = new Gtk.Menu ();
            var n = 1;
            foreach (string path in path_list) {
                int cn = n++; // For explanation look up
                var item = new Gtk.MenuItem.with_label (GLib.Uri.unescape_string (path));
                item.activate.connect (() => {
                    forward (cn);
                });
                forward_menu.insert (item, -1);
            }

            forward_menu.show_all ();
            button_forward.menu = forward_menu;
        }

        public void update_location_bar (string new_path) {
message ("TM New path is %s", new_path);
            location_bar.path = new_path;
        }

    }
}
