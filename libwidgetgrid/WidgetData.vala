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

/*** WidgetGrid.DataInterface is the base class for objects stored by WidgetGrid.Model.
     The data contained herein is used to dynamically update widgets used for display
     by WidgetGrid.View.
***/
namespace WidgetGrid {
public class WidgetData : Object, DataInterface {
    public uint64 data_id { get; construct; }
    public bool is_selected { get; set; default = false; }

    construct {
        data_id = get_monotonic_time ();
    }
}
}

