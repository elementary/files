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

/*** The interface for a rectangular frame for rubberband selection.
     May have negative dimensions if current moving point behind/above starting point.
***/
public interface SelectionFrame : Object {
    public abstract int x { get; set; }
    public abstract int y { get; set; }
    public abstract int width { get; set; }
    public abstract int height { get; set; }

    public abstract void initialize (int x, int y);
    public abstract void update_size (int width, int height);
    public abstract void close ();
    public abstract bool draw (Cairo.Context ctx);

    /* Always return positive dimensions */
    public virtual Gdk.Rectangle get_rectangle () {
        var rect = Gdk.Rectangle ();
        rect.x = x;
        rect.y = y;
        rect.width = width;
        rect.height = height;

        if (width < 0) {
            rect.x = x + width;
            rect.width = -width;
        }

        if (height < 0) {
            rect.y = y + height;
            rect.height = -height;
        }

        return rect;
    }
}
