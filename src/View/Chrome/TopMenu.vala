//
//  TopMenu.cs
//
//  Author:
//       mathijshenquet <mathijs.henquet@gmail.com>
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
        public AppMenu app_menu;
        public LocationBar? location_bar;
        public Window win;

        public TopMenu (Window window)
        {
            win = window;
	    get_style_context().add_class ("primary-toolbar");

            compact_menu = (Gtk.Menu) win.ui.get_widget("/CompactMenu");

            MenuItem coloritem = new ColorWidget(win);
            coloritem.show_all();
            Gtk.Widget set_color_label = new Gtk.MenuItem.with_label ("Set Color:");
            compact_menu.append((Gtk.MenuItem) set_color_label);
            set_color_label.set_sensitive(false);
            set_color_label.show();
            compact_menu.append((Gtk.MenuItem) coloritem);

            app_menu = new AppMenu.from_stock(Stock.PROPERTIES, IconSize.MENU, "Menu", compact_menu);
            setup_items();
            show();
        }

        public void setup_items ()
        {
            if (compact_menu != null)
                compact_menu.ref();
            @foreach (toolitems_destroy);
            string[]? toolbar_items = Preferences.settings.get_strv("toolbar-items");
            foreach (string name in toolbar_items) {
                if (name == "Separator")
                {
                        Gtk.SeparatorToolItem? sep = new Gtk.SeparatorToolItem ();
                        sep.set_draw(true);
                        sep.show();
                        insert(sep, -1);
                        continue;
                }
                if (name == "LocationEntry")
                {
                    location_bar = new LocationBar ();
                    location_bar.show_all();
                    insert(location_bar, -1);
                    /* init the path if we got a curent tab with a valid slot
                       and a valid directory loaded */
                    if (win.current_tab != null && win.current_tab.slot != null
                        && win.current_tab.slot.directory != null)
                        location_bar.path = win.current_tab.slot.directory.get_uri();
                    continue;
                }
                if (name == "ViewSwitcher")
                {
                    view_switcher = new ViewSwitcher(win.main_actions);
		    view_switcher.get_style_context().add_class ("raised");
                    view_switcher.show_all();
                    insert(view_switcher, -1);
                    continue;
                }

                Gtk.ToolItem? item;
                Gtk.Action? main_action = win.main_actions.get_action(name);

                if (main_action != null)
                {
                    if (name == "Forward"){
                        win.button_forward = new ToolButtonWithMenu.from_action(main_action);
                        win.button_forward.show_all();
                        insert(win.button_forward, -1);
                    }
                    else if ( name == "Back"){
                        win.button_back = new ToolButtonWithMenu.from_action(main_action);
                        win.button_back.show_all();
                        insert(win.button_back, -1);
                    }else{
                        item = (ToolItem) main_action.create_tool_item();
                        insert(item, -1);
                    }

                }
            }

            /*refresh = new ToolButton.from_stock(Stock.REFRESH);*/
            insert(app_menu, -1);
        }

        private void toolitems_destroy (Gtk.Widget? w) {
            ((Gtk.Container)this).remove (w);
        }
    }
}

