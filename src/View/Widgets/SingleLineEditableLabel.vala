/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace Files {
    public class SingleLineEditableLabel : Gtk.Frame, EditableLabelInterface {

        public bool small_size { get; set; }
        public bool draw_outline { get; set; }
        public float yalign { get; set; }
        public float xalign { get; set; }
        
        // public signal void editing_done ();
        // public signal void remove_widget ();

        protected Gtk.Entry textview;
        private int select_start = 0;
        private int select_end = 0;
        // private string original_name;

        construct {
            init_delegate ();
            set_child (textview);
        }

        public void init_delegate () {
            textview = new Gtk.Entry ();
            /* Block propagation of button press event as this would cause renaming to end */
            // textview.button_press_event.connect_after (() => { return true; });
            // return textview as Gtk.Widget;
        }

        public unowned Gtk.Editable? get_delegate () {
            return (Gtk.Editable?)textview;
        }

        public void set_text (string text) {
            textview.set_text (text);
            // original_name = text;
        }


        public void set_justify (Gtk.Justification jtype) {
            switch (jtype) {
                case Gtk.Justification.LEFT:
                    textview.set_alignment (0.0f);
                    break;

                case Gtk.Justification.CENTER:
                    textview.set_alignment (0.5f);
                    break;

                case Gtk.Justification.RIGHT:
                    textview.set_alignment (1.0f);
                    break;

                default:
                    textview.set_alignment (0.5f);
                    break;
            }
        }

        public string get_text () {
            return textview.get_text ();
        }

        //TODO Use EventControllers
        // public bool on_key_press_event (Gdk.EventKey event) {
        //     /* Ensure rename cancelled on cursor Up/Down */
        //     uint keyval;
        //     event.get_keyval (out keyval);
        //     switch (keyval) {
        //         case Gdk.Key.Up:
        //         case Gdk.Key.Down:
        //             end_editing (true);
        //             return true;

        //         default:
        //             break;
        //     }

        //     return base.on_key_press_event (event);
        // }

        /** Gtk.Editable interface */

        public void select_region (int start_pos, int end_pos) {
            /* Cannot select textview region here because it is not realised yet and the selected region
             * will be overridden when keyboard focus is grabbed after realising. So just remember start and end.
             */
            select_start = start_pos;
            select_end = end_pos;
        }

        public void do_delete_text (int start_pos, int end_pos) {
            textview.delete_text (start_pos, end_pos);
        }

        public void do_insert_text (string new_text, int new_text_length, ref int position) {
            textview.insert_text (new_text, new_text_length, ref position);
        }

        public string get_chars (int start_pos, int end_pos) {
            return textview.get_chars (start_pos, end_pos);
        }

        public int get_position () {
            return textview.get_position ();
        }

        public bool get_selection_bounds (out int start_pos, out int end_pos) {
            int start, end;
            bool result = textview.get_selection_bounds (out start, out end);
            start_pos = start;
            end_pos = end;
            return result;
        }

        public void set_position (int position) {
            textview.set_position (position);
        }

        // public void set_size_request (int width, int height) {
        //     textview.set_size_request (width, height);
        // }

        // CellEditable interface (abstract part)
        [NoAccessorMethod]
        public bool editing_canceled { get; set; }
        public void start_editing (Gdk.Event? event) {
            /* Now realised.  Grab keyboard focus first and then select region */
            textview.grab_focus ();
            textview.select_region (select_start, select_end);
        }
        
        //EditableLabelInterface (abstract)
        public void end_editing (bool cancelled) {
            editing_canceled = cancelled;
            remove_widget ();
            editing_done ();
        }
    }
}
