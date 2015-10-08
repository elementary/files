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
    write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
    Boston, MA 02111-1307, USA.
*
***/

public class Marlin.View.Chrome.BreadcrumbElement : Object {

    private static const int ICON_MARGIN = 3;
    private string icon_name; /*For testing */
    private double text_width = -1;
    private double text_height = -1;

    public string? text {get; private set;}
    public double offset = 0;
    public double max_width = -1;
    public double last_height = 0;
    public double x  = 0;
    public double width {
        get {
            return text_width + padding.left + padding.right + last_height / 2;
        }
    }
    public double real_width {
        get {
            return (max_width > 0 ? max_width : text_width) +
                    padding.left + padding.right + last_height / 2;
        }
    }
    public bool hidden = false;
    public bool display = true;
    public bool display_text = true;
    public string? text_displayed = null;

    public bool pressed = false;
    private Gtk.Border padding = Gtk.Border ();
    private Gdk.Pixbuf? icon = null;

    public BreadcrumbElement (string text_) {
        text = text_;
        text_displayed = Uri.unescape_string (text);
    }

    public void set_icon (Gdk.Pixbuf icon_) {
        icon = icon_;
    }
    public void set_icon_name (string icon_name_) {
        icon_name = icon_name_;
    }

    public double draw (Cairo.Context cr, double x, double y, double height, Gtk.StyleContext button_context, bool is_RTL, Gtk.Widget widget) {
        var state = button_context.get_state ();
        if (pressed)
            state |= Gtk.StateFlags.ACTIVE;

        padding = button_context.get_padding (state);
        double line_width = cr.get_line_width ();

        cr.restore ();
        cr.save ();
        last_height = height;
        cr.set_source_rgb (0,0,0);
        string? text = text_displayed ?? this.text;
        Pango.Layout layout = widget.create_pango_layout (text ?? "");

        if (icon == null) {
            computetext_width (layout);
        } else if (!display_text) {
            text_width = icon.get_width () + ICON_MARGIN;
        } else {
            computetext_width (layout);
            text_width += icon.get_width () + 2 * ICON_MARGIN;
        }

        if (max_width > 0) {
            layout.set_width (Pango.units_from_double (max_width));
            layout.set_ellipsize (Pango.EllipsizeMode.MIDDLE);
        }

        if (offset > 0.0) {
            if (is_RTL) {
                cr.move_to (x + height/2, y);
                cr.line_to (x, y + height/2);
                cr.line_to (x + height/2, y + height);
                cr.line_to (x - text_width - padding.left, y + height);
                cr.line_to (x - text_width - height/2 - padding.left, y + height/2);
                cr.line_to (x - text_width - padding.left, y);
                cr.close_path ();
                cr.clip ();
            } else {
                cr.move_to (x - height/2, y);
                cr.line_to (x, y + height/2);
                cr.line_to (x - height/2, y + height);
                cr.line_to (x + text_width + padding.left, y + height);
                cr.line_to (x + text_width + height/2 + padding.left, y + height/2);
                cr.line_to (x + text_width + padding.left, y);
                cr.close_path ();
                cr.clip ();
            }
        }

        if (pressed) {
            cr.save ();
            double base_x, left_x, right_x, arrow_right_x;
                double text_width = max_width > 0 ? max_width : this.text_width;

            if (is_RTL) {
                base_x = x;
                left_x = base_x + height / 2 - line_width;
                right_x = base_x - text_width - padding.left - padding.right;
                arrow_right_x = right_x - height / 2;

            } else {
                base_x = x;
                left_x = base_x - height / 2 + line_width;
                right_x = base_x + text_width + padding.left + padding.right;
                arrow_right_x = right_x + height / 2;
            }
            var top_y = y + padding.top - line_width;
            var bottom_y = y + height - padding.bottom + line_width;
            var arrow_y = y + height / 2;
            cr.move_to (left_x, top_y);
            cr.line_to (base_x, arrow_y);
            cr.line_to (left_x, bottom_y);
            cr.line_to (right_x, bottom_y);
            cr.line_to (arrow_right_x, arrow_y);
            cr.line_to (right_x, top_y);
            cr.close_path ();

            cr.clip ();
            button_context.save ();
            button_context.set_state (Gtk.StateFlags.ACTIVE);
            button_context.render_background (cr, left_x, y, text_width + height + padding.left + padding.right + 2 * line_width, height);
            button_context.render_frame (cr, 0, padding.top - line_width, widget.get_allocated_width (), height - line_width);
            button_context.restore ();
            cr.restore ();
        }

        if (is_RTL) {
            x -= padding.left;
            x += Math.sin (offset*Math.PI_2) * width;
            if (icon == null) {
                button_context.render_layout (cr, x - text_width,
                                              y + height/2 - text_height/2, layout);
            } else if (!display_text) {
                button_context.render_icon (cr, icon, x - ICON_MARGIN - icon.get_width (),
                                            y + height/2 - icon.get_height ()/2);
            } else {
                button_context.render_icon (cr, icon, x - ICON_MARGIN - icon.get_width (),
                                            y + height/2 - icon.get_height ()/2);
                /* text_width already includes icon_width */
                button_context.render_layout (cr, x - text_width,
                                              y + height/2 - text_height/2, layout);
            }
        } else {
            x += padding.left;
            x -= Math.sin (offset*Math.PI_2) * width;
            if (icon == null) {
                button_context.render_layout (cr, x,
                                              y + height/2 - text_height/2, layout);
            } else if (!display_text) {
                button_context.render_icon (cr, icon, x + ICON_MARGIN,
                                             y + height/2 - icon.get_height ()/2);
            } else {
                button_context.render_icon (cr, icon, x + ICON_MARGIN,
                                             y + height/2 - icon.get_height ()/2);
                button_context.render_layout (cr, x + icon.get_width () + 2 * ICON_MARGIN,
                                              y + height/2 - text_height/2, layout);
            }
        }

        if (is_RTL) {
            x -= (padding.left + (max_width > 0 ? max_width : text_width));
        } else {
            x += padding.right + (max_width > 0 ? max_width : text_width);
        }

        if (is_RTL) {
            /* Draw the separator */
            cr.save ();
            cr.translate (x + height/4, y + height / 2);
            cr.rectangle (0, -height / 2 + line_width, -height, height - 2 * line_width);
            cr.clip ();
            cr.rotate (Math.PI_4);
            button_context.save ();
            button_context.add_class ("noradius-button");
            if (pressed)
                button_context.set_state (Gtk.StateFlags.ACTIVE);

            button_context.render_frame (cr, -height / 2, -height / 2, height, height);
            button_context.restore ();
            cr.restore ();
        } else {
            /* Draw the separator */
            cr.save ();
            cr.translate (x - height / 4, y + height / 2);
            cr.rectangle (0, -height / 2 + line_width, height, height - 2 * line_width);
            cr.clip ();
            cr.rotate (Math.PI_4);
            button_context.save ();
            button_context.add_class ("noradius-button");
            if (pressed) {
                button_context.set_state (Gtk.StateFlags.ACTIVE);
            }
            button_context.render_frame (cr, -height / 2, -height / 2, height, height);
            button_context.restore ();
            cr.restore ();
        }

        if (is_RTL) {
            x -= height / 2;
        } else {
            x += height / 2;
        }

        return x;
    }

    private void computetext_width (Pango.Layout pango) {
        int width, height;
        pango.get_size (out width, out height);
        this.text_width = Pango.units_to_double (width);
        this.text_height = Pango.units_to_double (height);
    }

    /** To help testing **/
    public string get_icon_name () {
        if (icon_name != null) {
            return icon_name;
        } else {
            return "null";
        }
    }
}
