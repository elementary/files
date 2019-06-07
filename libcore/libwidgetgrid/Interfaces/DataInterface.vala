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

/*** WidgetGrid.WidgetData is the base class for objects stored by WidgetGrid.Model.
     The data contained herein is used to dynamically update widgets used for display
     by WidgetGrid.View.
***/

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

/*** WidgetGrid.DataInterface is the rewuired interdace for objects stored by WidgetGrid.Model.
     The data contained herein is used to dynamically update widgets used for display
     by WidgetGrid.View.
***/
namespace WidgetGrid {
public interface DataInterface : Object {
    public static int compare_data_func (void* a, void* b) {
        var data1 = (DataInterface)a;
        var data2 = (DataInterface)b;

        return data1.compare (data2);
    }

    /* Warning: is_selected should only be changed by the SelectionHandler */
    public abstract bool is_selected { get; set; default = false; }
    public abstract bool is_cursor_position { get; set; default = false; }
    public abstract uint64 data_id { get; construct; } /* Implementations must ensure a unique id is assigned */

    public virtual bool equal (DataInterface b) {return data_id == b.data_id;}

    public virtual int compare (DataInterface b) {
        if (data_id > b.data_id) {
            return 1;
        } else if (b.data_id > data_id) {
            return -1;
        } else {
            return 0;
        }
    }
}
}

