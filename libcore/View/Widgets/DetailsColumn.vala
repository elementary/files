/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2020-2025 elementary, Inc. (https://elementary.io)
 *
 * Authors : Andres Mendez <shiruken@gmail.com>
 */

public class Files.View.DetailsColumn : Gtk.Box {
    public int width {
        get {
            return PREVIEW_SIZE + 2 * PREVIEW_H_MARGIN;
        }
    }

    public Files.File file { get; construct; }
    public Files.AbstractDirectoryView view { get; construct; }

    private const int PREVIEW_SIZE = 512;
    private const int PREVIEW_H_MARGIN = 24;
    private const int MAX_PREVIEW_FILE_SIZE = 2 * 8 * 1024 * 1024; // 2MB
    private GLib.Cancellable? cancellable;
    private Gtk.Label resolution_value;
    private bool previewing_text = false;

    public DetailsColumn (Files.File file, Files.AbstractDirectoryView view) {
        Object (
            file: file,
            view: view
        );
    }

    construct {
        var file_real_size = PropertiesWindow.file_real_size (file);

        var info_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6
        };

        var file_image = new Gtk.Image () {
            hexpand = true,
            vexpand = true,
            halign = CENTER,
            valign = CENTER
        };
        file_image.get_style_context ().add_class (Granite.STYLE_CLASS_CARD);
        file_image.get_style_context ().add_class (Granite.STYLE_CLASS_CHECKERBOARD);

        var file_text = new Gtk.TextView () {
            cursor_visible = false,
            editable = false,
            top_margin = 12,
            bottom_margin = 12,
            left_margin = 12,
            right_margin = 12,
        };

        Gdk.Pixbuf? ico_pix = file.get_icon_pixbuf (
            PREVIEW_SIZE, get_scale_factor (), Files.File.IconFlags.NONE
        );

        if (ico_pix != null) {
            file_image.gicon = ico_pix;
            file_image.pixel_size = 48;
        }

        // overwriting, yes, but easier on the boolean
        if (file.is_readable () && file_real_size <= MAX_PREVIEW_FILE_SIZE) {
            var filename = file.location.get_path ();

            if (file.is_image ()) {
                file_image.gicon = new FileIcon (file.location);
                file_image.pixel_size = PREVIEW_SIZE;

            // thanks to https://wiki.gnome.org/Projects/Vala/PopplerSample
            } else if (file.is_pdf ()) {
                try {
                    var doc = new Poppler.Document.from_file (
                        Filename.to_uri (filename), null
                    );

                    var page = doc.get_page (0); //TODO: multi-page?

                    var surface = new Cairo.ImageSurface (
                        Cairo.Format.ARGB32, PREVIEW_SIZE, PREVIEW_SIZE
                    );

                    var ctx = new Cairo.Context (surface);
                    ctx.set_source_rgb (255, 255, 255);
                    ctx.paint ();
                    ctx.scale (0.5, 0.5); //TODO: I just eye-balled this
                    page.render (ctx);
                    ctx.restore ();

                    var pdf_pix = Gdk.pixbuf_get_from_surface (
                        surface, 0, 0, PREVIEW_SIZE, PREVIEW_SIZE
                    );

                    file_image.set_from_pixbuf (pdf_pix);
                } catch (Error e) {
                    warning ("Error: %s\n", e.message);
                }
            } else if (file.is_text ()) {
                try {
                    previewing_text = true;
                    uint8[] contents;
                    string etag_out;
                    file.location.load_contents (null, out contents, out etag_out);

                    var buffer = file_text.get_buffer ();
                    buffer.set_text ((string) contents);
                } catch (Error e) {
                    warning ("Error: %s\n", e.message);
                }
            }
        }

        var name_key_label = make_key_label (_("Name:"));
        var name_value = make_value_label (file.get_display_name ());

        /** begin adapted copy-pasta from PropertiesWindow.construct_info_panel **/
        var size_key_label = make_key_label (_("Size:"));
        var spinner = new Gtk.Spinner () {
            halign = START
        };

        var size_value = make_value_label ("");
        size_value.label = GLib.format_size (file_real_size);

        info_grid.attach (name_key_label, 0, 1);
        info_grid.attach_next_to (name_value, name_key_label, RIGHT);
        info_grid.attach (size_key_label, 0, 2, 1);
        info_grid.attach_next_to (spinner, size_key_label, RIGHT);
        info_grid.attach_next_to (size_value, size_key_label, RIGHT);

        var time_created = FileUtils.get_formatted_time_attribute_from_info (
            file.info,
            FileAttribute.TIME_CREATED
        );

        int n = 5;
        if (time_created != "") {
            var key_label = make_key_label (_("Created:"));
            var value_label = make_value_label (time_created);
            info_grid.attach (key_label, 0, n, 1, 1);
            info_grid.attach_next_to (value_label, key_label, RIGHT, 3, 1);
            n++;
        }

        var time_modified = FileUtils.get_formatted_time_attribute_from_info (
            file.info,
            FileAttribute.TIME_MODIFIED
        );

        if (time_modified != "") {
            var key_label = make_key_label (_("Modified:"));
            var value_label = make_value_label (time_modified);
            info_grid.attach (key_label, 0, n, 1, 1);
            info_grid.attach_next_to (value_label, key_label, RIGHT, 3, 1);
            n++;
        }

        if (file.is_trashed ()) {
            var deletion_date = FileUtils.get_formatted_time_attribute_from_info (
                file.info,
                FileAttribute.TRASH_DELETION_DATE
            );

            if (deletion_date != "") {
                var key_label = make_key_label (_("Deleted:"));
                var value_label = make_value_label (deletion_date);
                info_grid.attach (key_label, 0, n, 1, 1);
                info_grid.attach_next_to (value_label, key_label, RIGHT, 3, 1);
                n++;
            }
        }

        var ftype = filetype (file);
        var mimetype_key = make_key_label (_("Media type:"));
        var mimetype_value = make_value_label (ftype);
        info_grid.attach (mimetype_key, 0, n, 1, 1);
        info_grid.attach_next_to (mimetype_value, mimetype_key, RIGHT, 3, 1);
        n++;

        if (file.is_image ()) {
            var resolution_key = make_key_label (_("Resolution:"));
            resolution_value = make_value_label (resolution (file));
            info_grid.attach (resolution_key, 0, n, 1, 1);
            info_grid.attach_next_to (resolution_value, resolution_key, RIGHT, 3, 1);
            n++;
        }

        if (file.info.get_attribute_boolean (GLib.FileAttribute.STANDARD_IS_SYMLINK)) {
            var key_label = make_key_label (_("Target:"));
            var value_label = make_value_label (
                file.info.get_attribute_byte_string (GLib.FileAttribute.STANDARD_SYMLINK_TARGET)
            );
            info_grid.attach (key_label, 0, n, 1, 1);
            info_grid.attach_next_to (value_label, key_label, RIGHT, 3, 1);
            n++;
        }

        if (file.is_trashed ()) {
            var key_label = make_key_label (_("Original Location:"));
            var value_label = make_value_label (original_location (file));
            info_grid.attach (key_label, 0, n, 1, 1);
            info_grid.attach_next_to (value_label, key_label, RIGHT, 3, 1);
            n++;
        }

        var more_info_button = new Gtk.Button.with_label (_("Properties…")) {
            halign = END
        };

        var info_window = new Gtk.ScrolledWindow (null, null) {
            child = info_grid,
            propagate_natural_height = true,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        if (previewing_text) {
            var text_window = new Gtk.ScrolledWindow (null, null) {
                child = file_text,
                width_request = PREVIEW_SIZE,
                height_request = PREVIEW_SIZE,
                max_content_height = PREVIEW_SIZE,
                max_content_width = PREVIEW_SIZE
            };

            add (text_window);
        } else {
            add (file_image);
        }

        orientation = VERTICAL;
        spacing = 12;
        margin_top = 12;
        margin_bottom = 12;
        margin_start = 12;
        margin_end = 12;
        add (info_window);
        add (more_info_button);

        show_all ();

        more_info_button.clicked.connect (() => {
            var the_file_in_a_list = new GLib.List<Files.File> ();
            the_file_in_a_list.append (file);
            new View.PropertiesWindow (the_file_in_a_list, view);
        });
    }

    /** Also an adjusted copy from PropertiesWindow **/
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
        var file = goffile.location;
        var resolution = _("Could not be determined");

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
