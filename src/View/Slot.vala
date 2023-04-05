/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later

 * Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

public class Files.Slot : Gtk.Box, SlotInterface {
    public ViewMode view_mode { get; construct; }
    public int width { get; private set; }
    public Directory? directory { get; set; }
    public unowned Files.File? file { get { return directory != null ? directory.file : null; }}
    public unowned string uri { get { return file != null ? file.uri : ""; }}
    public Files.ViewInterface? view_interface { get; private set; }
    public int displayed_files_count {
        get {
            if (directory != null && directory.state == Directory.State.LOADED) {
                return (int)(directory.displayed_files_count);
            }

            return -1;
        }
    }

    private Gtk.Overlay overlay;
    private Gtk.Box extra_location_widgets;
    private Gtk.Box extra_action_widgets;
    private Gtk.Label empty_label;

    private int preferred_column_width;
    private uint reload_timeout_id = 0;
    private uint path_change_timeout_id = 0;

    private const string EMPTY_MESSAGE = _("This Folder Is Empty");
    private const string EMPTY_TRASH_MESSAGE = _("Trash Is Empty");
    private const string EMPTY_RECENT_MESSAGE = _("There Are No Recent Files");
    private const string DENIED_MESSAGE = _("Access Denied");

    public Slot (GLib.File? _location, ViewMode _mode) {
        Object (
            view_mode: _mode,
            orientation: Gtk.Orientation.VERTICAL,
            vexpand: true,
            hexpand: _mode != ViewMode.MULTICOLUMN
        );

        set_up_directory (_location ??
            GLib.File.new_for_commandline_arg (Environment.get_home_dir ())
        );
    }

    ~Slot () {
        //TODO Cancel timeouts when destroyed.
        debug ("Slot %s destruct", file.basename);
        while (get_last_child () != null) {
            get_last_child ().unparent ();
        }
    }

    construct {
        extra_location_widgets = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        overlay = new Gtk.Overlay () {
            hexpand = true,
            vexpand = true
        };
        extra_action_widgets = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        empty_label = new Gtk.Label ("") {
            halign = Gtk.Align.CENTER,
            valign = Gtk.Align.CENTER,
            focusable = false,
            margin_start = 48,
            margin_end = 48
        };
        empty_label.add_css_class (Granite.STYLE_CLASS_H2_LABEL);
        switch (view_mode) {
            case ViewMode.ICON:
                view_interface = new Files.GridView (this);
                break;
            case ViewMode.LIST:
                view_interface = new Files.ListView (this);
                break;
            case ViewMode.MULTICOLUMN:
                var gv = new Files.GridView (this);
                gv.grid_view.max_columns = 1;
                view_interface = gv;
                break;

            default:
                view_interface = new Files.GridView (this);
                break;
        }

        overlay.child = view_interface;
        if (view_mode == ViewMode.MULTICOLUMN) {
            preferred_column_width = Files.column_view_settings.get_int (
                "preferred-column-width"
            );
            width = preferred_column_width;
            view_interface.width_request = preferred_column_width;
        }

        view_interface.selection_changed.connect (on_view_interface_selection_changed);

        append (extra_location_widgets);
        append (overlay);
        append (extra_action_widgets);
    }

    uint selection_changed_timeout_id = 0;
    List<Files.File> selected_files = null; // Maintain a reference for overlaybar
    private void on_view_interface_selection_changed () {
        activate_action ("win.selection-changing", null);

        if (selection_changed_timeout_id > 0) {
            Source.remove (selection_changed_timeout_id);
        }

        selection_changed_timeout_id = Timeout.add (100, () => {
            selection_changed_timeout_id = 0;
            activate_action ("win.update-selection", null);
            selection_changed (selected_files); // Trash plughin listens to this.
            return Source.REMOVE;
        });
    }

    // Signal could be from subdirectory as well as slot directory
    private void connect_directory_handlers (Directory dir) {
        dir.file_added.connect (on_directory_file_added);
        dir.duplicate_added.connect (on_directory_duplicate_added);
        dir.file_changed.connect (on_directory_file_changed);
        dir.file_deleted.connect (on_directory_file_deleted);
        dir.will_reload.connect (on_directory_will_reload);
        dir.done_loading.connect (on_directory_done_loading);
    }

