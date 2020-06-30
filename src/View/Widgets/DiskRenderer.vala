/***
     Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
     Copyright (c) 2015-2019 elementary, Inc (https://elementary.io)

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
    private const int OFFSET = 3;
    private const int BAR_HEIGHT = 4;

    construct {
        is_disk = false;
        disk_size = 0;
        free_space = 0;
    }

    public override void get_preferred_height_for_width (Gtk.Widget widget, int width,
                                                         out int minimum_size, out int natural_size) {
        int min, nat;
        base.get_preferred_height_for_width (widget, width, out min, out nat);
        natural_size = nat + BAR_HEIGHT;
        minimum_size = min + BAR_HEIGHT;
    }

    public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle bg_area,
                                 Gdk.Rectangle area, Gtk.CellRendererState flags) {

        base.render (cr, widget, bg_area, area, flags);

        if (!is_disk) {
            return;
        }

        var x = area.x += OFFSET;
        /* Draw bar on background area to allow room for space between bar and text */
        var y = bg_area.y + bg_area.height - BAR_HEIGHT - 3;
        var total_width = area.width - OFFSET - 2;
        uint fill_width = total_width - (int) (((double) free_space / (double) disk_size) * (double) total_width);

        var sidebar_provider = new Gtk.CssProvider ();
        sidebar_provider.load_from_resource ("/io/elementary/files/DiskRenderer.css");

        var context = widget.get_style_context ();
        context.add_provider (sidebar_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        context.save ();

        /* Full length and height background */
        context.add_class (Gtk.STYLE_CLASS_LEVEL_BAR);
        context.add_class (Gtk.STYLE_CLASS_FRAME);
        context.render_background (cr, x, y, total_width, BAR_HEIGHT);
        context.render_frame (cr, x, y, total_width, BAR_HEIGHT);

        /* Filled part of bar */
        double filled_percent = ((double) disk_size - (double) free_space) / (double) disk_size;
        if (filled_percent >= 0.9) {
            context.add_class ("fill-block-critical");
        } else if (filled_percent >= 0.75) {
            context.add_class ("fill-block-warn");
        } else {
            context.add_class ("fill-block");
        }

        context.render_background (cr, x, y, fill_width , BAR_HEIGHT);
        context.render_frame (cr, x, y, fill_width, BAR_HEIGHT);

        context.restore ();
    }
}
