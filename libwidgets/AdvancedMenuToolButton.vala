/*
 * Copyright (c) 2011 Mathijs Henquet
 *
 * Marlin is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

using Gdk;

namespace Gtk {

    public abstract class AdvancedMenuToolButton : ToolButton
    {
        public delegate Menu MenuFetcher();

        private int long_press_time = Gtk.Settings.get_default().gtk_double_click_time * 2;
        private int menu_width = 200;
        private Button button;
        private int timeout = -1;

        private PositionType _menu_orientation;
        public PositionType menu_orientation{
            set{
                var orientation = value;
                switch(orientation){
                    case(PositionType.TOP):
                    case(PositionType.BOTTOM):
                        orientation = PositionType.LEFT;
                    break;
                }
                _menu_orientation = orientation;
            }
            get{
                return _menu_orientation;
            }
        }

        public signal void long_click();
        public signal void right_click(Gdk.EventButton ev);

        private bool has_fetcher = false;
        private MenuFetcher _fetcher;
        public MenuFetcher fetcher{
            set{
                _fetcher = value;
                has_fetcher = true;
            }
            get{
                return _fetcher;
            }
        }

        private Menu _menu;
        public Menu menu {
            get {
                    return _menu;
                }
            set {
                    if(has_fetcher)
                        Log.println(Log.Level.WARN, "Don't set the menu property on a AdvancedMenuToolButton when there is allready a menu fetcher");
                    else{
                        _menu = value;
                        update_menu_properties();
                }
            }
        }

        public AdvancedMenuToolButton.from_stock (string stock_image, IconSize size, string label, Menu menu)
        {
            Image image = new Image.from_stock(stock_image, size);

            this(image, label, menu);
        }

        private void update_menu_properties()
        {
            if(menu_orientation == PositionType.RIGHT){
                menu.set_size_request(menu_width, -1);
            }
            menu.attach_to_widget (this, null);
            menu.deactivate.connect(() => {
                //active = false;
            });
            menu.deactivate.connect(popdown_menu);
        }

        public AdvancedMenuToolButton (Image image, string label, Menu _menu, PositionType _menu_orientation = PositionType.LEFT)
        {
            this.menu_orientation = _menu_orientation;

            icon_widget = image;
            label_widget = new Label (label);
            ((Label) label_widget).use_underline = true;
            can_focus = true;

            menu = _menu;

            mnemonic_activate.connect(on_mnemonic_activate);

            button = (Button) get_child();
            button.events |= EventMask.BUTTON_PRESS_MASK
                          |  EventMask.BUTTON_RELEASE_MASK;

            button.button_press_event.connect(on_button_press_event);
            button.button_release_event.connect(on_button_release_event);
        }

        public override void show_all(){
            menu.show_all();
            base.show_all();
        }

        private bool on_button_release_event (Gdk.EventButton ev)
        {
            if(timeout != -1){
                Source.remove((uint) timeout);
                timeout = -1;
            }

            return false;
        }

        private bool on_button_press_event (Gdk.EventButton ev)
        {
            if(timeout == -1 && ev.button == 1){
                timeout = (int) Timeout.add(long_press_time, () => {
                    long_click();
                    timeout = -1;
                    return false;
                });
            }

            if(ev.button == 3){
                right_click(ev);
            }

            return false;
        }

        private bool on_mnemonic_activate (bool group_cycling)
        {
            // ToggleButton always grabs focus away from the editor,
            // so reimplement Widget's version, which only grabs the
            // focus if we are group cycling.
            if (!group_cycling) {
                activate ();
            } else if (can_focus) {
                grab_focus ();
            }

            return true;
        }

        protected new void popup_menu(Gdk.EventButton? ev = null)
        {
            if(has_fetcher) fetch_menu();

            menu.select_first (true);

            try {
                menu.popup (null,
                            null,
                            get_menu_position,
                            (ev == null) ? 0 : ev.button,
                            (ev == null) ? get_current_event_time() : ev.time);
            } finally {
                // Highlight the parent
                if (menu.attach_widget != null)
                    menu.attach_widget.set_state(StateType.SELECTED);
            }
        }

        protected void popdown_menu ()
        {
            menu.popdown ();

            // Unhighlight the parent
            if (menu.attach_widget != null)
                menu.attach_widget.set_state(Gtk.StateType.NORMAL);
        }

        private void fetch_menu(){
            _menu = fetcher();
            update_menu_properties();
        }

        private void get_menu_position (Menu menu, out int x, out int y, out bool push_in)
        {
            if (menu.attach_widget == null ||
                menu.attach_widget.get_window() == null) {
                // Prevent null exception in weird cases
                x = 0;
                y = 0;
                push_in = true;
                return;
            }

            menu.attach_widget.get_window().get_origin (out x, out y);
            Allocation allocation;
            menu.attach_widget.get_allocation(out allocation);

            x += allocation.x;

            if(menu_orientation == PositionType.RIGHT){
                x += allocation.width;
                x -= menu_width;
            }

            y += allocation.y;

            int width, height;
            menu.get_size_request(out width, out height);

            if (y + height >= menu.attach_widget.get_screen().get_height())
                y -= height;
            else
                y += allocation.height;

            push_in = true;
        }
    }
}

