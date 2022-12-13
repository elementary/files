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
    protected BasicBreadcrumbs breadcrumbs;
    protected BasicPathEntry path_entry;
    public PathBarMode mode { get; set; default = PathBarMode.CRUMBS; }
    public string display_uri { get; set; default = ""; }

    //TODO Implement animation (use revealer transitions?)
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

        var focus_controller = new Gtk.EventControllerFocus ();
        add_controller (focus_controller);
        focus_controller.notify["contains-focus"].connect (() => {
            // Timeout required to ignore temporary focus out when switching keyboard layout
            // Idle is not long enough
            Timeout.add (20, () => {
                if (!focus_controller.contains_focus) {
                    mode = PathBarMode.CRUMBS;
                }

                return Source.REMOVE;
            });
        });

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

    protected class BasicBreadcrumbs : Gtk.Widget {
        public List<Crumb> crumbs;
        public Gtk.ScrolledWindow scrolled_window;
        private Gtk.Label spacer; // Maintain minimum clickable space after crumbs
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
            scrolled_window = new Gtk.ScrolledWindow () {
                hscrollbar_policy = Gtk.PolicyType.EXTERNAL,
                vscrollbar_policy = Gtk.PolicyType.NEVER,
                hexpand = true,
                focusable = false,
                propagate_natural_width = true
            };


            spacer = new Gtk.Label ("") {
                width_request = 48,
                halign = Gtk.Align.START
            }; //TODO Use different widget or omit?

            main_child = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
                halign = Gtk.Align.START
            };
            main_child.append (spacer);
            scrolled_window.child = main_child;

            var refresh_button = new Gtk.Button () {
                icon_name = "view-refresh-symbolic",
                action_name = "win.refresh",
                hexpand = false,
                halign = Gtk.Align.END,
                can_focus = false
            };
            var search_button = new Gtk.Button () {
                icon_name = "edit-find-symbolic",
                action_name = "win.find",
                action_target = "",
                hexpand = false,
                halign = Gtk.Align.START,
                margin_end = 24,
                can_focus = false
            };

            search_button.set_parent (this);
            scrolled_window.set_parent (this);
            refresh_button.set_parent (this);

            var primary_gesture = new Gtk.GestureClick () {
                button = Gdk.BUTTON_PRIMARY,
                propagation_phase = Gtk.PropagationPhase.CAPTURE
            };
            primary_gesture.pressed.connect (() => {
                // Need to block primary press to stop window menu appearing
                primary_gesture.set_state (Gtk.EventSequenceState.CLAIMED);
            });
            primary_gesture.released.connect ((n_press, x, y) => {
                var crumb = get_crumb_from_coords (x, y);
                if (crumb != null && crumb.dir_path != null) {
                    activate_action (
                        "win.path-change-request",
                        "(su)",
                        protocol + crumb.dir_path,
                        OpenFlag.DEFAULT
                    );
                } else {
                    path_bar.mode = PathBarMode.ENTRY; // Clicked on spacer or empty
                }
            });
            scrolled_window.add_controller (primary_gesture);

            scrolled_window.realize.connect_after (() => {
                var hadj = scrolled_window.hadjustment;
                notify["uri"].connect (() => {
                    FileUtils.split_protocol_from_path (uri, out protocol, out path);
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
                        crumbs.append (new Crumb (protocol, false));
                    } else {
                        var last = parts.length - 1;
                        int index = 0;
                        foreach (unowned var part in parts) {
                            crumb_path += part;
                            var crumb = new Crumb (crumb_path, index != last);
                            crumbs.append (crumb);
                            if (crumb.hide_previous) {
                                int j = 0;
                                while (j < index) {
                                    crumbs.nth_data (j).hide ();
                                    j++;
                                }
                            }
                            index++;
                            crumb_path += Path.DIR_SEPARATOR_S;
                        }
                    }

                    foreach (var crumb in crumbs) {
                        main_child.append (crumb);
                    }

                    main_child.append (spacer);
                    // Scroll to show the last breadcrumb
                    hadj.changed ();
                });

                hadj.changed.connect (() => {
                    // Show last breadcrumb when uri or window width changes
                    // Without the idle, does not scroll to correct position sometimes
                    Idle.add (() => {
                        hadj.set_value (
                            main_child.get_allocated_width () - scrolled_window.get_allocated_width ()
                        );
                        return Source.REMOVE;
                    });
                });

                // Update pathbar and show last breadcrumb on initial showing of window
                Idle.add (() => {
                    notify_property ("uri");
                    return Source.REMOVE;
                });
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

        public Crumb? get_crumb_from_coords (double x, double y) {
            var widget = main_child.pick (x, y, Gtk.PickFlags.DEFAULT);
            if (widget != null) {
                widget = widget.get_ancestor (typeof (Crumb));
                if (widget != null) {
                    return (Crumb)widget;
                }
            }

            return null;
        }
    }

    protected class Crumb : Gtk.Widget {
        public string? dir_path { get; construct; }
        public bool show_separator { get; construct; }

        private Gtk.Label name_label;
        private Gtk.Image? dir_icon = null;
        private Gtk.Image? separator_image = null;

        public bool hide_previous = false;

        public Crumb (string? path, bool show_separator) {
            Object (
                dir_path: path,
                show_separator: show_separator
            );
        }

        ~Crumb () {
            while (this.get_last_child () != null) {
                this.get_last_child ().unparent ();
            }
        }

        construct {
            name ="crumb";
            var layout = new Gtk.BoxLayout (Gtk.Orientation.HORIZONTAL);
            set_layout_manager (layout);
            name_label = new Gtk.Label (
                dir_path != null ? Path.get_basename (dir_path) : "") {
                margin_start = 3
            };

            string path, display_name, protocol;
            Icon? icon;
            FileUtils.split_protocol_from_path (dir_path, out protocol, out path);
            unowned var key = path != "" ? path : protocol;
            unowned var icon_map = BreadcrumbIconMap.get_default ();
            bool result = icon_map.get_icon_info_for_key (
                key,
                out icon,
                out display_name,
                out hide_previous
            );
            if (result) {
                dir_icon = new Gtk.Image () {
                    gicon = icon,
                    margin_end = 6
                };
            }

            if (display_name != "") {
                name_label.label = display_name;
            } else {
                name_label.label = Path.get_basename (dir_path);
            }

            if (dir_icon != null) {
                dir_icon.set_parent (this);
            }

            if (name_label.label != "") {
                name_label.set_parent (this);
            }

            if (show_separator) {
                separator_image = new Gtk.Image () {
                    gicon = new ThemedIcon ("go-next-symbolic"),
                    margin_start = 24
                };
                separator_image.set_parent (this);
            }


        }
    }

    protected class BasicPathEntry : Gtk.Widget {
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
