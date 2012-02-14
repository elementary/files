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
using Gtk;

namespace Marlin.View.Chrome
{
    public class TopMenu : Gtk.Toolbar
    {
        public ViewSwitcher? view_switcher;
        public Gtk.Menu compact_menu;
        public Gtk.Menu toolbar_menu;
        public Varka.Widgets.AppMenu app_menu;
        public LocationBar? location_bar;
        public Window win;

        public TopMenu (Window window)
        {
            win = window;
            if (Preferences.settings.get_boolean("toolbar-primary-css-style"))
	            get_style_context().add_class ("primary-toolbar");
            //set_icon_size (Gtk.IconSize.SMALL_TOOLBAR);

            compact_menu = (Gtk.Menu) win.ui.get_widget("/CompactMenu");
            toolbar_menu = (Gtk.Menu) win.ui.get_widget("/ToolbarMenu");

            app_menu = new Varka.Widgets.AppMenu (compact_menu);
            setup_items();
            show();
            
            button_press_event.connect(right_click);
        }
        
        public bool right_click(Gdk.EventButton event)
        {
            if(event.button == 3)
            {
                right_click_extern(event);
                return true;
            }
            return false;
        }
        
        public void right_click_extern(Gdk.EventButton event)
        {
            Eel.pop_up_context_menu(toolbar_menu, 0, 0, event);
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
                    location_bar = new LocationBar (win.ui, win);

                    /* init the path if we got a curent tab with a valid slot
                       and a valid directory loaded */
                    if (win.current_tab != null && win.current_tab.slot != null
                        && win.current_tab.slot.directory != null) {
                        location_bar.path = win.current_tab.slot.directory.location.get_parse_name ();
                        //debug ("topmenu test path %s", location_bar.path);
                    }

                    location_bar.escape.connect( () => { ((FM.Directory.View) win.current_tab.slot.view_box).grab_focus(); });
                    location_bar.activate.connect(() => { win.current_tab.path_changed(File.new_for_commandline_arg(location_bar.path)); });
                    if (get_icon_size () == Gtk.IconSize.LARGE_TOOLBAR) {
                        location_bar.margin_top = 6;
                        location_bar.margin_bottom = 6;
                    } 
                    location_bar.show_all();
                    insert(location_bar, -1);
                    continue;
                }
                if (name == "ViewSwitcher")
                {
                    view_switcher = new ViewSwitcher (win.main_actions);
                    if (get_icon_size () == Gtk.IconSize.LARGE_TOOLBAR) {
                        view_switcher.margin_top = 6;
                        view_switcher.margin_bottom = 6;
                    } 
                    view_switcher.show_all();
                    insert(view_switcher, -1);
                    continue;
                }

                Gtk.ToolItem? item;
                Gtk.Action? main_action = win.main_actions.get_action(name);

                if (main_action != null)
                {
                    if (name == "Forward"){
                        win.button_forward = new Varka.Widgets.ToolButtonWithMenu.from_action(main_action);
                        win.button_forward.show_all();
                        insert(win.button_forward, -1);
                    }
                    else if ( name == "Back"){
                        win.button_back = new Varka.Widgets.ToolButtonWithMenu.from_action(main_action);
                        win.button_back.show_all();
                        insert(win.button_back, -1);
                    }else{
                        item = (ToolItem) main_action.create_tool_item();
                        insert(item, -1);
                    }

                }
            }

            insert(app_menu, -1);
            app_menu.right_click.connect(right_click_extern);
        }

        private void toolitems_destroy (Gtk.Widget? w) {
            ((Gtk.Container)this).remove (w);
        }
    }
}

