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

public class Files.BasicPathBar : Gtk.Widget, PathBarInterface {
    static construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
    }

    /* PathBar Interface */

    private BasicBreadcrumbs breadcrumbs;
    private BasicPathEntry path_entry;
    public PathBarMode mode { get; set; default = PathBarMode.CRUMBS; }
    public string display_uri { get; set; }

    public bool with_animation {
        set {
            breadcrumbs.animate = value;
        }
    }

    construct {
        breadcrumbs = new BasicBreadcrumbs (this);
        path_entry = new BasicPathEntry (this);
        var stack = new Gtk.Stack ();
        stack.add_child (breadcrumbs);
        stack.add_child (path_entry);
        stack.visible_child = breadcrumbs;
        stack.set_parent (this);

        // notify["display-uri"].connect (() => {
        //     stack.visible_child = breadcrumbs;
        // });

        notify["mode"].connect (() => {
            switch (mode) {
                case PathBarMode.CRUMBS:
                    stack.visible_child = breadcrumbs;
                    break;
                case PathBarMode.ENTRY:
                    path_entry.text = breadcrumbs.get_uri_from_crumbs ();
                    stack.visible_child = path_entry;
                    path_entry.grab_focus ();
                    break;
            }
        });
        bind_property ("display-uri", breadcrumbs, "uri", BindingFlags.DEFAULT);
    }

    // public override void search (string term) {
    //     mode = PathBarMode.SEARCH;
    //     search_widget.term = term;
    // }

    private class BasicBreadcrumbs : Gtk.Widget {
        private List<Crumb> crumbs;
        private Crumb spacer; // Maintain minimum clickable space after crumbs
        private Gtk.Box main_child;
        private string protocol;
        private string path;

        public string uri { get; set; }
        public bool animate { get; set; }
        public PathBarInterface path_bar { get; construct; }

        public BasicBreadcrumbs (PathBarInterface path_bar) {
            Object (path_bar: path_bar);
        }

        construct {
            var layout = new Gtk.BoxLayout (Gtk.Orientation.HORIZONTAL);
            set_layout_manager (layout);
            crumbs = new List<Crumb> ();
            var scrolled_window = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.EXTERNAL,
                vscrollbar_policy = Gtk.PolicyType.NEVER,
                hexpand = true
            };
            var hadj = new Gtk.Adjustment (0.0, 0.0, 100.0, 1.0, 1.0 , 1.0);
            hadj.changed.connect (() => {
                hadj.value = main_child.get_allocated_width () - scrolled_window.get_allocated_width ();
            });
            scrolled_window.hadjustment = hadj;

            spacer = new Crumb.spacer (); //TODO Use different widget or omit?
            main_child = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                halign = Gtk.Align.START
            };
            main_child.append (spacer);
            scrolled_window.child = main_child;

            var refresh_button = new Gtk.Button () {
                icon_name = "view-refresh-symbolic",
                action_name = "win.refresh",
                hexpand = false,
                halign = Gtk.Align.END
            };
            var search_button = new Gtk.Button () {
                icon_name = "edit-find-symbolic",
                action_name = "win.find",
                action_target = "",
                hexpand = false,
                halign = Gtk.Align.START
            };

            search_button.set_parent (this);
            scrolled_window.set_parent (this);
            refresh_button.set_parent (this);

            var click_gesture = new Gtk.GestureClick () {
                button = 0,
                propagation_phase = Gtk.PropagationPhase.CAPTURE
            };
            click_gesture.pressed.connect (() => {
                // Need to block primary press to stop window menu appearing
                click_gesture.set_state (Gtk.EventSequenceState.CLAIMED);
            });
            click_gesture.released.connect (button_release_handler);
            scrolled_window.add_controller (click_gesture);

            notify["uri"].connect (() => {
                FileUtils.split_protocol_from_path (uri, out protocol, out path);
                draw_crumbs ();
                activate_action ("win.go-to", "s", uri);
            });
        }

        public string get_uri_from_crumbs () {
            var sb = new StringBuilder (protocol);
            foreach (unowned var crumb in crumbs) {
                sb.append (Path.DIR_SEPARATOR_S);
                sb.append (Path.get_basename (crumb.dir_path));
            }

            return sb.str;
        }

        private void button_release_handler (Gtk.EventController source, int n_press, double x, double y) {
            var button = ((Gtk.GestureSingle)source).get_current_button ();
            switch (button) {
                case Gdk.BUTTON_PRIMARY:
                    var widget = main_child.pick (x, y, Gtk.PickFlags.DEFAULT);
                    if (widget != null) {
                        var crumb = (Crumb)(widget.get_ancestor (typeof (Crumb)));
                        assert (crumb is Crumb);
                        if (crumb.dir_path != null) {
                            activate_action ("win.go-to", "s", protocol + crumb.dir_path);
                            break;
                        }
                    }

                    path_bar.mode = PathBarMode.ENTRY; // Clicked on spacer or empty
                    break;
                case Gdk.BUTTON_SECONDARY:
                    break;
                default:
                    break;
            }
        }

        private void draw_crumbs () {
            spacer.unparent ();
            foreach (var crumb in crumbs) {
                crumb.unparent ();
                crumb.destroy ();
            }
            crumbs = null;
            //Break apart
            string[] parts;
            parts = path.split (Path.DIR_SEPARATOR_S);
            //Make crumbs
            string crumb_path = "";
            if (parts.length == 0) {
                crumbs.append (new Crumb (Path.DIR_SEPARATOR_S));
            } else {
                foreach (unowned var part in parts) {
                    if (part != "") {
                        crumb_path += Path.DIR_SEPARATOR_S + part;
                        var crumb = new Crumb (crumb_path);
                        crumbs.append (crumb);
                    }
                }
            }

            foreach (var crumb in crumbs) {
                main_child.append (crumb);
            }

            main_child.append (spacer);
        }
    }

    private class Crumb : Gtk.Widget {
        public string? dir_path { get; construct; }
        public bool show_icon { get; construct; }
        public bool show_name { get; construct; }

        private Gtk.Label name_label;
        private Gtk.Image dir_icon;
        private Gtk.Revealer icon_revealer;
        private Gtk.Revealer name_revealer;


        public Crumb (string? path, bool show_icon = false, bool show_name = true) {
            Object (
                dir_path: path,
                show_icon: show_icon,
                show_name: show_name
            );
        }

        public Crumb.spacer () {
            Object (
                dir_path: null,
                show_icon: false,
                show_name: false
            );
        }

        ~Crumb () {
            icon_revealer.unparent ();
            name_revealer.unparent ();
        }

        construct {
            name ="crumb";
            var layout = new Gtk.BoxLayout (Gtk.Orientation.HORIZONTAL);
            set_layout_manager (layout);
            name_label = new Gtk.Label (
                dir_path != null ? Path.get_basename (dir_path) : "SPACE"
            );
            dir_icon = new Gtk.Image () {
                icon_name = "image-missing-symbolic"
            };
            icon_revealer = new Gtk.Revealer ();
            icon_revealer.child = dir_icon;
            name_revealer = new Gtk.Revealer ();
            name_revealer.child = name_label;

            icon_revealer.set_parent (this);
            name_revealer.set_parent (this);

            icon_revealer.set_reveal_child (show_icon);
            name_revealer.set_reveal_child (show_name);
        }
    }

    private class BasicPathEntry : Gtk.Widget {
        static construct {
            set_layout_manager_type (typeof (Gtk.BinLayout));
        }

        public PathBarInterface path_bar { get; construct; }
        public string text {
            get {
                return path_entry.text;
            }

            set {
                path_entry.text = value;
            }
        }

        private Gtk.Entry path_entry;

        public BasicPathEntry (PathBarInterface path_bar) {
            Object (path_bar: path_bar);
        }

        construct {
            path_entry = new Gtk.Entry (); //TODO Use validated entry?
            path_entry.set_parent (this);
            path_entry.activate.connect (() => {
                path_bar.display_uri = FileUtils.sanitize_path (path_entry.text);
                path_bar.mode = PathBarMode.CRUMBS;
            });
        }

        public override bool grab_focus () {
            return path_entry.grab_focus ();
        }
    }
}
