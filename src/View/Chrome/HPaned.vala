
using Gtk;
using Gdk;

namespace Marlin.View.Chrome{
    public class HPaned : Gtk.HPaned{
        private int saved_state = 10;
        private uint last_click_time = 0;
        
        public signal void shrink();
        public new signal void expand(int saved_state);
    
        public HPaned(){
            events |= EventMask.BUTTON_PRESS_MASK;
            
            button_press_event.connect(detect_toggle);
        }
    
        private bool detect_toggle( EventButton event )
        {
            if(event.time < (last_click_time + Gtk.Settings.get_default().gtk_double_click_time) && event.type != EventType.2BUTTON_PRESS ){
                return true;
            }        
        
            if( 
              Gdk.Window.at_pointer( null, null ) == this.get_handle_window() 
              && event.type == EventType.2BUTTON_PRESS 
            ){
                accept_position();
            
                var current_position = this.get_position();
                int pos;
                
                if( current_position == 0 ){
                    Log.println( Log.Level.INFO, "[HPaned] expand" );
                    
                    pos = saved_state;
                }
                else{
                    saved_state = current_position;
                    Log.println( Log.Level.INFO, "[HPaned] shrink" );
                    
                    pos = 0;
                }
                
                set_position(pos);
                
                return true;
            }
            
            last_click_time = event.time;
            
            return false;
        }
    }
}
