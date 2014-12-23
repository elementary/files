/*
 * Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
 *
 * Marlin is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */

public class Marlin.CellRendererDisk : Gtk.CellRendererText {

    public uint64 free_space { set; get; }
    public uint64 disk_size { set; get; }

    /* padding to the right of the disk usage graphic */
    public uint rpad {set; get;}

    /* offset to left align disk usage graphic with the text */
    private int offset = 2;

    public CellRendererDisk () {
        rpad = 0;
    }

    /**
     * Function called by gtk to determine the size request of the cell.
     **/
    public override void get_size (Gtk.Widget widget, Gdk.Rectangle? cell_area,
                                   out int x_offset, out int y_offset,
                                   out int width, out int height) {
        height = 50;
        width = 250; /* Hardcoded, maybe it should be configurable */
        x_offset = 0;
        y_offset = 0;
    }

    /**
     * Function called by gtk to draw the cell content.
     **/
    public override void render (Cairo.Context cr, Gtk.Widget widget,
                                 Gdk.Rectangle background_area, Gdk.Rectangle area,
                                 Gtk.CellRendererState flags) {
        base.render (cr, widget, background_area, area, flags);
        area.x+= offset; 
        area.width-= offset;
        if (free_space > 0) {
            Gtk.StateFlags state;
            Gtk.StyleContext context = widget.get_parent ().get_style_context ();
            cr.set_line_width (1.0);
            uint width = area.width - rpad;
            if (widget.get_state_flags () != Gtk.StateFlags.BACKDROP) {
                state = Gtk.StateFlags.NORMAL;
                state |= widget.get_state_flags ();
                var color_border = context.get_color (state);
                color_border.alpha -= 0.4;
                Gdk.cairo_set_source_rgba (cr, color_border);
                cr.rectangle (area.x,
                              area.y + area.height - 3,
                              width,
                              4);
                cr.fill ();
            }
            state = Gtk.StateFlags.SELECTED;
            state |= widget.get_state_flags ();
            Gdk.cairo_set_source_rgba (cr, context.get_color (state));
            cr.rectangle (area.x + 1,
                          area.y + area.height - 2,
                          width - 2,
                          2);
            cr.fill ();

            Gdk.cairo_set_source_rgba (cr, context.get_background_color(state));
            cr.rectangle (area.x + 1,
                          area.y + area.height - 2,
                          width - (int)(((double)free_space)/((double)disk_size)*((double)area.width - 2)),
                          2);
            cr.stroke ();
        }
    }
}
