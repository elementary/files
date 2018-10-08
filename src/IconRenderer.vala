/***
    Copyright (c) 2016-2018 elementary LLC <https://elementary.io>

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
        public Gdk.Rectangle helper_rect;
        public Gdk.Rectangle hover_rect;
        public bool follow_state {get; set;}
        public GOF.File drop_file {get; set;}

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

        public GOF.File? file {
            get {
                return _file;
            }
            set {
                _file = value;
                if (_file != null) {
                    _file.update_icon (icon_size, icon_scale);
                }
            }
        }

        private bool show_emblems = true;
        private Marlin.ZoomLevel _zoom_level = Marlin.ZoomLevel.NORMAL;
        private GOF.File? _file;
        private Marlin.IconSize icon_size;
        private int icon_scale = 1;
        private unowned Gdk.Pixbuf? pixbuf {
            get {
                return _file != null ? _file.pix : null;
            }
        }

        private ClipboardManager clipboard;

        construct {
            clipboard = Marlin.ClipboardManager.get_for_display ();
            hover_rect = {0, 0, (int) Marlin.IconSize.NORMAL, (int) Marlin.IconSize.NORMAL};
            helper_rect = {0, 0, (int) Marlin.IconSize.EMBLEM, (int) Marlin.IconSize.EMBLEM};
        }

        public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle background_area,
                                     Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {

            if (file == null || pixbuf == null) {
                return;
            }

            if (widget.get_scale_factor () != icon_scale) {
                icon_scale = widget.get_scale_factor ();
                file.update_icon (icon_size, icon_scale);
            }

            Gdk.Pixbuf? pb = pixbuf;

            var pix_rect = Gdk.Rectangle ();

            pix_rect.width = pixbuf.width / icon_scale;
            pix_rect.height = pixbuf.height / icon_scale;
            pix_rect.x = cell_area.x + (cell_area.width - pix_rect.width) / 2;
            pix_rect.y = cell_area.y + (cell_area.height - pix_rect.height) / 2;

            var draw_rect = Gdk.Rectangle ();
            if (!cell_area.intersect (pix_rect, out draw_rect)) {
                return;
            }

            string? special_icon_name = null;
            string suffix = "";
            bool is_drop_file = (file == drop_file);

            if (file.is_directory) {
                var names = ((GLib.ThemedIcon) file.icon).get_names ();
                if (names.length > 0) {
                    special_icon_name = names[0];
                } else {
                    special_icon_name = "folder";
                }

                bool expanded = (flags & Gtk.CellRendererState.EXPANDED) > 0 || file.is_expanded;

                if (expanded) {
                    suffix = "-open";
                } else if (is_drop_file) {
                    suffix = "-drag-accept";
                }
            } else if (is_drop_file) {
                special_icon_name = "system-run";
            }

            if (is_drop_file) {
                flags |= Gtk.CellRendererState.PRELIT;
            }

            if (special_icon_name != null) {
                special_icon_name = special_icon_name + suffix;
                var nicon = Marlin.IconInfo.lookup_from_name (special_icon_name, icon_size, icon_scale);
                if (nicon != null) {
                    pb = nicon.get_pixbuf_nodefault ();
                } else {
                    special_icon_name = null;
                }
            }

            if (clipboard.has_cutted_file (file)) {
                /* 50% translucent for cutted files */
                pb = PF.PixbufUtils.lucent (pixbuf, 50);
            }
            if (file.is_hidden) {
                /* 75% translucent for hidden files */
                pb = PF.PixbufUtils.lucent (pixbuf, 75);
                pb = PF.PixbufUtils.darken (pb, 150, 200);
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
                }

                if (focused) {
                    var bg = style_context.get_property ("background-color", state);

                    if (bg.holds (typeof (Gdk.RGBA))) {
                        var color = (Gdk.RGBA) bg;

                        /* if background-color is black something probably is wrong */
                        if (color.red != 0 || color.green != 0 || color.blue != 0) {
                            pb = PF.PixbufUtils.colorize (pb, color);
                        }
                    }
                }

                if (prelit || focused) {
                    pb = PF.PixbufUtils.lighten (pb);
                }
            }

            if (pb == null) {
                return;
            }

            cr.scale (1.0 / icon_scale, 1.0 / icon_scale);

            style_context.render_icon (cr, pb, draw_rect.x * icon_scale, draw_rect.y * icon_scale);
            style_context.restore ();
            int h_overlap = int.min (draw_rect.width, Marlin.IconSize.EMBLEM) / 2;
            int v_overlap = int.min (draw_rect.height, Marlin.IconSize.EMBLEM) / 2;

            if ((selected || prelit) && file != drop_file) {
                special_icon_name = null;
                if (selected && prelit) {
                    special_icon_name = "selection-remove";
                } else if (selected) {
                    special_icon_name = "selection-checked";
                } else if (prelit) {
                    special_icon_name = "selection-add";
                }

                if (special_icon_name != null) {
                    int helper_size = (int)(zoom_level <= Marlin.ZoomLevel.NORMAL ?
                                            Marlin.IconSize.EMBLEM : Marlin.IconSize.LARGE_EMBLEM);

                    helper_rect.width = helper_size;
                    helper_rect.height = helper_size;

                    var nicon = Marlin.IconInfo.lookup_from_name (special_icon_name, helper_size, icon_scale);
                    Gdk.Pixbuf? pix = null;

                    if (nicon != null) {
                        pix = nicon.get_pixbuf_nodefault ();
                    }

                    if (pix != null) {
                        helper_rect.x = int.max (cell_area.x, draw_rect.x - helper_size + h_overlap);
                        helper_rect.y = int.max (cell_area.y, draw_rect.y - helper_size + v_overlap);

                        style_context.render_icon (cr, pix, helper_rect.x * icon_scale, helper_rect.y * icon_scale);
                        cr.paint ();
                    }
                }

                if (prelit) {
                    /* Save position of icon that is being hovered */
                    hover_rect = draw_rect;
                }
            }

            /* check if we should render emblems as well */
            /* Do not show emblems for very small icons */
            /* Still show emblems when selection helpers hidden in double click mode */
            /* How many emblems can be shown depends on icon icon_size (zoom lebel) */
            if (show_emblems) {
                int emblem_size = (int)(Marlin.IconSize.EMBLEM);
                int pos = 0;
                var emblem_area = Gdk.Rectangle ();

                foreach (string emblem in file.emblems_list) {
                    if (pos > zoom_level) {
                        break;
                    }

                    Gdk.Pixbuf? pix = null;
                    var nicon = Marlin.IconInfo.lookup_from_name (emblem, emblem_size, icon_scale);

                    if (nicon == null) {
                        continue;
                    }

                    pix = nicon.get_pixbuf_nodefault ();

                    if (pix == null) {
                        continue;
                    }

                    emblem_area.y = draw_rect.y + pix_rect.height - v_overlap;
                    emblem_area.y = int.min (emblem_area.y, cell_area.y + cell_area.height - emblem_size);

                    emblem_area.y -= emblem_size * pos;
                    emblem_area.y = int.max (cell_area.y, emblem_area.y);

                    emblem_area.x = draw_rect.x + pix_rect.width - h_overlap;
                    emblem_area.x = int.min (emblem_area.x, cell_area.x + cell_area.width - emblem_size);

                    style_context.render_icon (cr, pix, emblem_area.x * icon_scale, emblem_area.y * icon_scale);
                    cr.paint ();
                    pos++;
                }
            }
        }

        public override void get_preferred_width (Gtk.Widget widget, out int minimum_size, out int natural_size) {
            minimum_size = (int)icon_size + helper_rect.width;
            natural_size = minimum_size;
        }

        public override void get_preferred_height (Gtk.Widget widget, out int minimum_size, out int natural_size) {
            minimum_size = (int)icon_size + helper_rect.height / 2;
            natural_size = minimum_size;
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
}
