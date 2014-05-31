/*
 * Copyright (c) 2014 Elementary Developers and Jeremy Wootten
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
 * Authors : Jeremy Wootten <jeremywootten@gmail.com>
 *
 * Based on gtkcellrendererspinner.c and gtkcellrendererpixbuf.c from
 * GTK - the GIMP Toolkit.
 */

public class Marlin.IconSpinnerRenderer : Gtk.CellRenderer {

    public bool active { get; set; }

    public uint pulse { get; set; }
    public Gtk.IconSize icon_size { get; set; }
    public GLib.Icon? gicon { get; set; }

    public IconSpinnerRenderer () {
    }

    /* Need to implement this abstract method even though it is deprecated since Gtk 3.0 */
    public override void get_size ( Gtk.Widget widget,
                                    Gdk.Rectangle? cell_area,
                                    out int x_offset,
                                    out int y_offset,
                                    out int width,
                                    out int height) {
        int w, h, x, y;
        get_icon_size_and_offsets (widget, cell_area, out w, out h, out x, out y);

        x_offset = x;
        y_offset = y;
        width = w;
        height = h;
    }

    private void get_icon_size_and_offsets (Gtk.Widget widget,
                                            Gdk.Rectangle? cell_area,
                                            out int w, out int h,
                                            out int x_offset, out int y_offset) {
        double align;
        bool rtl;
        int width, height;

        if (!Gtk.icon_size_lookup (icon_size, out width, out height)) {
            warning ("Invalid icon size %d\n", icon_size);
            width = height = 24;
        }

        w = width;
        h = height;

        if (cell_area != null) {
            rtl = widget.get_direction () == Gtk.TextDirection.RTL;

            align = rtl ? 1.0 - this.xalign : this.xalign;
            x_offset = (int) align * (cell_area.width - w - (int) this.xpad * 2);
            x_offset = int.max (x_offset, 0);

            align = rtl ? 1.0 - this.yalign : this.yalign;
            y_offset = (int) align * (cell_area.height - h - (int) this.ypad * 2);
            y_offset = int.max (y_offset, 0);
        } else {
            x_offset = 0;
            y_offset = 0;
        }
    }

    public override void render (Cairo.Context cr,
                                 Gtk.Widget widget,
                                 Gdk.Rectangle background_area,
                                 Gdk.Rectangle cell_area,
                                 Gtk.CellRendererState flags) {

        if (!this.active && this.gicon == null)
            return;

        Gdk.Rectangle pix_rect = { 0, 0, 0, 0 };
        Gdk.Rectangle draw_rect = { 0, 0, 0, 0 };

        get_icon_size_and_offsets (widget,
                                   cell_area,
                                   out pix_rect.width,
                                   out pix_rect.height,
                                   out pix_rect.x,
                                   out pix_rect.y);

        pix_rect.x += cell_area.x + (int) xpad;
        pix_rect.y += cell_area.y + (int) ypad;

        if (!cell_area.intersect (pix_rect, out draw_rect))
            return;

        Gtk.StyleContext style_context = widget.get_style_context ();
        style_context.set_state (get_state (widget, flags));

        if (!active) {
            /* Draw icon */
            style_context.add_class (Gtk.STYLE_CLASS_IMAGE);
            Gtk.IconTheme theme = Gtk.IconTheme.get_for_screen (style_context.get_screen ());
            Gtk.IconInfo info = theme.lookup_by_gicon (gicon,
                                                       int.min (pix_rect.width, pix_rect.height),
                                                       Gtk.IconLookupFlags.USE_BUILTIN |
                                                       Gtk.IconLookupFlags.GENERIC_FALLBACK);
            bool symbolic;
            try {
                Gdk.Pixbuf pixbuf = info.load_symbolic_for_context (style_context, out symbolic);
                style_context.render_icon (cr, pixbuf, pix_rect.x, pix_rect.y);
            } catch (GLib.Error e) {
                warning ("IconSpinnerRenderer could not load and render pixbuf for icon %s", info.get_display_name ());
            }
        } else {
            /* Draw spinner */
            cr.save ();
            Gdk.cairo_rectangle (cr, cell_area);
            cr.clip ();
            Gtk.paint_spinner (widget.get_style (),
                               cr,
                               Gtk.StateType.ACTIVE,
                               widget,
                               "cell",
                               pulse,
                               draw_rect.x, draw_rect.y,
                               draw_rect.width, draw_rect.height);

            cr.restore ();
        }
    }
}
