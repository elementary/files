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
    public abstract class AbstractEditableLabel : Gtk.Frame, Gtk.Editable, Gtk.CellEditable {

        public bool editing_canceled { get; set; }
        public bool small_size { get; set; }
        public float yalign {get; set;}
        public float xalign {get; set;}
        public string original_name;
        public bool draw_outline {get; set;}

        // private Gtk.Widget editable_widget;

        construct {
            init_delegate ();
            set_child (get_delegate ());
            // get_delegate ().key_press_event.connect (on_key_press_event);
        }

        //TODO Use EventControllers
        // public virtual bool on_key_press_event (Gdk.EventKey event) {
        //     Gdk.ModifierType state;
        //     event.get_state (out state);
        //     uint keyval;
        //     event.get_keyval (out keyval);
        //     var mods = state & Gtk.accelerator_get_default_mod_mask ();
        //     bool only_control_pressed = (mods == Gdk.ModifierType.CONTROL_MASK);

        //     switch (keyval) {
        //         case Gdk.Key.Return:
        //         case Gdk.Key.KP_Enter:
        //             /*  Only end rename with unmodified Enter. This is to allow use of Ctrl-Enter
        //              *  to commit Chinese/Japanese characters when using some input methods, without ending rename.
        //              */
        //             if (mods == 0) {
        //                 end_editing (false);
        //                 return true;
        //             }

        //             break;

        //         case Gdk.Key.Escape:
        //             end_editing (true);
        //             return true;

        //         case Gdk.Key.z:
        //             /* Undo with Ctrl-Z only */
        //             if (only_control_pressed) {
        //                 set_text (original_name);
        //                 return true;
        //             }
        //             break;

        //         default:
        //             break;
        //     }
        //     return false;
        // }

        public void end_editing (bool cancelled) {
            editing_canceled = cancelled;
            remove_widget ();
            editing_done ();
        }

        public virtual void set_text (string text) {
            original_name = text;
        }

        public virtual void set_line_wrap (bool wrap) {}
        public virtual void set_line_wrap_mode (Pango.WrapMode mode) {}
        public virtual void set_justify (Gtk.Justification jtype) {}
        public virtual void set_padding (int xpad, int ypad) {}

        public abstract new void set_size_request (int width, int height);
        public abstract void init_delegate ();
        // public abstract string get_text ();
        public abstract void select_region (int start_pos, int end_pos);
        public abstract void do_delete_text (int start_pos, int end_pos);
        public abstract void do_insert_text (string new_text, int new_text_length, ref int position);
        public abstract string get_chars (int start_pos, int end_pos);
        public abstract int get_position ();
        public abstract bool get_selection_bounds (out int start_pos, out int end_pos);
        public abstract void set_position (int position);

        /** CellEditable interface */
        public virtual void start_editing (Gdk.Event? event) {}
        
        /** Editable interface */
        public string text { get; set; }
        public bool editable { get; set; }
        public bool enable_undo { get; set; }
        public int max_width_chars { get; set; }
        public int selection_bound { get;}
        public int cursor_position { get; }
        public int width_chars { get; set; }
        public abstract unowned string get_text ();
        public abstract unowned Gtk.Editable? get_delegate ();
        
    }
}
