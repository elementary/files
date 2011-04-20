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
        public string text = "/";
        Gee.ArrayList<int> list;
        public Breadcrumbs()
        {

        add_events(Gdk.EventMask.BUTTON_PRESS_MASK
                  | Gdk.EventMask.BUTTON_RELEASE_MASK
                  | Gdk.EventMask.POINTER_MOTION_MASK);
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
                        print(text);

                        changed();
                        break;
                    }
                }
            }
            return false;
        }

        public override bool draw(Cairo.Context cr)
        {
            double height = get_allocated_height();
            double width = get_allocated_width();
            Gtk.render_background(get_style_context(), cr, 0, 0, get_allocated_width(), get_allocated_height());
           

            cr.set_source_rgb(0.8,0.8,0.8);
            int r = 10;
            int x = 0;
            int y = 5;
            height -= 2*y;
            width -= 2*x;
               cr.move_to(x+r, y); // Move to A
               cr.line_to(x+width-r, y); // Straight line to B
               cr.curve_to(x+width, y, x+width, y, x+width, y+r); // Curve to C, Control points are both at Q
               cr.line_to(x+width, y+height-r); // Move to D
               cr.curve_to(x+width, y+height, x+width, y+height, x+width-r, y+height); // Curve to E
               cr.line_to(x+r,y+height); // Line to F
               cr.curve_to(x,y+height,x,y+height,x,y+height-r); // Curve to 
               cr.line_to(x,y+r); // Line to H
               cr.curve_to(x,y,x,y,x+r,y); // Curve to A
            height = get_allocated_height();
            width = get_allocated_width();

            Cairo.Pattern pat = new Cairo.Pattern.linear(0,0, 0, height-2*y);

            pat.add_color_stop_rgb(0, 0.8,0.8,0.8);
            pat.add_color_stop_rgb(1, 0.7,0.7,0.7);

            cr.set_source(pat);
            cr.fill_preserve();
            cr.set_source_rgb(0.5,0.5,0.5);
            cr.set_line_width(1);
            cr.stroke();


            cr.set_source_rgb(0,0,0);
            //cr.paint();
            cr.set_font_size(15);
            var dirs = text.split("/");
            var path = "";
            foreach(string dir in dirs)
            {
                path += dir + "   ";
            }
            cr.move_to(0, get_allocated_height()/2 + 15/2);

            cr.show_text(path);
            double x_render = -10;
            Cairo.TextExtents txt = Cairo.TextExtents();
            cr.set_line_width(1);
            cr.set_source_rgb(0.6,0.6,0.6);
            list = new Gee.ArrayList<int>();
            foreach(string dir in dirs)
            {
                cr.text_extents(dir + "   ", out txt);
                x_render += txt.x_advance;
                cr.move_to(x_render, height/3);
                cr.line_to(x_render + 5, height/2);
                cr.line_to(x_render, height/2 + height/6);
                cr.stroke();
                list.add((int)x_render);
            }

            return true;
        }
    }
}

