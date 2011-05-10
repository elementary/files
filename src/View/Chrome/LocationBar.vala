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
        public Window win;
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

        public LocationBar (Window window)
        {
            win = window;
            entry = new Entry ();
            bread = new Breadcrumbs(window);

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
                border_width = 0;
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

    public class Breadcrumbs : Gtk.EventBox
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
        string protocol = "";

        Gtk.StyleContext button_context;
        Gtk.StyleContext entry_context;
        BreadcrumbsEntry entry;

        private UIManager ui;
        public Gtk.ActionGroup clipboard_actions;
        
        /* This list will contain all BreadcrumbsElement */
        Gee.ArrayList<BreadcrumbsElement> elements;
        
        /* This list will contain the BreadcrumbsElement which are animated */
        Gee.List<BreadcrumbsElement> newbreads;

        string[] home;
        
        /* A flag to know when the animation is finished */
        int anim_state = 0;

        /* Used for auto-copmpletion */
        GOF.Directory.Async files;
        /* The string which contains the text we search in the file. e.g, if the
         * user enter /home/user/a, we will search for "a". */
        string to_search;

        /* Used for the context menu we show when there is a right click */
        GOF.Directory.Async files_menu;
        Menu menu;
        string current_right_click_root;
        double right_click_root;

        /* if we must display the BreadcrumbsElement which are in  newbreads. */
        bool view_old = false;

        /* Used to decide if this button press event must be send to the
         * integrated entry or not. */
        double x_render_saved = 0;

        /* The custom icons
         * FIXME: they shouldn't be hardcoded. */
        Gdk.Pixbuf home_img;
        Gdk.Pixbuf trash_img;
        Gdk.Pixbuf network_img;

        /* if we have the focus or not
         * FIXME: this should be replaced with some nice Gtk.Widget method. */
        new bool focus = false;
        
        private int timeout = -1;

        public Breadcrumbs(Window window)
        {
            add_events(Gdk.EventMask.BUTTON_PRESS_MASK
                      | Gdk.EventMask.BUTTON_RELEASE_MASK
                      | Gdk.EventMask.KEY_PRESS_MASK
                      | Gdk.EventMask.KEY_RELEASE_MASK
                      | Gdk.EventMask.POINTER_MOTION_MASK
                      | Gdk.EventMask.LEAVE_NOTIFY_MASK);

            /* grab the UIManager */
            ui = window.ui;
            init_clipboard ();

            /* Loade default font */
            var gtk_settings = Gtk.Settings.get_for_screen (get_screen ());
            gtk_settings.get ("gtk-font-name", out gtk_font_name);
            var font = Pango.FontDescription.from_string (gtk_font_name);
            /* FIXME: This is hackish */
            gtk_font_size = (int)(int.parse(gtk_font_name.split(" ")[1]) * 1.3);

            gtk_font_name = font.get_family();

            button_context = new Gtk.Button().get_style_context();
            entry_context = new Gtk.Entry().get_style_context();

            set_can_focus(true);
            set_visible_window (false);

            /* x padding */
            x = 0;
            /* y padding */
            y = 6;
            
            elements = new Gee.ArrayList<BreadcrumbsElement>();

            entry = new BreadcrumbsEntry(gtk_font_name, gtk_font_size, button_context);

            entry.enter.connect(on_entry_enter);

            /* Let's connect the signals ;)
             * FIXME: there could be a separate function for each signal */
            entry.need_draw.connect(() => { queue_draw(); });

            entry.left.connect(() => {
                if(elements.size > 0)
                {
                    var element = elements[elements.size - 1];
                    elements.remove(element);
                    if(element.display)
                    {
                        if(entry.text[0] != '/')
                        {
                            entry.text = element.text + "/" + entry.text;
                            entry.cursor = element.text.length + 1;
                        }
                        else
                        {
                            entry.text = element.text + entry.text;
                            entry.cursor = element.text.length;
                        }
                    }
                }
            });

            entry.left_full.connect(() => {
                string tmp = entry.text;
                entry.text = "";
                foreach(BreadcrumbsElement element in elements)
                {
                    if(element.display)
                    {
                        if(entry.text[0] != '/')
                        {
                            entry.text += element.text + "/";
                        }
                        else
                        {
                            entry.text += element.text;
                        }
                    }
                }
                entry.text += tmp;
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
                        path += element.text + "/"; /* sometimes, + "/" is useless
                                                     * but we are never careful enough */
                }
                path = Marlin.Utils.get_parent(path + "/" +  entry.text);
                if(entry.text.split("/").length > 0)
                    to_search = entry.text.split("/")[entry.text.split("/").length - 1];
                else
                    to_search = "";
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
            
            entry.paste.connect( () => {
                var display = get_display();
                Gdk.Atom atom = Gdk.SELECTION_CLIPBOARD;
                Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display(display,atom);
                clipboard.request_text(request_text);
            });

            entry.hide();
            
            /* Load custom icons */
            try {
                home_img = IconTheme.get_default ().load_icon ("go-home-symbolic", 16, 0);
            } catch (Error err) {
                try {
                    home_img = IconTheme.get_default ().load_icon ("go-home", 16, 0);
                } catch (Error err) {
                    stderr.printf ("Unable to load home icon: %s", err.message);
                }
            }
            try {
                trash_img = IconTheme.get_default ().load_icon ("user-trash", 16, 0);
            } catch (Error err) {
                stderr.printf ("Unable to load home icon: %s", err.message);
            }
            try {
                network_img = IconTheme.get_default ().load_icon ("network", 16, 0);
            } catch (Error err) {
                stderr.printf ("Unable to load home icon: %s", err.message);
            }

            /* FIXME: This won't work if the user dir is not in /home/ */
            home = new string[2];
            home[0] = "home";
            home[1] = Environment.get_home_dir().split("/")[2];
            menu = new Menu();
            menu.show_all();
        }

        private void action_paste()
        {
            if(focus)
            {
                var display = get_display();
                Gdk.Atom atom = Gdk.SELECTION_CLIPBOARD;
                Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display(display,atom);
                clipboard.request_text(request_text);
            }
        }

        private void action_copy()
        {
            if(focus)
            {
                var display = get_display();
                Gdk.Atom atom = Gdk.SELECTION_CLIPBOARD;
                Gtk.Clipboard clipboard = Gtk.Clipboard.get_for_display(display,atom);
                clipboard.set_text(entry.get_selection(), entry.get_selection().length);
            }
        }
        
        private void action_cut()
        {
            //TODO check
            if(focus)
            {
                action_copy();
                entry.delete_selection();
            }
        }

        /**
         * Load the file list for auto-completion.
         **/
        private bool load_file_hash ()
        {
            foreach (var file in files.file_hash.get_values())
            {
                on_file_loaded ((GOF.File) file);
            }
            return false;
        }

        /**
         * This function can be called by load_file_hash or it is used as a
         * callback for files.file_loaded. We check that the file can be used
         * in auto-completion, if yes we put it in our entry.
         *
         * @param file The file you want to load
         *
         **/
        private void on_file_loaded(GOF.File file)
        {
            if(file.is_directory && file.name.slice(0, to_search.length) == to_search)
            {
                entry.completion = file.name.slice(to_search.length, file.name.length);
            }
        }

        private bool load_file_hash_menu ()
        {
            foreach (var file in files_menu.file_hash.get_values ()) {
                on_file_loaded_menu ((GOF.File) file);
            }
            return false;
        }

        private void on_file_loaded_menu(GOF.File file)
        {
            if(file.is_directory)
            {
                var menuitem = new Gtk.MenuItem.with_label(file.name);
                menu.append(menuitem);
                menuitem.activate.connect(() => {
                    changed(current_right_click_root + "/" + ((MenuItem)menu.get_active()).get_label()); });
                menu.show_all();
            }
        }

        /**
         * Select the breadcrumb to make a right click. This function check
         * where the user click, then, it loads a context menu with the others
         * directory in it parent.
         * See load_right_click_menu() for the context menu.
         *
         * @param x where the user click along the x axis
         * @param event a button event to compute the coords of the new menu.
         *
         **/
        private bool select_bread_from_coord(double x, Gdk.EventButton event)
        {
            double x_previous = -10;
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
                        right_click_root = x_previous;

                        if(Marlin.Utils.has_parent(newpath))
                        {
                            /* Compute the coords of the menu, to show it at the
                             * bottom of our pathbar. */
                            if(x_previous < 0)
                                x_previous = 0;
                            menu_x_root = event.x_root - event.x + x_previous;
                            menu_y_root = event.y_root + get_allocated_height() - event.y - 5;
                            /* Let's remove the last directory since we only want the parent */
                            current_right_click_root = Marlin.Utils.get_parent(newpath);

                            load_right_click_menu();
                        }
                        found = true;

                        break;
                    }
                    x_previous = x_render;
                }
            }
            return found;
        }

        private void load_right_click_menu()
        {
            menu = new Menu();
            var directory = File.new_for_path(current_right_click_root +"/");
            files_menu = new GOF.Directory.Async.from_gfile (directory);
            if (files_menu.load())
                files_menu.file_loaded.connect(on_file_loaded_menu);
            else
                Idle.add ((SourceFunc) load_file_hash_menu, Priority.DEFAULT_IDLE);

            menu.popup (null,
                        null,
                        get_menu_position,
                        0,
                        Gtk.get_current_event_time());
        }

        public override bool button_press_event(Gdk.EventButton event)
        {
            if(timeout == -1 && event.button == 1){
                timeout = (int) Timeout.add(800, () => {
                    select_bread_from_coord(event.x, event);
                    timeout = -1;
                    return false;
                });
            }

            if(event.type == Gdk.EventType.2BUTTON_PRESS)
            {
                activate_entry();
            }
            else if(event.button == 3)
            {
                return select_bread_from_coord(event.x, event);
            }
            if(focus)
            {
                event.x -= x_render_saved;
                entry.mouse_press_event(event, get_allocated_width() - x_render_saved);
            }
            return true;
        }
        
        double menu_x_root;
        double menu_y_root;
        
        private void get_menu_position (Menu menu, out int x, out int y, out bool push_in)
        {
            x = (int)menu_x_root;
            y = (int)menu_y_root;
        }

        public override bool button_release_event(Gdk.EventButton event)
        {
            if(timeout != -1){
                Source.remove((uint) timeout);
                timeout = -1;
            }
            if(event.button == 1)
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
                    text += element.text + "/";
            }
            if(text != "")
                changed(text + "/" + entry.text + entry.completion);
            else
                changed(entry.text + entry.completion);
                
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
            var explode_protocol = newpath.split("://");
            if(explode_protocol.length > 1)
            {
                protocol = explode_protocol[0] + "://";
                text = explode_protocol[1];
            }
            else
            {
                text = newpath;
                protocol = "";
            }
            selected = -1;
            var breads = text.split("/");
            var newelements = new Gee.ArrayList<BreadcrumbsElement>();
            if(breads[0] == "")
                newelements.add(new BreadcrumbsElement("/", gtk_font_name, gtk_font_size));
            
            foreach(string dir in breads)
            {
                if(dir != "")
                newelements.add(new BreadcrumbsElement(dir, gtk_font_name, gtk_font_size));
            }
            
            newelements[0].text = protocol + newelements[0].text;
            
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
                newelements[2].text = "/home/" + home[1];
                newelements[1].display = false;;
                newelements[0].display = false;
            }
            
            switch(protocol)
            {
            case "trash://":
                newelements[0].set_icon(trash_img);
                break;
            case "network://":
                newelements[0].set_icon(network_img);
                break;
            default:
                break;
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
            foreach(BreadcrumbsElement bread in newbreads)
            {
                bread.offset = anim_state;
            }
            Timeout.add(1000/60, () => {
                anim_state++;
                /* FIXME: Instead of this hacksih if( != null), we should use a
                 * nice mutex */
                if(newbreads != null)
                {
                    foreach(BreadcrumbsElement bread in newbreads)
                    {
                        bread.offset = anim_state;
                    }
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
            foreach(BreadcrumbsElement bread in newbreads)
            {
                bread.offset = anim_state;
            }
            Timeout.add(1000/60, () => {
                anim_state--;
                /* FIXME: Instead of this hacksih if( != null), we should use a
                 * nice mutex */
                if(newbreads != null)
                {
                    foreach(BreadcrumbsElement bread in newbreads)
                    {
                        bread.offset = anim_state;
                    }
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
                button_context.get_background_color(Gtk.StateFlags.SELECTED, color);
                
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
            set_tooltip_text("");
            foreach(BreadcrumbsElement element in elements)
            {
                if(element.display)
                {
                    x_render += element.text_width + space_breads;
                    if(x <= x_render + 5 && x > x_previous + 5)
                    {
                        selected = elements.index_of(element);
                        set_tooltip_text(_("Go to %s").printf(element.text));
                        break;
                    }
                    x_previous = x_render;
                }
            }
            event.x -= x_render_saved;
            entry.mouse_motion_event(event, get_allocated_width() - x_render_saved);
            if(event.x > 0)
            {
                get_window().set_cursor(new Gdk.Cursor(Gdk.CursorType.XTERM));
            }
            else
            {
                get_window().set_cursor(null);
            }
            queue_draw();
            return true;
        }

        public override bool leave_notify_event(Gdk.EventCrossing event)
        {
            selected = -1;
            queue_draw();
            get_window().set_cursor(null);
            return false;
        }
        
        public override bool focus_out_event(Gdk.EventFocus event)
        {
            focus = false;
            entry.hide();
            merge_out_clipboard_actions ();
            return true;
        }
        
        public override bool focus_in_event(Gdk.EventFocus event)
        {
            focus = true;
            merge_in_clipboard_actions ();
            return true;
        }
        
        private void request_text(Gtk.Clipboard clip, string? text)
        {
            if(text != null)
                entry.insert(text);
        }

        public override bool draw(Cairo.Context cr)
        {
            double height = get_allocated_height();
            double width = get_allocated_width();
            double margin = 6;

            /* Draw toolbar background */
            if(focus)
            {
                Gtk.render_background(entry_context, cr, 0, margin, width, height - margin*2);
                Gtk.render_frame(entry_context, cr, 0, margin, width, height - margin*2);
            }
            else
            {
                Gtk.render_background(button_context, cr, 0, margin, width, height-margin*2);
                Gtk.render_frame(button_context, cr, 0, margin, width, height-margin*2);
            }

            double x_render = y;
            int i = 0;

            foreach(BreadcrumbsElement element in elements)
            {
                if(element.display)
                {
                    element.draw(cr, x_render, margin, height-margin*2, button_context, this);
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
                        element.draw(cr, x_render, margin, height - margin*2, button_context, this);
                        x_render += element.text_width + space_breads;
                    }
                }
            }

            draw_selection(cr);

            x_render_saved = x_render + space_breads/2;
            entry.draw(cr, x_render + space_breads/2, height, width - x_render, this, button_context);
            return false;
        }

        private void init_clipboard ()
        {
            clipboard_actions = new Gtk.ActionGroup ("ClipboardActions");
            clipboard_actions.add_actions (action_entries, this);
        }

        private void merge_in_clipboard_actions ()
        {
            ui.insert_action_group (clipboard_actions, 0);
            ui.ensure_update ();        
        }

        private void merge_out_clipboard_actions ()
        {
            ui.remove_action_group (clipboard_actions);
            ui.ensure_update ();        
        }

        static const Gtk.ActionEntry[] action_entries = {
  /* name, stock id */         { "Cut", Stock.CUT,
  /* label, accelerator */       null, null,
  /* tooltip */                  N_("Cut the selected text to the clipboard"),
                                 action_cut },
  /* name, stock id */         { "Copy", Stock.COPY,
  /* label, accelerator */       null, null,
  /* tooltip */                 N_("Copy the selected text to the clipboard"),
                                action_copy },
  /* name, stock id */        { "Paste", Stock.PASTE,
  /* label, accelerator */      null, null,
  /* tooltip */                 N_("Paste the text stored on the clipboard"),
                                action_paste }
         };

        /* TESTS */
        public int tests_get_elements_size()
        {
            int i = 0;
            foreach(BreadcrumbsElement element in elements)
            {
                if(element.display)
                    i++;
            }
            return i;
        }
    }
    
    class BreadcrumbsElement : GLib.Object
    {
        public string text;
        string font_name;
        int font_size;
        public int offset = 0;
        public double text_width = -1;
        public double text_height = -1;
        Gdk.Pixbuf icon;
        public bool display = true;
        public BreadcrumbsElement(string text_, string font_name_, int font_size_)
        {
            text = text_;
            font_name = font_name_;
            font_size = font_size_;
        }
        
        public void set_icon(Gdk.Pixbuf icon_)
        {
            icon = icon_;
        }
        
        private void computetext_width(Pango.Layout pango)
        {
            int text_width, text_height;
            pango.get_size(out text_width, out text_height);
            this.text_width = Pango.units_to_double(text_width);
            this.text_height = Pango.units_to_double(text_height);
        }
        
        public void draw(Cairo.Context cr, double x, double y, double height, Gtk.StyleContext button_context, Gtk.Widget widget)
        {
            cr.set_source_rgb(0,0,0);
            cr.select_font_face(font_name, Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(font_size);
            Pango.Layout layout = widget.create_pango_layout(text);
            if(text_width < 0 && icon == null)
            {
                computetext_width(layout);
            }
            else if(icon != null)
            {
                text_width = icon.get_width();
            }
            
            if(offset != 0)
            {
                cr.move_to(x, y);
                cr.line_to(x + 5, y + height/2);
                cr.line_to(x, y + height);
                cr.line_to(x + text_width + 5, y+ height);
                cr.line_to(x + text_width + 10 + 5, y+height/2);
                cr.line_to(x + text_width + 5, y);
                cr.close_path();
                cr.clip();
            }
            
            if(icon == null)
            {
                /*Gtk.render_layout(button_context, cr, x - offset*5,
                            y + height/2 - text_height/2, layout);*/
                Gdk.RGBA color = Gdk.RGBA();
                button_context.get_color(Gtk.StateFlags.NORMAL, color);
                cr.set_source_rgba(color.red, color.green, color.blue, color.alpha);
                cr.move_to(x - offset*5,
                            y + height/2 - text_height/2);
                Pango.cairo_show_layout(cr, layout);
                //print("%s\n", layout.get_markup());
            }
            else
            {
                Gdk.cairo_set_source_pixbuf(cr, icon, x - offset*5,
                           y + height/2 - icon.get_height()/2);
                cr.paint();
            }
            cr.save();
            cr.set_source_rgba(0,0,0,0.5);
            /* Draw the separator */
            cr.translate(x  - offset*5 + text_width - height/4, y + height/2);
            cr.rectangle(0, -height/2 + 2, height, height - 4);
            cr.clip();
            cr.rotate(Math.PI/4);
            Gtk.render_frame(button_context, cr, -height/2, -height/2, Math.sqrt(height*height), Math.sqrt(height*height));
            cr.restore();
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
        Gdk.Pixbuf arrow_img;
        
        double selection_mouse_start = -1;
        double selection_mouse_end = -1;
        double selection_start = 0;
        double selection_end = 0;
        int selected_start = 0;
        int selected_end = 0;
        bool hover = false;
        new bool focus = false;
        
        bool is_selecting = false;
        
        public signal void enter();
        public signal void backspace();
        public signal void left();
        public signal void left_full();
        public signal void need_draw();
        public signal void paste();
        public signal void need_completion();
        
        public BreadcrumbsEntry(string font_name, int font_size, Gtk.StyleContext context_)
        {
            im_context = new IMMulticontext();
            im_context.commit.connect(commit);
            this.font_name = font_name;
            this.font_size = font_size;
            context = context_;
            
            /* Load arrow image */
            try {
                arrow_img = IconTheme.get_default ().load_icon ("go-jump-symbolic", 16, 0);
            } catch (Error err) {
                try {
                    arrow_img = IconTheme.get_default ().load_icon ("go-jump", 16, 0);
                } catch (Error err) {
                    stderr.printf ("Unable to load home icon: %s", err.message);
                }
            }
        }
        
        public void show()
        {
            focus = true;
            if (timeout > 0)
                Source.remove(timeout);
            timeout = Timeout.add(700, () => {blink = !blink;  need_draw(); return true;});
        }

        public void delete_selection()
        {
            int first = selected_start > selected_end ? selected_end : selected_start;
            int second = selected_start > selected_end ? selected_start : selected_end;

            text = text.slice(0, first) + text.slice(second, text.length);
            reset_selection();
            cursor = first;
        }
        
        public void insert(string to_insert)
        {
            int first = selected_start > selected_end ? selected_end : selected_start;
            int second = selected_start > selected_end ? selected_start : selected_end;
            if(first != second)
            {
                text = text.slice(0, first) + to_insert + text.slice(second, text.length);
                selected_start = 0;
                selected_end = 0;
                selection_start = 0;
                selection_end = 0;
                cursor = first + to_insert.length;
            }
            else
            {
                text = text.slice(0,cursor) + to_insert + text.slice(cursor, text.length);
                cursor += to_insert.length;
            }
            need_completion();
        }
        
        private void commit(string character)
        {
            insert(character);
        }
        
        public void key_press_event(Gdk.EventKey event)
        {
            /* FIXME: I can't find the vapi to not use hardcoded key value. */
            switch(event.keyval)
            {
            case 0xff51: /* left */
                if(cursor > 0 && ! ((event.state & Gdk.ModifierType.CONTROL_MASK) == 4))
                {
                    cursor --; /* No control pressed, the cursor is not at the begin */
                    reset_selection();
                }
                else if( cursor == 0 && (event.state & Gdk.ModifierType.CONTROL_MASK) == 4)
                    left_full(); /* Control pressed, the cursor is at the begin */
                else if((event.state & Gdk.ModifierType.CONTROL_MASK) == 4) cursor = 0;
                else left();
                break;
            case 0xff53: /* right */
                if(cursor < text.length)
                {
                    cursor ++;
                    reset_selection();
                }
                else if(completion != "")
                {
                    text += completion + "/";
                    cursor += completion.length + 1;
                    completion = "";
                }
                break;
            case 0xff0d: /* enter */
                reset_selection();
                enter();
                break;
            case 0xff08: /* backspace */
                if(get_selection() != "")
                {
                    delete_selection();
                }
                else if(cursor > 0)
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
                if(get_selection() == "" && cursor < text.length && !((event.state & Gdk.ModifierType.CONTROL_MASK) == 4))
                {
                    text = text.slice(0,cursor) + text.slice(cursor + 1, text.length);
                }
                else if(get_selection() != "")
                {
                    delete_selection();
                }
                else if(cursor < text.length)
                    text = text.slice(0,cursor);
                need_completion();
                break;
            case 0xff09: /* tab */
                reset_selection();
                if(completion != "")
                {
                    text += completion + "/";
                    cursor += completion.length + 1;
                    completion = "";
                }
                break;
            default:
                im_context.filter_keypress(event);
                break;
            }
            blink = true;
            //print("%x\n", event.keyval);
        }
        
        public string get_selection()
        {
            int first = selected_start > selected_end ? selected_end : selected_start;
            int second = selected_start > selected_end ? selected_start : selected_end;
            return text.slice(first,second);
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
            if(is_selecting)
            {
                selection_mouse_end = event.x;
            }
        }
        
        public void mouse_press_event(Gdk.EventButton event, double width)
        {
            reset_selection();
            blink = true;
            if(event.x < width && event.x > width - arrow_img.get_width())
                enter();
            else if(event.x >= 0)
            {
                is_selecting = true;
                selection_mouse_start = event.x;
                selection_mouse_end = event.x;
            }
            else if(event.x >= -20)
            {
                is_selecting = true;
                selection_mouse_start = 0;
                selection_mouse_end = 0;
            }
            need_draw();
        }
        
        public void mouse_release_event(Gdk.EventButton event)
        {
            selection_mouse_end = event.x;
            is_selecting = false;
        }
        
        private void reset_selection()
        {
            selected_start = 0;
            selected_end = 0;
            selection_start = 0;
            selection_end = 0;
        }
        
        private void update_selection(Cairo.Context cr, Widget widget)
        {
            double last_diff = double.MAX;
            Pango.Layout layout = widget.create_pango_layout(text);
            if(selection_mouse_start > 0)
            {
                selected_start = 0;
                selection_start = 0;
                cursor = text.length;
                for(int i = 0; i <= text.length; i++)
                {
                    layout.set_text(text.slice(0, i), -1);
                    if(Math.fabs(selection_mouse_start - get_width(layout)) < last_diff)
                    {
                        last_diff = Math.fabs(selection_mouse_start - get_width(layout));
                        selection_start = get_width(layout);
                        selected_start = i;
                    }
                }
                selection_mouse_start = -1;
            }

            if(selection_mouse_end > 0)
            {
                last_diff = double.MAX;
                selected_end = 0;
                selection_end = 0;
                cursor = text.length;
                for(int i = 0; i <= text.length; i++)
                {
                    layout.set_text(text.slice(0, i), -1);
                    if(Math.fabs(selection_mouse_end - get_width(layout)) < last_diff)
                    {
                        last_diff = Math.fabs(selection_mouse_end - get_width(layout));
                        selected_end = i;
                        selection_end = get_width(layout);
                        cursor = i;
                    }
                }
                selection_mouse_end = -1;
            }
        }

        double text_width;
        double text_height;        
        
        private void computetext_width(Pango.Layout pango)
        {
            int text_width, text_height;
            pango.get_size(out text_width, out text_height);
            this.text_width = Pango.units_to_double(text_width);
            this.text_height = Pango.units_to_double(text_height);
        }
        
        private double get_width(Pango.Layout pango)
        {
            int text_width, text_height;
            pango.get_size(out text_width, out text_height);
            return Pango.units_to_double(text_width);
        }

        public void draw(Cairo.Context cr, double x, double height, double width, Gtk.Widget widget, Gtk.StyleContext button_context)
        {
            cr.select_font_face(font_name, Cairo.FontSlant.NORMAL, Cairo.FontWeight.NORMAL);
            cr.set_font_size(font_size);
            cr.set_source_rgba(0,0,0,0.8);

            update_selection(cr, widget);

            cr.set_source_rgba(0,0,0,0.8);

            Pango.Layout layout = widget.create_pango_layout(text);
            computetext_width(layout);
            Gtk.render_layout(button_context, cr, x, height/2 - text_height/2, layout);

            layout.set_text(text.slice(0, cursor), -1);
            if(blink && focus)
            {
                cr.move_to(x + get_width(layout), height/4);
                cr.line_to(x + get_width(layout), height/2 + height/4);
                cr.stroke();
            }
            if(text != "")
            {
                    Gdk.cairo_set_source_pixbuf(cr,arrow_img,
                                          x + width - arrow_img.get_width() - 10,
                                          height/2 - arrow_img.get_height()/2);
                if(hover)
                    cr.paint();
                else
                    cr.paint_with_alpha(0.8);
            }
            
            /* draw completion */
            cr.move_to(x + text_width, height/2 - text_height/2);
            layout.set_text(completion, -1);
            Gdk.RGBA color = Gdk.RGBA();
            button_context.get_color(Gtk.StateFlags.NORMAL, color);
            cr.set_source_rgba(color.red, color.green, color.blue, color.alpha - 0.3);
            Pango.cairo_show_layout(cr, layout);
            
            /* draw selection */
            if(focus)
            {
                cr.rectangle(x + selection_start, height/4, selection_end - selection_start, height/2);
                cr.set_source_rgba(0,0,0,0.5);
                cr.fill();
            }
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

namespace Marlin.Utils
{
    public string get_parent(string newpath)
    {
        var path = File.new_for_uri(newpath);
        if(!path.query_exists())
            path = File.new_for_path(newpath);
        return path.get_parent().get_path();
    }

    public bool has_parent(string newpath)
    {
        var path = File.new_for_uri(newpath);
        if(!path.query_exists())
            path = File.new_for_path(newpath);
        return path.has_parent(null);
    }
}

