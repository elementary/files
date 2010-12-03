
using Gtk;
using Gdk;

namespace Marlin.View.Chrome{
    public class HPaned : Gtk.HPaned{
        private int saved_state = 10;
        private uint last_click_time = 0;
        
        public signal void shrink();
        public new signal void expand(int saved_state);
    
        public HPaned(){
            events |= EventMask.BUTTON_PRESS_MASK
                   |  EventMask.BUTTON_RELEASE_MASK;
            
            button_press_event.connect(detect_toggle);
            button_release_event.connect(() => {
                return false;
            });
        }
    
        private bool detect_toggle( EventButton event )
        {
            if(event.time < (last_click_time + 1500) && event.type != EventType.2BUTTON_PRESS ){
                Log.println( Log.Level.DEBUG, "[HPaned] too soon" );
                return true;
            }
        
            Log.println( Log.Level.DEBUG, "[HPaned] event" );
        
            if( 
              Gdk.Window.at_pointer( null, null ) == this.get_handle_window() 
              && event.type == EventType.2BUTTON_PRESS 
            ){
                accept_position();
            
                var current_position = this.get_position();
                
                if( current_position == 0 ){
                    Log.println( Log.Level.DEBUG, "[HPaned] expand" );
                    set_position( saved_state );
                    
                }
                else{
                    saved_state = current_position;
                    Log.println( Log.Level.DEBUG, "[HPaned] shrink" );
                    set_position( 0 );
                }
                
                return true;
            }
            
            last_click_time = event.time;
            
            return false;
        }
    }
}
