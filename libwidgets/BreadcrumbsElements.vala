/*
 * Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
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
 */

public class Marlin.View.Chrome.BreadcrumbsElement : Object {
    public string? text;
    public double offset = 0;
    public double last_height = 0;
    public double text_width = -1;
    public double text_height = -1;
    public int left_padding = 1;
    public int right_padding = 1;
    public double max_width = -1;
    public double x = 0;
    public double width {
        get {
            return text_width + left_padding + right_padding + last_height/2;
        }
    }
    public double real_width {
        get {
            return (max_width > 0 ? max_width : text_width) + left_padding + right_padding + last_height/2;
        }
    }
    Gdk.Pixbuf icon;
    public bool display = true;
    public bool display_text = true;
    public string? text_displayed = null;

    public BreadcrumbsElement (string text_, int left_padding, int right_padding) {
        text = text_;
        this.left_padding = left_padding;
        this.right_padding = right_padding;
    }

    public void set_icon (Gdk.Pixbuf icon_) {
        icon = icon_;
    }

    void computetext_width (Pango.Layout pango) {
        int text_width, text_height;
        pango.get_size(out text_width, out text_height);
        this.text_width = Pango.units_to_double(text_width);
        this.text_height = Pango.units_to_double(text_height);
    }

    public bool pressed = false;

    public double draw (Cairo.Context cr, double x, double y, double height, Gtk.StyleContext button_context, Gtk.Widget widget) {
        int estimated_border_size = 3; /* to be under the borders properly. */

        cr.restore ();
        cr.save ();
        last_height = height;
        cr.set_source_rgb (0,0,0);
        string text = text_displayed ?? this.text;
        Pango.Layout layout = widget.create_pango_layout (text);
        if (icon == null)
            computetext_width (layout);
        else if (!display_text)
            text_width = icon.get_width ();
        else {
            computetext_width (layout);
            text_width += icon.get_width () + 5;
        }

        if (max_width > 0) {
            layout.set_width (Pango.units_from_double (max_width));
            layout.set_ellipsize (Pango.EllipsizeMode.MIDDLE);
        }

        if (offset > 0.0) {
            cr.move_to (x - height/2, y);
            cr.line_to (x, y + height/2);
            cr.line_to (x - height/2, y + height);
            cr.line_to (x + text_width + estimated_border_size, y + height);
            cr.line_to (x + text_width + height/2 + estimated_border_size, y + height/2);
            cr.line_to (x + text_width + estimated_border_size, y);
            cr.close_path ();
            cr.clip ();
        }

        if (pressed) {
            cr.save ();
            double text_width = max_width > 0 ? max_width : text_width;
            cr.move_to (x - height/2 - estimated_border_size, 0);
            cr.line_to (x - height/2 - estimated_border_size, y);
            cr.line_to (x - estimated_border_size, y + height/2);
            cr.line_to (x - height/2 - estimated_border_size, y + height);
            cr.line_to (x - height/2 - estimated_border_size, y + height + 3);
            cr.line_to (x + text_width + estimated_border_size, y + height + 3);
            cr.line_to (x + text_width + estimated_border_size, y + height);
            cr.line_to (x + text_width + height/2 + estimated_border_size, y + height/2);
            cr.line_to (x + text_width + estimated_border_size, y);
            cr.line_to (x + text_width + estimated_border_size, 0);
            cr.close_path ();

            cr.clip ();
            button_context.save ();
            button_context.set_state (Gtk.StateFlags.ACTIVE);
            button_context.render_background (cr, x - height/2 - estimated_border_size, y, text_width + 2*height/2 + 4*estimated_border_size, height);
            button_context.render_frame (cr, 0, y, widget.get_allocated_width (), height );
            button_context.restore ();
            cr.restore ();
        }

        x += left_padding;

        x -= Math.sin (offset*Math.PI/2) * width;
        if (icon == null) {
            button_context.render_layout (cr, x,
                        y + height/2 - text_height/2, layout);
        } else if (!display_text) {
            Gdk.cairo_set_source_pixbuf (cr, icon, x,
                       y + height/2 - icon.get_height ()/2);
            cr.paint ();
        } else {
            Gdk.cairo_set_source_pixbuf (cr, icon, x,
                       y + height/2 - icon.get_height ()/2);
            cr.paint ();
            button_context.render_layout (cr, x + icon.get_width () + 5,
                        y + height/2 - text_height/2, layout);
        }

        if (pressed) {
            double text_width = max_width > 0 ? max_width : text_width;
            cr.restore ();

            cr.move_to (0, 0);
            cr.line_to (x - height/2 - 2*estimated_border_size - 1, 0);
            cr.line_to (x - estimated_border_size, y + height/2);
            cr.line_to (x - height/2 - 2*estimated_border_size - 1, y + height + 3);
            cr.line_to (0, y + height + 3);
            cr.close_path ();

            cr.move_to (x + text_width, y + height + 3);
            cr.line_to (x + text_width, y + height);
            cr.line_to (x + text_width + height/2, y+height/2);
            cr.line_to (x + text_width, y);
            cr.line_to (x + text_width, 0);
            cr.line_to (widget.get_allocated_width (), 0);
            cr.line_to (widget.get_allocated_width (), y + height);
            cr.line_to (widget.get_allocated_width (), y + height + 3);
            cr.close_path ();
            cr.clip ();

            cr.save ();
        }

        x += right_padding + (max_width > 0 ? max_width : text_width);

        /* Draw the separator */
        cr.save ();
        cr.translate (x - height/4, y + height/2);
        cr.rectangle (0, -height/2 + 2, height - 4, height - 4);
        cr.clip ();
        cr.rotate (Math.PI/4);
        button_context.save ();
        button_context.add_class ("noradius-button");
        button_context.render_frame (cr, -height/2, -height/2, Math.sqrt (height*height), Math.sqrt (height*height));
        button_context.restore ();
        cr.restore ();

        x += height/2;

        return x;
    }
}
