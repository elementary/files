//  
//  LocationBar.cs
//  
//  Author:
//       mathijshenquet <${AuthorEmail}>
// 
//  Copyright (c) 2010 mathijshenquet
// 
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
using Gtk;

namespace Marlin.View.Chrome
{
    public class LocationBar : ToolItem
    {
        private Entry entry;
        private Breadcrumbs bread;
        bool _state;
        public bool state
        {
            get { return _state; }
            set { _state = value; update_widget(); }
        }

        public new string path{
            set{
                var new_path = value;
                entry.text = new_path;
                bread.animate_new_breadcrumbs(new_path);
                state = true;
            }
            get{
                return entry.text;
            }
        }

        public new signal void activate();

        public LocationBar ()
        {
            entry = new Entry ();
            bread = new Breadcrumbs();

            bread.activate_entry.connect( () => { state = false; });

            bread.changed.connect(on_bread_changed);
            state = true;

            set_expand(true);
            add(bread);

            entry.activate.connect(() => { activate(); state = true;});
            entry.focus_out_event.connect(() => { if(!state) state = true; return true; });
        }
        
        private void on_bread_changed(string changed)
        {
             entry.text = changed;
             activate();
        }

        private void update_widget()
        {
            var list = get_children();
            foreach(Widget w in list)
                remove(w);
            if(_state)
            {
                add(bread);
            }
            else
            {
                add(entry);
                show_all();
                entry.grab_focus();
            }
        }
    }

    class Breadcrumbs : DrawingArea
    {
        public signal void activate_entry();
        public signal void changed(string changed);
        string _text = "";
        public string text
        {
            get { return _text; }
            set { _text = value;  selected = -1; queue_draw();}
        }
        int selected = -1;
        string gtk_font_name;
        int space_breads = 12;
        int x;
        int y;

        Cairo.ImageSurface home_img;
        Gtk.Button button;
        Gtk.IMContext im_context;
        
        Gee.ArrayList<BreadcrumbsElement> elements;
        Gee.List<BreadcrumbsElement> newbreads;
        
        public Breadcrumbs()
        {
            add_events(Gdk.EventMask.BUTTON_PRESS_MASK
                      | Gdk.EventMask.BUTTON_RELEASE_MASK
                      | Gdk.EventMask.KEY_PRESS_MASK
                      | Gdk.EventMask.POINTER_MOTION_MASK
                      | Gdk.EventMask.LEAVE_NOTIFY_MASK);

            /* Loade default font */
            var gtk_settings = Gtk.Settings.get_for_screen (get_screen ());
            gtk_settings.get ("gtk-font-name", out gtk_font_name);
            var font = Pango.FontDescription.from_string (gtk_font_name);
            gtk_font_name = font.get_family();

            /* Load home image */
            home_img = new Cairo.ImageSurface.from_png(Config.PIXMAP_DIR + "/home.png");
            
            /* FIXME: we should directly use a Gtk.StyleContext */
            button = new Gtk.Button();
            
            set_can_focus(true);

            /* x padding */
            x = 0;
            /* y padding */
            y = 6;
            
            elements = new Gee.ArrayList<BreadcrumbsElement>();
        }

        string [] old_text = new string[0];
        
        /* Where the new text start */
        int new_text_index = -1;
        int anim_state = 0;

        public override bool button_press_event(Gdk.EventButton event)
        {
            if(event.type == Gdk.EventType.2BUTTON_PRESS)
            {
                activate_entry();
            }
            else
            {
                double x_previous = -10;
                int x = (int)event.x;
                double x_render = 0;
                string newpath = "";
                foreach(BreadcrumbsElement element in elements)
                {
                    x_render += element.text_width + space_breads;
                    newpath += element.text + "/";
                    if(x <= x_render + 5 && x > x_previous + 5)
                    {
                        selected = elements.index_of(element);
                        changed(newpath);
                        break;
                    }
                    x_previous = x_render;
                }
            }
            return true;
        }

        private bool is_in_home(string[] dirs)
        {
            return Environment.get_home_dir() == "/" + dirs[1] + "/" + dirs[2];
        }

        public void animate_new_breadcrumbs(string newpath)
        {
            _text = newpath;
            selected = -1;
            var breads = newpath.split("/");
            var newelements = new Gee.ArrayList<BreadcrumbsElement>();
            if(breads[0] == "")
                newelements.add(new BreadcrumbsElement("/", "Ubuntu", 13));
            
            foreach(string dir in breads)
            {
                if(dir != "")
                newelements.add(new BreadcrumbsElement(dir, "Ubuntu", 13));
            }
            
            int max_path = 0;
            if(newelements.size > elements.size)
            {
                max_path = elements.size;
            }
            else
            {
                max_path = newelements.size;
            }
            
            bool same = true;
            
            for(int i = 0; i < max_path; i++)
            {
                if(newelements[i].text != elements[i].text)
                {
                    same = false;
                    break;
                }
            }
            
            
            if(newelements.size > elements.size)
            {
                view_old = false;
                newbreads = newelements.slice(max_path, newelements.size);
                animate_new_breads();
            }
            else if(newelements.size < elements.size)
            {
                view_old = true;
                newbreads = elements.slice(max_path, elements.size);
                animate_old_breads();
            }
            
            elements.clear();
            elements = newelements;
        }
        
        bool view_old = false;

        private void animate_old_breads()
        {
            anim_state = 0;
            Timeout.add(1000/60, () => {
                anim_state++;
                foreach(BreadcrumbsElement bread in newbreads)
                {
                    bread.offset = anim_state;
                }
                queue_draw();
                if(anim_state >= 10)
                {
                    newbreads = null;
                    view_old = false;
                    queue_draw();
                    return false;
                }
                return true;
            } );
        }

