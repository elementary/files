using Gtk;

namespace Marlin.View.Chrome {

    public class CompactToolMenuButton : ToolButtonWithMenu
    {
        public CompactToolMenuButton.from_stock (string stock_image, IconSize size, string label, Menu menu)
        {
            Image image = new Image.from_stock(stock_image, size);

            this(image, label, menu);
        }

        public CompactToolMenuButton (Image image, string label, Menu menu)
        {
            base(image, label, menu);

            clicked.connect(on_clicked);
        }

        private void on_clicked ()
        {
            menu.select_first (true);
            popup_menu (null);
        }
    }
}
