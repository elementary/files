
using Gtk;
using Gdk;

namespace Marlin.View.Chrome{
    

    public class HPaned : Gtk.HPaned{
        private int saved_state = 10;
        private uint last_click_time = 0;
        
        public int collapse = -1;
        public signal void shrink();
        public new signal void expand(int saved_state);
    
        public HPaned(){
            events |= EventMask.BUTTON_PRESS_MASK;
            
            button_press_event.connect(detect_toggle);
        }
    
        private bool detect_toggle( EventButton event )
        {
            if(collapse == -1){ // if colapse == -1, dont collapse at all
                return false;
            }
        
            if(event.time < (last_click_time + Gtk.Settings.get_default().gtk_double_click_time) && event.type != EventType.2BUTTON_PRESS ){
                return true;
            }        
        
            if( 
              Gdk.Window.at_pointer( null, null ) == this.get_handle_window() 
              && event.type == EventType.2BUTTON_PRESS 
            ){
                accept_position();
            
                Allocation allocation;
                get_allocation(out allocation);
                var current_position = this.get_position();
                
                if(collapse == 2){ // if collapse mode is 2
                    current_position = (allocation.width - current_position) - get_handle_window().get_width(); // change current_position to be relative
                }
                
                int requested_position;                
                if( current_position == 0 ){
                    Log.println( Log.Level.INFO, "[HPaned] expand" );
                    
                    requested_position = saved_state;
                }
                else{
                    saved_state = current_position;
                    Log.println( Log.Level.INFO, "[HPaned] shrink" );
                    
                    requested_position = 0;
                }
                
                if(collapse == 2){
                    requested_position = (allocation.width - requested_position) - get_handle_window().get_width(); // change requeste_position back to be non-relative
                }
                
                set_position(requested_position);
                
                return true;
            }
            
            last_click_time = event.time;
            
            return false;
        }
    }
}
