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
    public class TopMenu : Gtk.Toolbar {
        public ViewSwitcher? view_switcher;
        public Gtk.Menu toolbar_menu;
        public LocationBar? location_bar;
        public Marlin.View.Window win;

        public TopMenu (Marlin.View.Window window) {
            win = window;

            get_style_context ().add_class (Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);

            toolbar_menu = (Gtk.Menu) win.ui.get_widget ("/ToolbarMenu");

            setup_items ();

            show ();
        }

        public override bool popup_context_menu (int x, int y, int button) {
            toolbar_menu.popup (null, null, null, button, Gtk.get_current_event_time ());
            return true;
        }

        public void setup_items () {
            @foreach (toolitems_destroy);
            string[]? toolbar_items = Preferences.settings.get_strv ("toolbar-items");

            foreach (string name in toolbar_items) {
                if (name == "Separator") {
                    Gtk.SeparatorToolItem? sep = new Gtk.SeparatorToolItem ();
                    sep.set_draw(true);
                    sep.show();
                    insert(sep, -1);
                    continue;
                }

                if (name == "LocationEntry") {
                    location_bar = new LocationBar (win.ui, win);
                    location_bar.halign = Gtk.Align.FILL;
                    location_bar.valign = Gtk.Align.FILL;
                    location_bar.margin_left = 6;
                    location_bar.margin_right = 6;

                    /* init the path if we got a curent tab with a valid slot
                       and a valid directory loaded */
                    if (win.current_tab != null && win.current_tab.slot != null
                        && win.current_tab.slot.directory != null) {
                        location_bar.path = win.current_tab.slot.directory.location.get_parse_name ();
                        //debug ("topmenu test path %s", location_bar.path);
                    }

                    location_bar.escape.connect (() => {
                        if (win.current_tab.content_shown)
                            win.current_tab.content.grab_focus ();
                        else
                            win.current_tab.slot.view_box.grab_focus ();
                    });

                    location_bar.activate.connect (() => {
message ("Location bar activate path is %s", location_bar.path);
                        win.current_tab.path_changed (File.new_for_commandline_arg (location_bar.path));
                    });

                    location_bar.activate_alternate.connect ((a) => {
                        win.add_tab (File.new_for_commandline_arg (a));
                    });

                    location_bar.show_all ();
                    insert (location_bar, -1);
                    continue;
                }

                if (name == "ViewSwitcher") {
                    view_switcher = new ViewSwitcher (win.main_actions);
                    view_switcher.show_all ();
                    view_switcher.margin_left = view_switcher.margin_right = 6;
                    insert (view_switcher, -1);
                    continue;
                }

                Gtk.ToolItem? item;
                Gtk.Action? main_action = win.main_actions.get_action(name);

                if (main_action != null) {
                    if (name == "Forward") {
                        win.button_forward = new Granite.Widgets.ToolButtonWithMenu.from_action (main_action);
                        win.button_forward.show_all ();
                        insert (win.button_forward, -1);
                    } else if ( name == "Back") {
                        win.button_back = new Granite.Widgets.ToolButtonWithMenu.from_action (main_action);
                        win.button_back.show_all ();
                        insert (win.button_back, -1);
                    } else {
                        item = (Gtk.ToolItem) main_action.create_tool_item ();
                        insert (item, -1);
                    }
                }
            }

        }

        private void toolitems_destroy (Gtk.Widget? w) {
            ((Gtk.Container) this).remove (w);
        }
    }
}