    private void disconnect_directory_handlers (Directory dir) {
        dir.file_added.disconnect (on_directory_file_added);
        dir.duplicate_added.disconnect (on_directory_duplicate_added);
        dir.file_changed.disconnect (on_directory_file_changed);
        dir.file_deleted.disconnect (on_directory_file_deleted);
        dir.will_reload.disconnect (on_directory_will_reload);
        dir.done_loading.disconnect (on_directory_done_loading);
    }

    // Use only for single file changes, not initial loading for performance
    private void on_directory_file_added (Directory dir, Files.File? file, bool is_internal) {
        if (file != null && !dir.is_loading ()) {
            view_interface.select_after_add = is_internal;
            view_interface.add_file (file);
        }

        //TODO Determine whether dir is loading or freespace update required.
    }

    // Could get duplicate file additions if monitor change event processed before internal change
    // The file must be selected but not added
    private void on_directory_duplicate_added (Directory dir, Files.File? file) {
        if (file != null && !dir.is_loading ()) {
            view_interface.show_and_select_file (file, true, false, false);
        }
    }

    private void on_directory_file_changed (Directory dir, Files.File file) {
        if (file.location.equal (dir.file.location)) {
            /* The slot directory has changed - it can only be the properties */
        } else {
            view_interface.file_changed (file);
        }
    }

    public void on_directory_file_deleted (Directory dir, Files.File file) {
        /* The deleted file could be the whole directory */
        file.exists = false;
        view_interface.file_deleted (file);

        if (file.get_thumbnail_path () != null) {
            FileUtils.remove_thumbnail_paths_for_uri (file.uri);
        }

        if (plugins != null) {
            plugins.update_file_info (file);
        }

        // handle_free_space_change (); //TODO Reimplement in Gtk4
    }

    // Only receives this when another entity will initiate the reload
    private void on_directory_will_reload (Directory dir) {
        view_interface.clear ();
        directory.file_added.disconnect (on_directory_file_added);
        dir.done_loading.connect (on_directory_done_loading);
        activate_action ("win.loading-uri", "s", dir.file.uri);
    }

    private void on_directory_done_loading () {
        // Ensure all windows updated
        view_interface.add_files (directory.get_files ());
        directory.file_added.connect (on_directory_file_added);
        // Directory is only loaded once (unless reloaded);
        directory.done_loading.disconnect (on_directory_done_loading);
        activate_action ("win.loading-finished", null);
    }

    public void change_path (GLib.File location) {
        view_interface.clear ();
        set_up_directory (location);
    }

    private void set_up_directory (GLib.File loc) {
        if (directory != null) {
            disconnect_directory_handlers (directory);
        }

        directory = Directory.from_gfile (loc);
        connect_directory_handlers (directory);
    }

    public async bool initialize_directory (List<Files.File> selected_locations = null) {
        if (directory.is_loading ()) {
            // Can occur restoring duplicate tabs
            warning (
                "Slot.initialize_directory () called when directory already loading - ignoring"
            );
            return false;
        }

        directory.file_added.disconnect (on_directory_file_added);
        //NOTE activate_action does not work in async function ??
        yield directory.init ();

        if (!directory.can_load) {
            return false;
        }
        if (file.is_recent_uri_scheme ()) {
            view_interface.sort_type = Files.SortType.MODIFIED;
            view_interface.sort_reversed = false;
        } else if (this.directory.file.info != null) {
            view_interface.sort_type = this.directory.file.sort_type;
            view_interface.sort_reversed = this.directory.file.sort_reversed;
        }

        if (directory.is_empty ()) { /* No files in the file cache */
            empty_label.label = get_empty_message ();
            if (empty_label.parent == null) {
                overlay.add_overlay (empty_label);
                //Expand column to accomodate label
                overlay.set_measure_overlay (empty_label, true);
            }
        } else {
            if (empty_label.parent == overlay) {
                overlay.remove_overlay (empty_label);
            }

            if (selected_locations != null) {
                view_interface.select_files (selected_locations);
            } else if (directory.selected_file != null) {
                if (directory.selected_file.query_exists ()) {
                    view_interface.show_and_select_file (
                        Files.File.@get (directory.selected_file),
                        true,
                        true
                    );
                }
            } else {
                view_interface.set_vadj_val (0.0); /* Does not select */
            }
        }

        return true;
    }

