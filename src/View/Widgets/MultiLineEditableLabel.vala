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
    public class MultiLineEditableLabel : AbstractEditableLabel {

        protected Gtk.ScrolledWindow scrolled_window;
        protected Gtk.TextView textview;

        public MultiLineEditableLabel () {}

        public override Gtk.Widget create_editable_widget () {
            textview = new Gtk.TextView ();
            /* Block propagation of button press event as this would cause renaming to end */
            textview.button_press_event.connect_after (() => { return true; });

            scrolled_window = new Gtk.ScrolledWindow (null, null) {
                child = textview
            };

            return scrolled_window as Gtk.Widget;
        }

        public override Gtk.Widget get_real_editable () {
            return textview;
        }

        public override void set_text (string text) {
            textview.get_buffer ().set_text (text);
            original_name = text;
        }

        public override void set_line_wrap (bool wrap) {
            if (!wrap) {
                textview.set_wrap_mode (Gtk.WrapMode.NONE);
            } else {
                textview.set_wrap_mode (Gtk.WrapMode.CHAR);
            }
        }

        public override void set_line_wrap_mode (Pango.WrapMode mode) {
            switch (mode) {
                case Pango.WrapMode.CHAR:
                    textview.set_wrap_mode (Gtk.WrapMode.CHAR);
                    break;

                case Pango.WrapMode.WORD:
                    textview.set_wrap_mode (Gtk.WrapMode.WORD);
                    break;

                case Pango.WrapMode.WORD_CHAR:
                    textview.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);
                    break;

                default:
                    break;
            }
        }

        public override void set_justify (Gtk.Justification jtype) {
            textview.justification = jtype;
        }

        public override void set_padding (int xpad, int ypad) {
            textview.set_margin_start (xpad);
            textview.set_margin_end (xpad);
            textview.set_margin_top (ypad);
            textview.set_margin_bottom (ypad);
        }

        public override string get_text () {
            var buffer = textview.get_buffer ();
            Gtk.TextIter? start = null;
            Gtk.TextIter? end = null;
            buffer.get_start_iter (out start);
            buffer.get_end_iter (out end);
            return buffer.get_text (start, end, false);
        }

        /** Gtk.Editable interface */

        public override void select_region (int start_pos, int end_pos) {
            textview.grab_focus ();
            var buffer = textview.get_buffer ();
            Gtk.TextIter? ins = null;
            Gtk.TextIter? bound = null;

            buffer.get_iter_at_offset (out ins, start_pos);

            if (end_pos > 0) {
                buffer.get_iter_at_offset (out bound, end_pos);
            } else {
                buffer.get_end_iter (out bound);
            }

            buffer.select_range (ins, bound);
        }

        public override void do_delete_text (int start_pos, int end_pos) {
            var buffer = textview.get_buffer ();
            Gtk.TextIter? start = null;
            Gtk.TextIter? end = null;

            buffer.get_iter_at_offset (out start, start_pos);

            if (end_pos > 0) {
                buffer.get_iter_at_offset (out end, end_pos);
            } else {
                buffer.get_end_iter (out end);
            }

            buffer.delete_range (start, end);
        }

        public override void do_insert_text (string new_text, int new_text_length, ref int position) {
            var buffer = textview.get_buffer ();
            Gtk.TextIter? pos = null;

            buffer.get_iter_at_offset (out pos, position);
            buffer.insert (ref pos, new_text, new_text_length);
        }

        public override string get_chars (int start_pos, int end_pos) {
            var buffer = textview.get_buffer ();
            Gtk.TextIter? start = null;
            Gtk.TextIter? end = null;

            buffer.get_iter_at_offset (out start, start_pos);

            if (end_pos > 0) {
                buffer.get_iter_at_offset (out end, end_pos);
            } else {
                buffer.get_end_iter (out end);
            }

            return buffer.get_text (start, end, false);
        }

        public override int get_position () {
            var buffer = textview.get_buffer ();
            var mark = buffer.get_insert ();
            Gtk.TextIter? iter = null;
            buffer.get_iter_at_mark (out iter, mark);

            return iter.get_offset ();
        }

        public override bool get_selection_bounds (out int start_pos, out int end_pos) {
            var buffer = textview.get_buffer ();
            Gtk.TextIter? start = null;
            Gtk.TextIter? end = null;

            buffer.get_selection_bounds (out start, out end);
            start_pos = start.get_offset ();
            end_pos = end.get_offset ();

            return start_pos != end_pos;
        }

        public override void set_position (int position) {
            var buffer = textview.get_buffer ();
            Gtk.TextIter? iter = null;
            buffer.get_start_iter (out iter);
            iter.set_offset (position);
            buffer.place_cursor (iter);
        }

        public override bool draw (Cairo.Context cr) {
            bool result = base.draw (cr);
            if (draw_outline) {
                Gtk.Allocation allocation;
                Gdk.RGBA color;
                Gdk.Rectangle outline;

                get_allocation (out allocation);
                color = get_style_context ().get_color (get_state_flags ());
                Gdk.cairo_set_source_rgba (cr, color);
                cr.set_line_width (1.0);
                outline = {0, 0, allocation.width, allocation.height};
                Gdk.cairo_rectangle (cr, outline);
                cr.stroke ();
            }
            return result;
        }

        public override void set_size_request (int width, int height) {
            textview.set_size_request (width, height);
        }

        public override void start_editing (Gdk.Event? event) {
            textview.grab_focus ();
        }
    }
}
