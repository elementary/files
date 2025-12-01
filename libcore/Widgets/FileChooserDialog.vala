/*
 * Copyright 2021 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

[DBus (name = "org.freedesktop.impl.portal.Request")]
public interface Xdp.Request : Object {
    public abstract void close () throws DBusError, IOError;
}

public class Files.FileChooserDialog : Gtk.Dialog, Xdp.Request {
    // public signal void response (Gtk.ResponseType response);

    public string? parent_window { get; construct; }
    public BasicViewContainer content { get; construct; }
    public Hdy.HeaderBar headerbar;
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
            return content.dir_view.get_selection_mode () == Gtk.SelectionMode.MULTIPLE;
        }

        set {
            // FileChooser is expected to select at least one item
            var mode = value ? Gtk.SelectionMode.MULTIPLE : Gtk.SelectionMode.SINGLE;
            content.dir_view.set_selection_mode (mode);
        }
    }

    private Gtk.FileFilter? _filter;
    public Gtk.FileFilter? filter {
        get {
            return _filter;
        }

        set {
            if (value != null) {
                add_filter (filter);
            }

            _filter = value;
            filter_box.set_active_id (value != null ? value.get_filter_name () : null);
            content.dir_view.set_filter (value);

            // message_label.label = value != null ? value.to_gvariant ().print (false) : "Null filter";
        }
    }

    private SList<Gtk.FileFilter> filter_list;

    // private Hdy.HeaderBar header;
    // private View.Chrome.BasicLocationBar location_bar;
    private BasicWindow chooser;
    // private FileChooserWidget chooser;
    // private Gtk.TreeView tree_view;
    // private BasicWindow window;

    private Gtk.Button accept_button;
    private Gtk.ComboBoxText filter_box;
    private Gtk.Entry entry;

    private Gtk.Box choices_box;
    private Gtk.Box extra_box;

    public Gtk.Label message_label;

    // private Queue<string> previous_paths;
    // private Queue<string> next_paths;
    // private string? current_path = null;
    // private bool previous_button_clicked = false;
    // private bool next_button_clicked = false;

    private uint register_id = 0;
    private DBusConnection? dbus_connection = null;

    private Settings settings;

    public FileChooserDialog (Gtk.FileChooserAction action, string? parent_window, string title) {
        Object (
            parent_window: parent_window,
            action: action,
            title: title
        );
    }


    construct {
        Hdy.init ();
        decorated=false;
        modal = true;
        set_default_size (600, 400);
        chooser = new BasicWindow ();
        get_content_area ().add (chooser);
        // previous_paths = new Queue<string> ();
        // next_paths = new Queue<string> ();
        // Hdy.init ();

        // chooser = new Files.FileChooserWidget (action) {
        //     vexpand = true
        // };
        // location_bar = new View.Chrome.BasicLocationBar ();

        // var previous_button = new Gtk.Button.from_icon_name ("go-previous-symbolic", Gtk.IconSize.LARGE_TOOLBAR) {
        //     tooltip_markup = _("Previous"),
        //     sensitive = false
        // };
        // previous_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        // var next_button = new Gtk.Button.from_icon_name ("go-next-symbolic", Gtk.IconSize.LARGE_TOOLBAR) {
        //     tooltip_markup = _("Next"),
        //     sensitive = false
        // };
        // next_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        // header = new Hdy.HeaderBar () {
        //     custom_title = location_bar,
        //     title = title
        // };
        // header.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        // header.pack_start (previous_button);
        // header.pack_start (next_button);

        // chooser = new Gtk.FileChooserWidget (action) {
        //     vexpand = true
        // };

        var cancel_button = new Gtk.Button.with_label (_("Cancel"));
        accept_button = new Gtk.Button () {
            use_underline = true,
            can_default = true
        };
        accept_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        filter_box = new Gtk.ComboBoxText ();

        extra_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            hexpand = true,
            halign = START,
            margin = 6
        };
        extra_box.pack_start (filter_box);
        if (action == SAVE) {
            entry = new Gtk.Entry () {
                placeholder_text = _("Enter name of file to save"),
                width_chars = 50,
                input_purpose = URL
            };

            var entry_label = new Gtk.Label (_("Name:")) {
                hexpand = false,
                halign = CENTER
            };
            entry_label.get_style_context ().add_class (Granite.STYLE_CLASS_PRIMARY_LABEL);

            extra_box.add (entry_label);
            extra_box.add (entry);
        }

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

        // action_box.pack_start (extra_box);
        // action_box.set_child_secondary (extra_box, true);
        action_box.pack_end (cancel_button);
        action_box.pack_end (accept_button);


        choices_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            halign = Gtk.Align.START,
            margin = 6
        };

        message_label = new Gtk.Label ("No Message");
        var grid = new Gtk.Box (HORIZONTAL, 6);
        // grid.add (header);
        // grid.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        // grid.add (chooser);
        // grid.add (new Gtk.Separator (Gtk.Orientation.HORIZONTAL));
        grid.add (message_label);
        grid.add (choices_box);
        grid.add (extra_box);
        grid.add (action_box);
        grid.show_all ();

        get_content_area ().add (grid);
        // add_extra_widget (grid);

        // setup_chooser ();

        settings = new Settings ("io.elementary.files.file-chooser");
        int width, height;
        settings.get ("window-size", "(ii)", out width, out height);

        type_hint = Gdk.WindowTypeHint.DIALOG;
        default_height = height;
        default_width = width;
        can_focus = true;

        realize.connect (() => {
            if (parent_window != "") {
                var parent = ExternalWindow.from_handle (parent_window);
                if (parent == null) {
                    warning ("Failed to associate portal window with parent window %s", parent_window);
                } else {
                    parent.set_parent_of (get_window ());
                }
            }

            if (list_filters ().length () == 0) {
                filter_box.visible = false;
            } else if (filter_box.active_id == null) {
                filter_box.active = 0;
            }

            if (choices_box.get_children ().length () == 0) {
                choices_box.visible = false;
            }

            if (action == Gtk.FileChooserAction.SAVE) {
                entry.grab_focus ();
            } else {
                grab_focus ();
            }
        });

        // previous_button.clicked.connect (() => {
        //     previous_button_clicked = true;
        //     chooser.set_current_folder_uri (previous_paths.pop_head ());
        // });

        // next_button.clicked.connect (() => {
        //     next_button_clicked = true;
        //     chooser.set_current_folder_uri (next_paths.pop_head ());
        // });

        // location_bar.path_change_request.connect ((path) => {
        //     chooser.set_current_folder_uri (path);
        // });

        filter_box.changed.connect (() => {
            Gtk.FileFilter? f = null;
            if (filter_box.active_id != null) {
                f = filter_list.search<string> (
                    filter_box.active_id,
                    (a, b) => strcmp (a.get_filter_name (), b)
                ).data;
            }

            filter = f;
        });

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

        // chooser.current_folder_changed.connect_after (() => {
        //     var previous_path = current_path;
        //     current_path = chooser.get_current_folder_uri () ?? Environment.get_home_dir ();

        //     if (previous_path != null && previous_path != current_path) {
        //         if (previous_button_clicked) {
        //             next_paths.push_head (previous_path);
        //         } else {
        //             previous_paths.push_head (previous_path);
        //             if (!next_button_clicked) {
        //                 next_paths.clear ();
        //             }
        //         }
        //     }

        //     previous_button.sensitive = !previous_paths.is_empty ();
        //     next_button.sensitive = !next_paths.is_empty ();
        //     previous_button_clicked = false;
        //     next_button_clicked = false;

        //     location_bar.set_display_path (current_path);
        // });

        content.dir_view.file_activated.connect (() => {
            activate_selected_items ();
        });

        cancel_button.clicked.connect (() => response (Gtk.ResponseType.CANCEL));
        accept_button.clicked.connect (() => response (Gtk.ResponseType.OK));

        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });

        set_current_folder_uri (settings.get_string ("last-folder-uri"));

        show_all ();
    }

    private void activate_selected_items () {
        var filename = get_filename ();
        var only_one = (content.dir_view.get_selected_files ().first ().next )== null;
        if (only_one && GLib.FileUtils.test (filename, FileTest.IS_DIR)) {
            content.dir_view.path_change_request (get_file (), Files.OpenFlag.DEFAULT, false);
        } else if (only_one || select_multiple) {
            response (Gtk.ResponseType.OK);
        }
    }

    // private static T find_child_by_name<T> (Gtk.Widget root, string path) requires (root is Gtk.Container) {
    //     var paths = path.has_prefix ("/") ? path[1 : path.length].split ("/") : path.split ("/");
    //     Gtk.Widget? widget = null;
    //     string name = paths[0];

    //     /* `find_custom ()` and `search ()` do not work if the element is unowned */
    //     ((Gtk.Container) root).get_children ().foreach ((w) => {
    //         if (widget == null) {
    //             if (name.has_prefix ("<")) {
    //                 var c_type = Type.from_name (name[1 : name.length - 1]);
    //                 var w_type = w.get_type ();

    //                 widget = w_type.is_a (c_type) ? w : null;
    //             } else if (w is Gtk.Buildable) {
    //                 widget = ((Gtk.Buildable) w).get_name () == name ? w : null;
    //             } else {
    //                 widget = w.name == name ? w : null;
    //             }
    //         }
    //     });

    //     if (widget != null) {
    //         if (paths.length > 1) {
    //             return find_child_by_name (widget, string.joinv ("/", paths[1 : paths.length]));
    //         } else {
    //             return (T) widget;
    //         }
    //     }

    //     warning ("cannot find child with name \"%s\" in \"%s\"", name, root.get_type ().name ());
    //     return null;
    // }

    // private void setup_chooser () {
        // Gtk.Revealer revealer = find_child_by_name (
        //     chooser,
        //     "browse_widgets_box/browse_widgets_hpaned/<GtkBox>/browse_header_revealer"
        // );

        // /* move the new folder button to HeaderBar and remove the chooser header */
        // Gtk.Stack stack = find_child_by_name (revealer.get_child (), "browse_header_stack");
        // Gtk.MenuButton new_folder_button = find_child_by_name (stack, "<GtkBox>/browse_new_folder_button");
        // new_folder_button.image = new Gtk.Image.from_icon_name ("folder-new", Gtk.IconSize.LARGE_TOOLBAR);
        // new_folder_button.parent.remove (new_folder_button);
        // header.pack_end (new_folder_button);

        // /* hide the revealer when not searching, for this to work:
        //  * 1. we need to set reveal_child during realize.
        //  * 2. we need to connect the signals after we set `reveal_child`
        //  */
        // realize.connect (() => {
        //     revealer.reveal_child = false;

        //     revealer.notify["reveal-child"].connect (() => {
        //         if (revealer.reveal_child) {
        //             revealer.reveal_child = stack.visible_child_name == "search";
        //         }
        //     });

        //     stack.notify["visible-child"].connect (() => {
        //         revealer.reveal_child = stack.visible_child_name == "search";
        //     });
        // });

        // /* move the filename entry from the chooser to the action_box */
        // if (action == Gtk.FileChooserAction.SAVE) {
        //     Gtk.Grid grid = find_child_by_name (chooser, "<GtkBox>/<GtkGrid>");
        //     grid.parent.remove (grid);
        //     grid.border_width = 0;
        //     grid.margin_top = 2;  // seems to have a better result than using Gtk.Align.CENTER

        //     extra_box.pack_start (grid);

        //     // bind the accept_button sensitivity with the entry text
        //     entry = find_child_by_name (grid, "<GtkFileChooserEntry>");
        //     entry.set_placeholder_text (_("Enter new filename"));
        //     entry.bind_property ("text-length", accept_button, "sensitive", BindingFlags.SYNC_CREATE);
        //     entry.activate.connect (() => {
        //         if (accept_button.sensitive) {
        //             response (Gtk.ResponseType.OK);
        //         }
        //     });

        //     chooser.remove (find_child_by_name (chooser, "<GtkBox>"));
        // }

        // /* get a reference of the tree view, so we can grab focus later */
        // Gtk.Stack view_stack = find_child_by_name (revealer.parent, "list_and_preview_box/browse_files_stack");

        // tree_view = find_child_by_name (
        //     view_stack.get_child_by_name ("list"),
        //     "browse_files_swin/browse_files_tree_view"
        // );

        // /* remove extra unneeded widgets */
        // view_stack.parent.remove (find_child_by_name (view_stack.parent, "preview_box"));
        // chooser.remove (find_child_by_name (chooser, "extra_and_filters"));
    // }

    protected override bool key_press_event (Gdk.EventKey event) { // Match conflict dialog
        uint keyval;
        event.get_keyval (out keyval);
        if (keyval == Gdk.Key.Escape) {
            response (Gtk.ResponseType.DELETE_EVENT);
            return Gdk.EVENT_STOP;
        }

        return base.key_press_event (event);
    }

    // protected override void quit () {
    //     response (Gtk.ResponseType.DELETE_EVENT);
    // }

    protected override void show () {
        base.show ();

        unowned var window = get_window ();
        if (window == null) {
            return;
        }

        window.focus (Gdk.CURRENT_TIME);
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

    public void add_filter (Gtk.FileFilter? new_filter) {
        if (new_filter == null) {
            return;
        }

        var name = new_filter.get_filter_name ();

        if (filter_list.search<string> (name, (a, b) => strcmp (a.get_filter_name (), b)) == null) {
            //TODO filter the view;
            filter_box.append (name, name);
            filter_list.append (new_filter);
            filter = new_filter;
        }
    }

    // public void add_filter_variant (Variant filter_variant) {

    // }

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

    public void save_and_unregister () {
    // public override void dispose () {
        int w, h;
        get_size (out w, out h);
        settings.set_string ("last-folder-uri", get_current_folder_uri ());
        settings.set ("window-size", "(ii)", w, h);

        // if (register_id != 0 && dbus_connection != null) {
            dbus_connection.unregister_object (register_id);
        // }

        // base.dispose ();
    }

    public GLib.File? get_file () {
        return content.dir_view.get_selected_files ().first ().data.location;
    }

    //TODO Complete
    public GLib.File? get_preview_file () {
        return null;
    }

    public string? get_current_folder_uri () {
        return content.uri;
    }

    public GLib.File? get_current_folder_file () {
        return content.location;
    }

    public string? get_filename () {
        var selected_file = content.dir_view.get_selected_files ().first ().data;
        if (selected_file != null) {
            try {
                return Filename.from_uri (selected_file.uri);
            } catch (Error e) {
                return null;
            }
        }

        return null;
    }

    public SList<string> get_filenames () {
        unowned var selected_files = content.dir_view.get_selected_files ();
        var return_list = new SList<string> ();
        if (selected_files != null) {
            foreach (File file in selected_files) {
                return_list.append (file.location.get_path ());
            }
        }

        return return_list;
    }

    public string get_uri () {
        var file = get_file ();
        return file != null ? file.get_uri () : null;
    }

    public string[] get_uris () {
        string[] uris = {};

        unowned var selection = content.dir_view.get_selected_files ();
        selection.foreach ((file) => {
            uris += file.uri;
        });

        return uris;
    }

    public void set_uri (string uri) {
        // uri_path_change_request (uri);
    }

    public void set_current_folder_uri (string uri) {
        // uri_path_change_request (uri);
    }

    public void set_current_name (string text) {
        if (action == SAVE) {
            entry.text = text;
        }
    }

    public void set_current_folder (string filename) {
        try {
            set_current_folder_uri (filename);
        } catch (Error e) {
            set_current_folder_uri (Environment.get_home_dir ());
        }
    }

    public SList<unowned Gtk.FileFilter> list_filters () {
        return filter_list.copy ();
    }
}
    /* Unimplemented FileChooser interface */
        // public bool create_folders { get; set; }
        // Whether a file chooser not in gtk_file_chooser_action_open mode will offer the user to create new folders.
        // public bool do_overwrite_confirmation { get; set; }
        // Whether a file chooser in gtk_file_chooser_action_save mode will present an overwrite confirmation dialog if the user selects a file name that already exists.
        // public Widget extra_widget { get; set; }
        // public FileFilter filter { get; set; }
        // public bool local_only { get; set; }
        // public Widget preview_widget { get; set; }
        // public bool preview_widget_active { get; set; }
        // public bool show_hidden { get; set; }
        // public bool use_preview_label { get; set; }
        // Methods:
        // public void add_choice (string id, string label, string[]? options, string[]? option_labels)
        // Adds a 'choice' to the file chooser.
        // public bool add_shortcut_folder (string folder) throws Error
        // Adds a folder to be displayed with the shortcut folders in a file chooser.
        // public bool add_shortcut_folder_uri (string uri) throws Error
        // Adds a folder URI to be displayed with the shortcut folders in a file chooser.
        // public unowned string get_choice (string id)
        // Gets the currently selected option in the 'choice' with the given ID.
        // public bool get_create_folders ()
        // Gets whether file choser will offer to create new folders.
        // public bool get_do_overwrite_confirmation ()
        // Queries whether a file chooser is set to confirm for overwriting when the user types a file name that already exists.
        // public unowned Widget? get_extra_widget ()
        // Gets the current extra widget; see set_extra_widget.
        // public File get_file ()
        // Gets the File for the currently selected file in the file selector.
        // public string? get_filename ()
        // Gets the filename for the currently selected file in the file selector.
        // public SList<string> get_filenames ()
        // Lists all the selected files and subfolders in the current folder of this.
        // public SList<File> get_files ()
        // Lists all the selected files and subfolders in the current folder of this as File.
        // public unowned FileFilter? get_filter ()
        // Gets the current filter; see set_filter.
        // public bool get_local_only ()
        // Gets whether only local files can be selected in the file selector.
        // public string? get_preview_filename ()
        // Gets the filename that should be previewed in a custom preview widget.
        // public string? get_preview_uri ()
        // Gets the URI that should be previewed in a custom preview widget.
        // public unowned Widget? get_preview_widget ()
        // Gets the current preview widget; see set_preview_widget.
        // public bool get_preview_widget_active ()
        // Gets whether the preview widget set by set_preview_widget should be shown for the current filename.
        // public bool get_select_multiple ()
        // Gets whether multiple files can be selected in the file selector.
        // public bool get_show_hidden ()
        // Gets whether hidden files and folders are displayed in the file selector.
        // public bool get_use_preview_label ()
        // Gets whether a stock label should be drawn with the name of the previewed file.
        // public SList<unowned FileFilter> list_filters ()
        // Lists the current set of user-selectable filters; see add_filter, remove_filter.
        // public SList<string>? list_shortcut_folder_uris ()
        // Queries the list of shortcut folders in the file chooser, as set by add_shortcut_folder_uri.
        // public SList<string>? list_shortcut_folders ()
        // Queries the list of shortcut folders in the file chooser, as set by add_shortcut_folder.
        // public void remove_choice (string id)
        // Removes a 'choice' that has been added with add_choice.
        // public void remove_filter (FileFilter filter)
        // Removes filter from the list of filters that the user can select between.
        // public bool remove_shortcut_folder (string folder) throws Error
        // Removes a folder from a file chooser’s list of shortcut folders.
        // public bool remove_shortcut_folder_uri (string uri) throws Error
        // Removes a folder URI from a file chooser’s list of shortcut folders.
        // public void select_all ()
        // Selects all the files in the current folder of a file chooser.
        // public bool select_file (File file) throws Error
        // Selects the file referred to by file.
        // public bool select_filename (string filename)
        // Selects a filename.
        // public bool select_uri (string uri)
        // Selects the file to by uri.
        // public void set_choice (string id, string option)
        // Selects an option in a 'choice' that has been added with add_choice.
        // public void set_create_folders (bool create_folders)
        // Sets whether file choser will offer to create new folders.
        // public bool set_current_folder (string filename)
        // Sets the current folder for this from a local filename.
        // public bool set_current_folder_file (File file) throws Error
        // Sets the current folder for this from a File.
        // public bool set_current_folder_uri (string uri)
        // Sets the current folder for this from an URI.
        // public void set_current_name (string name)
        // Sets the current name in the file selector, as if entered by the user.
        // public void set_do_overwrite_confirmation (bool do_overwrite_confirmation)
        // Sets whether a file chooser in gtk_file_chooser_action_save mode will present a confirmation dialog if the user types a file name that already exists.
        // public void set_extra_widget (Widget extra_widget)
        // Sets an application-supplied widget to provide extra options to the user.
        // public bool set_file (File file) throws Error
        // Sets file as the current filename for the file chooser, by changing to the file’s parent folder and actually selecting the file in list.
        // public bool set_filename (string filename)
        // Sets filename as the current filename for the file chooser, by changing to the file’s parent folder and actually selecting the file in list; all other files will be unselected.
        // public void set_filter (FileFilter filter)
        // Sets the current filter; only the files that pass the filter will be displayed.
        // public void set_local_only (bool local_only)
        // Sets whether only local files can be selected in the file selector.
        // public void set_preview_widget (Widget preview_widget)
        // Sets an application-supplied widget to use to display a custom preview of the currently selected file.
        // public void set_preview_widget_active (bool active)
        // Sets whether the preview widget set by set_preview_widget should be shown for the current filename.
        // public void set_select_multiple (bool select_multiple)
        // Sets whether multiple files can be selected in the file selector.
        // public void set_show_hidden (bool show_hidden)
        // Sets whether hidden files and folders are displayed in the file selector.
        // public bool set_uri (string uri)
        // Sets the file referred to by uri as the current file for the file chooser, by changing to the URI’s parent folder and actually selecting the URI in the list.
        // public void set_use_preview_label (bool use_label)
        // Sets whether the file chooser should display a stock label with the name of the file that is being previewed; the default is true.
        // public void unselect_all ()
        // Unselects all the files in the current folder of a file chooser.
        // public void unselect_file (File file)
        // Unselects the file referred to by file.
        // public void unselect_filename (string filename)
        // Unselects a currently selected filename.
        // public void unselect_uri (string uri)
        // Unselects the file referred to by uri.
        // Signals:
        // public signal FileChooserConfirmation confirm_overwrite ()
        // This signal gets emitted whenever it is appropriate to present a confirmation dialog when the user has selected a file name that already exists.
        // public signal void current_folder_changed ()
        // This signal is emitted when the current folder in a FileChooser changes.
        // public signal void file_activated ()
        // This signal is emitted when the user "activates" a file in the file chooser.
        // public signal void selection_changed ()
        // This signal is emitted when there is a change in the set of selected files in a FileChooser.
        // public signal void update_preview ()
        // This signal is emitted when the preview in a file chooser should be regenerated.
