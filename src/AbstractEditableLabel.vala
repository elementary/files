/*
 Copyright (C) 2014 elementary Developers

 This program is free software: you can redistribute it and/or modify it
 under the terms of the GNU Lesser General Public License version 3, as published
 by the Free Software Foundation.

 This program is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY; without even the implied warranties of
 MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 PURPOSE. See the GNU General Public License for more details.

 You should have received a copy of the GNU General Public License along
 with this program. If not, see <http://www.gnu.org/licenses/>.

 Authors : Jeremy Wootten <jeremy@elementary.org>
*/


namespace Marlin {
    public abstract class AbstractEditableLabel : Gtk.Frame, Gtk.Editable, Gtk.CellEditable {

        public bool editing_canceled { get; set; }
        public bool small_size { get; set; }
        public float yalign {get; set;}
        public float xalign {get; set;}
        public string original_name;
        public bool draw_outline {get; set;}

        public Gtk.Widget editable_widget;

        public AbstractEditableLabel () {
            editable_widget = create_editable_widget ();
            add (editable_widget);
            show_all ();
            get_real_editable ().key_press_event.connect (on_key_press_event);
        } 

        public bool on_key_press_event (Gdk.EventKey event) {
            bool control_pressed = ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0);
            switch (event.keyval) {
                case Gdk.Key.Return:
                case Gdk.Key.KP_Enter:
                    editing_canceled = false;
                    editing_done ();
                    remove_widget ();
                    break;

                case Gdk.Key.Escape:
                    editing_canceled = true;
                    editing_done ();
                    remove_widget ();
                    break;

                case Gdk.Key.z:
                    if (control_pressed)
                        set_text (original_name);
                    else
                        return false;

                    break;

                default:
                    return false;
            }
            return true;
        }


        public virtual void set_text (string text) {
            original_name = text;
        }

        public virtual void set_line_wrap (bool wrap) {}
        public virtual void set_line_wrap_mode (Pango.WrapMode mode) {}
        public virtual void set_justify (Gtk.Justification jtype) {}
        public virtual void set_padding (int xpad, int ypad) {}
        
        public abstract new void set_size_request (int width, int height);
        public abstract Gtk.Widget create_editable_widget ();
        public abstract string get_text ();
        public abstract void select_region (int start_pos, int end_pos);
        public abstract void do_delete_text (int start_pos, int end_pos);
        public abstract void do_insert_text (string new_text, int new_text_length, ref int position);
        public abstract string get_chars (int start_pos, int end_pos);
        public abstract int get_position ();
        public abstract bool get_selection_bounds (out int start_pos, out int end_pos);
        public abstract void set_position (int position);
        public abstract Gtk.Widget get_real_editable ();


        /** CellEditable interface */
        /* modified gtk+-3.0.vapi required */
        public virtual void start_editing (Gdk.Event? event) {}
    }
}
