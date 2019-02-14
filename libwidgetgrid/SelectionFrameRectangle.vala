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

/*** Used to draw a translucent rectangle for use in rubber band selection.
     It may be possible to use a widget to produce more a sophisticated theme-aware appearance.
***/
public class SelectionFrameRectangle : Object, SelectionFrame {
    private Gdk.Rectangle rect;
    public int x { get {return rect.x;} set {rect.x = value;}}
    public int y { get {return rect.y;} set {rect.y = value;}}
    public int width { get {return rect.width;} set {rect.width = value;}}
    public int height { get {return rect.height;} set {rect.height = value;}}

    construct {
        rect = Gdk.Rectangle () {x = 0, y = 0, width = 0, height = 0};
    }

    public void initialize (int x, int y) {
        this.x = x;
        this.y = y;
    }

    public void update_size (int width, int height) {
        this.width = width;
        this.height = height;
    }

    public void close () {
        x = 0;
        y = 0;
        width = 0;
        height = 0;
    }

    public bool draw (Cairo.Context ctx) {
        var draw_rect = get_rectangle ();
        double xx = (double)(draw_rect.x);
        double yy = (double)(draw_rect.y);
        double ww = (double)(draw_rect.width);
        double hh = (double)(draw_rect.height);

        ctx.save ();
        ctx.set_source_rgba (0, 0, 1, 0.3);
        ctx.rectangle (xx, yy, ww, hh);
        ctx.fill ();
        ctx.restore ();

        return false;
    }
}
