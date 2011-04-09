/*
 * Copyright (C) 2010 ammonkey
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * version 3.0 as published by the Free Software Foundation.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License version 3.0 for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library. If not, see
 * <http://www.gnu.org/licenses/>.
 *
 * Author: ammonkey <am.monkeyd@gmail.com>
 */

using Gee;

namespace Marlin.View {

    /* Used in our menu item, it is a callback which is sent to Browser
     * (when it is initialized), and then it is sent to any BrowserMenuItem,
     * which call it when it is activated.
     * Using a real callback/signal here seems more difficult. */
    public delegate void path_callback(int i);

    private class BrowserMenuItem : Gtk.MenuItem
    {
        string text_path;
        path_callback pressed;
        int i;
        public BrowserMenuItem(string path_, int i_, path_callback pressed_)
        {
            pressed = pressed_;
            text_path = path_;
            i = i_;
            set_label(text_path);
            this.activate.connect(activate_path);
        }

        /* The activate callback, this function send another callback to it
         * delegate pressed, which is usually a ViewContainer.go_back_forward */
        private void activate_path()
        {
            pressed(i);
        }
    }

    public class Browser<G> : GLib.Object
    {
        private Stack<string> back_stack;
        private Stack<string> forward_stack;
        path_callback pressed;

        private string current_uri = null;
        private int history_list_length = 10;
        
        /* The two menus which are displayed on the back/forward buttons */
        public Gtk.Menu back_menu;
        public Gtk.Menu forward_menu;

        public Browser (path_callback pressed_)
        {
            pressed = pressed_;
            back_stack = new Stack<string> ();
            forward_stack = new Stack<string> ();

            back_menu = new Gtk.Menu ();
            forward_menu = new Gtk.Menu ();
            back_menu.show_all();
            forward_menu.show_all();
        }

        /**
         * Use this method to track an uri location in
         * the back/forward stacks
         */
        public void record_uri (string uri)
        {
            if (current_uri != null)
            {
                back_stack.push (current_uri);
                forward_stack.clear ();
            }

            current_uri = uri;
            
            update_menu();
        }

        /*private void clear ()
          {
          back_stack.clear ();
          forward_stack.clear ();
          current_uri = null;
          }*/

        /*private void printstack ()
          {
          stdout.printf ("bck|fwd: %d %d\n", back_stack.size(), forward_stack.size());
          }*/

        public Gee.List go_back_list(){
            return back_stack.slice_head(history_list_length);
        }

        public Gee.List go_forward_list(){
            return forward_stack.slice_head(history_list_length);
        }

        public string? go_back ()
        {
            var uri = back_stack.pop();
            if (uri != null)
            {
                if (current_uri != null) {
                    forward_stack.push (current_uri);
                    current_uri = uri;
                }
                //stdout.printf ("%% %s\n", uri);
            
                update_menu();
                return (uri);
            }
            return null;
        }

        public string? go_forward ()
        {
            var uri = forward_stack.pop();
            if (uri != null)
            {
                if (current_uri != null) {
                    back_stack.push (current_uri);
                    current_uri = uri;
                }
                //stdout.printf ("%% %s\n", uri);
            
                update_menu();
                return (uri);
            }
            return null;
        }

        public bool can_go_back ()  {
            return !back_stack.is_empty ();
        }

        public bool can_go_forward ()  {
            return !forward_stack.is_empty ();
        }
        
        private void update_menu()  {
            /* Clear the back menu and re-add the correct entries. */
            back_menu = new Gtk.Menu ();
            var list = back_stack.slice_head(int.min(back_stack.size(), 8));
            foreach(string path in list)
            {
                back_menu.insert(new BrowserMenuItem (path.replace("file://", ""),
                                                      list.index_of(path) + 1,
                                                      pressed),
                                 -1);
            }
            back_menu.show_all();

            /* Same for the forward menu */
            forward_menu = new Gtk.Menu ();
            list = forward_stack.slice_head(int.min(forward_stack.size(), 8));
            foreach(string path in list)
            {
                forward_menu.insert(new BrowserMenuItem (path.replace("file://", ""),
                                                         -(list.index_of(path) + 1),
                                                         pressed),
                                 -1);
            }
            forward_menu.show_all();
        }
    } /* End: Browser class */

    /**
     * Stack api
     */
    public class Stack<G>
    {
        private LinkedList<G> list;

        public Stack ()
        {
            list = new LinkedList<G>();
        }

        public Stack<G> push (G element)
        {
            list.offer_head (element);
            return this;
        }

        public G pop ()
        {
            return list.poll_head ();
        }

        public G peek ()
        {
            return list.peek_head ();
        }

        public int size ()
        {
            return list.size;
        }

        public void clear ()
        {
            list.clear ();
        }

        public bool is_empty ()
        {
            return size() == 0;
        }

        public Gee.List<G>? slice_head(int amount){
            return list.slice(0, amount);
        }
    }

} /* namespace */

