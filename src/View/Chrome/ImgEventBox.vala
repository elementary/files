/*  
 * Copyright (C) 2011 Elementary Developers
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author: ammonkey <am.monkeyd@gmail.com>
 */ 

using Gtk;
using Gdk;
using Cairo;

namespace Varka.Widgets {

    public class ImgEventBox : EventBox 
    {
        private Pixbuf? pix = null;
        private int wpix;
        private int hpix;

        public Orientation orientation { get; set; }
        
        public ImgEventBox (Orientation o)
        {
            visible_window = false;
            orientation = o;
        }

        protected override bool draw (Context cr) {
            Allocation vba;
            get_allocation (out vba);

            if (pix != null) { 
                //cairo_set_source_pixbuf (cr, pix, 0, 0);
                if (orientation == Orientation.HORIZONTAL)
                    cairo_set_source_pixbuf (cr, pix, vba.width/2 - wpix/2, 0);
                else
                    cairo_set_source_pixbuf (cr, pix, 3, vba.height/2 - hpix/2);
                cr.paint();
            }
            
            return true;
        }

        public void set_from_pixbuf (Pixbuf _pix) {
            pix = _pix;
            wpix = pix.get_width();
            hpix = pix.get_height();
            //message ("evbox set_from_pix %d %d", wpix, hpix);
            if (orientation == Orientation.HORIZONTAL)
                set_size_request (-1, hpix);
            else
                set_size_request (wpix+6, -1);
            queue_draw ();
        }
    }
}
