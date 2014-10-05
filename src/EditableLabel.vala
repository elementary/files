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
    public class EditableLabel : Gtk.TextView, Gtk.Editable, Gtk.CellEditable {

        public bool editing_canceled { get; set; }
        public bool small_size { get; set; }
        public float yalign {get; set;}
        public float xalign {get; set;}
        public string original_name;

        public EditableLabel () {
            key_press_event.connect (on_key_press_event);
        }

        public void set_text (string text) {
            get_buffer ().set_text (text);
            original_name = text;
        }

        public void set_line_wrap (bool wrap) {
            if (!wrap)
                set_wrap_mode (Gtk.WrapMode.NONE);
            else
                set_wrap_mode (Gtk.WrapMode.CHAR);
        }

        public void set_line_wrap_mode (Pango.WrapMode mode) {
            switch (mode) {
                case Pango.WrapMode.CHAR:
                    set_wrap_mode (Gtk.WrapMode.CHAR);
                    break;
                case Pango.WrapMode.WORD:
                    set_wrap_mode (Gtk.WrapMode.WORD);
                    break;
                case Pango.WrapMode.WORD_CHAR:
                    set_wrap_mode (Gtk.WrapMode.WORD_CHAR);
                    break;
                default:
                    break;
            }
        }

        public void set_justify (Gtk.Justification jtype) {
            justification = jtype;
        }

        public void set_padding (int xpad, int ypad) {
            set_margin_start (xpad);
            set_margin_end (xpad);
            set_margin_top (ypad);
            set_margin_bottom (ypad);
        }

        public string get_text () {
            var buffer = get_buffer ();
            Gtk.TextIter? start = null;
            Gtk.TextIter? end = null;
            buffer.get_start_iter (out start);
            buffer.get_end_iter (out end);
            return buffer.get_text (start, end, false);
        }

        public bool on_key_press_event (Gdk.EventKey event) {
//message ("Editable key press");
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

                    break;
                default:
                    return false;
            }

            return true;
        }

        /** Gtk.Editable interface */

        public void select_region (int start_pos, int end_pos) {
            var buffer = get_buffer ();
            Gtk.TextIter? ins = null;
            Gtk.TextIter? bound = null;

            buffer.get_iter_at_offset (out ins, start_pos);
            if (end_pos > 0)
                buffer.get_iter_at_offset (out bound, end_pos);
            else
                buffer.get_end_iter (out bound);

            buffer.select_range (ins, bound);
        }

        public void do_delete_text (int start_pos, int end_pos) {
            var buffer = get_buffer ();
            Gtk.TextIter? start = null;
            Gtk.TextIter? end = null;

            buffer.get_iter_at_offset (out start, start_pos);
            if (end_pos > 0)
                buffer.get_iter_at_offset (out end, end_pos);
            else
                buffer.get_end_iter (out end);

            buffer.delete_range (start, end);
        }

        public void do_insert_text (string new_text, int new_text_length, ref int position) {
            var buffer = get_buffer ();
            Gtk.TextIter? pos = null;

            buffer.get_iter_at_offset (out pos, position);
            buffer.insert (ref pos, new_text, new_text_length);
        }

        public string get_chars (int start_pos, int end_pos) {
            var buffer = get_buffer ();
            Gtk.TextIter? start = null;
            Gtk.TextIter? end = null;

            buffer.get_iter_at_offset (out start, start_pos);
            if (end_pos > 0)
                buffer.get_iter_at_offset (out end, end_pos);
            else
                buffer.get_end_iter (out end);

            buffer.delete_range (start, end);

            return buffer.get_text (start, end, false);
        }

        public int get_position () {
            var buffer = get_buffer ();
            var mark = buffer.get_insert ();
            Gtk.TextIter? iter = null;
            buffer.get_iter_at_mark (out iter, mark);

            return iter.get_offset ();
        }

        public bool get_selection_bounds (out int start_pos, out int end_pos) {
            var buffer = get_buffer ();
            Gtk.TextIter? start = null;
            Gtk.TextIter? end = null;

            buffer.get_selection_bounds (out start, out end);
            start_pos = start.get_offset ();
            end_pos = end.get_offset ();
            return start_pos != end_pos;
        }

        public void set_position (int position) {
            var buffer = get_buffer ();
            Gtk.TextIter? iter = null;
            buffer.get_start_iter (out iter);
            iter.set_offset (position);
            buffer.place_cursor (iter);
        }

        /** CellEditable interface */
        /* modified gtk+-3.0.vapi required */
        public void start_editing (Gdk.Event? event) {

        }
    }
}
