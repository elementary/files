/***
    Copyright (c) 2016 elementary LLC (http://launchpad.net/elementary)

    Copyright (C) 2000  Red Hat, Inc.,  Jonathan Blandford <jrb@redhat.com>
    Copyright (c) 2011  ammonkey <am.monkeyd@gmail.com>

    Transcribed from marlin-icon-renderer
    Originaly Written in gtk+: gtkcellrendererpixbuf

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


namespace Marlin {

    public class IconRenderer : Gtk.CellRenderer {
        public Marlin.IconSize helper_size {get; private set; default = Marlin.IconSize.EMBLEM;}
        public bool follow_state {get; set;}
        public GOF.File drop_file {get; set;}
        public bool selection_helpers {get; set; default = true;}

        public Marlin.ZoomLevel zoom_level {
            get {
                return _zoom_level;
            }
            set {
                _zoom_level = value;
                icon_size = Marlin.zoom_level_to_icon_size (_zoom_level);
                show_emblems = _zoom_level > Marlin.ZoomLevel.SMALLEST;
            }
        }

        private GOF.File? _file = null;
        public GOF.File file {
            get {
                return _file;
            }

            set {

                /* Dummy rows in expanded empty folder result in null file */
                if (value != null && (_file == null || (icon_size != value.pix_size))) {
                    value.update_icon (icon_size);

                }

                _file = value;
            }
        }

        private bool show_emblems = true;
        private Marlin.ZoomLevel _zoom_level = Marlin.ZoomLevel.NORMAL;

        private Marlin.IconSize icon_size;
        public int helper_x {get; private set;}
        public int helper_y {get; private set;}
        private unowned Gdk.Pixbuf? pixbuf {
            get {
                return _file != null ? _file.pix : null;
            }
        }
        private double scale;
        private ClipboardManager clipboard;

        construct {
            clipboard = Marlin.ClipboardManager.get_for_display ();
        }

        public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle background_area,
                                     Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {

            if (file == null || pixbuf == null) {
                return;
            }

            Gdk.Pixbuf? pb = pixbuf;

            var pix_rect = Gdk.Rectangle ();

            pix_rect.width = pixbuf.get_width ();
            pix_rect.height = pixbuf.get_height ();
            pix_rect.x = cell_area.x + (cell_area.width - pix_rect.width) / 2;
            pix_rect.y = cell_area.y + (cell_area.height - pix_rect.height) / 2;

            var draw_rect = Gdk.Rectangle ();
            if (!cell_area.intersect (pix_rect, out draw_rect)) {
                return;
            }

            string? special_icon_name = null;
            if (file == drop_file) {
                flags |= Gtk.CellRendererState.PRELIT;
                special_icon_name = "folder-drag-accept";

            } else if (file.is_directory && file.is_expanded) {
                special_icon_name = "folder-open";
            }

            if (special_icon_name != null) {
                var nicon = Marlin.IconInfo.lookup_from_name (special_icon_name, icon_size);
                if (nicon != null) {
                    pb = nicon.get_pixbuf_nodefault ();
                }
            }

            if (clipboard.has_cutted_file (file)) {
                /* 50% translucent for cutted files */
                pb = Eel.gdk_pixbuf_lucent (pixbuf, 50);
            }
            if (file.is_hidden) {
                /* 75% translucent for hidden files */
                pb = Eel.gdk_pixbuf_lucent (pixbuf, 75);
                pb = Eel.create_darkened_pixbuf (pb, 150, 200);
            }

            var style_context = widget.get_parent ().get_style_context ();
            style_context.save ();

            bool prelit = (flags & Gtk.CellRendererState.PRELIT) > 0;
            bool selected = (flags & Gtk.CellRendererState.SELECTED) > 0;
            bool focused = (flags & Gtk.CellRendererState.FOCUSED) > 0;
            var state = Gtk.StateFlags.NORMAL;

            if (!widget.sensitive || !this.sensitive) {
                state |= Gtk.StateFlags.INSENSITIVE;
            } else if (follow_state) {
                if (selected) {
                    state = Gtk.StateFlags.SELECTED;
                    state |= widget.get_state_flags ();

                    var bg = style_context.get_property ("background-color", state);

                    if (bg.holds (typeof (Gdk.RGBA))) {
                        var color = (Gdk.RGBA) bg;

                        /* if background-color is black something probably is wrong */
                        if (color.red != 0 || color.green != 0 || color.blue != 0) {
                            pb = Eel.create_colorized_pixbuf (pb, color);
                        }
                    }
                }

                if (prelit || focused) {
                    pb = Eel.create_spotlight_pixbuf (pb);
                }
            }

            if (pb == null) {
                return;
            }

            style_context.render_icon (cr, pb, draw_rect.x, draw_rect.y);
            style_context.restore ();

            /* Do not show selection helpers or emblems for very small icons */
            if (selection_helpers &&
                (selected || prelit) &&
                file != drop_file) {

                special_icon_name = null;
                if (selected && prelit) {
                    special_icon_name = "selection-remove";
                } else if (selected) {
                    special_icon_name = "selection-checked";
                } else if (prelit) {
                    special_icon_name = "selection-add";
                }

                if (special_icon_name != null) {
                    helper_size = Marlin.IconSize.LARGE_EMBLEM > int.max (pixbuf.get_width (), pixbuf.get_height ()) / 2 ?
                                  Marlin.IconSize.EMBLEM : Marlin.IconSize.LARGE_EMBLEM;

                    var nicon = Marlin.IconInfo.lookup_from_name (special_icon_name, helper_size);
                    Gdk.Pixbuf? pix = null;

                    if (nicon != null) {
                        pix = nicon.get_pixbuf_nodefault ();
                    }

                    if (pix != null) {
                        int overlap = helper_size / 4;
                        var helper_area = Gdk.Rectangle ();
                        helper_area.x = draw_rect.x - overlap;
                        helper_area.y = draw_rect.y - overlap;

                        if (helper_area.y < background_area.y) {
                            helper_area.y = background_area.y;
                        }

                        if (helper_area.x < background_area.x) {
                            helper_area.x = background_area.x;
                        }

                        helper_x = helper_area.x;
                        helper_y = helper_area.y;

                        Gdk.cairo_set_source_pixbuf (cr, pix, helper_x, helper_y);
                        cr.paint ();
                    }
                }
            }

            /* check if we should render emblems as well */
            /* Still show emblems when selection helpers hidden in double click mode */
            /* How many emblems can be shown depends on icon icon_size (zoom lebel) */
            if (show_emblems) {
                int pos = 0;
                int emblem_overlap = helper_size / 4;
                var emblem_area = Gdk.Rectangle ();

                foreach (string emblem in file.emblems_list) {
                    if (pos > zoom_level) {
                        break;
                    }

                    Gdk.Pixbuf? pix = null;
                    var nicon = Marlin.IconInfo.lookup_from_name (emblem, helper_size);

                    if (nicon == null) {
                        continue;
                    }

                    pix = nicon.get_pixbuf_nodefault ();

                    if  (pix == null) {
                        continue;
                    }

                    emblem_area.x = draw_rect.x + draw_rect.width - emblem_overlap;
                    emblem_area.y = draw_rect.y + draw_rect.height - helper_size;
                    emblem_area.y -= helper_size * pos;

                    if (emblem_area.y < background_area.y) {
                        break;
                    }

                    if (emblem_area.x + helper_size > (background_area.x + background_area.width)) {
                        emblem_area.x = (background_area.x + background_area.width) - helper_size;
                    }

                    Gdk.cairo_set_source_pixbuf (cr, pix, emblem_area.x, emblem_area.y);
                    cr.paint ();
                    pos++;
                }
            }
        }

        /* We still have to implement this even though it is deprecated */
        public override void get_size (Gtk.Widget widget, Gdk.Rectangle? cell_area,
                                       out int x_offset, out int y_offset,
                                       out int width, out int height) {

            width = -1;
            height = -1;
            x_offset = 0;
            y_offset = 0;

            if (pixbuf == null || !(pixbuf is Gdk.Pixbuf)) {
                return;
            }


            int pixbuf_width = pixbuf.get_width ();
            int pixbuf_height = pixbuf.get_height ();

            int calc_width = pixbuf_width;
            int calc_height = pixbuf_height;

            if (cell_area != null && pixbuf_width > 0 && pixbuf_height > 0) {
                float xalign, yalign;
                bool rtl = widget.get_direction () == Gtk.TextDirection.RTL;
                get_alignment (out xalign, out yalign);
                x_offset = (int)(rtl ? (1.0 -xalign) : xalign) * (cell_area.width - calc_width);
                x_offset = int.max (x_offset, 0);
                y_offset = (int)(yalign * (cell_area.height - calc_height));
                y_offset = int.max (y_offset, 0);
            } else {
                x_offset = 0;
                y_offset = 0;
            }

            /* Even if the last new pixbuf corresponding to the last requested icon_size isn't generated
               yet, we can still determine its dimensions. This allow to asyncronously load the thumbnails
               pixbuf */

            int s = int.max (pixbuf_width, pixbuf_height);
            scale = double.min (1.0, (double)icon_size / s); /* scaling to make pix required icon_size (not taking into account screen scaling) */

            width = (int)(calc_width * scale);
            height = (int)(calc_height * scale);
        }
    }
}
