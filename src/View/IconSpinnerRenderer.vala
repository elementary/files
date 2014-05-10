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

    public override void get_size ( Gtk.Widget widget,
                                    Gdk.Rectangle? cell_area,
                                    out int x_offset,
                                    out int y_offset,
                                    out int width,
                                    out int height) {
        double align;
        int w, h;
        bool rtl;

        icon_get_size (out w, out h);

        w += (int) this.xpad * 2;
        h += (int) this.ypad * 2;

        if (cell_area != null) {
            rtl = widget.get_direction () == Gtk.TextDirection.RTL;

            align = rtl ? 1.0 - this.xalign : this.xalign;
            x_offset = (int) align * (cell_area.width - w);
            x_offset = int.max (x_offset, 0);

            align = rtl ? 1.0 - this.yalign : this.yalign;
            y_offset = (int) align * (cell_area.height - h);
            y_offset = int.max (y_offset, 0);
        } else {
            x_offset = 0;
            y_offset = 0;
        }

        width = w;
        height = h;
    }

    private void icon_get_size (out int pixbuf_width, out int pixbuf_height ) {
        int width, height;
        if (!Gtk.icon_size_lookup (icon_size, out width, out height)) {
            warning ("Invalid icon size %d\n", icon_size);
            width = height = 24;
        }
        pixbuf_width = width;
        pixbuf_height = height;
    }

    public override void render (Cairo.Context cr,
                                 Gtk.Widget widget,
                                 Gdk.Rectangle background_area,
                                 Gdk.Rectangle cell_area,
                                 Gtk.CellRendererState flags) {

        Gdk.Rectangle pix_rect = { 0, 0, 0, 0 };
        Gdk.Rectangle draw_rect = { 0, 0, 0, 0 };

        if (!this.active && this.gicon == null)
            return;

        get_size (widget, cell_area, out pix_rect.x, out pix_rect.y, out pix_rect.width, out pix_rect.height);

        pix_rect.x += cell_area.x + (int) xpad;
        pix_rect.y += cell_area.y + (int) ypad;
        pix_rect.width -= (int) xpad * 2;
        pix_rect.height -= (int) ypad * 2;

        if (!cell_area.intersect (pix_rect, out draw_rect))
            return;

        var state = Gtk.StateType.NORMAL;
        if ((widget.get_state_flags () & Gtk.StateFlags.INSENSITIVE) != 0 || !get_sensitive ())
            state = Gtk.StateType.INSENSITIVE;
        else {
            if ((flags & Gtk.CellRendererState.SELECTED) != 0) {
                if (widget.has_focus)
                    state = Gtk.StateType.SELECTED;
                else
                    state = Gtk.StateType.ACTIVE;
            } else
                state = Gtk.StateType.PRELIGHT;
        }

        if (!active) {
            /* Draw icon */
            Gtk.StyleContext style_context = widget.get_style_context ();
            style_context.save ();
            style_context.set_state (get_state (widget, flags));
            style_context.add_class (Gtk.STYLE_CLASS_IMAGE);

            Gtk.IconTheme theme = Gtk.IconTheme.get_for_screen (style_context.get_screen ());
            Gtk.IconInfo info = theme.lookup_by_gicon (gicon,
                                                       int.min (pix_rect.width, pix_rect.height),
                                                       Gtk.IconLookupFlags.USE_BUILTIN |
                                                       Gtk.IconLookupFlags.GENERIC_FALLBACK);
            bool symbolic;
            try {
                Gdk.Pixbuf pixbuf = info.load_symbolic_for_context (style_context, out symbolic);
                Gtk.render_icon (style_context, cr, pixbuf, pix_rect.x, pix_rect.y);
            } catch (GLib.Error e) {
                warning ("IconSpinnerRenderer could not load and render pixbuf for icon %s", info.get_display_name ());
            }
            style_context.restore ();
        } else {
            /* Draw spinner */
            cr.save ();
            Gdk.cairo_rectangle (cr, cell_area);
            cr.clip ();
            Gtk.paint_spinner (widget.get_style (),
                               cr,
                               state,
                               widget,
                               "cell",
                               pulse,
                               draw_rect.x, draw_rect.y,
                               draw_rect.width, draw_rect.height);
            cr.restore ();
        }
    }
}
