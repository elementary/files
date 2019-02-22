/***
    Copyright (c) 2019 Jeremy Wootten <https://github.com/jeremypw/widget-grid>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors: Jeremy Wootten <jeremy@elementaryos.org>
***/

/*** The WidgetGrid.SelectionHandler interface contains functions associated with selecting items.
     including handling rubberband selection and storing the selected items.
***/
namespace WidgetGrid {
public interface SelectionHandler : Object, PositionHandler {
    /* We can assume only one rubberbanding operation will occur at a time */
    private static int previous_last_rubberband_row = 0;
    private static int previous_last_rubberband_col = 0;

    public abstract SelectionFrame frame { get; construct; }
    public abstract bool rubber_banding { get; set; default = false; }
    public abstract bool can_rubber_band { get; set; default = true; }
    public abstract bool deselect_before_rubber_band { get; set; default = true; }
    public abstract Gee.TreeSet<DataInterface> selected_data { get; set; }

    public abstract Gtk.Widget get_widget ();

    public virtual void start_rubber_banding (Gdk.EventButton event) {
        if (!can_rubber_band) {
            return;
        }

        if (deselect_before_rubber_band && (event.state & Gdk.ModifierType.CONTROL_MASK) == 0) {
            clear_selection ();
        }

        if (!rubber_banding) {
            var x = (int)(event.x);
            var y = (int)(event.y);
            frame.initialize (x, y);
            rubber_banding = true;
        }
    }

    public virtual bool do_rubber_banding (Gdk.EventMotion event) {
        if (!rubber_banding) {
            return false;
        }

        var x = (int)(event.x);
        var y = (int)(event.y);

        var new_width = x - frame.x;
        var new_height = y - frame.y;

        frame.update_size (new_width, new_height);
        var res = mark_selected_in_rectangle (get_framed_rectangle ());
        get_widget ().queue_draw ();
        return res;
    }

    public virtual void end_rubber_banding () {
        SelectionHandler.previous_last_rubberband_row = 0;
        SelectionHandler.previous_last_rubberband_col = 0;

        rubber_banding = false;
        frame.close ();
        get_widget ().queue_draw ();
    }

    protected Gdk.Rectangle get_framed_rectangle () {
        return frame.get_rectangle ();
    }

    protected virtual bool mark_selected_in_rectangle (Gdk.Rectangle rect) {
        int first_row, first_col;
        int previous_last_row = SelectionHandler.previous_last_rubberband_row;
        int previous_last_col = SelectionHandler.previous_last_rubberband_col;
        int last_row, last_col;
        Gdk.Point wp = {0, 0};

        get_row_col_at_pos (rect.x + hpadding, rect.y + vpadding,
                            out first_row, out first_col, out wp);

        get_row_col_at_pos (rect.x + rect.width - hpadding, rect.y + rect.height - vpadding,
                            out last_row, out last_col, out wp);

        bool res = false;
        for (int r = first_row; r <= int.max (last_row, previous_last_row); r++) {
            for (int c = first_col; c <= int.max (last_col, previous_last_col); c++) {
                var to_select = (r <= last_row && c <= last_col);
                var index = get_index_at_row_col (r, c);
                if (to_select) {
                    res |= select_index (index);
                } else {
                    res |= unselect_index (index);
                }
            }
        }

        previous_last_rubberband_col = last_col;
        previous_last_rubberband_row = last_row;

        return res;
    }

    public virtual bool draw_rubberband (Cairo.Context ctx) {
        if (rubber_banding) {
            frame.draw (ctx);
        }

        return false;
    }

    public virtual bool clear_selection () {
        selected_data.clear ();
        reset_selected_data ();
        return true;
    }

    protected virtual bool reset_selected_data () {
        bool res = false;
        for (int i = 0; i < model.get_n_items (); i++) {
            res |= unselect_index (i);
        }

        return res;
    }

    public virtual bool select_all_data () {
        /* Slow for large numbers? Maybe use flag and select on the fly */
        bool res = false;
        for (int i = 0; i < model.get_n_items (); i++) {
            res |= select_index (i);
        }

        return false;
    }

    /* Not efficient - try to avoid - use selected_data if possible */
    public virtual int[] get_selected_indices () {
        var indices = new Gee.LinkedList<int> ();
        for (int i = 0; i < model.get_n_items (); i++) {
            var data = model.lookup_index (i);
            if (data.is_selected) {
                indices.add (i);
            }
        }

        return indices.to_array ();
    }

    public virtual bool select_index (int index) {
        var data = model.lookup_index (index);
        if (data != null && !data.is_selected) {
            data.is_selected = true;
            selected_data.add (data);
            return true;
        }

        return false;
    }

    public virtual bool unselect_index (int index) {
        var data = model.lookup_index (index);
        if (data.is_selected) {
            data.is_selected = false;
            selected_data.remove (data);
            return true;
        }

        return false;
    }
}
}
