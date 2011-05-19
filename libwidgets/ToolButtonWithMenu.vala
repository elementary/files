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

namespace Gtk{
    public class ToolButtonWithMenu : AdvancedMenuToolButton, Activatable {
        public ToolButtonWithMenu.from_action (Action action)
        {
            this.from_stock(action.stock_id, IconSize.MENU, action.label);

            use_action_appearance = true;
            set_related_action(action);

            action.connect_proxy(this);


        }

        public ToolButtonWithMenu.from_stock (string stock_image, IconSize size, string label)
        {
            var _menu = new Menu();
            _menu.insert(new MenuItem.with_label("Todo"), -1);
            _menu.show_all();

            base.from_stock(stock_image, size, label, _menu);

            connect_actions();
        }

        public ToolButtonWithMenu (Image image, string label, PositionType menu_orientation = PositionType.LEFT)
        {
            base(image, label, new Menu(), menu_orientation);

            connect_actions();
        }

        private void connect_actions(){
            long_click.connect(() => {
                popup_menu();
            });

            right_click.connect(() => {
                popup_menu();
            });
        }
    }
}

