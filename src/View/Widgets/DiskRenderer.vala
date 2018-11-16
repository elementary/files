/***
     Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
     Copyright (c) 2015 elementary Team

     Marlin is free software; you can redistribute it and/or
     modify it under the terms of the GNU General Public License as
     published by the Free Software Foundation; either version 2 of the
     License, or (at your option) any later version.

     Marlin is distributed in the hope that it will be useful,
     but WITHOUT ANY WARRANTY; without even the implied warranty of
     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
     General Public License for more details.

     You should have received a copy of the GNU General Public
     License along with this program; see the file COPYING.  If not,
     write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
     Boston, MA 02110-1335 USA.

***/

public class Marlin.CellRendererDisk : Gtk.CellRendererText {
    public uint64 free_space { set; get; }
    public uint64 disk_size { set; get; }
    public bool is_disk { set; get; }

    // offset to left align disk usage graphic with the text
    private const int OFFSET = 2;
    private const int BAR_HEIGHT = 5;

    construct {
        is_disk = false;
        disk_size = 0;
        free_space = 0;
    }

    public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle bg_area,
                                 Gdk.Rectangle area, Gtk.CellRendererState flags) {

        base.render (cr, widget, bg_area, area, flags);

        if (!is_disk) {
            return;
        }

        var x = area.x += OFFSET;
        /* Draw bar on background area to allow room for space between bar and text */
        var y = bg_area.y + bg_area.height - BAR_HEIGHT - 2;
        var total_width = area.width - OFFSET - 2;
        uint fill_width = total_width - (int) (((double) free_space / (double) disk_size) * (double) total_width);



        var context = widget.get_style_context ();

        /* White full length and height background */
        context.add_class ("storage-bar");
        context.add_class ("trough");
        context.render_background (cr, x, y, total_width, BAR_HEIGHT);
        context.remove_class ("trough");
        /* Blue part of bar */
        context.add_class ("fill-block");
        context.render_background (cr, x, y, fill_width , BAR_HEIGHT);

        cr.rectangle (x, y, total_width, BAR_HEIGHT);
        cr.set_line_width (1.0);
        cr.set_source_rgba (0.0, 0.0, 0.0, 0.3);
        cr.stroke ();
    }
}
