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

        private ToolButtonWithMenu.from_stock (string stock_image, IconSize size, string label)
        {
            var _menu = new Menu();
            _menu.insert(new MenuItem.with_label("Todo"), -1);
            _menu.show_all();

            base.from_stock(stock_image, size, label, _menu);

            connect_actions();
        }

        private ToolButtonWithMenu (Image image, string label, PositionType menu_orientation = PositionType.LEFT)
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

