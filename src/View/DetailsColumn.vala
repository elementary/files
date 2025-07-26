/*
 * SPDX-License-Identifier: GPL-2.0+
 * SPDX-FileCopyrightText: 2020-2025 elementary, Inc. (https://elementary.io)
 *
 * Authors : Andres Mendez <shiruken@gmail.com>
 */

public class Files.View.DetailsColumn : Gtk.Box {
    private Gtk.ScrolledWindow details_window;
    private GLib.Cancellable? cancellable;
    private Gtk.Box details_container;
    private Gtk.Spinner spinner;
    private Gtk.Label size_value;
    private Gtk.Label resolution_value;

    public Gtk.Grid info_grid = new Gtk.Grid () {
        column_spacing = 6,
        row_spacing = 6
    };

    public new bool has_focus {
        get {
            return details_container.has_focus;
        }
    }

    public DetailsColumn (Files.File file, Files.AbstractDirectoryView view) {
        GLib.List<Files.File> the_file_in_a_list = new GLib.List<Files.File> ();
        the_file_in_a_list.append(file);

        var preview_box = new Gtk.Box (VERTICAL, 0) {
            vexpand = true
        };

        var file_pix = file.get_icon_pixbuf (48, get_scale_factor (), Files.File.IconFlags.NONE);
        if (file_pix != null) {
            var file_icon = new Gtk.Image.from_gicon (file_pix, Gtk.IconSize.DIALOG) {
                pixel_size = 48
            };

            var file_overlay = new Gtk.Overlay () {
                child = file_icon
            };

            preview_box.pack_start (file_overlay, false, false);

            if (file.emblems_list != null) {
                int pos = 0;
                var emblem_box = new Gtk.Box (VERTICAL, 0) {
                    halign = Gtk.Align.END,
                    valign = Gtk.Align.END
                };

                foreach (string emblem_name in file.emblems_list) {
                    var emblem = new Gtk.Image.from_icon_name (emblem_name, Gtk.IconSize.BUTTON);
                    emblem_box.add (emblem);

                    pos++;
                    if (pos > 3) { /* Only room for 3 emblems */
                        break;
                    }
                }


                file_overlay.add_overlay (emblem_box);
            }
        }

        var details_box = new Gtk.Box (VERTICAL, 0) {
            vexpand = true
        };

        Gtk.Label name_key_label = make_key_label (_("Name:"));
        Gtk.Label name_value = make_value_label (file.get_display_name ());

        info_grid.attach (name_key_label, 0, 1);
        info_grid.attach_next_to (name_value, name_key_label, RIGHT);

        /** begin adapted copy-pasta from PropertiesWindow.construct_info_panel **/

        var size_key_label = make_key_label (_("Size:"));

        spinner = new Gtk.Spinner ();
        spinner.halign = Gtk.Align.START;

        Gtk.Label size_value = make_value_label ("");

        info_grid.attach (size_key_label, 0, 2, 1);
        info_grid.attach_next_to (spinner, size_key_label, RIGHT);
        info_grid.attach_next_to (size_value, size_key_label, RIGHT);

        int n = 5;

        var time_created = FileUtils.get_formatted_time_attribute_from_info (file.info,
                                                                             FileAttribute.TIME_CREATED);
        if (time_created != "") {
            var key_label = make_key_label (_("Created:"));
            var value_label = make_value_label (time_created);
            info_grid.attach (key_label, 0, n, 1, 1);
            info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
            n++;
        }

        var time_modified = FileUtils.get_formatted_time_attribute_from_info (file.info,
                                                                              FileAttribute.TIME_MODIFIED);

        if (time_modified != "") {
            var key_label = make_key_label (_("Modified:"));
            var value_label = make_value_label (time_modified);
            info_grid.attach (key_label, 0, n, 1, 1);
            info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
            n++;
        }

        if (file.is_trashed ()) {
            var deletion_date = FileUtils.get_formatted_time_attribute_from_info (file.info,
                                                                                  FileAttribute.TRASH_DELETION_DATE);
            if (deletion_date != "") {
                var key_label = make_key_label (_("Deleted:"));
                var value_label = make_value_label (deletion_date);
                info_grid.attach (key_label, 0, n, 1, 1);
                info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
                n++;
            }
        }

        var ftype = filetype (file);

        var mimetype_key = make_key_label (_("Media type:"));
        var mimetype_value = make_value_label (ftype);
        info_grid.attach (mimetype_key, 0, n, 1, 1);
        info_grid.attach_next_to (mimetype_value, mimetype_key, Gtk.PositionType.RIGHT, 3, 1);
        n++;

        // if ("image" in ftype) {
        //     var resolution_key = make_key_label (_("Resolution:"));
        //     resolution_value = make_value_label (resolution (file));
        //     info_grid.attach (resolution_key, 0, n, 1, 1);
        //     info_grid.attach_next_to (resolution_value, resolution_key, Gtk.PositionType.RIGHT, 3, 1);
        //     n++;
        // }

        var location_key = make_key_label (_("Location:"));
        var location_value = make_value_label (location (file, view));
        location_value.ellipsize = Pango.EllipsizeMode.MIDDLE;
        location_value.max_width_chars = 32;
        info_grid.attach (location_key, 0, n, 1, 1);
        info_grid.attach_next_to (location_value, location_key, Gtk.PositionType.RIGHT, 3, 1);
        n++;

        if (file.info.get_attribute_boolean (GLib.FileAttribute.STANDARD_IS_SYMLINK)) {
            var key_label = make_key_label (_("Target:"));
            var value_label = make_value_label (file.info.get_attribute_byte_string (GLib.FileAttribute.STANDARD_SYMLINK_TARGET));
            info_grid.attach (key_label, 0, n, 1, 1);
            info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
            n++;
        }

        if (file.is_trashed ()) {
            var key_label = make_key_label (_("Original Location:"));
            var value_label = make_value_label (original_location (file));
            info_grid.attach (key_label, 0, n, 1, 1);
            info_grid.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
            n++;
        }

        /** end copy-pasta from PropertiesWindow.construct_info_panel **/

        details_box.add (info_grid);

        Gtk.Button more_info_button = new Gtk.Button.with_label (_("More Info"));

        more_info_button.clicked.connect (() => {
            new View.PropertiesWindow (the_file_in_a_list, view, Files.get_active_window ());
        });
        details_box.add (more_info_button);

        details_container = new Gtk.Box (VERTICAL, 0) {
            vexpand = true
        };

        details_container.add (preview_box);
        details_container.add (details_box);

        details_window = new Gtk.ScrolledWindow (null, null) {
            child = details_container,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        orientation = Gtk.Orientation.VERTICAL;
        width_request = Files.app_settings.get_int ("minimum-sidebar-width");
        get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);
        add (details_window);

        show_all ();
    }

