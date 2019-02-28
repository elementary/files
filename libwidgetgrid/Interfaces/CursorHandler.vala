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
public interface CursorHandler : Object, SelectionHandler {
    public abstract Gtk.Layout layout { get; construct; }
    public abstract DataInterface data_at_cursor { get; set; }
    public abstract int cursor_index { get; set; }

    public virtual int get_index_at_cursor () {
        return cursor_index;
    }

    public virtual void cursor_invalidated () {
        cursor_index = model.lookup_data (data_at_cursor);
    }

    public virtual int cursor_back () {
        var new_cursor = cursor_index;
        new_cursor--;
        update_cursor (new_cursor);

        return new_cursor;
    }

    public virtual int cursor_forward () {
        var new_cursor = cursor_index;
        new_cursor++;
        update_cursor (new_cursor);

        return cursor_index;
    }

    public virtual int cursor_up () {
        var new_cursor = cursor_index;
        new_cursor -= cols;
        update_cursor (new_cursor);

        return cursor_index;
    }

    public virtual int cursor_down () {
        var new_cursor = cursor_index;
        new_cursor += cols;
        update_cursor (new_cursor);

        return cursor_index;
    }

    private bool update_cursor (int new_cursor) {
        bool res = false;
        if (data_at_cursor != null) {
            data_at_cursor.is_cursor_position = false;
            res = true;
        }

        int cursor = new_cursor.clamp (0, n_items - 1);
        data_at_cursor = model.lookup_index (cursor);

        if (data_at_cursor != null) {
            data_at_cursor.is_cursor_position = true;
            res = true;
            cursor_index = cursor;
        } else {
            cursor_index = -1;
        }


        return false;
    }

    public virtual void handle_cursor_keys (uint keyval) {
        switch (keyval) {
            case Gdk.Key.Up:
                cursor_up ();
                break;

            case Gdk.Key.Down:
                cursor_down ();
                break;

            case Gdk.Key.Left:
                cursor_back ();
                break;

            case Gdk.Key.Right:
                cursor_forward ();
                break;

            default:
                break;
        }

        layout.queue_draw ();
    }

    public void set_cursor (int index, bool select = false) {
        if (update_cursor (index) && select) {
            select_data_index (index);
        }
    }

    public virtual void initialize_cursor () {
        if (n_items > 0) {
            update_cursor (0);
        }
    }

    public virtual bool move_cursor (uint keyval, bool linear_select = false, bool deselect = true) {
        var previous_cursor_index = cursor_index;

        if (keyval == Gdk.Key.Right) {
            cursor_forward ();
        } else if (keyval == Gdk.Key.Left) {
            cursor_back ();
        } else if (keyval == Gdk.Key.Up) {
            cursor_up ();
        } else if (keyval == Gdk.Key.Down) {
            cursor_down ();
        }

        if (linear_select) {
            linear_select_index (cursor_index, previous_cursor_index);
        } else {
            if (deselect) {
                clear_selection ();
            }

            set_cursor (cursor_index, true);
            end_linear_select ();
        }

        return true;
    }

    protected void end_linear_select () {
        initial_linear_selection_index = -1;
        previous_linear_selection_index = -1;
    }
}
}
