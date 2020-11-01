/***
    Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>

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
    write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
    Boston, MA 02110-1335 USA.

***/

public class Marlin.View.Chrome.BreadcrumbElement : Object {

    private const int ICON_MARGIN = 3;
    private BreadcrumbIconInfo? icon_info = null;

    public string? text {get; private set;}
    private double text_width;
    private double text_half_height;

    public double offset = 0;
    public double x = 0;

    public double natural_width {
        get {
            if (icon_info != null) {
                return text_width + icon_info.icon_width + 2 * ICON_MARGIN + padding.left + padding.right;
            } else {
                return text_width + padding.left + padding.right;
            }
        }
    }
    public double display_width = -1;
    public double real_width {
        get {
            return display_width > 0 ? display_width : natural_width;
        }
    }

    public bool hidden = false;
    public bool display = true;
    public bool can_shrink = true;
    public bool pressed = false;

    public bool text_is_displayed = true;
    private string _text_for_display = "";
    public string? text_for_display {
        set {
            _text_for_display = value;
            update_text_width ();
        }

        get {
            return _text_for_display;
        }
    }

    private Gtk.Border padding;
    private Pango.Layout layout;
    private Gtk.Widget widget;

    public BreadcrumbElement (string text_, Gtk.Widget widget_, Gtk.StyleContext button_context) {
        text = text_;
        widget = widget_;
        padding = button_context.get_padding (button_context.get_state ());
        text_for_display = Uri.unescape_string (text);
    }

    public void set_icon (BreadcrumbIconInfo icon_info) {
        this.icon_info = icon_info;
    }

    private Cairo.Surface? get_mask (double x1, double y1, double x2, double y2, int scale, Cairo.Path? clip_path) {
        if (clip_path == null) {
            return null;
        }

        int w = (int) (Math.ceil (x2) - Math.floor (x1)) * scale;
        int h = (int) (Math.ceil (y2) - Math.floor (y1)) * scale;
        var mask = new Cairo.ImageSurface (Cairo.Format.A8, w, h);

        var cr = new Cairo.Context (mask);
        cr.translate (-x1, -y1);
        cr.set_source_rgb (0, 0, 0);
        cr.append_path (clip_path);
        cr.fill ();

        return mask;
    }

