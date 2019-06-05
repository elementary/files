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

/*** The PositionHandler interface contains functions associated with determining the correct position
     of items, the dimensions of rows, and retrieving items from position data.
***/
namespace WidgetGrid {
public interface PositionHandler : Object {
    public abstract Gee.ArrayList<RowData> row_data { get; set; }
    public abstract Gee.ArrayList<Item> widget_pool { get; construct; }
    public abstract int first_displayed_widget_index { get;}
    public abstract int last_displayed_widget_index { get; }

    public abstract WidgetGrid.Model<DataInterface> model { get; construct; }
    public abstract int n_items { get; protected set; default = 0; }

    public abstract int vpadding { get; set; default = 6;}
    public abstract int hpadding { get; set; default = 6;}
    public abstract int cols { get; protected set; default = 1;}
    public abstract int item_width { get; set; default = 48;}
    public int column_width {
        get {
            return item_width + hpadding;
        }
    }

    protected abstract void position_items ();
    protected abstract Item widget_for_data_index (int data_index);

    public int index_below (int index) {
        index += cols;
        if (index < 0 || index > n_items) {
            return -1;
        } else {
            return index;
        }
    }

    public int index_above (int index) {
        index -= cols;
        if (index < 0 || index > n_items) {
            return -1;
        } else {
            return index;
        }
    }

    public bool get_row_col_at_pos (int x, int y, out int row, out int col, out Gdk.Point widget_p) {
        bool on_item_cell = true;
        row = 0;
        col = 0;
        int wx = -1;
        int wy = -1;
        widget_p = {0, 0};

        if (row_data.size < 1) {
            return false;
        }

        double cc = (double)(x - hpadding) / (double)column_width;
        double x_offset;
        if (cc > (double)(cols)) {
            x_offset = -1;
            cc = cols - 1;
        } else {
            x_offset = (cc - (int)cc) * column_width;
        }

        if (x_offset < 0 || x_offset > item_width) {
            on_item_cell = false;
        } else {
            wx = (int)x_offset;
        }

        int index = 0;

        while (index < (row_data.size - 1) && row_data[index].y < y) {
            index++;
        }

        if (index > 0) {
            index--;
        }

        var y_offset = y - row_data[index].y;
        if (y_offset < 0 || y_offset > row_data[index].height) {
            on_item_cell = false;
        } else {
            wy = (int)y_offset;
        }

        row = index;
        col = (int)cc;
        widget_p = {wx, wy};

        return row * cols + col < n_items && on_item_cell;
    }

    public virtual int get_index_at_row_col (int row, int col) {
        if (row < 0 || row >= row_data.size) {
            return -1;
        }

        return row_data[row].first_data_index + col;
    }

    public virtual int get_index_at_pos (Gdk.Point p) {
        int row = 0;
        int col = 0;
        Gdk.Point wp = {0, 0};

        if (get_row_col_at_pos (p.x, p.y, out row, out col, out wp)) {
            return row_data[row].first_data_index + col;
        } else {
            return -1;
        }
    }

    public virtual DataInterface? get_data_at_row_col (int row, int col) {
        DataInterface data;
        if (model.lookup_index (row_data[row].first_data_index + col, out data)) {
            return data;
        } else {
            return null;
        }
    }

    public virtual bool get_data_at_pos (Gdk.Point p, out DataInterface data) {
        int row = 0;
        int col = 0;
        Gdk.Point wp = {0, 0};
        data = null;

        if (get_row_col_at_pos (p.x, p.y, out row, out col, out wp)) {
            data = get_data_at_row_col (row, col);
            return true;
        } else {
            return false;
        }
    }

    public virtual Item? get_item_at_row_col (int row, int col) {
        var data_index = row_data[row].first_data_index + col;
        if (data_index >= n_items) {
            return null;
        }

        return widget_pool[row_data[row].first_widget_index + col];
    }

    public virtual Item? get_item_at_pos (Gdk.Point p, out Gdk.Point corrected_p) {
        int r = 0;
        int c = 0;
        corrected_p = {0, 0};

        Item? item = null;

        if (get_row_col_at_pos (p.x, p.y, out r, out c, out corrected_p)) {
            item = get_item_at_row_col (r, c);
        }

        if (item != null) {
            var p_rect = Gdk.Rectangle () {x = p.x, y = p.y, width = 1, height = 1};
            if (!item.intersect (p_rect)) {
                item = null;
            }
        }

        return item;
    }

    /** @index is the index of the last item on the previous row (or -1 for the first row).
        The row height is the largest height request of the widgets in the row
    **/
    protected virtual int get_row_height (int data_index) { /* widgets previous updated */
        if (data_index < 0) {
            critical ("invalid index");
            return -1;
        }

        var max_h = 0;
        var d_index = data_index;
        for (int c = 0; c < cols && d_index < model.get_n_items (); c++) {
            var item = widget_for_data_index (d_index);
            DataInterface data;
            if (model.lookup_index (d_index, out data)) {
                item.update_item (data);
            }

            item.set_max_width (item_width);

            int min_h, nat_h, min_w, nat_w;
            item.get_preferred_width (out min_w, out nat_w);
            item.get_preferred_height_for_width (min_w, out min_h, out nat_h);

            if (nat_h > max_h) {
                max_h = nat_h;
            }

            if (min_w > item_width + hpadding) {
                item_width = min_w - hpadding;
            }

            d_index++;
        }

        d_index = data_index;
        for (int c = 0; c < cols && d_index < model.get_n_items (); c++) {
            var item = widget_for_data_index (d_index);
            item.set_size_request (-1, max_h);
            d_index++;
        }

        return max_h;
    }
}
}
