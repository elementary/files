/***
    Copyright (c) 2021 Elementary, Inc <https://elementary.io>

    Pantheon Files is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of the
    License, or (at your option) any later version.

    Pantheon Files is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this program; see the file COPYING.  If not,
    write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1335 USA.

    Author(s):  Jeremy Wootten <jeremy@elementaryos.org>

***/

public class Files.EmblemRenderer : Gtk.CellRenderer {
    private static Gee.HashMap<string, Gdk.Pixbuf> emblem_pixbuf_map;
    static construct {
        emblem_pixbuf_map = new Gee.HashMap<string, Gdk.Pixbuf> ();
    }

    public static void clear_cache () {
        emblem_pixbuf_map.clear ();
    }

    public Files.File? file { get; set; }
    private const int RIGHT_MARGIN = 12;
    private int icon_scale = 1;

    public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle background_area,
                                 Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {

        if (file == null) {
            return;
        }

        if (widget.get_scale_factor () != icon_scale) {
            icon_scale = widget.get_scale_factor ();
        }

        var style_context = widget.get_parent ().get_style_context ();

        int pos = 1;
        var emblem_area = Gdk.Rectangle ();

        foreach (string emblem in file.emblems_list) {
            Gdk.Pixbuf? pix = null;
            var key = emblem + "-symbolic";

            if (emblem_pixbuf_map.has_key (key)) {
                pix = emblem_pixbuf_map.@get (key);
            } else {
                pix = render_icon (key, style_context);
                if (pix == null) {
                    continue;
                }

                emblem_pixbuf_map.@set (key, pix);
            }

            emblem_area.y = cell_area.y + (cell_area.height - Files.IconSize.EMBLEM) / 2;
            emblem_area.x = cell_area.x + cell_area.width - (pos * Files.IconSize.EMBLEM) - RIGHT_MARGIN;

            style_context.render_icon (cr, pix, emblem_area.x * icon_scale, emblem_area.y * icon_scale);
            pos++;
        }
    }

    public Gtk.IconPaintable? render_icon (string icon_name, Gtk.StyleContext context) {
        var theme = Gtk.IconTheme.get_default ();
        // Gtk.IconPaintable? pix = null;
        Gtk.IconPaintable? gtk_icon_info = null;
        var scale = context.get_scale ();
        var direction = context.get_direction ();
        var gicon = new ThemedIcon.with_default_fallbacks (icon_name);

        var flags = Gtk.IconLookupFlags.FORCE_SIZE | Gtk.IconLookupFlags.FORCE_SYMBOLIC;
        gtk_icon_info = theme.lookup_by_gicon (gicon, 16, scale, direction, flags);

        // if (gtk_icon_info != null) {
        //     try {
        //         pix = gtk_icon_info.load_symbolic_for_context (context);
        //     } catch (Error e) {
        //         warning ("Failed to load icon for %s: %s", icon_name, e.message);
        //     }
        // }

        return gtk_icon_info;
    }

    public override void get_preferred_width (Gtk.Widget widget, out int minimum_size, out int natural_size) {
        if (file != null) {
            minimum_size = (int) ((file.n_emblems + 1) * Files.IconSize.EMBLEM) + RIGHT_MARGIN;
            natural_size = minimum_size;
        } else {
            minimum_size = 0;
            natural_size = 0;
        }
    }

    public override void get_preferred_height (Gtk.Widget widget, out int minimum_size, out int natural_size) {
        natural_size = (int)Files.IconSize.EMBLEM;
        minimum_size = natural_size;
    }

    /* We still have to implement this even though it is deprecated, else compiler complains.
     * It is not called (in Juno)  */
    public override void get_size (Gtk.Widget widget, Gdk.Rectangle? cell_area,
                                   out int x_offset, out int y_offset,
                                   out int width, out int height) {

        /* Just return some default values for offsets */
        x_offset = 0;
        y_offset = 0;
        int mw, nw, mh, nh;
        get_preferred_width (widget, out mw, out nw);
        get_preferred_height (widget, out mh, out nh);

        width = nw;
        height = nh;
    }
}
