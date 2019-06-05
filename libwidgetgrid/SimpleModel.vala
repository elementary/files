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

/*** WidgetGrid.SimpleModel is a basic falback model for WidgetGrid.View if no other is provided
     on creation of the View.
     It is based on Vala.ArrayList and does not implement sorting.
***/

namespace WidgetGrid {
public class SimpleModel : Object, Model<DataInterface> {
    private Vala.ArrayList<DataInterface> list;

    construct {
        list = new Vala.ArrayList<DataInterface> ();
    }

    protected bool real_add (DataInterface data) {
        assert (data != null);
        return list.add (data);
    }

    protected bool real_remove_data (DataInterface data) {
        assert (data != null);
        return list.remove (data);
    }

    protected bool real_remove_index (int index) {
        return list.remove_at (index) != null;
    }

    public bool lookup_index (int index, out DataInterface data) {
        data = null;

        if (index < 0 || index >= list.size) {
            return false;
        } else {
            data = list[index];
            return true;
        }
    }

    public int lookup_data (DataInterface data) {
        assert (data != null);
        return list.index_of (data);
    }

    public int get_n_items () {
        return list.size;
    }
}
}
