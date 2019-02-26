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
public interface CursorHandler : Object, PositionHandler {
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
        if (cursor_index > 0) {
            new_cursor--;
            update_cursor (new_cursor);
        }

        return new_cursor;
    }

    public virtual int cursor_forward () {
        var new_cursor = cursor_index;
        if (cursor_index < n_items - 1) {
            new_cursor++;
            update_cursor (new_cursor);
        }

        return cursor_index;
    }

    public virtual int cursor_up () {
        var new_cursor = cursor_index;
        if (cursor_index >= cols) {
            new_cursor -= cols;
            update_cursor (new_cursor);
        }

        return cursor_index;
    }

    public virtual int cursor_down () {
        var new_cursor = cursor_index;
        if (cursor_index < n_items - cols - 1) {
            new_cursor += cols;
            update_cursor (new_cursor);
        }

        return cursor_index;
    }

    private void update_cursor (int new_cursor) {
        if (data_at_cursor != null) {
            data_at_cursor.is_cursor_position = false;
        }

        if (new_cursor >= 0 && new_cursor < n_items) {
            data_at_cursor = model.lookup_index (new_cursor);
        }

        if (data_at_cursor != null) {
            data_at_cursor.is_cursor_position = true;
            cursor_index = new_cursor;
        }
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

    public void set_cursor (int index) {
        update_cursor (index);
    }

    public virtual void initialize_cursor () {
        if (n_items > 0) {
            update_cursor (0);
        }
    }
}
}