        private void animate_new_breads()
        {
            anim_state = 10;
            Timeout.add(1000/60, () => {
                anim_state--;
                foreach(BreadcrumbsElement bread in newbreads)
                {
                    bread.offset = anim_state;
                }
                queue_draw();
                if(anim_state <= 0)
                {
                    newbreads = null;
                    view_old = false;
                    queue_draw();
                    return false;
                }
                return true;
            } );
        }

        private void draw_selection(Cairo.Context cr)
        {

            /* If a dir is selected (= mouse hover)*/
            if(selected != -1)
            {
                y++;
                int height = get_allocated_height();
                /* FIXME: this block could be cleaned up, +7 and +5 are
                 * hardcoded. */
                double x_hl = y;
                if(selected > 0)
                {
                    foreach(BreadcrumbsElement element in elements)
                    {
                        x_hl += element.text_width;
                        x_hl += space_breads;
                        if(element == elements[selected - 1])
                        {
                            break;
                        }
                    }
                }
                else
                {
                    x_hl = -10;
                }
                x_hl += 7;
                double first_stop = x_hl - 7*(height/2 - y)/(height/2 - height/3) + 7;
                cr.move_to(first_stop,
                           y);
                cr.line_to(x_hl + 5,
                           height/2);
                cr.line_to(first_stop,
                           height - y);
                if(selected > 0)
                    x_hl += elements[selected].text_width;
                else
                    x_hl = elements[selected].text_width + space_breads/2 + y;
                double second_stop = x_hl - 7*(height/2 - y)/(height/2 - height/3) + 7;
                cr.line_to(second_stop,
                           height - y);
                cr.line_to(x_hl + 5,
                           height/2);
                cr.line_to(second_stop,
                           y);
                cr.close_path();
                Gdk.RGBA color = Gdk.RGBA();
                button.get_style_context().get_background_color(Gtk.StateFlags.SELECTED, color);
                
                Cairo.Pattern pat = new Cairo.Pattern.linear(first_stop, y, second_stop, y);
                pat.add_color_stop_rgba(0.7, color.red, color.green, color.blue, 0);
                pat.add_color_stop_rgba(1, color.red, color.green, color.blue, 0.6);

                cr.set_source(pat);
                cr.fill();
                y--;
            }
        }

        public override bool motion_notify_event(Gdk.EventMotion event)
        {
            int x = (int)event.x;
            double x_render = 0;
            double x_previous = -10;
            selected = -1;
            if(event.y > get_allocated_height() - 5 || event.y < 5)
            {
                queue_draw();
                return true;
            }
            foreach(BreadcrumbsElement element in elements)
            {
                x_render += element.text_width + space_breads;
                if(x <= x_render + 5 && x > x_previous + 5)
                {
                    selected = elements.index_of(element);
                    break;
                }
                x_previous = x_render;
            }
            queue_draw();
            return true;
        }

        public override bool leave_notify_event(Gdk.EventCrossing event)
        {
            selected = -1;
            queue_draw();
            return false;
        }

        public override bool draw(Cairo.Context cr)
        {
            double height = get_allocated_height();
            double width = get_allocated_width();

            /* Draw toolbar background */

            Gtk.render_background(get_style_context(), cr, 0, 0, get_allocated_width(), get_allocated_height());
            Gtk.render_background(button.get_style_context(), cr, 0, 6, get_allocated_width(), get_allocated_height() - 12);
            Gtk.render_frame(button.get_style_context(), cr, 0, 6, get_allocated_width(), get_allocated_height() - 12);

            double x_render = y;
            int i = 0;

            foreach(BreadcrumbsElement element in elements)
            {
                element.draw(cr, x_render, y, height);
                x_render += element.text_width + space_breads;
                i++;
            }
            if(view_old)
            {
                foreach(BreadcrumbsElement element in newbreads)
                {
                    element.draw(cr, x_render, y, height);
                    x_render += element.text_width + space_breads;
                }
            }

            draw_selection(cr);
            return false;
        }
    }
    
    class BreadcrumbsElement : GLib.Object
    {
        public string text;
        string font_name;
        int font_size;
        public int offset = 0;
        public double text_width = -1;
        public BreadcrumbsElement(string text_, string font_name_, int font_size_)
        {
            text = text_;
            font_name = font_name_;
            font_size = font_size_;
        }
        
        private void compute_text_width(Cairo.Context cr)
        {
            Cairo.TextExtents txt = Cairo.TextExtents();
            cr.text_extents(text, out txt);
            text_width = txt.x_advance;
        }
        
        public void draw(Cairo.Context cr, double x, double y, double height)
        {
            cr.set_source_rgb(0,0,0);
            cr.select_font_face(font_name, Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(font_size);
            if(text_width < 0)
            {
                compute_text_width(cr);
            }
            
            if(offset != 0)
            {
                cr.move_to(x, y);
                cr.line_to(x + 5, height/2);
                cr.line_to(x, height - y);
                cr.line_to(x + text_width + 5, height - y);
                cr.line_to(x + text_width + 10 + 5, height/2);
                cr.line_to(x + text_width + 5, y);
                cr.close_path();
                cr.clip();
            }
            
            cr.move_to(x - offset*5,
                       height/2 + font_size/2);
            cr.show_text(text);
            /* Draw the separator */
            cr.set_line_width(1);
            cr.move_to(x - offset*5 + text_width, y);
            cr.line_to(x - offset*5 + text_width + 10, height/2);
            cr.line_to(x - offset*5 + text_width, height - y);
            cr.stroke();
        }
    }
}

