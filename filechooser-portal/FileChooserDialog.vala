/*
 * Copyright 2021 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

[DBus (name = "org.freedesktop.impl.portal.Request")]
public interface Xdp.Request : Object {
    public abstract void close () throws DBusError, IOError;
}

public class Files.FileChooserDialog : Gtk.Window, Xdp.Request {
    public signal void response (Gtk.ResponseType response);

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

    private Adw.HeaderBar header;
    private View.Chrome.BasicLocationBar location_bar;
    private Gtk.FileChooserWidget chooser;
    private Gtk.TreeView tree_view;

    private Gtk.Button accept_button;
    private Gtk.ComboBoxText filter_box;
    private Gtk.Entry? entry;

    private Gtk.Box choices_box;
    private Gtk.Box extra_box;

    private Queue<GLib.File> previous_files;
    private Queue<GLib.File> next_paths;
    private GLib.File? current_file = null;
    private bool previous_button_clicked = false;
    private bool next_button_clicked = false;

    private uint register_id = 0;
    private DBusConnection? dbus_connection = null;

    private Settings settings;

    public FileChooserDialog (Gtk.FileChooserAction action, string parent_window, string title) {
        Object (
            parent_window: parent_window,
            action: action,
            title: title
        );
    }

    construct {
        previous_files = new Queue<GLib.File> ();
        next_paths = new Queue<GLib.File> ();

        location_bar = new View.Chrome.BasicLocationBar ();
        var title_label = new Gtk.Label (title);
        var title_widget = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        title_widget.prepend (title_label);
        title_widget.append (location_bar);

        var previous_button = new Gtk.Button.from_icon_name ("go-previous-symbolic") {
            tooltip_markup = "Previous",
            sensitive = false
        };
        previous_button.add_css_class ("flat");

        var next_button = new Gtk.Button.from_icon_name ("go-next-symbolic") {
            tooltip_markup = "Next",
            sensitive = false
        };
        next_button.add_css_class ("flat");

        header = new Adw.HeaderBar () {
            title_widget = title_widget
        };
        header.add_css_class ("flat");
        header.pack_start (previous_button);
        header.pack_start (next_button);

        chooser = new Gtk.FileChooserWidget (action) {
            vexpand = true
        };

        var cancel_button = new Gtk.Button.with_label (_("Cancel")) {
            halign = Gtk.Align.END
        };
        accept_button = new Gtk.Button () {
            use_underline = true,
            halign = Gtk.Align.END
        };
        accept_button.add_css_class ("suggested-action");

        filter_box = new Gtk.ComboBoxText ();

        extra_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            halign = Gtk.Align.START
        };
        extra_box.prepend (filter_box);

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
            extra_box.append (read_only_check);
        }

        var action_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            margin_top = 6,
            margin_bottom = 6,
            margin_start = 6,
            margin_end = 6
        };

        action_box.append (cancel_button);
        action_box.append (accept_button);
        action_box.append (extra_box);

        choices_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            halign = Gtk.Align.START,
            margin_top = 6,
            margin_bottom = 6,
            margin_start = 6,
            margin_end = 6
        };

        var grid = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        grid.append (header);
        grid.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        grid.append (chooser);
        grid.append (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        grid.append (choices_box);
        grid.append (action_box);
        child = grid;

        setup_chooser ();

        settings = new Settings ("io.elementary.files.file-chooser");
        int width, height;
        settings.get ("window-size", "(ii)", out width, out height);

        default_height = height;
        default_width = width;
        can_focus = true;
        modal = true;

        ((Gtk.Widget)this).realize.connect (() => {
            //TODO Replace if needed
            // if (parent_window != "") {
            //     var parent = ExternalWindow.from_handle (parent_window);
            //     if (parent == null) {
            //         warning ("Failed to associate portal window with parent window %s", parent_window);
            //     } else {
            //         parent.set_parent_of (get_window ());
            //     }
            // }

            if (chooser.get_filters ().get_n_items () == 0) {
                filter_box.visible = false;
            } else if (filter_box.active_id == null) {
                filter_box.active = 0;
            }

            choices_box.visible = choices_box.get_first_child () != null;
        });

        previous_button.clicked.connect (() => {
            previous_button_clicked = true;
            try {
                var file = previous_files.pop_head ();
                chooser.set_current_folder (file);
            } catch (Error e) {
                warning ("Could not set current folder. %s", e.message);
            }
        });

        next_button.clicked.connect (() => {
            next_button_clicked = true;
            try {
                var file = next_paths.pop_head ();
                chooser.set_current_folder (file);
            } catch (Error e) {
                warning ("Could not set current folder. %s", e.message);
            }
        });

        location_bar.path_change_request.connect ((path) => {
            try {
                var file = GLib.File.new_for_uri (path);
                chooser.set_current_folder (file);
            } catch (Error e) {
                warning ("Could not set current folder. %s", e.message);
            }
        });

        filter_box.changed.connect (() => {
            var active_filter_name = filter_box.active_id;
            var filter_list = chooser.get_filters ();
            Gtk.FileFilter? filter = null;
            for (uint i = 0; i < filter_list.get_n_items (); i++) {
                var item = (Gtk.FileFilter)filter_list.get_item (i);
                if (item.name == active_filter_name) {
                    filter = item;
                    break;
                }
            }
            if (filter != null) {
                chooser.filter = filter;
            }
        });

        //TODO Use EventController
        // tree_view.button_release_event.connect ((w, e) => {
        //     unowned var tv = (Gtk.TreeView) w;
        //     if (e.type == Gdk.EventType.@2BUTTON_PRESS) {
        //         return false;
        //     }

        //     tv.activate_on_single_click = false;
        //     Gtk.TreePath? path = null;
        //     Gtk.TreeViewColumn? column = null;

        //     if (tv.get_path_at_pos ((int) e.x, (int) e.y, out path, out column, null, null)) {
        //         var model = tv.get_model ();
        //         Gtk.TreeIter? iter = null;

        //         if (model.get_iter (out iter, path)) {
        //             bool is_folder;

        //             model.get (iter, 6, out is_folder);
        //             if (is_folder) {
        //                 tv.activate_on_single_click = true;
        //             }
        //         }
        //     }

        //     return false;
        // });

        //TODO Replace missing signal
        // chooser.current_folder_changed.connect_after (() => {
        //     var previous_file = current_file;
        //     current_file = chooser.get_current_folder () ?? File.new_for_path (Environment.get_home_dir ());

        //     if (previous_file != null && !previous_file.equal (current_folder)) {
        //         if (previous_button_clicked) {
        //             next_paths.push_head (previous_file);
        //         } else {
        //             previous_files.push_head (previous_file);
        //             if (!next_button_clicked) {
        //                 next_paths.clear ();
        //             }
        //         }
        //     }

        //     previous_button.sensitive = !previous_files.is_empty ();
        //     next_button.sensitive = !next_paths.is_empty ();
        //     previous_button_clicked = false;
        //     next_button_clicked = false;

        //     location_bar.set_display_path (current_folder.get_uri ());
        //     tree_view.grab_focus ();
        // });

        //TODO Replace missing signal
        // chooser.file_activated.connect (() => {
        //      if (!GLib.FileUtils.test (chooser.get_filename (), FileTest.IS_DIR)) {
        //          response (Gtk.ResponseType.OK);
        //      }
        // });

        cancel_button.clicked.connect (() => response (Gtk.ResponseType.CANCEL));
        accept_button.clicked.connect (() => response (Gtk.ResponseType.OK));

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });

        try {
            var file = GLib.File.new_for_uri (settings.get_string ("last-folder-uri"));
            chooser.set_current_folder (file);
        } catch (Error e) {
            warning ("Could not set current folder. %s", e.message);
        }
    }

    private static Gtk.Widget? find_child_by_name (Gtk.Widget root, string path) {
        var paths = path.has_prefix ("/") ? path[1 : path.length].split ("/") : path.split ("/");
        Gtk.Widget? widget = null;
        string name = paths[0];

        /* `find_custom ()` and `search ()` do not work if the element is unowned */
        var child = root.get_first_child ();
        while (child != null && widget == null) {
        // ((Gtk.Container) root).get_children ().foreach ((w) => {
            if (name.has_prefix ("<")) {
                var c_type = Type.from_name (name[1 : name.length - 1]);
                var w_type = child.get_type ();

                widget = w_type.is_a (c_type) ? child : null;
            } else if (child is Gtk.Buildable) {
                widget = ((Gtk.Buildable) child).get_id () == name ? child : null;
            } else {
                widget = child.name == name ? child : null;
            }

            child = child.get_next_sibling ();
        }

        if (widget != null) {
            if (paths.length > 1) {
                return find_child_by_name (widget, string.joinv ("/", paths[1 : paths.length]));
            } else {
                return widget;
            }
        }

        warning ("cannot find child with name \"%s\" in \"%s\"", name, root.get_type ().name ());
        return null;
    }

    private static void remove_child (Gtk.Widget root, string path) {
        var child = find_child_by_name (root, path);
        if (child != null) {
            child.unparent ();
        }
    }

    private void setup_chooser () {
        var revealer = (Gtk.Revealer?)find_child_by_name (
            chooser,
            "browse_widgets_box/browse_widgets_hpaned/<GtkBox>/browse_header_revealer"
        );

        /* move the new folder button to HeaderBar and remove the chooser header */
        var stack = (Gtk.Stack?)find_child_by_name (revealer.get_child (), "browse_header_stack");
        var new_folder_button = (Gtk.MenuButton?)find_child_by_name (stack, "<GtkBox>/browse_new_folder_button");
        new_folder_button.icon_name = "new-folder";
        new_folder_button.unparent ();
        // new_folder_button.parent.remove (new_folder_button);
        header.pack_end (new_folder_button);

        /* hide the revealer when not searching, for this to work:
         * 1. we need to set reveal_child during realize.
         * 2. we need to connect the signals after we set `reveal_child`
         */
        ((Gtk.Widget)this).realize.connect (() => {
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
            var grid = (Gtk.Grid?)find_child_by_name (chooser, "<GtkBox>/<GtkGrid>");
            grid.unparent ();
            grid.margin_top = 2;  // seems to have a better result than using Gtk.Align.CENTER

            extra_box.prepend (grid);

            // bind the accept_button sensitivity with the entry text
            entry = (Gtk.Entry?)find_child_by_name (grid, "<GtkFileChooserEntry>");
            entry.bind_property ("text-length", accept_button, "sensitive", BindingFlags.SYNC_CREATE);
            entry.activate.connect (() => {
                if (accept_button.sensitive) {
                    response (Gtk.ResponseType.OK);
                }
            });

            remove_child (chooser, "<GtkBox>");
        }

        /* get a reference of the tree view, so we can grab focus later */
        var view_stack = (Gtk.Stack?)find_child_by_name (revealer.parent, "list_and_preview_box/browse_files_stack");

        tree_view = (Gtk.TreeView?)find_child_by_name (
            view_stack.get_child_by_name ("list"),
            "browse_files_swin/browse_files_tree_view"
        );

        /* remove extra unneeded widgets */
        remove_child (view_stack.parent, "preview_box");
        remove_child (chooser, "extra_and_filters");
    }

    // protected override bool key_press_event (Gdk.EventKey event) { // Match conflict dialog
    //     uint keyval;
    //     event.get_keyval (out keyval);
    //     if (keyval == Gdk.Key.Escape) {
    //         response (Gtk.ResponseType.DELETE_EVENT);
    //         return Gdk.EVENT_STOP;
    //     }

    //     return base.key_press_event (event);
    // }

    // protected void show () {
        // unowned var window = get_window ();
        // if (window == null) {
        //     return;
        // }

        // window.focus (Gdk.CURRENT_TIME);
    // }

    public void set_current_folder (string? uri) {
        try {
            var file = GLib.File.new_for_uri (uri ?? Environment.get_home_dir ());
            chooser.set_current_folder (file);
        } catch (Error e) {
                warning ("Could not set current folder. %s", e.message);
        }
    }

    public void set_current_name (string text) {
        chooser.set_current_name (text);
        entry.grab_focus ();
    }

    public string get_uri () {
        return chooser.get_file ().get_uri ();
    }

    public void set_uri (string uri) {
        try {
            chooser.set_file (GLib.File.new_for_uri (uri));
        } catch (Error e) {
            warning ("Could not set current uri to %s", uri);
        }
    }

    public string[] get_uris () {
        string[] uris = {};
        var files_list = chooser.get_files ();
        var n_files = files_list.get_n_items ();
        for (uint i =0; i < n_files; i++) {
            uris += ((GLib.File)files_list.get_item (i)).get_uri ();
        }

        return uris;
    }

    public GLib.File get_file () {
        return chooser.get_file ();
    }

    public void add_choice (FileChooserChoice choice) {
        choices_box.append (choice);
    }

    public Variant[] get_choices () {
        Variant[] choices = {};

        var child = choices_box.get_first_child ();
        while (child != null) {
            if (child is FileChooserChoice) {
                unowned var c = (FileChooserChoice) child;
                choices += new Variant ("(ss)", c.name, c.selected);
            }
            child = child.get_next_sibling ();
        }

        return choices;
    }

    public void add_filter (Gtk.FileFilter filter) {
        var name = filter.get_filter_name ();
        var filter_list = chooser.get_filters ();
        var n_filters = filter_list.get_n_items ();
        var found = false;
        for (uint i = 0; i < n_filters; i++) {
            if (((Gtk.FileFilter)filter_list.get_item (i)).name == name) {
                found = true;
                break;
            }
        }

        if (found) {
            chooser.add_filter (filter);
            filter_box.append (name, name);
        }
    }

    public new void close () throws DBusError, IOError {
        response (Gtk.ResponseType.DELETE_EVENT);
    }

    public bool register_object (DBusConnection connection, ObjectPath handle) {
        dbus_connection = connection;
        try {
            register_id = connection.register_object<Xdp.Request> (handle, this);
        } catch (Error e) {
            critical (e.message);
            return false;
        }

        return true;
    }

    public override void dispose () {
        // int w, h;
        // get_size (out w, out h);
        settings.set_string ("last-folder-uri", chooser.get_current_folder ().get_uri ());
        settings.set ("window-size", "(ii)", get_width (), get_height ());

        if (register_id != 0 && dbus_connection != null) {
            dbus_connection.unregister_object (register_id);
        }

        base.dispose ();
    }
}
