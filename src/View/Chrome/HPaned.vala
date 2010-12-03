
using Gtk;
using Gdk;

namespace Marlin.View.Chrome{
    public class HPaned : Gtk.HPaned{
        private int saved_state = 10;
        public signal void shrink();
        public new signal void expand(int saved_state);
    
        public HPaned(){
            events |= EventMask.BUTTON_PRESS_MASK;
            
            button_press_event.connect(detect_toggle);
        }
    
        private bool detect_toggle( EventButton event )
        {
            Log.println( Log.Level.DEBUG, "[ContextView] did" );
        
            if( 
              Gdk.Window.at_pointer( null, null ) == this.get_handle_window() 
              && event.button == 3 
            ){
                var current_position = this.get_position();
                
                if( current_position == 0 ){
                    Log.println( Log.Level.INFO, "[ContextView] expand hpaned" );
                    set_position( saved_state );
                }
                else{
                    saved_state = current_position;
                    Log.println( Log.Level.INFO, "[ContextView] shrink hpaned" );
                    set_position( 0 );
                }
            }
            
            return false;
        }
    }
}
