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

public class Marlin.View.Chrome.BreadcrumbsElement : GLib.Object
{
    public string? text;
    public double offset = 0;
    public double last_height = 0;
    public double text_width = -1;
    public double text_height = -1;
    public int left_padding = 1;
    public int right_padding = 1;
    public double max_width = -1;
    public double width { get { return text_width + left_padding + right_padding + last_height/2; }}
    public double real_width { get { return (max_width > 0 ? max_width : text_width) + left_padding + right_padding + last_height/2; }}
    Gdk.Pixbuf icon;
    public bool display = true;
    public bool display_text = true;
    public string? text_displayed = null;
    public BreadcrumbsElement(string text_, int left_padding, int right_padding)
    {
        text = text_;
        this.left_padding = left_padding;
        this.right_padding = right_padding;
    }
    
    public void set_icon(Gdk.Pixbuf icon_)
    {
        icon = icon_;
    }
    
    void computetext_width(Pango.Layout pango)
    {
        int text_width, text_height;
        pango.get_size(out text_width, out text_height);
        this.text_width = Pango.units_to_double(text_width);
        this.text_height = Pango.units_to_double(text_height);
    }
    
    public double draw(Cairo.Context cr, double x, double y, double height, Gtk.StyleContext button_context, Gtk.Widget widget)
    {
        cr.restore();
        cr.save();
        last_height = height;
        cr.set_source_rgb(0,0,0);
        string text = text_displayed ?? this.text;
        Pango.Layout layout = widget.create_pango_layout(text);
        if(icon == null)
        {
            computetext_width(layout);
        }
        else if(!display_text)
        {
            text_width = icon.get_width();
        }
        else
        {
            computetext_width(layout);
            text_width += icon.get_width() + 5;
        }
        if(max_width > 0)
        {
            layout.set_width(Pango.units_from_double(max_width));
            layout.set_ellipsize(Pango.EllipsizeMode.MIDDLE);
        }
        
        if(offset > 0.0)
        {
            cr.move_to(x - 5, y);
            cr.line_to(x, y + height/2);
            cr.line_to(x - 5, y + height);
            cr.line_to(x + text_width + 5, y+ height);
            cr.line_to(x + text_width + 10 + 5, y+height/2);
            cr.line_to(x + text_width + 5, y);
            cr.close_path();
            cr.clip();
        }
        
        x += left_padding;
        
        x -= Math.sin(offset*Math.PI/2)*width;
        if(icon == null)
        {
            Gtk.render_layout(button_context, cr, x,
                        y + height/2 - text_height/2, layout);
        }
        else if(!display_text)
        {
            Gdk.cairo_set_source_pixbuf(cr, icon, x,
                       y + height/2 - icon.get_height()/2);
            cr.paint();
        }
        else
        {
            Gdk.cairo_set_source_pixbuf(cr, icon, x,
                       y + height/2 - icon.get_height()/2);
            cr.paint();
            Gtk.render_layout(button_context, cr, x + icon.get_width() + 5,
                        y + height/2 - text_height/2, layout);
        }
        cr.save();
        cr.set_source_rgba(0,0,0,0.5);
        x += right_padding + (max_width > 0 ? max_width : text_width);
        /* Draw the separator */
        cr.translate(x - height/4, y + height/2);
        cr.rectangle(0, -height/2 + 2, height, height - 4);
        cr.clip();
        cr.rotate(Math.PI/4);
        Gtk.render_frame(button_context, cr, -height/2, -height/2, Math.sqrt(height*height), Math.sqrt(height*height));
        cr.restore();
        x += height/2;
        return x;
    }
}