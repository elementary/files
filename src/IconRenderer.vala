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
        public int helper_x {get; private set;}
        public int helper_y {get; private set;}
        private unowned Gdk.Pixbuf? pixbuf {
            get {
                return _file != null ? _file.pix : null;
            }
        }

        private ClipboardManager clipboard;

        construct {
            clipboard = Marlin.ClipboardManager.get_for_display ();
        }

        public override void render (Cairo.Context cr, Gtk.Widget widget, Gdk.Rectangle background_area,
                                     Gdk.Rectangle cell_area, Gtk.CellRendererState flags) {

            if (file == null || pixbuf == null) {
                return;
            }

            var new_scale = widget.get_scale_factor ();
            if (icon_scale != new_scale) {
                icon_scale = new_scale;
                _file.update_icon (icon_size, icon_scale);
            }

            Gdk.Pixbuf? pb = pixbuf;

            var pix_rect = Gdk.Rectangle ();

            pix_rect.width = (pixbuf.get_width ()  + Marlin.IconSize.EMBLEM / 2)/ icon_scale;
            pix_rect.height = (pixbuf.get_height ()  + Marlin.IconSize.EMBLEM / 2)/ icon_scale;
            pix_rect.x = cell_area.x + (cell_area.width - pix_rect.width) / 2;
            pix_rect.y = cell_area.y + (cell_area.height - pix_rect.height) / 2;

            var draw_rect = Gdk.Rectangle ();
            if (!cell_area.intersect (pix_rect, out draw_rect)) {
                return;
            }

            string? special_icon_name = null;
            if (file == drop_file) {
                flags |= Gtk.CellRendererState.PRELIT;
                if (file.is_directory) {
                    special_icon_name = "folder-drag-accept";
                } else {
                    special_icon_name = "system-run";
                }

            } else if (file.is_directory) {
                bool expanded = (flags & Gtk.CellRendererState.EXPANDED) > 0 || file.is_expanded;
                if (expanded) {
                    special_icon_name = "folder-open";
                }
            }

            if (special_icon_name != null) {
                var nicon = Marlin.IconInfo.lookup_from_name (special_icon_name, icon_size, icon_scale);
                if (nicon != null) {
                    pb = nicon.get_pixbuf_nodefault ();
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

            /* Do not show selection helpers or emblems for very small icons */
            if ((selected || prelit) && file != drop_file) {
                helper_size = Marlin.IconSize.LARGE_EMBLEM > (int.max (pixbuf.get_width (), pixbuf.get_height ()) / icon_scale) / 2 ?
                              Marlin.IconSize.EMBLEM : Marlin.IconSize.LARGE_EMBLEM;

                special_icon_name = null;
                if (selected && prelit) {
                    special_icon_name = "selection-remove";
                } else if (selected) {
                    special_icon_name = "selection-checked";
                } else if (prelit) {
                    special_icon_name = "selection-add";
                }

                if (special_icon_name != null) {
                    var nicon = Marlin.IconInfo.lookup_from_name (special_icon_name, helper_size, icon_scale);
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

                        style_context.render_icon (cr, pix, helper_x * icon_scale, helper_y * icon_scale);
                        cr.paint ();
                    }
                }
            }

            /* check if we should render emblems as well */
            /* Still show emblems when selection helpers hidden in double click mode */
            /* How many emblems can be shown depends on icon icon_size (zoom lebel) */
            if (show_emblems) {
                helper_size = Marlin.IconSize.LARGE_EMBLEM > (int.max (pixbuf.get_width (), pixbuf.get_height ())) / icon_scale / 3 ?
                              Marlin.IconSize.EMBLEM : Marlin.IconSize.LARGE_EMBLEM;

                int pos = 0;
                var emblem_area = Gdk.Rectangle ();

                foreach (string emblem in file.emblems_list) {
                    if (pos > zoom_level) {
                        break;
                    }

                    Gdk.Pixbuf? pix = null;
                    var nicon = Marlin.IconInfo.lookup_from_name (emblem, helper_size, icon_scale);

                    if (nicon == null) {
                        continue;
                    }

                    pix = nicon.get_pixbuf_nodefault ();

                    if (pix == null) {
                        continue;
                    }

                    emblem_area.y = draw_rect.y + draw_rect.height - helper_size + (int)ypad;
                    emblem_area.y -= helper_size * pos;
                    emblem_area.x = (draw_rect.x + (pixbuf.get_width () + Marlin.IconSize.EMBLEM / 2) / icon_scale) - helper_size;

                    style_context.render_icon (cr, pix, emblem_area.x * icon_scale, emblem_area.y * icon_scale);
                    cr.paint ();
                    pos++;
                }
            }
        }

        public override void get_preferred_width (Gtk.Widget widget, out int minimum_size, out int natural_size) {
            var new_scale = widget.get_scale_factor ();
            if (icon_scale != new_scale) {
                icon_scale = new_scale;
                _file.update_icon (icon_size, icon_scale);
            }

            minimum_size = (pixbuf.get_width () + Marlin.IconSize.EMBLEM / 2) / icon_scale ;
            natural_size = minimum_size;
        }

        public override void get_preferred_height (Gtk.Widget widget, out int minimum_size, out int natural_size) {
            var new_scale = widget.get_scale_factor ();
            if (icon_scale != new_scale) {
                icon_scale = new_scale;
                _file.update_icon (icon_size, icon_scale);
            }

            minimum_size = int.max (helper_size + helper_size / 2, pixbuf.get_height () / icon_scale + Marlin.IconSize.EMBLEM / 2);
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
