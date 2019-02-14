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

/*** WidgetGrid.RowData is used to store relevant information about each displayed row in the View.
***/
namespace WidgetGrid {
public class RowData {
    public int first_data_index = int.MAX;
    public int first_widget_index = int.MAX;
    public int y = int.MAX;
    public int height = int.MAX;

    public void update (int fdi, int fwi, int y, int h) {
        first_data_index = fdi;
        first_widget_index = fwi;
        this.y = y;
        height = h;
    }
}
}
