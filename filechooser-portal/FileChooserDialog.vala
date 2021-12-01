/*
 * Copyright 2021 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

[DBus (name = "org.freedesktop.impl.portal.Request")]
public interface Xdp.Request : Object {
    public abstract void close () throws DBusError, IOError;
}

public class Files.FileChooserDialog : Hdy.Window, Xdp.Request {
    public signal void response (Gtk.ResponseType response);

    public uint register_id { get; set; default = 0; }
    public string parent_window { get; construct; }

    public Gtk.FileChooserAction action { get; construct; }

    public bool read_only { get; set; default = false; }

    public string accept_label {
        get {
            return accept_button.label;
        }

        set {
            accept_button.label = value;
        }
    }

    public bool select_multiple {
        get {
            return chooser.select_multiple;
        }

        set {
            chooser.select_multiple = value;
        }
    }

    public Gtk.FileFilter filter {
        get {
            return chooser.filter;
        }

        set {
            if (!filter_box.set_active_id (value.get_filter_name ())) {
                chooser.filter = value;
            }
        }
    }

    private Hdy.HeaderBar header;
    private View.Chrome.BasicLocationBar location_bar;
    private Gtk.FileChooserWidget chooser;
    private Gtk.TreeView tree_view;

    private Gtk.Button accept_button;
    private Gtk.ComboBoxText filter_box;
    private Gtk.Entry entry;

    private Gtk.Box choices_box;
    private Gtk.Box extra_box;

    private Queue<string> previous_paths;
    private Queue<string> next_paths;

    public FileChooserDialog (Gtk.FileChooserAction action, string parent_window, string title) {
        Object (
            parent_window: parent_window,
            action: action,
            title: title
        );
    }

    construct {
        previous_paths = new Queue<string> ();
        next_paths = new Queue<string> ();
        Hdy.init ();

        location_bar = new View.Chrome.BasicLocationBar ();

        var previous_button = new Gtk.Button.from_icon_name ("go-previous-symbolic", Gtk.IconSize.LARGE_TOOLBAR) {
            tooltip_markup = "Previous",
            sensitive = false
        };
        previous_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var next_button = new Gtk.Button.from_icon_name ("go-next-symbolic", Gtk.IconSize.LARGE_TOOLBAR) {
            tooltip_markup = "Next",
            sensitive = false
        };
        next_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        header = new Hdy.HeaderBar () {
            custom_title = location_bar,
            title = title
        };
        header.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        header.pack_start (previous_button);
        header.pack_start (next_button);

        chooser = new Gtk.FileChooserWidget (action) {
            vexpand = true
        };

        var cancel_button = new Gtk.Button.with_label (_("Cancel"));
        accept_button = new Gtk.Button () {
            use_underline = true,
            can_default = true
        };

        filter_box = new Gtk.ComboBoxText ();

        extra_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        extra_box.pack_start (filter_box);

        if (action == Gtk.FileChooserAction.OPEN) {
            var read_only_check = new Gtk.CheckButton.with_label (
                select_multiple ? _("Open Files as Read Only") : _("Open File as Read Only")
            ) {
                margin_start = 6
            };

            notify["select-multiple"].connect (() => {
                read_only_check.label = select_multiple ? _("Open Files as Read Only") : _("Open File as Read Only");
            });

            read_only_check.bind_property ("active", this, "read-only");
            extra_box.pack_end (read_only_check);
        }

        var action_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL) {
            layout_style = Gtk.ButtonBoxStyle.END,
            spacing = 6,
            margin = 6
        };

        action_box.pack_start (cancel_button);
        action_box.pack_start (accept_button);
        action_box.pack_start (extra_box);
        action_box.set_child_secondary (extra_box, true);

        choices_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            halign = Gtk.Align.START,
            margin = 6
        };

        var grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL
        };
        grid.add (header);
        grid.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        grid.add (chooser);
        grid.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        grid.add (choices_box);
        grid.add (action_box);
        add (grid);

        setup_chooser ();

        var settings = new Settings ("io.elementary.files.file-chooser");
        int width, height;

        settings.get ("window-size", "(ii)", out width, out height);

        type_hint = Gdk.WindowTypeHint.DIALOG;
        default_height = height;
        default_width = width;
        can_focus = true;
        modal = true;

        realize.connect (() => {
            if (parent_window != "") {
                var parent = ExternalWindow.from_handle (parent_window);
                if (parent == null) {
                    warning ("Failed to associate portal window with parent window %s", parent_window);
                } else {
                    parent.set_parent_of (get_window ());
                }
            }

            if (chooser.list_filters ().length () == 0) {
                filter_box.visible = false;
            } else if (filter_box.active_id == null) {
                filter_box.active = 0;
            }

            if (choices_box.get_children ().length () == 0) {
                choices_box.visible = false;
            }
        });

        previous_button.clicked.connect (() => {
            next_paths.push_head (chooser.get_current_folder_uri ());
            location_bar.path_change_request (previous_paths.pop_head ());
        });

        next_button.clicked.connect (() => {
            previous_paths.push_head (chooser.get_current_folder_uri ());
            location_bar.path_change_request (next_paths.pop_head ());
        });

        location_bar.path_change_request.connect ((path) => {
            location_bar.set_display_path (path);
            chooser.set_current_folder_uri (path);
        });

        filter_box.changed.connect (() => {
            var filter = chooser.list_filters ().search<string> (
                filter_box.active_id,
                (a, b) => strcmp (a.get_filter_name (), b)
            ).data;

            if (filter != null) {
                chooser.filter = filter;
            }
        });

        tree_view.button_release_event.connect ((w, e) => {
            unowned var tv = (Gtk.TreeView) w;
            if (e.type == Gdk.EventType.@2BUTTON_PRESS) {
                return false;
            }

            tv.activate_on_single_click = false;
            Gtk.TreePath? path = null;
            Gtk.TreeViewColumn? column = null;

            if (tv.get_path_at_pos ((int) e.x, (int) e.y, out path, out column, null, null)) {
                var model = tv.get_model ();
                Gtk.TreeIter? iter = null;

                if (model.get_iter (out iter, path)) {
                    bool is_folder;

                    model.get (iter, 6, out is_folder);
                    if (is_folder) {
                        tv.activate_on_single_click = true;
                    }
                }
            }

            return false;
        });

        chooser.current_folder_changed.connect (() => {
            var previous = location_bar.get_display_path () ?? Environment.get_home_dir ();
            var current = chooser.get_current_folder_uri ();

            if (previous != current) {
                location_bar.set_display_path (current);
                previous_paths.push_head (previous);
                next_paths.clear ();
            }

            previous_button.sensitive = !previous_paths.is_empty ();
            next_button.sensitive = !next_paths.is_empty ();

            tree_view.grab_focus ();
        });

        chooser.file_activated.connect (() => {
             if (!GLib.FileUtils.test (chooser.get_filename (), FileTest.IS_DIR)) {
                 response (Gtk.ResponseType.OK);
             }
        });

        cancel_button.clicked.connect (() => response (Gtk.ResponseType.CANCEL));
        accept_button.clicked.connect (() => response (Gtk.ResponseType.OK));

        // save the dialog size and close after selection
        response.connect_after (() => {
            int w, h;

            get_size (out w, out h);

            settings.set_string ("last-folder-uri", chooser.get_current_folder_uri ());
            settings.set ("window-size", "(ii)", w, h);

            destroy ();
        });

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });

        set_current_folder (settings.get_string ("last-folder-uri"));
    }

    private static T find_child_by_name<T> (Gtk.Widget root, string path) requires (root is Gtk.Container) {
        var paths = path.has_prefix ("/") ? path[1 : path.length].split ("/") : path.split ("/");
        Gtk.Widget? widget = null;
        string name = paths[0];

        /* `find_custom ()` and `search ()` do not work if the element is unowned */
        ((Gtk.Container) root).get_children ().foreach ((w) => {
            if (widget == null) {
                if (name.has_prefix ("<")) {
                    var c_type = Type.from_name (name[1 : name.length - 1]);
                    var w_type = w.get_type ();

                    widget = w_type.is_a (c_type) ? w : null;
                } else if (w is Gtk.Buildable) {
                    widget = ((Gtk.Buildable) w).get_name () == name ? w : null;
                } else {
                    widget = w.name == name ? w : null;
                }
            }
        });

        if (widget != null) {
            if (paths.length > 1) {
                return find_child_by_name (widget, string.joinv ("/", paths[1 : paths.length]));
            } else {
                return (T) widget;
            }
        }

        warning ("cannot find child with name \"%s\" in \"%s\"", name, root.get_type ().name ());
        return null;
    }

    private void setup_chooser () {
        Gtk.Revealer revealer = find_child_by_name (
            chooser,
            "browse_widgets_box/browse_widgets_hpaned/<GtkBox>/browse_header_revealer"
        );

        /* move the new folder button to HeaderBar and remove the chooser header */
        Gtk.Stack stack = find_child_by_name (revealer.get_child (), "browse_header_stack");
        Gtk.MenuButton new_folder_button = find_child_by_name (stack, "<GtkBox>/browse_new_folder_button");
        new_folder_button.image = new Gtk.Image.from_icon_name ("folder-new", Gtk.IconSize.LARGE_TOOLBAR);
        new_folder_button.parent.remove (new_folder_button);
        header.pack_end (new_folder_button);

        /* hide the revealer when not searching, for this to work:
         * 1. we need to set reveal_child during realize.
         * 2. we need to connect the signals after we set `reveal_child`
         */
        realize.connect (() => {
            revealer.reveal_child = false;

            revealer.notify["reveal-child"].connect (() => {
                if (revealer.reveal_child) {
                    revealer.reveal_child = stack.visible_child_name == "search";
                }
            });

            stack.notify["visible-child"].connect (() => {
                revealer.reveal_child = stack.visible_child_name == "search";
            });
        });

        /* move the filename entry from the chooser to the action_box */
        if (action == Gtk.FileChooserAction.SAVE) {
            Gtk.Grid grid = find_child_by_name (chooser, "<GtkBox>/<GtkGrid>");
            grid.parent.remove (grid);
            grid.border_width = 0;
            grid.margin_top = 2;  // seems to have a better result than using Gtk.Align.CENTER

            extra_box.pack_start (grid);

            // bind the accept_button sensitivity with the entry text
            entry = find_child_by_name (grid, "<GtkFileChooserEntry>");
            entry.bind_property ("text-length", accept_button, "sensitive", BindingFlags.SYNC_CREATE);
            entry.activate.connect (() => {
                if (accept_button.sensitive) {
                    response (Gtk.ResponseType.OK);
                }
            });

            chooser.remove (find_child_by_name (chooser, "<GtkBox>"));
        }

        /* get a reference of the tree view, so we can grab focus later */
        Gtk.Stack view_stack = find_child_by_name (revealer.parent, "list_and_preview_box/browse_files_stack");

        tree_view = find_child_by_name (
            view_stack.get_child_by_name ("list"),
            "browse_files_swin/browse_files_tree_view"
        );

        /* remove extra unneeded widgets */
        view_stack.parent.remove (find_child_by_name (view_stack.parent, "preview_box"));
        chooser.remove (find_child_by_name (chooser, "extra_and_filters"));
    }

    protected override bool key_release_event (Gdk.EventKey event) {
        if (event.keyval == Gdk.Key.Escape) {
            response (Gtk.ResponseType.DELETE_EVENT);
            return Gdk.EVENT_STOP;
        }

        return Gdk.EVENT_PROPAGATE;
    }

    public void set_current_folder (string? uri) {
        location_bar.path_change_request (uri ?? Environment.get_home_dir ());
    }

    public void set_current_name (string text) {
        chooser.set_current_name (text);
        entry.grab_focus ();
    }

    public string get_uri () {
        return chooser.get_uri ();
    }

    public void set_uri (string uri) {
        chooser.set_uri (uri);
    }

    public string[] get_uris () {
        string[] uris = {};

        chooser.get_uris ().foreach ((uri) => {
            uris += uri;
        });

        return uris;
    }

    public void add_choice (FileChooserChoice choice) {
        choices_box.add (choice);
    }

    public Variant[] get_choices () {
        Variant[] choices = {};

        choices_box.get_children ().foreach ((w) => {
            unowned var c = (FileChooserChoice) w;
            choices += new Variant ("(ss)", c.name, c.selected);
        });

        return choices;
    }

    public void add_filter (Gtk.FileFilter filter) {
        var name = filter.get_filter_name ();

        if (chooser.list_filters ().search<string> (name, (a, b) => strcmp (a.get_filter_name (), b)) == null) {
            chooser.add_filter (filter);
            filter_box.append (name, name);
        }
    }

    public new void close () throws DBusError, IOError {
        response (Gtk.ResponseType.DELETE_EVENT);
    }
}