    /** Also an adjusted copy from PropertiesWindow **/
    public static string location (Files.File file, Files.AbstractDirectoryView view) {
        if (view.in_recent) {
            string original_location = file.get_display_target_uri ().replace ("%20", " ");
            string file_name = file.get_display_name ().replace ("%20", " ");
            string location_folder = original_location.slice (0, -file_name.length).replace ("%20", " ");
            string location_name = location_folder.slice (7, -1);

            return "<a href=\"" + Markup.escape_text (location_folder) +
                   "\">" + Markup.escape_text (location_name) + "</a>";
        } else {
            return "<a href=\"" + Markup.escape_text (file.directory.get_uri ()) +
                   "\">" + Markup.escape_text (file.directory.get_parse_name ()) + "</a>";
        }
    }

    public static string original_location (Files.File file) {
        /* print orig location of trashed files */
        if (file.info.get_attribute_byte_string (FileAttribute.TRASH_ORIG_PATH) != null) {
            var trash_orig_loc = get_common_trash_orig (file);
            if (trash_orig_loc != null) {
                var orig_pth = file.info.get_attribute_byte_string (FileAttribute.TRASH_ORIG_PATH);
                return "<a href=\"" + get_parent_loc (orig_pth).get_uri () + "\">" + trash_orig_loc + "</a>";
            }
        }
        return _("Unknown");
    }

    public static string filetype (Files.File file) {
        string ftype = file.get_ftype ();
        if (ftype != null) {
            return ftype;
        } else {
            /* show list of mimetypes only if we got a default application in common */
            if (MimeActions.get_default_application_for_file (file) != null) {
                return file.get_ftype ();
            }
        }
        return _("Unknown");
    }

    private async void get_resolution (Files.File goffile) {
        GLib.FileInputStream? stream = null;
        GLib.File file = goffile.location;
        string resolution = _("Could not be determined");

        try {
            stream = yield file.read_async (0, cancellable);
            if (stream == null) {
                error ("Could not read image file's size data");
            } else {
                var pixbuf = yield new Gdk.Pixbuf.from_stream_async (stream, cancellable);
                goffile.width = pixbuf.get_width ();
                goffile.height = pixbuf.get_height ();
                resolution = goffile.width.to_string () + " × " + goffile.height.to_string () + " px";
            }
        } catch (Error e) {
            warning ("Error loading image resolution in PropertiesWindow: %s", e.message);
        }
        try {
            stream.close ();
        } catch (GLib.Error e) {
            debug ("Error closing stream in get_resolution: %s", e.message);
        }

        resolution_value.label = resolution;
    }

    private string resolution (Files.File file) {
        if (file.width > 0) { /* resolution has already been determined */
            return file.width.to_string () + " × " + file.height.to_string () + " px";
        } else {
            /* Async function will update info when resolution determined */
            get_resolution.begin (file);
            return _("Loading…");
        }
    }

    public static string get_common_trash_orig (Files.File file) {
        GLib.File loc = get_parent_loc (file.info.get_attribute_byte_string (FileAttribute.TRASH_ORIG_PATH));
        string path = null;

        if (loc == null) {
            path = "/";
        } else {
            path = loc.get_parse_name ();
        }

        return path;
    }

    public static GLib.File? get_parent_loc (string path) {
        var loc = GLib.File.new_for_path (path);
        return loc.get_parent ();
    }
}
