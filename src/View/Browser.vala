/***
    Copyright (c) 2010 ammonkey

    This library is free software; you can redistribute it and/or modify
    it under the terms of the GNU Lesser General Public License
    version 3.0 as published by the Free Software Foundation.

    This library is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Lesser General Public License version 3.0 for more details.

    You should have received a copy of the GNU Lesser General Public
    License along with this library. If not, see
    <http://www.gnu.org/licenses/>.

    Author: ammonkey <am.monkeyd@gmail.com>
***/

namespace Files.View {

    public class Browser : Object {
        private Stack<string> back_stack;
        private Stack<string> forward_stack;

        private string current_uri = null;
        private int history_list_length = 10;

        /* The two menus which are displayed on the back/forward buttons */
        public Gtk.Menu back_menu;
        public Gtk.Menu forward_menu;

        public Browser () {
            back_stack = new Stack<string> ();
            forward_stack = new Stack<string> ();
        }

        /**
         * Use this method to track an uri location in
         * the back/forward stacks
         */
        public void record_uri (string? uri) {
            /* When path changed by browser buttons or menu, uri will equal current_uri */
            if (current_uri != null) {
                if (uri != null) {
                    /* Only record if the uri has changed other than by use of forward or back buttons */
                    /* If the forward or back buttons were pressed then the current uri would already have
                     * been made equal to the new uri */
                    if (current_uri != uri) {
                        forward_stack.clear ();
                        back_stack.push (current_uri);
                    }
                } else { /* If current uri is not loadable remember previous uri anyway so that back button works */
                    back_stack.push (current_uri);
                }
            }
            current_uri = uri;
        }

        public Gee.List<string> go_back_list () {
            return back_stack.slice_head (history_list_length);
        }

        public Gee.List<string> go_forward_list () {
            return forward_stack.slice_head (history_list_length);
        }

        public string? go_back (uint n = 1) {
            debug ("[Browser] go back %i places", (int) n);
            var uri = back_stack.pop ();
            if (uri != null) {
                if (current_uri != null) {
                    forward_stack.push (current_uri);
                    current_uri = uri; /* This stops the change affecting the history */
                }
            }

            if (n <= 1) {
                return uri;
            } else {
                return go_back (n - 1);
            }
        }

        public string? go_forward (uint n = 1) {
            debug ("[Browser] go forward %i places", (int) n);
            var uri = forward_stack.pop ();
            if (uri != null) {
                if (current_uri != null) {
                    back_stack.push (current_uri);
                    current_uri = uri; /* This stops the change affecting the history */
                }
            }

            if (n <= 1) {
                return uri;
            } else {
                return go_forward (n - 1);
            }
        }

        public bool get_can_go_back () {
            return !back_stack.is_empty ();
        }

        public bool get_can_go_forward () {
            return !forward_stack.is_empty ();
        }
    } /* End: Browser class */

    /**
     * Stack api
     */
    public class Stack<G> {
        private Gee.LinkedList<G> list;

        public Stack () {
            list = new Gee.LinkedList<G> ();
        }

        public Stack<G> push (G element) {
            list.offer_head (element);
            return this;
        }

        public G pop () {
            return list.poll_head ();
        }

        public G peek () {
            return list.peek_head ();
        }

        public int size () {
            return list.size;
        }

        public void clear () {
            list.clear ();
        }

        public bool is_empty () {
            return size () == 0;
        }

        public Gee.List<G>? slice_head (int amount) {
            return list.slice (0, int.min (size (), amount));
        }
    }

} /* namespace */
