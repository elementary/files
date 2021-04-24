/***
    Copyright (c) 2011  ammonkey <am.monkeyd@gmail.com>
    Copyright (C) 2000  Red Hat, Inc.,  Jonathan Blandford <jrb@redhat.com>
    Copyright (c) 2016-2020 elementary LLC <https://elementary.io>

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

namespace Files {

    public class IconRenderer : Gtk.CellRenderer {
        public Gdk.Rectangle hover_helper_rect;
        public Gdk.Rectangle hover_rect;
        public bool follow_state {get; set; default = true;}
        public int icon_size {get; set; default = -1;}
        public ViewMode view_mode { get; construct; }
        public Files.File? drop_file {get; set;}

        public Files.File? file {
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

        private int emblem_size = (int)Files.IconSize.EMBLEM;
        private Gdk.Rectangle emblem_area = Gdk.Rectangle ();
        private int h_overlap; // Horizontal overlap between helper and icon
        private int v_overlap; // Vertical overlap between helper and icon
        private int helper_size;

        private bool show_emblems;
        private Files.File? _file;
        private int icon_scale = 1;

        private unowned Gdk.Pixbuf? pixbuf {
            get {
                return _file != null ? _file.pix : null;
            }
        }

        private ClipboardManager clipboard;

        construct {
            // lpad = view_mode == ViewMode.LIST ? 4 : 0;
            show_emblems = view_mode == ViewMode.ICON;
            xpad = 0;
            clipboard = Files.ClipboardManager.get_for_display ();
            hover_rect = {0, 0, (int) Files.IconSize.NORMAL, (int) Files.IconSize.NORMAL};
            hover_helper_rect = {0, 0, (int) Files.IconSize.EMBLEM, (int) Files.IconSize.EMBLEM};

            notify["icon-size"].connect (() => {
                show_emblems = view_mode == ViewMode.ICON && icon_size > (int)Files.IconSize.SMALLEST;
                helper_size = icon_size <= (int)Files.IconSize.NORMAL ?
                              (int)Files.IconSize.EMBLEM : (int)Files.IconSize.LARGE_EMBLEM;
                h_overlap = helper_size / 2;
                v_overlap = h_overlap;
            });
        }

        public IconRenderer (ViewMode view_mode) {
            Object (view_mode: view_mode);
            show_emblems = view_mode == ViewMode.ICON;
            xpad = 0;
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
            if (show_emblems) {
                pix_rect.x = cell_area.x + (cell_area.width - pix_rect.width) / 2;
            } else {
                pix_rect.x = cell_area.x + (cell_area.width - pix_rect.width);
            }

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
                var nicon = Files.IconInfo.lookup_from_name (special_icon_name, icon_size, icon_scale);
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
            var state = Gtk.StateFlags.NORMAL;

            if (!widget.sensitive || !this.sensitive) {
                state |= Gtk.StateFlags.INSENSITIVE;
            }

            if (file.is_image ()) {
                style_context.add_class (Granite.STYLE_CLASS_CHECKERBOARD);
                style_context.add_class (Granite.STYLE_CLASS_CARD);
            }

            cr.scale (1.0 / icon_scale, 1.0 / icon_scale);

            style_context.render_icon (cr, pb, draw_rect.x * icon_scale, draw_rect.y * icon_scale);

            style_context.restore ();

            if ((selected || prelit) && file != drop_file) {
                special_icon_name = null;
                if (selected && prelit) {
                    special_icon_name = "selection-remove";
                } else if (selected) {
                    special_icon_name = "selection-checked";
                } else if (prelit) {
                    special_icon_name = "selection-add";
                }

                Gdk.Rectangle helper_rect = {0, 0, 1, 1};
                if (special_icon_name != null) {
                    helper_rect.width = helper_size;
                    helper_rect.height = helper_size;

                    var nicon = Files.IconInfo.lookup_from_name (special_icon_name, helper_size, icon_scale);
                    Gdk.Pixbuf? pix = null;

                    if (nicon != null) {
                        pix = nicon.get_pixbuf_nodefault ();
                    }

                    if (pix != null) {
                        helper_rect.x = int.max (cell_area.x, draw_rect.x - helper_size + h_overlap);
                        helper_rect.y = int.max (cell_area.y, draw_rect.y - helper_size + v_overlap);

                        style_context.render_icon (cr, pix, helper_rect.x * icon_scale, helper_rect.y * icon_scale);
                    }
                }

                if (prelit) {
                    /* Save position of icon that is being hovered */
                    hover_rect = cell_area;
                    hover_helper_rect = helper_rect;
                }
            }

            /* check if we should render emblems as well */
            /* Do not show emblems for very small icons in IconView */
            /* How many emblems can be shown depends on icon icon_size */
            if (show_emblems) {
                int n_emblems = (int)(file.emblems_list.length ());
                int spacing = 0;
                if (n_emblems > 0) {
                    if (n_emblems > 1) {
                        spacing = int.max (emblem_size, (draw_rect.height - emblem_size) / (n_emblems - 1));
                        spacing = int.min (draw_rect.height / 2, (cell_area.height - emblem_size) / (n_emblems - 1));
                    }

                    int total_height = spacing * (n_emblems - 1) + emblem_size;
                    emblem_area.y = cell_area.y + (cell_area.height + total_height) / 2;
                    emblem_area.y = int.max (emblem_area.y, draw_rect.y + draw_rect.height);
                    emblem_area.y = int.min (emblem_area.y, cell_area.y + cell_area.height);
                    emblem_area.y -= emblem_size;

                    emblem_area.x = draw_rect.x + pix_rect.width - h_overlap;
                    emblem_area.x = int.min (emblem_area.x, cell_area.x + cell_area.width - emblem_size);

                    spacing = int.min (spacing, emblem_size + icon_size / 16);
                    Gdk.Pixbuf? pix = null;
                    foreach (string emblem in file.emblems_list) {
                        var nicon = Files.IconInfo.lookup_from_name (emblem, emblem_size, icon_scale);

                        if (nicon == null) {
                            continue;
                        }

                        pix = nicon.get_pixbuf_nodefault ();

                        if (pix == null) {
                            continue;
                        }

                        if (emblem_area.y < (cell_area.y - spacing)) {
                            break; // No more room for emblems
                        }

                        style_context.render_icon (cr, pix, emblem_area.x * icon_scale, emblem_area.y * icon_scale);
                        emblem_area.y -= spacing;
                    }
                }
            }
        }

        public override void get_preferred_width (Gtk.Widget widget, out int minimum_size, out int natural_size) {
            // minimum_size = (int) (icon_size) + Files.IconSize.EMBLEM - h_overlap;
            minimum_size = (int) (icon_size) + helper_size -h_overlap;
            natural_size = minimum_size;
        }

        public override void get_preferred_height (Gtk.Widget widget, out int minimum_size, out int natural_size) {
            minimum_size = icon_size + hover_helper_rect.height / 2;
            natural_size = minimum_size;
            natural_size = (int) (icon_size) + helper_size - v_overlap;
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
}
