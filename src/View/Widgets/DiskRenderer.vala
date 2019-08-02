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

public class Marlin.CellRendererDisk : Marlin.TextRenderer {
    // padding to the right of the disk usage graphic
    public int rpad { set; get; }
    public uint64 free_space { set; get; }
    public uint64 disk_size { set; get; }

    // offset to left align disk usage graphic with the text
    private const int OFFSET = 2;
    private const int LEVEL_BAR_HEIGHT = 4;

    public CellRendererDisk (Marlin.ViewMode mode = Marlin.ViewMode.LIST) {
        base (mode);
        rpad = 0;
    }

    public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle bg_area,
                                 Gdk.Rectangle area, Gtk.CellRendererState flags) {

        base.render (cr, widget, bg_area, area, flags);
        area.x += OFFSET;
        area.width -= OFFSET;

        if (free_space > 0) {
            var context = widget.get_style_context ();
            context.add_class ("level-bar");
            uint width = area.width - rpad;
            uint fill_width = width - (int) (((double) free_space / (double) disk_size) * ((double) area.width - 2));

            context.render_background (cr, area.x, area.y + area.height - 3, width, LEVEL_BAR_HEIGHT);
            context.add_class ("fill-block");
            context.render_background (cr, area.x, area.y + area.height - 3, fill_width, LEVEL_BAR_HEIGHT);
            context.remove_class ("fill-block");
            context.render_frame (cr, area.x, area.y + area.height - 3, width, LEVEL_BAR_HEIGHT);
        }
    }
}