    public double draw (Cairo.Context cr, double x, double y, double height, Gtk.Widget widget) {
        weak Gtk.StyleContext button_context = widget.get_style_context ();
        var state = button_context.get_state ();
        var is_rtl = Gtk.StateFlags.DIR_RTL in state;
        var scale = widget.scale_factor;

        button_context.save ();
        if (pressed) {
            state |= Gtk.StateFlags.ACTIVE;
            button_context.set_state (state);
        }

        padding = button_context.get_padding (state);
        double line_width = cr.get_line_width ();

        cr.restore ();
        cr.save ();

        /* Suppress all drawing outside widget */
        cr.rectangle (0.0, 0.0, widget.get_allocated_width (), widget.get_allocated_height ());
        cr.clip ();

        var half_height = height / 2;
        var y_half_height = y + half_height;
        var y_height = y + height;

        cr.set_source_rgb (0, 0, 0);

        var width = this.real_width;
        var frame_width = width - padding.right;

        /* Erase area for drawing and outline */
        Cairo.Path clip_path = null;
        double clip_x1 = 0;
        double clip_y1 = 0;
        double clip_x2 = 0;
        double clip_y2 = 0;
        if (offset > 0.0) {
            double x_frame_width, x_half_height, x_frame_width_half_height;
            if (is_rtl) {
                x_frame_width = x - frame_width - line_width;
                x_half_height = x + half_height;
                x_frame_width_half_height = x_frame_width - half_height;
            } else {
                x_frame_width = x + frame_width + line_width;
                x_half_height = x - half_height;
                x_frame_width_half_height = x_frame_width + half_height;
            }

            cr.new_path ();
            cr.move_to (x_half_height, y);
            cr.line_to (x, y_half_height);
            cr.line_to (x_half_height, y_height);
            cr.line_to (x_frame_width, y_height);
            cr.line_to (x_frame_width_half_height, y_half_height);
            cr.line_to (x_frame_width, y);
            cr.close_path ();
            clip_path = cr.copy_path ();
            cr.clip ();
            cr.clip_extents (out clip_x1, out clip_y1, out clip_x2, out clip_y2);
        }

        if (pressed) {/* Highlight the breadcrumb */
            cr.save ();
            double base_x, left_x, right_x, arrow_right_x;
            base_x = x;
            if (is_rtl) {
                left_x = base_x + half_height - line_width;
                right_x = base_x - frame_width;
                arrow_right_x = right_x - half_height;
            } else {
                left_x = base_x - half_height;
                right_x = base_x + frame_width + line_width;
                arrow_right_x = right_x + half_height;
            }

            var top_y = y + padding.top - line_width;
            var bottom_y = y_height - padding.bottom + line_width;
            var arrow_y = y_half_height;

            cr.move_to (left_x, top_y);
            cr.line_to (base_x, arrow_y);
            cr.line_to (left_x, bottom_y);
            cr.line_to (right_x, bottom_y);
            cr.line_to (arrow_right_x, arrow_y);
            cr.line_to (right_x, top_y);
            cr.close_path ();

            cr.clip ();
            button_context.render_background (cr, left_x, y, width + height + 2 * line_width, height);
            button_context.render_frame (cr, 0, y, widget.get_allocated_width (), height);
            cr.restore ();
        }

        /* Determine space available for icon and text */
        var iw = icon_info != null ? icon_info.icon_width + 2 * ICON_MARGIN : 0;
        var room_for_text = text_is_displayed;
        var room_for_icon = icon_info != null ? true : false;
        double layout_width = (width - padding.left - padding.right);

        if (is_rtl) {
            x -= padding.left;
            x += offset * Math.round (offset * (width + half_height) * scale) / scale;
        } else {
            x += padding.left;
            x -= offset * Math.round (offset * (width + half_height) * scale) / scale;
        }

        if (layout_width < iw) {
            room_for_icon = false;
            iw = 0;
            if (layout_width >= 0) {
                layout.set_width (Pango.units_from_double (layout_width));
            } else {
                room_for_text = false;
            }
        } else {
            layout_width -= iw;
            if (layout_width >= 0) {
                layout.set_width (Pango.units_from_double (layout_width));
            } else {
                room_for_text = false;
            }
        }

        /* Get icon pixbuf and fade if appropriate */
        Gdk.Pixbuf? icon_to_draw = icon_info != null ? icon_info.render_icon (button_context) : null;
        if (icon_to_draw != null && (state & Gtk.StateFlags.BACKDROP) > 0) {
            icon_to_draw = PF.PixbufUtils.lucent (icon_to_draw, 50);
        }

        cr.save ();
        var mask = get_mask (clip_x1, clip_y1, clip_x2, clip_y2, scale, clip_path);
        cr.push_group ();

        /* Draw the text and icon (if present and there is room) */
        if (is_rtl) {
            if (icon_to_draw == null) {
                if (room_for_text) {
                    button_context.render_layout (cr, x - width,
                                                  y_half_height - text_half_height, layout);
                }
            } else {
                if (room_for_icon) {
                    cr.save ();
                    double draw_scale = 1.0 / scale;
                    cr.scale (draw_scale, draw_scale);
                    button_context.render_icon (cr, icon_to_draw,
                                                Math.round ((x - ICON_MARGIN - icon_info.icon_width) * scale),
                                                Math.round ((y_half_height - icon_info.icon_height / 2) * scale));
                    cr.restore ();
                }
                if (text_is_displayed && room_for_text) {
                    /* text_width already includes icon_width */
                    button_context.render_layout (cr, x - width,
                                                  y_half_height - text_half_height, layout);
                }
            }
        } else {
            cr.save ();


            if (icon_to_draw == null) {
                if (room_for_text) {
                    button_context.render_layout (cr, x,
                                                  y_half_height - text_half_height, layout);
                }
            } else {
                if (room_for_icon) {
                    cr.save ();
                    double draw_scale = 1.0 / scale;
                    cr.scale (draw_scale, draw_scale);
                    button_context.render_icon (cr, icon_to_draw,
                                                Math.round ((x + ICON_MARGIN) * scale),
                                                Math.round ((y_half_height - icon_info.icon_height / 2) * scale));
                    cr.restore ();
                }
                if (text_is_displayed && room_for_text && x > 0) {
                    button_context.render_layout (cr, x + iw,
                                                  y_half_height - text_half_height, layout);
                }
            }

            cr.restore ();
        }

        var group = cr.pop_group ();
        cr.set_source (group);
        if (mask != null) {
            cr.mask_surface (mask, clip_x1, clip_y1);
        } else {
            cr.paint ();
        }

        cr.restore ();

        /* Move to end of breadcrumb */
        if (is_rtl) {
            x -= frame_width;
        } else {
            x += frame_width;
        }

        /* Draw the arrow-shaped separator */
        if (is_rtl) {
            cr.save ();
            cr.translate (x + height / 4, y_half_height);
            cr.rectangle (0, -height / 2 + line_width, -height, height - 2 * line_width);
            cr.clip ();
            cr.rotate (Math.PI_4);
            button_context.save ();
            button_context.add_class ("noradius-button");
            button_context.render_frame (cr, -height / 2, -height / 2, height, height);
            button_context.restore ();
            cr.restore ();
        } else {
            cr.save ();
            cr.translate (x - height / 4, y + height / 2);
            cr.rectangle (0, -height / 2 + line_width, height, height - 2 * line_width);
            cr.clip ();
            cr.rotate (Math.PI_4);
            button_context.save ();
            button_context.add_class ("noradius-button");
            button_context.render_frame (cr, -height / 2, -height / 2, height, height);
            button_context.restore ();
            cr.restore ();
        }

        /* Move to end of separator */
        if (is_rtl) {
            x -= half_height;
        } else {
            x += half_height;
        }

        button_context.restore ();
        return x;
    }

    private void update_text_width () {
        layout = widget.create_pango_layout (_text_for_display);
        layout.set_ellipsize (Pango.EllipsizeMode.MIDDLE);

        int width, height;
        layout.get_size (out width, out height);
        this.text_width = Pango.units_to_double (width);
        this.text_half_height = Pango.units_to_double (height) / 2;
    }

    /** To help testing **/
    public string get_icon_name () {
        if (icon_info != null) {
            return icon_info.path;
        } else {
            return "null";
        }
    }
}
