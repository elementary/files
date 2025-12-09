/*
 * Copyright 2021 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-2.1-or-later
 */

[DBus (name = "org.freedesktop.impl.portal.Request")]
public interface Xdp.Request : Object {
    public abstract void close () throws DBusError, IOError;
}

/*
 * Implements functions supported by org.freedesktop.portal.FileChooser and in addition
 * Results keys:
 * OPEN: "writable" - as indicated by a "Read Only" checkbox. It is up to the user to honor this
 */
public class Files.FileChooserDialog : Gtk.Dialog, Xdp.Request {
    public string? parent_window { get; construct; }
    public BasicWindow file_view { get; construct; }

    public string supplied_uri { get; set; default = ""; } //used by Main.vala

    public Gtk.FileChooserAction action { get; set construct; }
    public ViewMode view_mode {
        get {
            return file_view.view_mode;
        }
    }

    public bool select_multiple {
        get {
            return file_view.selection_mode == Gtk.SelectionMode.MULTIPLE;
        }

        set {
            var mode = value ? Gtk.SelectionMode.MULTIPLE : Gtk.SelectionMode.SINGLE;
            file_view.selection_mode = mode;
        }
    }

    private Gtk.FileFilter? _filter = null;
    public Gtk.FileFilter? filter {
        get {
            return _filter;
        }

        set {
            if (value != null) {
                add_filter (filter);
            }

            _filter = value;
            filter_combo.set_active_id (value != null ? value.get_filter_name () : null);
            file_view.filter = _filter;
        }
    }

    public string accept_label {
        get {
            return accept_button.label;
        }

        set {
            warning ("set accept label");
            accept_button.label = value;
        }
    }

    public bool read_only { get; set; default = false; }

    private Gtk.TreeStore filter_model;
    private Gtk.Button accept_button;
    private Gtk.ComboBox filter_combo;
    private Gtk.Entry entry;
    private Gtk.Box choices_box;
    private Gtk.Box user_choices_box;
    private Gtk.Box filter_box;

    private uint register_id = 0;
    private DBusConnection? dbus_connection = null;

    private Settings settings;

    public FileChooserDialog (
        Gtk.FileChooserAction action,
        string? parent_window,
        string title
    ) {
        Object (
            parent_window: parent_window,
            action: action,
            title: title
        );
    }

    construct {
        use_header_bar = 1; // Stop native action area showing
        settings = new Settings ("io.elementary.files.file-chooser");
        int width, height;
        settings.get ("window-size", "(ii)", out width, out height);

        default_height = height;
        default_width = width;

        file_view = new BasicWindow ();
        this.set_titlebar (file_view.headerbar);
        get_content_area ().add (file_view);

        var cancel_button = new Gtk.Button.with_label (_("Cancel"));

        accept_button = new Gtk.Button () {
            use_underline = true,
            can_default = true
        };
        accept_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        switch (action) {
            case OPEN:
                accept_label = _("Open");
                break;
            case SAVE:
                accept_label = _("Save");
                break;
            case SELECT_FOLDER:
                accept_label = _("Select");
                break;
            case CREATE_FOLDER:
                accept_label = _("Create Folder");
                break;
            default:
                assert_not_reached ();
        }

        filter_model = new Gtk.TreeStore (2, typeof (string), typeof (Gtk.FileFilter));
        filter_combo = new Gtk.ComboBox.with_model (filter_model) {
            id_column = 0
        };

        var renderer = new Gtk.CellRendererText ();
        filter_combo.pack_start (renderer, true);
        filter_combo.add_attribute (renderer, "text", 0);
        filter_combo.active = 0;

        filter_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            hexpand = true,
            halign = START,
            margin = 6
        };
        filter_box.pack_start (filter_combo);

        filter_combo.changed.connect (() => {
            Gtk.FileFilter? f = filter_from_id (filter_combo.active_id);
            if (filter != f) {
                filter = f;
            }
        });

