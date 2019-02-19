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

/*** WidgetGrid.AbstractItemFactory is the basis for a class that generates WidgetGrid.Items on
     demand.  The factory can supply any widget that implements the WidgetGrid.Item interface.
     The definition of the Item class is usually contained within the ItemFactory.
***/
namespace FM {
public class IconGridItemFactory : WidgetGrid.AbstractItemFactory {
    public override WidgetGrid.Item new_item () {
        return new FM.IconGridItem ();
    }
}
}
