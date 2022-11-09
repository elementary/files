/***
    Copyright (c) 2022 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISitem_factory QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

/* Contains basic breadcrumb and path entry entry widgets for use in FileChooser */

public class Files.BasicPathBar : Gtk.Widget, PathBarInterface{
    static construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
    }

    /* PathBar Interface */

    private BasicBreadcrumbs breadcrumbs;
    private BasicPathEntry path_entry;
    protected string displayed_path {
        set {
            breadcrumbs.path = value;
            showing_breadcrumbs = true;
        }

        get {
            return breadcrumbs.path;
        }
    }

    public bool showing_breadcrumbs { get; set; }

    public bool with_animation {
        set {
            breadcrumbs.animate = value;
        }
    }

    construct {
        breadcrumbs = new BasicBreadcrumbs ();
        path_entry = new BasicPathEntry ();
        var stack = new Gtk.Stack ();
        stack.add_child (breadcrumbs);
        stack.add_child (path_entry);
        stack.visible_child = breadcrumbs;
        notify["showing-breadcrumbs"].connect (() => {
            if (showing_breadcrumbs) {
                stack.visible_child = breadcrumbs;
            } else {
                stack.visible_child = path_entry;
            }
        });

        stack.set_parent (this);
    }

    /* Interface methods */
    public void set_display_path (string path) { displayed_path = path; }
    public string get_display_path () { return displayed_path; }
    public bool set_focussed () {return false;}

    // protected virtual void connect_signals () {
    //     bread.entry_text_changed.connect_after (after_bread_text_changed);
    //     bread.activate_path.connect (on_bread_activate_path);
    //     bread.action_icon_press.connect (on_bread_action_icon_press);
    //     // bread.focus_in_event.connect_after (after_bread_focus_in_event);
    //     // bread.focus_out_event.connect_after (after_bread_focus_out_event);
    // }

    // protected virtual void after_bread_text_changed (string txt) {
    //     if (txt == "") {
    //         bread.set_placeholder (_("Type a path"));
    //         bread.set_action_icon_tooltip ("");
    //         bread.hide_action_icon ();
    //     } else {
    //         bread.set_placeholder ("");
    //         bread.set_default_action_icon_tooltip ();
    //     }
    // }

    // // protected virtual bool after_bread_focus_in_event (Gdk.EventFocus event) {
    // //     show_navigate_icon ();
    // //     return true;
    // // }
    // // protected virtual bool after_bread_focus_out_event (Gdk.EventFocus event) {
    // //     hide_navigate_icon ();
    // //     return true;
    // // }

    // protected virtual void on_bread_action_icon_press () {
    //     bread.activate ();
    // }

    // protected virtual void on_bread_activate_path (string path, Files.OpenFlag flag) {
    //     /* Navigatable is responsible for providing a valid path or empty string
    //      * and for translating e.g. ~/ */
    //     path_change_request (path, flag);
    // }

    // protected virtual void show_navigate_icon () {
    //     bread.show_default_action_icon ();
    // }
    // protected virtual void hide_navigate_icon () {
    //     bread.hide_action_icon ();
    // }

    // protected void show_breadcrumbs () {
    //     bread.set_breadcrumbs_path (displayed_path);
    //     this.minimum_width = bread.get_minimum_width () + 48; /* Allow extra space for margins */
    //     this.set_size_request (this.minimum_width, -1);
    // }

    // public virtual void set_display_path (string path) {
    //     displayed_path = path; /* Will also change breadcrumbs */
    // }

    // public string get_display_path () {
    //     return displayed_path;
    // }

    // public bool set_focussed () {
    //     bread.grab_focus ();
    //     return bread.has_focus;
    // }

    private class BasicBreadcrumbs : Gtk.Widget {
        static construct {
            set_layout_manager_type (typeof (Gtk.BinLayout));
        }

        private Gtk.DrawingArea drawing_area;
        public string path { get; set; }
        public bool animate { get; set; }
        construct {
            drawing_area = new Gtk.DrawingArea ();
            drawing_area.set_parent (this);
        }
    }

    private class BasicPathEntry : Gtk.Widget {
        static construct {
            set_layout_manager_type (typeof (Gtk.BinLayout));
        }

        private Gtk.Entry path_entry;

        construct {
            path_entry = new Gtk.Entry (); //TODO Use validated entry?
            path_entry.set_parent (this);
        }
    }
}

