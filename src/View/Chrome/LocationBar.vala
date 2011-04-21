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
                bread.text = new_path;
                state = true;
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

            bread.activate_entry.connect( () => { state = false; });

            bread.changed.connect( () => { entry.text = bread.text; activate(); });
            state = true;

            set_expand(true);
            add(bread);

            entry.activate.connect(() => { activate(); state = true;});
            entry.focus_out_event.connect(() => { if(!state) state = true; return true; });
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
        int space_breads = 12;

        Cairo.ImageSurface home_img;
        Gtk.Button button;
        
        public Breadcrumbs()
        {
            add_events(Gdk.EventMask.BUTTON_PRESS_MASK
                      | Gdk.EventMask.BUTTON_RELEASE_MASK
                      | Gdk.EventMask.POINTER_MOTION_MASK);
            var gtk_settings = Gtk.Settings.get_for_screen (get_screen ());
            gtk_settings.get ("gtk-font-name", out gtk_font_name);
            var font = Pango.FontDescription.from_string (gtk_font_name);
            gtk_font_name = font.get_family();

            home_img = new Cairo.ImageSurface.from_png(Config.PIXMAP_DIR + "/home.png");
            
            /* FIXME: we should directly use a Gtk.StyleContext */
            button = new Gtk.Button();
        }

        public override bool button_press_event(Gdk.EventButton event)
        {
            if(event.type == Gdk.EventType.2BUTTON_PRESS)
            {
                activate_entry();
            }
            else
            {
                int x_previous = -10;
                int x = (int)event.x;
                foreach(int x_render in list)
                {
                    if(x <= x_render + 5 && x > x_previous + 5)
                    {
                        int to_keep = list.index_of(x_render);

                        var text_tmp = text.split("/");
                        text = "";
                        if(Environment.get_home_dir() == "/" + text_tmp[1] + "/" + text_tmp[2])
                        {
                            to_keep += 2;
                        }
                        for(int i = 0; i <= to_keep; i++)
                        {
                            text += text_tmp[i] + "/";
                        }

                        changed();
                        break;
                    }
                    x_previous = x_render;
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
            /* It is increased when we draw each directory name to put the
             * separators at the good place */
            double x_render = 0;
            /* x padding */
            int x = 0;
            /* y padding */
            int y = 6;

            /* Draw toolbar background */
            Gtk.render_background(get_style_context(), cr, 0, 0, get_allocated_width(), get_allocated_height());
            Gtk.render_background(button.get_style_context(), cr, 0, 6, get_allocated_width(), get_allocated_height() - 12);
            Gtk.render_frame(button.get_style_context(), cr, 0, 6, get_allocated_width(), get_allocated_height() - 12);

            height -= 2*y;
            width -= 2*x;

            cr.restore();
            cr.save();
            cr.set_source_rgb(0.3,0.3,0.3);
            height = get_allocated_height();
            width = get_allocated_width();

            /* The > */
            /* Don't count the home directory since we won't draw it later. */
            var dirs = (text.replace(Environment.get_home_dir(), "") + "/").split("/");

            /* Select our system font */
            cr.select_font_face(gtk_font_name, Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            /* TODO: We should use system font size but cairo doesn't seem to
             * scale them like Gtk?! */
            cr.set_font_size(15);
            cr.set_line_width(1);
            cr.save();

            Cairo.TextExtents txt = Cairo.TextExtents();
            list = new Gee.ArrayList<int>();
            
            /* We must let some space for the first dir, it can be "/" or home */
            x_render += home_img.get_width();
            
            /* Draw the first > */

            cr.set_source_rgba(0.5,0.5,0.5,0.5);
            cr.move_to(x_render, y + 0.5);
            cr.line_to(x_render + 10, height/2);
            cr.line_to(x_render, height - y - 1);
            cr.stroke();

            /* Add the value into our list to recall it later. */
            list.add((int)x_render);
            
            foreach(string dir in dirs)
            {
                /* Don't add too much dir, e.g. in "/home///", we would get five
                 * dirs, and we only need three. */ 
                if(dir != "")
                {
                    cr.text_extents(dir + "   ", out txt);

                    /* Increase the separator position, with a custom padding
                     * (space_breads). */
                    x_render += txt.x_advance + space_breads;

                    /* Draw the separator */
                    cr.move_to(x_render, y + 1);
                    cr.line_to(x_render + 10, height/2);
                    cr.line_to(x_render, height - y - 1);
                    cr.stroke();

                    /* Add the value into our list to recall it later (useful
                     * for the mouse events) */
                    list.add((int)x_render);
                }
            }

            /* If a dir is selected (= mouse hover)*/
            if(selected != -1)
            {
                /* FIXME: this block could be cleaned up, +7 and +5 are
                 * hardcoded. */
                y++;
                int x_hl;
                if(selected == 0)
                    x_hl = -10;
                else
                    x_hl = list[selected - 1] + 5;
                cr.move_to(x_hl - 7*(height/2 - y)/(height/2 - height/3) + 7,
                           y);
                cr.line_to(x_hl + 5,
                           height/2);
                cr.line_to(x_hl - 7*(height/2 - y)/(height/2 - height/3) + 7,
                           height - y);
                x_hl = list[selected] + 7;
                cr.line_to(x_hl - 7*(height/2 - y)/(height/2 - height/3) + 7,
                           height - y);
                cr.line_to(x_hl + 5,
                           height/2);
                cr.line_to(x_hl - 7*(height/2 - y)/(height/2 - height/3) + 7,
                           y);
                cr.close_path();
                
                /* TODO: This color shouldn't be hardcoded, we should read it
                 * from a gtk theme */ 
                cr.set_source_rgba(0.5,0.5,0.5, 0.3);
                cr.fill();
                y--;
            }

            cr.restore();
            cr.save();
            cr.set_source_rgb(0,0,0);

            /* The path itself, e.g.  /   home */

            /* Remove all "/" and replace them with some space. We will keep the
             * first / since it shows the root path. */
            dirs = text.split("/");

            if(Environment.get_home_dir() != "/" + dirs[1] + "/" + dirs[2])
            {
                cr.move_to(10, get_allocated_height()/2 + 13/2);
                cr.show_text("/");
            }
            else
            {
                cr.translate(5, 1.75*y);
                cr.scale((height - 3.5*y)/home_img.get_height(),
                         (height - 3.5*y)/home_img.get_height());
                cr.set_source_surface(home_img, 0, 0);
                cr.paint();
                cr.restore();
                cr.save();
                dirs = (text.replace(Environment.get_home_dir(), "") + "/").split("/");
            }


            int i = 0;
            foreach(string dir in dirs)
            {
                /* Don't add too much dir, e.g. in "/home///", we would get five
                 * dirs, and we only need three. */ 
                if(dir != "")
                {
                    cr.move_to(15 + list[i],
                               get_allocated_height()/2 + 13/2);
                    cr.show_text(dir);
                    i++;
                }
            }

            return true;
        }
    }
}