    public void set_sort (Files.SortType sort_type) {
        view_interface.sort_type = sort_type;
        directory.file.set_sort (sort_type, Files.is_admin ()); // Sets metadata
    }

    public void set_reversed (bool reversed) {
        view_interface.sort_reversed = reversed;
        directory.file.set_reversed (reversed, Files.is_admin ()); // Sets metadata
    }

    public void reload () {
        directory.done_loading.connect (on_directory_done_loading);
        directory.schedule_reload ();
    }

    public override bool set_all_selected (bool select_all) {
        if (view_interface != null) {
            if (select_all) {
                view_interface.select_all ();
            } else {
                view_interface.unselect_all ();
            }
            return true;
        } else {
            return false;
        }
    }

    public List<Files.File> get_selected_files () {
        List<Files.File> selected_files = null;
        if (view_interface != null) {
            view_interface.get_selected_files (out selected_files);
        }

        return (owned)selected_files;
    }

    public void select_glib_files (GLib.List<GLib.File> locations, GLib.File? focus_location) {
        if (view_interface != null) {
            var files_to_select = new List<Files.File> ();
            locations.@foreach ((loc) => {
                files_to_select.prepend (Files.File.@get (loc));
            });

            var focus_after_select = focus_location != null ? focus_location.dup () : null;

            view_interface.select_files (files_to_select);
            if (focus_after_select != null) {
                view_interface.show_and_select_file (
                    Files.File.@get (focus_after_select), false, false, true
                );
            }
        }
    }

    public void select_gof_file (Files.File gof) {
        if (view_interface != null) {
            view_interface.show_and_select_file (gof, true, false, false);
        }
    }

    public void show_first_item () {
        if (view_interface != null) {
            view_interface.show_and_select_file (null, false, false, true);
        }
    }

    public void set_active_state (bool set_active, bool animate = true) {
        //TODO Reimplement if needed
    }

    public new void grab_focus () {
        if (view_interface != null) {
            view_interface.grab_focus ();
        }
    }

    public void zoom_in () {
        view_interface.zoom_in ();
    }

    public void zoom_out () {
        view_interface.zoom_out ();
    }

    public void zoom_normal () {
        view_interface.zoom_normal ();
    }

    public void close () {
        // Need to reduce references to one if poss
        cancel_timeouts ();
        if (directory != null) {
            directory.cancel ();
            disconnect_directory_handlers (directory);
        }

        view_interface.unparent ();
        view_interface.destroy ();
        view_interface = null;
    }

    public void refresh_files () {
        if (directory != null) {
            directory.update_files ();
        }
    }

    public FileInfo? lookup_file_info (GLib.File loc) {
        Files.File? gof = directory.file_hash_lookup_location (loc);
        if (gof != null) {
            return gof.info;
        } else {
            return null;
        }
    }

    private void cancel_timeouts () {
        cancel_timeout (ref reload_timeout_id);
        cancel_timeout (ref path_change_timeout_id);
        cancel_timeout (ref selection_changed_timeout_id);
    }

    private void cancel_timeout (ref uint id) {
        if (id > 0) {
            Source.remove (id);
            id = 0;
        }
    }

    public string get_empty_message () {
        string msg = EMPTY_MESSAGE;
        if (directory.is_recent) {
            msg = EMPTY_RECENT_MESSAGE;
        } else if (directory.is_trash && (uri == Files.TRASH_URI + Path.DIR_SEPARATOR_S)) {
            msg = EMPTY_TRASH_MESSAGE;
        } else if (directory.permission_denied) {
            msg = DENIED_MESSAGE;
        }

        return msg;
    }
}
