using Gtk;
using Gdk;

namespace Marlin.View.Chrome {

    public class ToolButtonExtraOptions : ToolButtonWithMenu
    {
        Button button;

        public ToolButtonExtraOptions.from_stock (string stock_image, IconSize size, string label, Menu menu)
        {
            Image image = new Image.from_stock(stock_image, size);

            this(image, label, menu);
        }

        public ToolButtonExtraOptions (Image image, string label, Menu menu)
        {
            base(image, label, menu);

            button = (Button) get_child();

            button.events |= EventMask.BUTTON_PRESS_MASK
                          |  EventMask.BUTTON_RELEASE_MASK;

            button.button_press_event.connect(on_button_press_event);
            button.button_release_event.connect(on_button_release_event);
        }

        private bool on_button_press_event (Gdk.EventButton ev)
        {
            Timeout.add(500, on_long_press);
            return false;
        }
        
        private bool on_long_press(){
            on_clicked();
            
            return false;
        }
        
        private bool on_button_release_event (Gdk.EventButton ev)
        {
            //if( button.intersect( { (int) Math.round(ev.x), (int) Math.round(ev.y), 0, 0 } , null) ){
            on_clicked();
            //}
            return false;
        }

        private void on_clicked ()
        {
            menu.select_first (true);
            popup_menu (null);
            set_active(true);
        }
    }
}
