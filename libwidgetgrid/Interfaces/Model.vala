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

/*** WidgetGrid.Model<G> interface defines the requirements for a model usable with WidgetGrid.View.
***/
namespace WidgetGrid {
[GenericAccessors]
public interface Model<DataInterface> : Object {
    public bool add (DataInterface data) {/* Returns position inserted at (or -1 if not implemented) */
        assert (data != null);
        if (real_add (data)) {
            n_items_changed (1);
            return true;
        } else {
            return false;
        }
    }

    protected abstract bool real_add (DataInterface data);

    public int add_array (DataInterface[] data_array) { /* Returns positions inserted at */
        int added = 0;
        var n_items = data_array.length;
        for (int index = 0; index < n_items; index++) {
            if (add (data_array[index])) {
                added++;
            }
        }

        return added;
    }

    public bool remove_index (int index) {
        DataInterface data;
        lookup_index (index, out data);
        if (data != null && real_remove_index (index)) {
            data_removed (data);
            return true;
        } else {
            return false;
        }
    }

    protected abstract bool real_remove_index (int index);

    public bool remove_data (DataInterface data) {
        assert (data != null);
        if (real_remove_data (data)) {
            data_removed (data);
            return true;
        } else {
            return false;
        }
    }

    protected abstract bool real_remove_data (DataInterface data);

    public abstract bool lookup_index (int index, out DataInterface data);

    public abstract int lookup_data (DataInterface data);

    public virtual bool sort (CompareDataFunc func) {
        return false;
    }

    public abstract int get_n_items ();

    public signal void n_items_changed (int n_changed);
    public signal void data_removed (DataInterface data);
}
}
