//  
//  TopMenu.cs
//  
//  Author:
//       mathijshenquet <${AuthorEmail}>
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
using Gtk;

namespace Marlin.View.Chrome
{
    public class TopMenu : Gtk.Toolbar
    {
        public ViewSwitcher? view_switcher;
        public Gtk.Menu compact_menu;
        public CompactMenuButton compact_menu_button;
        public LocationBar? location_bar;
        public Window win;

        public TopMenu (Window window)
        {
            win = window;
            setup_items();
        }

        public void setup_items ()
        {
            Gtk.Widget? titem;

            @foreach (toolitems_destroy);
            string[]? toolbar_items = Preferences.settings.get_strv("toolbar-items");
            foreach (string name in toolbar_items) { 
                if (strcmp(name, "Separator") == 0)
                {
                        Gtk.SeparatorToolItem? sep = new Gtk.SeparatorToolItem ();
                        sep.set_draw(true);
                        sep.show();
                        insert(sep, -1);
                        continue;
                }
                if (strcmp(name, "LocationPathBar") == 0)
                {
                    location_bar = new LocationBar ();
                    location_bar.show_all();
                    insert(location_bar, -1);
                    continue;
                }
                if (strcmp(name, "ViewModeButton") == 0)
                {
                    view_switcher = new ViewSwitcher(win.main_actions);
                    view_switcher.show_all();
                    insert(view_switcher, -1);
                    continue;
                }
                Gtk.Action? main_action = win.main_actions.get_action(name);
                if (main_action != null)
                {
                    titem = main_action.create_tool_item();
                    insert((Gtk.ToolItem) titem, -1);
                }

            }

            /*refresh = new ToolButton.from_stock(Stock.REFRESH);*/
            compact_menu = (Gtk.Menu) win.ui.get_widget("/CompactMenu");
            compact_menu_button = new CompactMenuButton.from_stock(Stock.PROPERTIES, IconSize.MENU, "Menu", compact_menu);
            insert(compact_menu_button, -1);
        }

        private void toolitems_destroy (Gtk.Widget? w) {
            ((Gtk.Container)this).remove (w);
        }
    }
}

