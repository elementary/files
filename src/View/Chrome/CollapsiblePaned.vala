//  
//  Copyright (C) 2011 Mathijs Henquet
// 
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
// 

using Gtk;
using Gdk;

namespace Varka.Widgets {

    public enum CollapseMode {
        NONE=0,
        LEFT=1, TOP=1, FIRST=1,
        RIGHT=2, BOTTOM=2, LAST=2
    }

    public class CollapsiblePaned : Paned {
    
        private int saved_state = 10;
        private uint last_click_time = 0;

        public CollapseMode collapse_mode = CollapseMode.NONE;
        //public signal void shrink(); //TODO: Make the default action overwriteable
        //public new signal void expand(int saved_state); //TODO same

        public CollapsiblePaned (Orientation o) {
            //events |= EventMask.BUTTON_PRESS_MASK;
            set_orientation (o);

            button_press_event.connect (detect_toggle);
        }

        private bool detect_toggle (EventButton event) {
            
            if (collapse_mode == CollapseMode.NONE)
                return false;

            if (event.time < (last_click_time + Gtk.Settings.get_default ().gtk_double_click_time) && event.type != EventType.2BUTTON_PRESS)
                return true;

            if (Gdk.Window.at_pointer (null, null) == this.get_handle_window () && event.type == EventType.2BUTTON_PRESS) {
            
                accept_position ();

                var current_position = get_position ();

                if (collapse_mode == CollapseMode.LAST)
                    current_position = (max_position - current_position); // change current_position to be relative

                int requested_position;
                if (current_position == 0) {
                    debug ("[CollapsablePaned] expand");

                    requested_position = saved_state;
                } else {
                    saved_state = current_position;
                    debug ("[CollapsablePaned] shrink");

                    requested_position = 0;
                }

                if (collapse_mode == CollapseMode.LAST)
                    requested_position = max_position - requested_position; // change requeste_position back to be non-relative

                set_position (requested_position);

                return true;
            }

            last_click_time = event.time;

            return false;
        }
        
    }

    public class HCollapsiblePaned : CollapsiblePaned {
    
        public HCollapsiblePaned () {
            base (Orientation.HORIZONTAL);
        }
        
    }

    public class VCollapsiblePaned : CollapsiblePaned {
    
        public VCollapsiblePaned () {
            base (Orientation.VERTICAL);
        }
        
    }
    
}

