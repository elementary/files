/***
    Copyright (c) 2011-2013 Mathijs Henquet

    This program or library is free software; you can redistribute it
    and/or modify it under the terms of the GNU Lesser General Public
    License as published by the Free Software Foundation; either
    version 3 of the License, or (at your option) any later version.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
    Lesser General Public License for more details.

    You should have received a copy of the GNU Lesser General
    Public License along with this library; if not, write to the
    Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1301 USA.

    Authors: Mathijs Henquet <mathijs.henquet@gmail.com>,
             ammonkey <am.monkeyd@gmail.com>
***/

/*
 * ButtonWithMenu
 * - support long click / right click with depressed button states
 * - activate a GtkAction if any or popup a menu.
 * (used in history navigation buttons next/prev, appmenu)
 *
 */

namespace Marlin.View.Chrome {

    /**
     * ButtonWithMenu
     * - support long click / right click with depressed button states
     * - activate a GtkAction if any or popup a menu
     * (used in history navigation buttons and the AppMenu)
     */
    public class ButtonWithMenu : Gtk.ToggleButton {

        public signal void right_click (Gdk.EventButton ev);

        /**
         * VMenuPosition:
         */
        public enum VMenuPosition {
            /**
             * TOP: Align the menu at top of button position.
             */
            TOP,
            /**
             * TOP: Align the menu at top of button position.
             */
            BOTTOM
        }

        /**
         * HMenuPosition:
         */
        public enum HMenuPosition {
            /**
             * LEFT: Left-align the menu relative to the button's position.
             */
            LEFT,
            /**
             * CENTER: Center-align the menu relative to the button's position.
             */
            CENTER,
            /**
             * RIGHT: Right-align the menu relative to the button's position.
             */
            RIGHT,
            /**
             * INSIDE_WINDOW: Keep the menu inside the GtkWindow. Center-align when possible.
             */
            INSIDE_WINDOW // center by default but move it the menu goes out of the window
        }

        public HMenuPosition horizontal_menu_position { get; set; default = HMenuPosition.CENTER; }
        public VMenuPosition vertical_menu_position { get; set; default = VMenuPosition.BOTTOM; }

        public ulong toggled_sig_id;

        public signal void slow_press ();

        private Gtk.Menu _menu;
        public Gtk.Menu menu {
            get {
                return _menu;
            }

            set {
                _menu = value;
                update_menu_properties ();
            }
        }

        private int LONG_PRESS_TIME = Gtk.Settings.get_default ().gtk_double_click_time * 2;
        private uint timeout = 0;
        private uint last_click_time = 0;

        construct {
            timeout = 0;

            realize.connect (() => {
                get_top_level ().configure_event.connect (() => {
                    if (timeout > 0) {
                        Source.remove (timeout);
                        timeout = 0;
                    }

                    return false;
                });
            });
        }

        public ButtonWithMenu.from_icon_name (string icon_name, Gtk.IconSize size) {
            this ();
            image = new Gtk.Image.from_icon_name (icon_name, size);
        }

        private void update_menu_properties () {
            menu.attach_to_widget (this, null);
            menu.deactivate.connect ( () => {
                deactivate_menu ();
            });
            menu.deactivate.connect (popdown_menu);
        }

        public ButtonWithMenu () {
            use_underline = true;
            can_focus = true;

            this.menu = new Gtk.Menu ();

            mnemonic_activate.connect (on_mnemonic_activate);

            events |= Gdk.EventMask.BUTTON_PRESS_MASK |
                      Gdk.EventMask.BUTTON_RELEASE_MASK;

            button_press_event.connect (on_button_press_event);
            button_release_event.connect (on_button_release_event);
        }

        public override void show_all () {
            menu.show_all ();
            base.show_all ();
        }

        private void deactivate_menu () {
            active = false;
        }

        private bool on_button_release_event (Gdk.EventButton ev) {
            if (ev.time - last_click_time < LONG_PRESS_TIME) {
                slow_press ();
                active = false;
            }

            if (timeout > 0) {
                Source.remove (timeout);
                timeout = 0;
            }

            return false;
        }

        private bool on_button_press_event (Gdk.EventButton ev) {
            /* If the button is kept pressed, don't make the user wait when there's no action */
            int max_press_time = LONG_PRESS_TIME;
            if (ev.button == 1 || ev.button == 3) {
                active = true;
            }

            if (timeout == 0 && ev.button == 1) {
                last_click_time = ev.time;
                timeout = Timeout.add (max_press_time, () => {
                    /* long click */
                    timeout = 0;
                    popup_menu (ev);
                    return false;
                });
            }

            if (ev.button == 3) {
                /* right_click */
                right_click (ev);
                popup_menu (ev);
            }
            return true;

        }

        private bool on_mnemonic_activate (bool group_cycling) {
            /* ToggleButton always grabs focus away from the editor,
             * so reimplement Widget's version, which only grabs the
             * focus if we are group cycling.
             */
            if (!group_cycling) {
                activate ();
            } else if (can_focus) {
                grab_focus ();
            }

            return true;
        }

        protected new void popup_menu (Gdk.EventButton? ev = null) {
            try {
                menu.popup (null,
                            null,
                            get_menu_position,
                            (ev == null) ? 0 : ev.button,
                            (ev == null) ? Gtk.get_current_event_time () : ev.time);
            } finally {
                menu.select_first (false);
            }
        }

        protected void popdown_menu () {
            menu.popdown ();
        }

        private void get_menu_position (Gtk.Menu menu, out int x, out int y, out bool push_in) {
            Gtk.Allocation menu_allocation;
            menu.get_allocation (out menu_allocation);

            if (menu.attach_widget == null || menu.attach_widget.get_window () == null) {
                /* Prevent null exception in weird cases */
                x = 0;
                y = 0;
                push_in = true;
                return;
            }

            menu.attach_widget.get_window ().get_origin (out x, out y);

            Gtk.Allocation allocation;
            menu.attach_widget.get_allocation (out allocation);

            /* Left, right or center??*/
            if (horizontal_menu_position == HMenuPosition.RIGHT) {
                x += allocation.x;

            } else if (horizontal_menu_position == HMenuPosition.CENTER) {
                x += allocation.x;
                x -= menu_allocation.width / 2;
                x += allocation.width / 2;
            } else {
                x += allocation.x;
                x -= menu_allocation.width;
                x += this.get_allocated_width ();
            }

            /* Bottom or top?*/
            if (vertical_menu_position == VMenuPosition.TOP) {
                y -= menu_allocation.height;
                y -= this.get_allocated_height ();
            }

            int width, height;
            menu.get_size_request (out width, out height);

            if (horizontal_menu_position == HMenuPosition.INSIDE_WINDOW) {
                /* Get window geometry */
                var parent_widget = get_toplevel ();

                Gtk.Allocation window_allocation;
                parent_widget.get_allocation (out window_allocation);

                parent_widget.get_window ().get_origin (out x, out y);
                int parent_window_x0 = x;
                int parent_window_xf = parent_window_x0 + window_allocation.width;

                /* Now check if the menu is outside the window and un-center it
                 * if that's the case
                 */

                if (x + menu_allocation.width > parent_window_xf) {
                    x = parent_window_xf - menu_allocation.width; // Move to left
                }

                if (x < parent_window_x0) {
                    x = parent_window_x0; // Move to right
                }
            }

            y += allocation.y;

            if (y + height >= menu.attach_widget.get_screen ().get_height ()) {
                y -= height;
            } else {
                y += allocation.height;
            }

            push_in = true;
        }
    }
}
