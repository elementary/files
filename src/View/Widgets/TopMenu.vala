/***
    TopMenu.cs

    Authors:
       mathijshenquet <mathijs.henquet@gmail.com>
       ammonkey <am.monkeyd@gmail.com>

    Copyright (c) 2010 mathijshenquet

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
***/

namespace Marlin.View.Chrome {
    public class TopMenu : Gtk.HeaderBar {
        public ViewSwitcher? view_switcher;
        public LocationBar? location_bar;
        public Chrome.ButtonWithMenu button_forward;
        public Chrome.ButtonWithMenu button_back;

        public bool locked_focus {get; private set; default = false;}

        public bool working {
            set {
                location_bar.sensitive = !value;
            }
        }

        public bool can_go_back {
           set {
                button_back.sensitive = value;
            }
        }

        public bool can_go_forward {
           set {
                button_forward.sensitive = value;
            }
        }

        public signal void forward (int steps);
        public signal void back (int steps); /* TODO combine using negative step */
        public signal void focus_location_request (GLib.File? location);
        public signal void path_change_request (string path, Marlin.OpenFlag flag);
        public signal void escape ();
        public signal void reload_request ();

        public TopMenu (ViewSwitcher switcher) {
            button_back = new Marlin.View.Chrome.ButtonWithMenu.from_icon_name ("go-previous-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            button_forward = new Marlin.View.Chrome.ButtonWithMenu.from_icon_name ("go-next-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            button_back.tooltip_text = _("Previous") + " (Alt + ←)";
            button_back.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            button_back.show_all ();
            pack_start (button_back);

            button_forward.tooltip_text = _("Next") + " (Alt + →)";
            button_forward.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
            button_forward.show_all ();
            pack_start (button_forward);


            button_forward.slow_press.connect (() => {
                forward (1);
            });

            button_back.slow_press.connect (() => {
                back (1);
            });

            view_switcher = switcher;
            view_switcher.margin_end = 20;
            view_switcher.show_all ();
            pack_start (view_switcher);

            location_bar = new LocationBar ();
            connect_location_bar_signals ();
            location_bar.show_all ();
            pack_start (location_bar);

            show ();
        }

        private void connect_location_bar_signals () {
            location_bar.reload_request.connect (() => {
                reload_request ();
            });
            location_bar.focus_file_request.connect ((file) => {
                focus_location_request (file);
            });
            location_bar.focus_in_event.connect ((event) => {
                locked_focus = true;
                return focus_in_event (event);
            });
            location_bar.focus_out_event.connect ((event) => {
                locked_focus = false;
                return focus_out_event (event);
            });
            location_bar.path_change_request.connect ((path, flag) => {
                path_change_request (path, flag);
            });
            location_bar.escape.connect (() => {escape ();});
        }

        public bool enter_search_mode () {
            return location_bar.enter_search_mode ();
        }

        public bool enter_navigate_mode () {
            return location_bar.enter_navigate_mode ();
        }

        public void set_back_menu (Gee.List<string> path_list) {
            /* Clear the back menu and re-add the correct entries. */
            var back_menu = new Gtk.Menu ();
            var n = 1;
            foreach (string path in path_list) {
                int cn = n++; /* No i'm not mad, thats just how closures work in vala (and other langs).
                               * You see if I would just use back(n) the reference to n would be passed
                               * in the closure, resulting in a value of n which would always be n=1. So
                               * by introducting a new variable I can bypass this anoyance.
                               */
                var item = new Gtk.MenuItem.with_label (PF.FileUtils.sanitize_path (path));
                item.activate.connect (() => {
                    back (cn);
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
                int cn = n++; /* For explanation look up */
                var item = new Gtk.MenuItem.with_label (PF.FileUtils.sanitize_path (path));
                item.activate.connect (() => {
                    forward (cn);
                });
                forward_menu.insert (item, -1);
            }

            forward_menu.show_all ();
            button_forward.menu = forward_menu;
        }

        public void update_location_bar (string new_path, bool with_animation = true) {
            location_bar.with_animation = with_animation;
            location_bar.set_display_path (new_path);
            location_bar.with_animation = true;
        }

        public void cancel () {
            location_bar.cancel ();
        }
    }
}
