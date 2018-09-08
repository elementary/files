/***
    Copyright (c) 2011-2018 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Author: ammonkey <am.monkeyd@gmail.com>
***/

namespace Granite.Widgets {

    public class ImgEventBox : Gtk.EventBox {
        private Gdk.Pixbuf? pix = null;
        private int wpix;
        private int hpix;

        public Gtk.Orientation orientation { get; set; }

        public ImgEventBox (Gtk.Orientation o) {
            visible_window = false;
            orientation = o;
        }

        protected override bool draw (Cairo.Context cr) {
            Gtk.Allocation vba;
            get_allocation (out vba);

            if (pix != null) {
                if (orientation == Gtk.Orientation.HORIZONTAL) {
                    Gdk.cairo_set_source_pixbuf (cr, pix, vba.width / 2 - wpix / 2, 0);
                } else {
                    Gdk.cairo_set_source_pixbuf (cr, pix, 3, vba.height / 2 - hpix / 2);
                }

                cr.paint ();
            }

            return true;
        }

        public void set_from_pixbuf (Gdk.Pixbuf _pix) {
            pix = _pix;
            wpix = pix.get_width ();
            hpix = pix.get_height ();

            if (orientation == Gtk.Orientation.HORIZONTAL) {
                set_size_request (-1, hpix);
            } else {
                set_size_request (wpix + 6, -1);
            }

            queue_draw ();
        }
    }
}
