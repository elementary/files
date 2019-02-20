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
namespace WidgetGrid {
public class WidgetData : Object {
    public static int compare_data_func (void* a, void* b) {
        var data1 = (WidgetData)a;
        var data2 = (WidgetData)b;

        return data1.compare (data2);
    }

    public uint64 data_id { get; construct; }
    public bool is_selected { get; set; default = false; }
    public virtual bool equal (WidgetData b) {return data_id == b.data_id;}
    public virtual int compare (WidgetData b) {
        if (data_id > b.data_id) {
            return 1;
        } else if (b.data_id > data_id) {
            return -1;
        } else {
            return 0;
        }
    }

    construct {
        data_id = get_monotonic_time ();
    }
}
}

