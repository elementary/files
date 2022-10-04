/***
    Copyright (c) 2010 mathijshenquet
    Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>

    Marlin is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of the
    License, or (at your option) any later version.

    Marlin is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this program; see the file COPYING.  If not,
    write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
    Boston, MA 02110-1335 USA.

***/

namespace Files.Chrome {
    public class BasicLocationBar : Gtk.Box, Locatable {
        private Navigatable bread;
        protected Gtk.Widget widget;
        private int minimum_width = 100;
        private string _path;
        protected string displayed_path {
            set {
                if (value == null) {
                    critical ("Tried to set null path");
                } else if (_path == null || _path != value) {
                    _path = value;
                    show_breadcrumbs ();
                }
            }

            get {
                return _path;
            }
        }

        public bool with_animation {
            set {
                bread.set_animation_visible (value);
            }
        }

        public new bool has_focus {
            get {
                return bread.has_focus;
            }
        }

        //TODO Replace with measure ()
        // public override void get_preferred_width (out int minimum_width, out int natural_width) {
        //     minimum_width = this.minimum_width;
        //     natural_width = 3000;
        // }

        construct {
            margin_start = 3;
            valign = Gtk.Align.CENTER;
        }

        public BasicLocationBar (Navigatable? _bread = null) {
            if (_bread == null) {
                bread = new BasicBreadcrumbsEntry () {
                    hexpand = true
                };
            } else {
                bread = _bread;
            }

            widget = _bread as Gtk.Widget;
            append (bread);
            connect_signals ();
            can_focus = false;
        }

        protected virtual void connect_signals () {
            bread.entry_text_changed.connect_after (after_bread_text_changed);
            bread.activate_path.connect (on_bread_activate_path);
            bread.action_icon_press.connect (on_bread_action_icon_press);
            // bread.focus_in_event.connect_after (after_bread_focus_in_event);
            // bread.focus_out_event.connect_after (after_bread_focus_out_event);
        }

        protected virtual void after_bread_text_changed (string txt) {
            if (txt == "") {
                bread.set_placeholder (_("Type a path"));
                bread.set_action_icon_tooltip ("");
                bread.hide_action_icon ();
            } else {
                bread.set_placeholder ("");
                bread.set_default_action_icon_tooltip ();
            }
        }

        // protected virtual bool after_bread_focus_in_event (Gdk.EventFocus event) {
        //     show_navigate_icon ();
        //     return true;
        // }
        // protected virtual bool after_bread_focus_out_event (Gdk.EventFocus event) {
        //     hide_navigate_icon ();
        //     return true;
        // }

        protected virtual void on_bread_action_icon_press () {
            bread.activate ();
        }

        protected virtual void on_bread_activate_path (string path, Files.OpenFlag flag) {
            /* Navigatable is responsible for providing a valid path or empty string
             * and for translating e.g. ~/ */
            path_change_request (path, flag);
        }

        protected virtual void show_navigate_icon () {
            bread.show_default_action_icon ();
        }
        protected virtual void hide_navigate_icon () {
            bread.hide_action_icon ();
        }

        protected void show_breadcrumbs () {
            bread.set_breadcrumbs_path (displayed_path);
            this.minimum_width = bread.get_minimum_width () + 48; /* Allow extra space for margins */
            this.set_size_request (this.minimum_width, -1);
        }

        public virtual void set_display_path (string path) {
            displayed_path = path; /* Will also change breadcrumbs */
        }

        public string get_display_path () {
            return displayed_path;
        }

        public bool set_focussed () {
            bread.grab_focus ();
            return bread.has_focus;
        }
    }
}
