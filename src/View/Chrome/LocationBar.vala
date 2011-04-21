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

        public bool state;

        public new string path{
            set{
                var new_path = value;
                entry.text = new_path;
                bread.text = new_path;
                bread.queue_draw();
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

            bread.activate_entry.connect( () => { state = false; update_widget(); });

            bread.changed.connect( () => { entry.text = bread.text; activate(); });
            state = true;

            set_expand(true);
            add(bread);

            entry.activate.connect(() => { activate(); state = true; update_widget(); });
            entry.focus_out_event.connect(() => {state = true; update_widget(); return false; });
        }

        private void update_widget()
        {
            remove(entry);
            remove(bread);
            if(state)
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
        public signal void changed();
        string _text;
        public string text
        {
            get { return _text; }
            set { _text = value;  selected = -1; queue_draw();}
        }
        Gee.ArrayList<int> list;
        int selected = -1;
        string gtk_font_name;
        int space_breads = 10;
        
        Cairo.ImageSurface bread_center;
        Cairo.ImageSurface bread_left;
        Cairo.ImageSurface bread_right;
        Cairo.ImageSurface bread_separator;
        
        public Breadcrumbs()
        {
            add_events(Gdk.EventMask.BUTTON_PRESS_MASK
                      | Gdk.EventMask.BUTTON_RELEASE_MASK
                      | Gdk.EventMask.POINTER_MOTION_MASK);
            var gtk_settings = Gtk.Settings.get_for_screen (get_screen ());
            gtk_settings.get ("gtk-font-name", out gtk_font_name);
            var font = Pango.FontDescription.from_string (gtk_font_name);
            gtk_font_name = font.get_family();
            print(gtk_font_name  + "\n\n\n\n");
            bread_center = new Cairo.ImageSurface.from_png("icons/bread_center.png");
            bread_right = new Cairo.ImageSurface.from_png("icons/bread_right.png");
            bread_left = new Cairo.ImageSurface.from_png("icons/bread_left.png");
            bread_separator = new Cairo.ImageSurface.from_png("icons/bread_separator.png");
        }

        public override bool button_press_event(Gdk.EventButton event)
        {
            if(event.type == Gdk.EventType.2BUTTON_PRESS)
            {
                activate_entry();
            }
            else
            {
                int x = (int)event.x;
                foreach(int x_render in list)
                {
                    if(x < x_render)
                    {
                        int to_keep = list.index_of(x_render);
                        print(to_keep.to_string() + "\n");

                        var text_tmp = text;
                        text = "";
                        for(int i = 0; i <= to_keep; i++)
                        {
                            text += text_tmp.split("/")[i] + "/";
                        }

                        changed();
                        break;
                    }
                }
            }
            return true;
        }
        
        public override bool motion_notify_event(Gdk.EventMotion event)
        {
        
            int x = (int)event.x;
            int x_previous = -10;
            selected = -1;
            if(event.y > get_allocated_height() - 5 || event.y < 5)
            {
                queue_draw();
                return true;
            }
            foreach(int x_render in list)
            {
                if(x <= x_render + 5 && x > x_previous + 5)
                {
                    selected = list.index_of(x_render);
                    break;
                }
                x_previous = x_render;
            }
            queue_draw();
            return true;
        }

        public override bool draw(Cairo.Context cr)
        {
            double height = get_allocated_height();
            double width = get_allocated_width();
            Gtk.render_background(get_style_context(), cr, 0, 0, get_allocated_width(), get_allocated_height());

            /* All this block is an ugly copy/paste to get a rounded rectangle,
             * it needs to be removed and replaced by some gtk/theming stuff. */
            cr.set_source_rgb(0.8,0.8,0.8);
            int r = 5;
            int x = 0;
            int y = 4;
            height -= 2*y;
            width -= 2*x;
            /*cr.move_to(x+r, y); // Move to A
            cr.line_to(x+width-r, y); // Straight line to B
            cr.curve_to(x+width, y, x+width, y, x+width, y+r); // Curve to C, Control points are both at Q
            cr.line_to(x+width, y+height-r); // Move to D
            cr.curve_to(x+width, y+height, x+width, y+height, x+width-r, y+height); // Curve to E
            cr.line_to(x+r,y+height); // Line to F
            cr.curve_to(x,y+height,x,y+height,x,y+height-r); // Curve to 
            cr.line_to(x,y+r); // Line to H
            cr.curve_to(x,y,x,y,x+r,y); // Curve to A*/
            cr.scale(1, height/bread_left.get_height());
            cr.set_source_surface(bread_left, 0, y * bread_left.get_height()/height);
            cr.paint();
            cr.restore();
            cr.save();

            Cairo.Pattern pat = new Cairo.Pattern.for_surface(bread_center);
            pat.set_extend(Cairo.Extend.REPEAT);
            Cairo.Matrix mat = Cairo.Matrix.identity();
            mat.scale((width - bread_left.get_width() - bread_right.get_width()), bread_center.get_height()/height);
            pat.set_matrix(mat);
            cr.translate(bread_left.get_width(),y);
            cr.set_source(pat);
            cr.rectangle(0,0,(width - bread_left.get_width() - bread_right.get_width()),height);
            cr.fill();
            cr.restore();
            cr.save();

            cr.translate(width - bread_right.get_width(), y);
            cr.scale(height/bread_right.get_height(), height/bread_right.get_height());
            cr.set_source_surface(bread_right, 0, 0);
            cr.paint();
            cr.restore();
            cr.save();

            height = get_allocated_height();
            width = get_allocated_width();

            /*Cairo.Pattern pat = new Cairo.Pattern.linear(0,0, 0, height-2*y);

            pat.add_color_stop_rgb(0, 0.99,0.99,0.99);
            pat.add_color_stop_rgb(1, 0.86,0.86,0.86);

            cr.set_source(pat);
            cr.fill_preserve();
            cr.set_source_rgb(0.66,0.66,0.66);
            cr.set_line_width(1);
            cr.stroke();*/

            /* Remove all "/" and replace them with some space. We will keep the
             * first / since it shows the root path. */
            var dirs = text.split("/");
            /* the > */
            double x_render = 0;
            /* Select system font */
            cr.select_font_face(gtk_font_name, Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            Cairo.TextExtents txt = Cairo.TextExtents();
            cr.set_font_size(15);
            cr.set_line_width(1);
            cr.save();
            list = new Gee.ArrayList<int>();
            cr.text_extents("/" + "  ", out txt);
            x_render += txt.x_advance;
            
            /* Draw the first > */
            /*cr.set_source_rgb(0.6,0.6,0.6);
            cr.move_to(x_render, height/3);
            cr.line_to(x_render + 5, height/2);
            cr.line_to(x_render, height/2 + height/6);
            cr.stroke();*/
            
            cr.translate(x_render, y);
            cr.scale((height - 2*y)/bread_separator.get_height(), (height -2*y)/bread_separator.get_height());
            cr.set_source_surface(bread_separator, 0, 0);
            cr.paint();
            cr.restore();
            cr.save();

            /* Add the value into our list to recall it later. */
            list.add((int)x_render);
            
            foreach(string dir in dirs)
            {
                /* Don't add too much dir, e.g. in "/home///", we would get five
                 * dirs, and we only need three. */ 
                if(dir != "")
                {
                    cr.text_extents(dir + "   ", out txt);
                    
                    x_render += txt.x_advance + space_breads;
                    cr.translate(x_render, y);
                    cr.scale((height - 2*y)/bread_separator.get_height(), (height -2*y)/bread_separator.get_height());
                    cr.set_source_surface(bread_separator, 0, 0);
                    cr.paint();
                    cr.restore();
                    cr.save();
                    list.add((int)x_render);
                }
            }
            
            /* If a dir is selected (= mouse hover)*/
            if(selected != -1)
            {
                y++;
                int x_hl;
                if(selected == 0)
                    x_hl = -1;
                else
                    x_hl = list[selected - 1] + 7;
                cr.move_to(x_hl - 5*(height/2 - y)/(height/2 - height/3) + 5, y);
                cr.line_to(x_hl + 5, height/2);
                cr.line_to(x_hl - 5*(height/2 - y)/(height/2 - height/3) + 5, height - y);
                x_hl = list[selected] + 7;
                cr.line_to(x_hl - 5*(height/2 - y)/(height/2 - height/3) + 5, height - y);
                cr.line_to(x_hl + 5, height/2);
                cr.line_to(x_hl - 5*(height/2 - y)/(height/2 - height/3) + 5, y);
                cr.close_path();
                cr.set_source_rgba(0.5,0.5,0.5, 0.2);
                cr.fill();
                
            }
                cr.set_source_rgb(0,0,0);

            /* The path itself, e.g. " /   home" */

            int i = 0;
            cr.move_to(5, get_allocated_height()/2 + 13/2);
            cr.show_text("/");
            foreach(string dir in dirs)
            {
                /* Don't add too much dir, e.g. in "/home///", we would get five
                 * dirs, and we only need three. */ 
                if(dir != "")
                {
                    cr.move_to(bread_separator.get_width() + list[i], get_allocated_height()/2 + 13/2);
                    cr.show_text(dir);
                    i++;
                }
            }

            return true;
        }
    }
}

