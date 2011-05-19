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

public class Marlin.View.PopupLocationBar : Gtk.Window
{
    PopupDraw popup;
    public signal void select(string path);
    public int selected { get { return popup.selected; } set { popup.selected = value; queue_draw(); } }
    public PopupLocationBar(int width)
    {
        ///Object(type: Gtk.WindowType.POPUP, type_hint: Gdk.WindowTypeHint.TOOLTIP);
        var scrolled = new Gtk.ScrolledWindow(null, null);
        popup = new PopupDraw();
        scrolled.add_with_viewport(popup);
        get_style_context().add_class("menu");
        add(scrolled);
        set_resizable(false);
        set_decorated(false);
        width_request = width;
        set_keep_above(true);
        popup.select.connect(select_);
    }
    public void select_(string text)
    {
        print(text + "\n");
        select(text);
    }

    public void add_item(string title)
    {
        popup.add_item(title);
        height_request = (int)Math.fmin(popup.height*popup.items.size + 16, 400);
    }
    
    public void enter()
    {
        if(popup.selected >= 0 && popup.selected < popup.items.size)
            select(popup.items[popup.selected].title);
    }
    
    public void clear()
    {
        popup.clear();
        height_request = (int)popup.height;
        queue_draw();
    }
}

class PopupDraw : Gtk.DrawingArea
{
    internal const double height = 30;
    internal Gee.ArrayList<PopupDrawItem> items;
    internal int selected;
    public signal void select(string path);
    Gtk.StyleContext style;
    Gtk.StyleContext style_;
    Gtk.MenuItem menuitem;
    public PopupDraw()
    {
        items = new Gee.ArrayList<PopupDrawItem>();
        
        add_events(Gdk.EventMask.BUTTON_PRESS_MASK
                  | Gdk.EventMask.BUTTON_RELEASE_MASK
                  | Gdk.EventMask.KEY_PRESS_MASK
                  | Gdk.EventMask.KEY_RELEASE_MASK
                  | Gdk.EventMask.POINTER_MOTION_MASK);
        menuitem = new Gtk.MenuItem();
        style = menuitem.get_style_context();
        style_ = new Gtk.Menu().get_style_context();
    }
    
    public override bool motion_notify_event(Gdk.EventMotion event)
    {
        if((int)(event.y/height) < items.size)
            selected = (int)(event.y/height);
        queue_draw();
        return true;
    }
    
    public override bool button_press_event(Gdk.EventButton event)
    {
        select(items[selected].title);
        return true;
    }
    
    public void add_item(string title)
    {
        var item = new PopupDrawItem(title, style);
        items.add(item);
        update_size_request();
        print("%s\n", title);
        queue_draw();
    }
    
    public void update_size_request()
    {
        height_request = (int)height * items.size + 6;
        width_request = 100;
    }
    
    public void clear()
    {
        items.clear();
    }
    
    public override bool draw(Cairo.Context cr)
    {
        double y = 3;
        Gtk.render_background(style_, cr, 0, 0, get_allocated_width(), get_allocated_height());
        if(items.size >= 1)
        {
            PopupDrawItem selected_item = null;
            if(selected < items.size && selected >= 0)
                selected_item = items[selected];
            foreach(var item in items)
            {
                item.draw(cr, height, get_allocated_width(), y, menuitem, selected_item == item);
                y += height;
            }
        }
        else
        {
            style.set_state(Gtk.StateFlags.ACTIVE);
            Pango.Layout layout = menuitem.create_pango_layout(_("(no result found)"));
            Gtk.render_layout(style, cr, 10, 5, layout);
        }
        return true;
    }
}

class PopupDrawItem : Object
{
    Gtk.StyleContext style;
    internal string title;
    public PopupDrawItem(string title_, Gtk.StyleContext style_)
    {
        title = title_;
        style = style_;
    }
    
    public void draw(Cairo.Context cr, double height, double width, double y, Gtk.MenuItem widget, bool selected = false)
    {
        const double margins = 3;
        double border = widget.get_border_width();
        if(selected)
        {
            style.set_state(Gtk.StateFlags.PRELIGHT);
            Gtk.render_frame(style, cr, border, y + border, width - border*2, height - border*2);
            Gtk.render_background(style, cr, border, y + border, width - border*2, height - border*2);
        }
        else
            style.set_state(Gtk.StateFlags.ACTIVE);
            
        Pango.Layout layout = widget.create_pango_layout(title);
        layout.set_ellipsize(Pango.EllipsizeMode.END);
        layout.set_width(Pango.units_from_double(width));
        
        Gtk.render_layout(style, cr, 0, y + margins, layout);
    }
}