        //Also used to hold entry and read-only checkbox
        choices_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            halign = Gtk.Align.START,
            margin = 6
        };
        user_choices_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12) {
            halign = Gtk.Align.START,
            margin = 6
        };

        choices_box.pack_start (user_choices_box);

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

            choices_box.pack_start (entry_label);
            choices_box.pack_start (entry);

            entry.changed.connect (check_can_accept);
        } else if (action == Gtk.FileChooserAction.OPEN) {
            var read_only_check = new Gtk.CheckButton.with_label (
                select_multiple ? _("Open Files as Read Only") : _("Open File as Read Only")
            ) {
                margin_start = 6
            };

            notify["select-multiple"].connect (() => {
                read_only_check.label = select_multiple ? _("Open Files as Read Only") : _("Open File as Read Only");
            });

            read_only_check.bind_property ("active", this, "read-only");
            choices_box.pack_start (read_only_check);
        }

        //TODO Add choices from options

        var action_box = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL) {
            layout_style = Gtk.ButtonBoxStyle.END,
            spacing = 6,
            margin = 6,
            hexpand = true,
        };

        action_box.pack_end (cancel_button);
        action_box.pack_end (accept_button);

        var grid = new Gtk.Box (HORIZONTAL, 6);
        grid.add (filter_box);
        grid.add (choices_box);
        grid.add (action_box);
        grid.show_all ();

        get_content_area ().add (grid);

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
                if (action == SELECT_FOLDER) {
                    // Only show folders
                    var filter_folder = new Gtk.FileFilter ();
                    filter_folder.add_mime_type ("inode/directory");
                    filter_folder.set_filter_name ("Folders");
                    add_filter (filter_folder);
                }
            } else {
                // We honor the user requested filters
            }

            if (action == Gtk.FileChooserAction.SAVE) {
                entry.grab_focus ();
            } else {
                grab_focus ();
            }

            file_view.file_activated.connect (activate_selected_items);
            file_view.selection_changed.connect (check_can_accept);
        });

        cancel_button.clicked.connect (() => response (Gtk.ResponseType.CANCEL));
        accept_button.clicked.connect (() => response (Gtk.ResponseType.OK));


        var granite_settings = Granite.Settings.get_default ();
        var gtk_settings = Gtk.Settings.get_default ();

        gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;

        granite_settings.notify["prefers-color-scheme"].connect (() => {
            gtk_settings.gtk_application_prefer_dark_theme = granite_settings.prefers_color_scheme == Granite.Settings.ColorScheme.DARK;
        });

        warning ("after construct, current folder uri is %s", get_current_folder_uri ());

        show_all ();
    }

    private void check_can_accept () {
        uint n_selected = 0;
        bool folder_selected = false, file_selected = false, can_accept = false;
        file_view.get_selection_details (out n_selected, out folder_selected, out file_selected);
        switch (action) {
            case OPEN:
                can_accept = file_selected && !folder_selected;
                break;
            case SAVE:
                // Do not need to select anything to save
                if (n_selected == 1 && file_selected) {
                    entry.text = get_file ().get_basename ();
                }

                can_accept = n_selected <= 1 && !folder_selected && entry.text != "";
                warning ("SAVE accept %s", can_accept.to_string ());
                break;
            case SELECT_FOLDER:
                can_accept = n_selected == 0 ||
                            (n_selected == 1 && !file_selected && folder_selected);
                break;
            default:
                break;
        }

        accept_button.sensitive = can_accept;
    }

    private Gtk.FileFilter? filter_from_id (string id) {
        Gtk.FileFilter? return_filter = null;
        Gtk.FileFilter? _filter = null;
        string? _id = null;
        filter_model.@foreach ((model, path, iter) => {
            model.@get (iter, 0, out _id, 1, out _filter);
            if (id == _id) {
                return_filter = _filter;
                return true;
            }

            return false;
        });

        return return_filter;
    }

    //TODO Pass on with "file activated"?
    private void activate_selected_items () {
        unowned var selected = file_view.selected_files;
        var file = selected.first ().data;
        var only_one = (selected.first ().next) == null;
        if (only_one && file.is_folder ()) {
            set_current_folder_uri (file.uri);
        } else if (only_one || select_multiple) {
            response (Gtk.ResponseType.OK);
        }
    }

    // public bool set_initial_location (GLib.File? loc) {
    //     return file_view.set_location (loc, ViewMode.LIST); //TODO Make setting and implement other modes
    // }

    protected override bool key_press_event (Gdk.EventKey event) { // Match conflict dialog
        uint keyval;
        event.get_keyval (out keyval);
        if (keyval == Gdk.Key.Escape) {
            response (Gtk.ResponseType.CANCEL);
            return Gdk.EVENT_STOP;
        }

        return base.key_press_event (event);
    }

    protected override void show () {
        base.show ();

        unowned var window = get_window ();
        if (window == null) {
            return;
        }

        window.focus (Gdk.CURRENT_TIME);
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
        int w, h;
        get_size (out w, out h);
        settings.set_string ("last-folder-uri", get_current_folder_uri ());
        settings.set ("window-size", "(ii)", w, h);

        if (register_id != 0 && dbus_connection != null) {
            dbus_connection.unregister_object (register_id);
        }

        base.dispose ();
    }

    public GLib.File? get_file () {
        unowned var selected_files = file_view.selected_files;
        GLib.File? gfile = null;
        if (selected_files != null) {
            gfile = selected_files.first ().data.location;
        }

        return gfile;
    }

    public void add_choice (FileChooserChoice choice) {
        user_choices_box.add (choice);
    }

    public unowned string get_choice (string id) {
        foreach (var w in choices_box.get_children ()) {
            unowned var c = (FileChooserChoice) w;
            if (c.id == id) {
                return c.selected;
            }
        }

        return null;
    }

    public Variant[] get_choices () {
        Variant[] choices = {};

        if (choices_box.visible) {
            user_choices_box.get_children ().foreach ((w) => {
                unowned var c = (FileChooserChoice) w;
                choices += new Variant ("(ss)", c.name, c.selected);
            });
        }

        return choices;
    }

    public void add_filter (Gtk.FileFilter? new_filter) {
        if (new_filter == null) {
            return;
        }

        var name = new_filter.get_filter_name ();
        if (filter_from_id (name) == null) {
            Gtk.TreeIter? iter = null;
            filter_model.append (out iter, null);
            filter_model.@set (iter, 0, name, 1, new_filter);
            filter_box.visible = true;
            filter_combo.active = 0;
        }
    }

    public string get_current_name () {
        if (entry != null) {
            return entry.text;
        } else {
            return "";
        }
    }

    public string? get_current_folder_uri () {
        return file_view.uri;
    }

    public string get_uri () { // Uri of selected file
        string uri = "";
        switch (action) {
            case OPEN:
                var file = get_file ();
                uri = file != null ? file.get_uri () : null;
                break;
            case SAVE:
                uri = Path.build_filename (get_current_folder_uri (), entry.text);
                break;
            case SELECT_FOLDER:
                var file = get_file ();
                uri = file != null ? file.get_uri () : get_current_folder_uri ();
                //TODO return uri of selected folder or current folder if none selected (?)
                break;
            case CREATE_FOLDER:
                //TODO What should return here?
                break;
        }

        return uri;
    }

    public string[] get_uris () { // Selected uris
        string[] uris = {};
        switch (action) {
            case OPEN:
                unowned var selection = file_view.selected_files;
                if (selection != null) {
                    selection.foreach ((file) => {
                        uris += file.uri;
                    });
                }
                break;
            case SAVE:
                uris += get_uri ();
                break;
            case SELECT_FOLDER:
                uris += get_uri ();
                break;
            case CREATE_FOLDER:
                //TODO What should return here?
                break;
        }


        return uris;
    }

    public void set_uri (string uri) { // Select file at uri
    warning ("FCD set uri to %s", uri);
        var file = GLib.File.new_for_uri (uri);
        if (file.query_exists ()) {
            file_view.set_selected_location (file);
            warning ("exists");
        } else {
            set_current_folder_uri (""); // default location
            warning ("not exists");
        }
    }

    public void set_current_folder_uri (string uri) { //Navigate to this folder
    warning ("setting current folder uri to %s", uri);
        if (uri == "") {
            var last_uri = settings.get_string ("last-folder-uri");
            if (last_uri == "") {
                last_uri = Environment.get_home_dir ();
            }

            warning ("using fallback");
            file_view.path_change (last_uri);
        } else {
            file_view.path_change (uri);
        }
    }

    public void set_current_folder (string path) {
        set_current_folder_uri (path);
    }

    public void set_current_name (string text) {
        if (action == SAVE) {
            entry.text = text;
        }
    }

    // public void set_current_folder (GLib.File folder) {
    //     set_current_folder_uri (folder.get_uri ());
    // }

    public SList<unowned Gtk.FileFilter> list_filters () {
        SList<unowned Gtk.FileFilter> list = null;
        filter_model.@foreach ((model, path, iter) => {
            Gtk.FileFilter? _filter;
            model.@get (iter, 1, out _filter);
            list.append (_filter);
            return false;
        });

        return list.copy ();
    }
}
