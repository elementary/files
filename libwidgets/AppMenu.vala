namespace Gtk {
    public class AppMenu : AdvancedMenuToolButton
    {
        public AppMenu.from_stock (string stock_image, IconSize size, string label, Menu menu)
        {
            base.from_stock(stock_image, size, label, menu);
            
            connect_actions();
        }

        public AppMenu (Image image, string label, Menu menu)
        {
            base(image, label, menu);
            
            connect_actions();
        }
        
        private void connect_actions(){
            clicked.connect(() => {
                popup_menu();
            });
        }
    }
}
