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
        public ToolButton go_back;
        public ToolButton go_forward;
        public ToolButton go_up;
        public ToolButton refresh;
        public ViewSwitcher view_switcher;
        public Gtk.Menu compact_menu;
        public CompactMenuButton compact_menu_button;
        public LocationBar location_bar;
        public Window win;

        public TopMenu (Window window)
        {
            win = window;
            go_back = new ToolButton.from_stock(Stock.GO_BACK);
            go_forward = new ToolButton.from_stock(Stock.GO_FORWARD);
            go_up = new ToolButton.from_stock(Stock.GO_UP);
            refresh = new ToolButton.from_stock(Stock.REFRESH);
            location_bar = new LocationBar ();
            compact_menu = (Gtk.Menu) win.ui.get_widget("/CompactMenu");
            compact_menu_button = new CompactMenuButton.from_stock(Stock.PROPERTIES, IconSize.MENU, "Menu", compact_menu);
            view_switcher = new ViewSwitcher();

            insert(go_back, -1);
            insert(go_forward, -1);
            insert(go_up, -1);
            insert(location_bar, -1);
            //insert(refresh, -1);
            insert(view_switcher, -1);
            insert(compact_menu_button, -1);
        }
    }
}

