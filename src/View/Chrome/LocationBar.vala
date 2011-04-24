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
                bread.change_breadcrumbs(new_path);
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
        /**
         * When the user use a double click, this signal is emited to ask the
         * parent to show the location bar.
         **/
        public signal void activate_entry();
        /**
         * When the user click on a breadcrumb, or when he enters a path by hand
         * in the integrated entry
         **/
        public signal void changed(string changed);

        string text = "";

        int selected = -1;
        string gtk_font_name;
        int space_breads = 12;
        int x;
        int y;
        int gtk_font_size;

        Gtk.Button button;
        BreadcrumbsEntry entry;
        
        /* This list will contain all BreadcrumbsElement */
        Gee.ArrayList<BreadcrumbsElement> elements;
        
        /* This list will contain the BreadcrumbsElement which are animated */
        Gee.List<BreadcrumbsElement> newbreads;

        string[] home;
        
        /* A flag to know when the animation is finished */
        int anim_state = 0;

        GOF.Directory.Async files;
        string to_search;
        
        bool view_old = false;
        
        double x_render_saved = 0;
        Cairo.ImageSurface home_img;
        
        new bool focus = false;

        public Breadcrumbs()
        {
            add_events(Gdk.EventMask.BUTTON_PRESS_MASK
                      | Gdk.EventMask.BUTTON_RELEASE_MASK
                      | Gdk.EventMask.KEY_PRESS_MASK
                      | Gdk.EventMask.KEY_RELEASE_MASK
                      | Gdk.EventMask.POINTER_MOTION_MASK
                      | Gdk.EventMask.LEAVE_NOTIFY_MASK);

            /* Loade default font */
            var gtk_settings = Gtk.Settings.get_for_screen (get_screen ());
            gtk_settings.get ("gtk-font-name", out gtk_font_name);
            var font = Pango.FontDescription.from_string (gtk_font_name);
            /* FIXME: This is hackish */
            gtk_font_size = (int)(int.parse(gtk_font_name.split(" ")[1]) * 1.3);

            gtk_font_name = font.get_family();

            /* FIXME: we should directly use a Gtk.StyleContext */
            button = new Gtk.Button();

            set_can_focus(true);

            /* x padding */
            x = 0;
            /* y padding */
            y = 6;
            
            elements = new Gee.ArrayList<BreadcrumbsElement>();

            entry = new BreadcrumbsEntry(gtk_font_name, gtk_font_size, button.get_style_context());

            entry.enter.connect(on_entry_enter);

            /* Let's connect the signals ;)
             * FIXME: there could be a separate function for eacg signal */
            entry.need_draw.connect(() => { queue_draw(); });

            entry.left.connect(() => {
                if(elements.size > 0)
                {
                    var element = elements[elements.size - 1];
                    elements.remove(element);
                    if(element.display)
                    {
                        entry.text = element.text + "/" + entry.text;
                        entry.cursor = element.text.length + 1;
                    }
                }
            });

            entry.left_full.connect(() => {
                string text_tmp = entry.text;
                entry.text = "";
                foreach(BreadcrumbsElement element in elements)
                {
                    if(element.display)
                    {
                        entry.text = entry.text + "/" + element.text;
                        entry.cursor = element.text.length + 1;
                    }
                }
                entry.text += text_tmp;
                elements.clear();
            });

            entry.backspace.connect(() => {
                if(elements.size > 0)
                {
                    var element = elements[elements.size - 1];
                    elements.remove(element);
                }
            });

            entry.need_completion.connect(() => {
                string path = "";
                foreach(BreadcrumbsElement element in elements)
                {
                    if(element.display)
                        path += element.text;
                }
                for(int i = 0; i < entry.text.split("/").length - 1; i++)
                {
                    path += "/" + entry.text.split("/")[i];
                }
                if(entry.text.split("/").length > 0)
                to_search = entry.text.split("/")[entry.text.split("/").length - 1];
                else
                to_search = "";
                print("%s\n", to_search);
                entry.completion = "";
                
                if(to_search.length > 0)
                {
                    var directory = File.new_for_path(path +"/");
                    files = new GOF.Directory.Async.from_gfile (directory);
                    if (files.load())
                        files.file_loaded.connect(on_file_loaded);
                    else
                        Idle.add ((SourceFunc) load_file_hash, Priority.DEFAULT_IDLE);
                }
            });

            entry.hide();
            
            home_img = new Cairo.ImageSurface.from_png(Config.PIXMAP_DIR + "/home.png");

            home = new string[2];
            home[0] = "home";
            home[1] = Environment.get_home_dir().split("/")[2];
        }

        private bool load_file_hash ()
        {
            foreach (var file in files.file_hash.get_values ()) {
                on_file_loaded ((GOF.File) file);
            }
            return false;
        }

        private void on_file_loaded(GOF.File file)
        {
            if(file.is_directory && file.name.slice(0, to_search.length) == to_search)
            {
                entry.completion = file.name.slice(to_search.length, file.name.length);
            }
        }

        public override bool button_press_event(Gdk.EventButton event)
        {
            if(event.type == Gdk.EventType.2BUTTON_PRESS)
            {
                activate_entry();
            }
            else
            {
                double x_previous = -10;
                double x = event.x;
                double x_render = 0;
                string newpath = "";
                bool found = false;
                foreach(BreadcrumbsElement element in elements)
                {
                    if(element.display)
                    {
                        x_render += element.text_width + space_breads;
                        newpath += element.text + "/";
                        if(x <= x_render + 5 && x > x_previous + 5)
                        {
                            selected = elements.index_of(element);
                            changed(newpath);
                            found = true;
                            break;
                        }
                        x_previous = x_render;
                    }
                }
                if(!found)
                {
                    grab_focus();
                    entry.show();
                }
            }
            if(focus)
            {
                event.x -= x_render_saved;
                entry.mouse_press_event(event, get_allocated_width() - x_render_saved);
            }
            return true;
        }

        public override bool button_release_event(Gdk.EventButton event)
        {
            if(focus)
            {
                event.x -= x_render_saved;
                entry.mouse_release_event(event);
            }
            return true;
        }

        private void on_entry_enter()
        {
            text = "";
            foreach(BreadcrumbsElement element in elements)
            {
                if(element.display)
                    text += element.text;
            }
            changed(text + "/" + entry.text + entry.completion);
            entry.reset();
        }

        public override bool key_press_event(Gdk.EventKey event)
        {
            entry.key_press_event(event);
            queue_draw();
            return true;
        }

        public override bool key_release_event(Gdk.EventKey event)
        {
            entry.key_release_event(event);
            queue_draw();
            return true;
        }

        /**
         * Change the Breadcrumbs content.
         *
         * This function will try to see if the new/old BreadcrumbsElement can
         * be animated.
         **/
        public void change_breadcrumbs(string newpath)
        {
            text = newpath;
            selected = -1;
            var breads = newpath.split("/");
            var newelements = new Gee.ArrayList<BreadcrumbsElement>();
            if(breads[0] == "")
                newelements.add(new BreadcrumbsElement("/", "Ubuntu", gtk_font_size));
            
            foreach(string dir in breads)
            {
                if(dir != "")
                newelements.add(new BreadcrumbsElement(dir, "Ubuntu", gtk_font_size));
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

            if(newelements.size > 2)
            if(newelements[1].text == home[0] && newelements[2].text == home[1])
            {
                newelements[2].set_icon(home_img);
                newelements[2].text = "/home/" + home[1] + "/";
                newelements[1].display = false;;
                newelements[0].display = false;
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
            entry.reset();
        }

        /* A threaded function to animate the old BreadcrumbsElement */
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

        /* A threaded function to animate the new BreadcrumbsElement */
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
                        if(element.display)
                        {
                            x_hl += element.text_width;
                            x_hl += space_breads;
                        }
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
                double first_stop = x_hl - 7*(height/2 - y)/(height/2 - height/3) + 5;
                cr.move_to(first_stop,
                           y);
                cr.line_to(x_hl + 3,
                           height/2);
                cr.line_to(first_stop,
                           height - y);
                if(selected > 0)
                    x_hl += elements[selected].text_width;
                else
                    x_hl = elements[selected].text_width + space_breads/2 + y;
                double second_stop = x_hl - 7*(height/2 - y)/(height/2 - height/3) + 5;
                cr.line_to(second_stop,
                           height - y);
                cr.line_to(x_hl + 3,
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
                if(element.display)
                {
                    x_render += element.text_width + space_breads;
                    if(x <= x_render + 5 && x > x_previous + 5)
                    {
                        selected = elements.index_of(element);
                        break;
                    }
                    x_previous = x_render;
                }
            }
            event.x -= x_render_saved;
            entry.mouse_motion_event(event, get_allocated_width() - x_render_saved);
            queue_draw();
            return true;
        }

        public override bool leave_notify_event(Gdk.EventCrossing event)
        {
            selected = -1;
            queue_draw();
            return false;
        }
        
        public override bool focus_out_event(Gdk.EventFocus event)
        {
            focus = false;
            entry.hide();
            return true;
        }
        
        public override bool focus_in_event(Gdk.EventFocus event)
        {
            focus = true;
            return true;
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
                if(element.display)
                {
                element.draw(cr, x_render, y, height);
                x_render += element.text_width + space_breads;
                }
                i++;
            }
            if(view_old)
            {
                foreach(BreadcrumbsElement element in newbreads)
                {
                    if(element.display)
                    {
                        element.draw(cr, x_render, y, height);
                        x_render += element.text_width + space_breads;
                    }
                }
            }

            draw_selection(cr);

            x_render_saved = x_render + space_breads/2;
            entry.draw(cr, x_render + space_breads/2, height, width - x_render);
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
        Cairo.ImageSurface icon;
        public bool display = true;
        public BreadcrumbsElement(string text_, string font_name_, int font_size_)
        {
            text = text_;
            font_name = font_name_;
            font_size = font_size_;
        }
        
        public void set_icon(Cairo.ImageSurface icon_)
        {
            icon = icon_;
        }
        
        private void computetext_width(Cairo.Context cr)
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
            if(text_width < 0 && icon == null)
            {
                computetext_width(cr);
            }
            else if(icon != null)
            {
                text_width = icon.get_width();
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
            
            if(icon == null)
            {
                cr.move_to(x - offset*5,
                           height/2 + font_size/2);
                cr.show_text(text);
            }
            else
            {
                cr.set_source_surface(icon, x - offset*5,
                           1.5*y);
                cr.paint();
                cr.set_source_rgba(0,0,0, 0.8);
            }
            cr.set_source_rgba(0,0,0,0.5);
            /* Draw the separator */
            cr.set_line_width(1);
            cr.move_to(x - offset*5 + text_width, y);
            cr.line_to(x - offset*5 + text_width + 10, height/2);
            cr.line_to(x - offset*5 + text_width, height - y);
            cr.stroke();
        }
    }
    
    class BreadcrumbsEntry : GLib.Object
    {
        IMContext im_context;
        public string text = "";
        internal int cursor = 0;
        string font_name;
        internal string completion = "";
        int font_size;
        uint timeout;
        bool blink = true;
        Gtk.StyleContext context;
        Cairo.ImageSurface arrow_img;
        Cairo.ImageSurface arrow_hover_img;
        
        double select = 0;
        int selected = 0;
        bool hover = false;
        new bool focus = false;
        
        public signal void enter();
        public signal void backspace();
        public signal void left();
        public signal void left_full();
        public signal void need_draw();
        public signal void need_completion();
        
        public BreadcrumbsEntry(string font_name, int font_size, Gtk.StyleContext context_)
        {
            im_context = new IMMulticontext();
            im_context.commit.connect(commit);
            this.font_name = font_name;
            this.font_size = font_size;
            context = context_;
            
            /* Load arrow image */
            arrow_img = new Cairo.ImageSurface.from_png(Config.PIXMAP_DIR + "/arrow.png");
            arrow_hover_img = new Cairo.ImageSurface.from_png(Config.PIXMAP_DIR + "/arrow_hover.png");
        }
        
        public void show()
        {
            focus = true;
            if (timeout > 0)
                Source.remove(timeout);
            timeout = Timeout.add(700, () => {blink = !blink;  need_draw(); return true;});
        }
        
        private void commit(string character)
        {
            text = text.slice(0,cursor) + character + text.slice(cursor, text.length);
            cursor ++;
            need_completion();
            //print("%s, %d\n", text, cursor);
        }
        
        public void key_press_event(Gdk.EventKey event)
        {
            switch(event.keyval)
            {
            case 0xff51: /* left */
                if(cursor > 0 && ! ((event.state & Gdk.ModifierType.CONTROL_MASK) == 4))
                    cursor --; /* No control pressed, the cursor is not at the begin */
                else if( cursor == 0 && (event.state & Gdk.ModifierType.CONTROL_MASK) == 4)
                    left_full(); /* Control pressed, the cursor is at the begin */
                else if((event.state & Gdk.ModifierType.CONTROL_MASK) == 4) cursor = 0;
                else left();
                break;
            case 0xff53: /* right */
                if(cursor < text.length) cursor ++;
                else
                {
                    text += completion + "/";
                    cursor += completion.length + 1;
                    completion = "";
                }
                break;
            case 0xff0d: /* enter */
                enter();
                break;
            case 0xff08: /* backspace */
                if(cursor > 0)
                {
                    text = text.slice(0,cursor - 1) + text.slice(cursor, text.length);
                    cursor --;
                }
                else
                {
                    backspace();
                }
                need_completion();
                break;
            case 0xffff: /* delete */
                if(cursor < text.length && !((event.state & Gdk.ModifierType.CONTROL_MASK) == 4))
                {
                    text = text.slice(0,cursor) + text.slice(cursor + 1, text.length);
                }
                else if(cursor < text.length)
                    text = text.slice(0,cursor);
                need_completion();
                break;
            default:
                im_context.filter_keypress(event);
                break;
            }
            //print("%x\n", event.keyval);
        }
        
        public void key_release_event(Gdk.EventKey event)
        {
            im_context.filter_keypress(event);
        }
        
        public void mouse_motion_event(Gdk.EventMotion event, double width)
        {
            hover = false;
            if(event.x < width && event.x > width - arrow_img.get_width())
                hover = true;
        }
        
        public void mouse_press_event(Gdk.EventButton event, double width)
        {
            select = event.x;
            if(event.x < width && event.x > width - arrow_img.get_width())
                enter();
        }
        
        public void mouse_release_event(Gdk.EventButton event)
        {
        }
        
        public void draw(Cairo.Context cr, double x, double height, double width)
        {
            cr.select_font_face(font_name, Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(font_size);
            cr.set_source_rgba(0,0,0,0.8);
            selected = 0;

            cr.set_source_rgba(0,0,0,0.8);
            
            
            cr.move_to(x, height/2 + font_size/2);
            cr.show_text(text);

            Cairo.TextExtents txt = Cairo.TextExtents();
            if(select > 0)
            {
                cursor = text.length;
                for(int i = 0; i < text.length; i++)
                {
                    cr.text_extents(text.slice(0, i), out txt);
                    if(txt.x_advance > select)
                    {
                        cursor = i;
                        break;
                    }
                    txt.x_advance = 0;
                }
                select = -1;
            }
            cr.text_extents(text.slice(0, cursor), out txt);
            if(blink && focus)
            {
                cr.move_to(x + txt.x_advance, height/4);
                cr.line_to(x + txt.x_advance, height/2 + height/4);
                cr.stroke();
            }
            if(text != "")
            {
                if(hover)
                    cr.set_source_surface(arrow_hover_img,
                                          x + width - arrow_hover_img.get_width() - 10,
                                          height/2 - arrow_hover_img.get_height()/2);
                else
                    cr.set_source_surface(arrow_img,
                                          x + width - arrow_img.get_width() - 10,
                                          height/2 - arrow_img.get_height()/2);
                cr.paint();
            }
            cr.text_extents(text, out txt);
            cr.set_source_rgba(0,0,0,0.5);
            cr.move_to(x + txt.x_advance, height/2 + font_size/2);
            cr.show_text(completion);
        }
        
        public void reset()
        {
            text = "";
            cursor = 0;
            completion = "";
        }
        
        public void hide()
        {
            focus = false;
            if (timeout > 0)
                Source.remove(timeout);
        }
        
        ~BreadcrumbsEntry()
        {
            hide();
        }
    }
}

