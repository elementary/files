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
        Gee.ArrayList<int> list;
        int selected = -1;
        string gtk_font_name;
        int space_breads = 12;
        int x;
        int y;

        Cairo.ImageSurface home_img;
        Gtk.Button button;
        
        public Breadcrumbs()
        {
            add_events(Gdk.EventMask.BUTTON_PRESS_MASK
                      | Gdk.EventMask.BUTTON_RELEASE_MASK
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

            /* x padding */
            x = 0;
            /* y padding */
            y = 6;
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
                int x_previous = -10;
                int x = (int)event.x;
                foreach(int x_render in list)
                {
                    if(x <= x_render + 5 && x > x_previous + 5)
                    {
                        int to_keep = list.index_of(x_render);

                        var text_tmp = text.split("/");
                        string text_ = "";
                        if(is_in_home(text_tmp))
                        {
                            to_keep += 2;
                        }
                        for(int i = 0; i <= to_keep; i++)
                        {
                            text_ += text_tmp[i] + "/";
                        }

                        /*save_old_breads(text_tmp, to_keep);

                        animate_old_breads();*/

                        changed(text_);
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
            var old_path = text.split("/");
            var new_path = newpath.split("/");
            int max_path = 0;
            bool different_path = false;
            if(old_path.length >= new_path.length && text != "/")
            {
                max_path = new_path.length;
                if(new_path[max_path - 1] == "")
                    max_path --;
            }
            else
            {
                max_path = old_path.length;
                if(text == "/")
                    max_path --;
            }
            
            for(int i = 0; i < max_path; i++)
            {
                if(old_path[i] != new_path[i])
                {
                    different_path = true;
                    text = newpath;
                    queue_draw();
                    break;
                }
            }
            if(!different_path)
            {
                if(old_path.length > new_path.length || (old_path.length == new_path.length && newpath == "/"))
                {
                    save_old_breads(old_path, max_path - 1);
                    text = newpath;
                    animate_old_breads();
                }
                else
                {
                    text = newpath;
                    new_text_index = 0;
                    foreach(string dir in old_path)
                    {
                        if(dir != "") new_text_index ++;
                    }
                    animate_new_breads();
                }
            }
        }

        private void save_old_breads(string[] text_tmp, int to_keep)
        {
            old_text = new string[text_tmp.length - to_keep - 1];
            for(int i = 0; i < old_text.length; i++)
            {
                old_text[i] = text_tmp[i + to_keep + 1];
            }
        }

        private void animate_old_breads()
        {
            anim_state = 10;
            Timeout.add(1000/60, () => {
                anim_state--;
                queue_draw();
                if(anim_state <= 0)
                {
                    old_text = new string[0];
                    queue_draw();
                    return false;
                }
                return true;
            } );
        }

        private void animate_new_breads()
        {
            anim_state = 0;
            Timeout.add(1000/60, () => {
                anim_state++;
                queue_draw();
                if(anim_state >= 10)
                {
                    new_text_index = -1;
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
                int x_hl;
                if(selected == 0)
                    x_hl = -10;
                else
                    x_hl = list[selected - 1] + 5;
                double first_stop = x_hl - 7*(height/2 - y)/(height/2 - height/3) + 7;
                cr.move_to(first_stop,
                           y);
                cr.line_to(x_hl + 5,
                           height/2);
                cr.line_to(first_stop,
                           height - y);
                x_hl = list[selected] + 7;
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

        public override bool leave_notify_event(Gdk.EventCrossing event)
        {
            selected = -1;
            queue_draw();
            return false;
        }

        private void populate_list_draw_separators(Cairo.Context cr, string[] dirs)
        {
            double height = get_allocated_height();
            double width = get_allocated_width();
            /* It is increased when we draw each directory name to put the
             * separators at the good place */
            double x_render = 0;
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
            
            /* Compute text width */

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

            foreach(string dir in old_text)
            {
                if(dir != "")
                {
                    cr.text_extents(dir + "   ", out txt);
                    x_render += txt.x_advance + space_breads;
                    list.add((int)x_render);
                }
            }
        }

        public override bool draw(Cairo.Context cr)
        {
            double height = get_allocated_height();
            double width = get_allocated_width();

            /* Draw toolbar background */

            /* the height +1 is here to fix an adwaita bug, we will have to
             * remove it, FIXME */
            Gtk.render_background(get_style_context(), cr, 0, 0, get_allocated_width(), get_allocated_height()+1);
            Gtk.render_background(button.get_style_context(), cr, 0, 6, get_allocated_width(), get_allocated_height() - 12);
            Gtk.render_frame(button.get_style_context(), cr, 0, 6, get_allocated_width(), get_allocated_height() - 12);

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
            
            populate_list_draw_separators(cr, dirs);
            
            draw_selection(cr);

            cr.restore();
            cr.save();
            cr.set_source_rgb(0,0,0);

            /* The path itself, e.g.  /   home */

            /* Remove all "/" and replace them with some space. We will keep the
             * first / since it shows the root path. */
            dirs = text.split("/");
            bool in_home = false;

            if(!is_in_home(dirs))
            {
                cr.move_to(10, get_allocated_height()/2 + 13/2);
                cr.show_text("/");
            }
            else
            {
                in_home = true;
                cr.translate(5, 1.75*y);
                cr.scale((height - 3.5*y)/home_img.get_height(),
                         (height - 3.5*y)/home_img.get_height());
                cr.set_source_surface(home_img, 0, 0);
                cr.paint();
                cr.restore();
                cr.save();
                dirs = (text.replace(Environment.get_home_dir(), "") + "/").split("/");
            }

            int i = draw_breads(cr, dirs, in_home);

            draw_old_animation(cr, i);

            return true;
        }

        private void get_mask(Cairo.Context cr, int i)
        {
            int x_hl;
            double height = get_allocated_height();
            double width = get_allocated_width();
            if(i < list.size)
                x_hl = list[i] + 7;
            else
                x_hl = 7;
            double second_stop = x_hl - 7*(height/2 - y)/(height/2 - height/3) + 7;
            cr.move_to(second_stop,
                       height - y);
            cr.line_to(x_hl + 5,
                       height/2);
            cr.line_to(second_stop,
                       y);
            cr.line_to(width, y);
            cr.line_to(width, height);
            cr.close_path();
            cr.clip();
        }

        private void draw_old_animation(Cairo.Context cr, int i)
        {
            get_mask(cr, i);
            cr.set_source_rgba(0,0,0,(double)anim_state/10.0);

            foreach(string dir in old_text)
            {
                if(dir != "")
                {
                    int old_x;
                    if(i == 0)
                        old_x = -10;
                    else
                        old_x = list[i - 1];
                    cr.move_to(15 + list[i] - list[i] + old_x + (double)anim_state/10.0*(list[i] - old_x),
                               get_allocated_height()/2 + 13/2);
                    cr.show_text(dir);
                    i++;
                }
            }
        }

        private int draw_breads(Cairo.Context cr, string[] dirs, bool in_home)
        {
            int i = 0;
            foreach(string dir in dirs)
            {
                /* Don't add too much dir, e.g. in "/home///", we would get five
                 * dirs, and we only need three. */ 
                if(dir != "")
                {
                    if((new_text_index != -1 && i >= new_text_index) || (in_home && new_text_index != -1 && i + 2 >= new_text_index))
                    {
                        get_mask(cr, i);
                        int old_x;
                        if(i == 0)
                            old_x = -10;
                        else
                            old_x = list[i - 1];
                        cr.set_source_rgba(0,0,0,(double)anim_state/10.0);
                        cr.move_to(15 + list[i] - list[i] + old_x + (double)anim_state/10.0*(list[i] - old_x),
                                   get_allocated_height()/2 + 13/2);
                        cr.show_text(dir);
                    }
                    else
                    {
                        cr.move_to(15 + list[i],
                                   get_allocated_height()/2 + 13/2);
                        cr.show_text(dir);
                    }
                    i++;
                }
            }
            return i;
        }
    }
}

