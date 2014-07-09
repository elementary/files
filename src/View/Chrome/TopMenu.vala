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

        public TopMenu (Marlin.View.Window window) {
//message ("New TopMenu");
            win = window;

            win.button_back = new ButtonWithMenu.from_icon_name ("go-previous", Gtk.IconSize.LARGE_TOOLBAR);
            win.button_back.tooltip_text = _("Previous");
            win.button_back.show_all ();
            pack_start (win.button_back);

            win.button_forward = new ButtonWithMenu.from_icon_name ("go-next", Gtk.IconSize.LARGE_TOOLBAR);
            win.button_forward.tooltip_text = _("Next");
            win.button_forward.show_all ();
            pack_start (win.button_forward);

            view_switcher = new ViewSwitcher (win.main_actions);
            view_switcher.show_all ();
            pack_start (view_switcher);

            //Location Bar
            location_bar = new LocationBar (win.ui, win);

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
    }
}
