/* Copyright (c) 2018 elementary LLC (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

public class Marlin.FileConflictDialog : Gtk.Dialog {
    public string new_name {
        owned get {
            return rename_entry.text;
        }
    }

    public bool apply_to_all {
        get {
            return apply_all_checkbutton.active;
        }
    }

    public enum ResponseType {
        SKIP,
        RENAME,
        REPLACE,
        NEWEST
    }

    private string conflict_name;
    private Gtk.Entry rename_entry;
    private Gtk.Button replace_button;
    private Gtk.Button keep_newest_button;
    private Gtk.CheckButton apply_all_checkbutton;

    private GOF.File source;
    private GOF.File destination;
    private GOF.File dest_dir;

    private Gtk.Label primary_label;
    private Gtk.Label secondary_label;

    private Gtk.Image source_image;
    private Gtk.Label source_size_label;
    private Gtk.Label source_type_label;
    private Gtk.Label source_time_label;

    private Gtk.Image destination_image;
    private Gtk.Label destination_size_label;
    private Gtk.Label destination_type_label;
    private Gtk.Label destination_time_label;

    public FileConflictDialog (Gtk.Window parent, GLib.File _source, GLib.File _destination, GLib.File _dest_dir) {
        Object (
            title: _("File conflict"),
            transient_for: parent,
            deletable: false,
            resizable: false,
            skip_taskbar_hint: true
        );

        source = GOF.File.@get (_source);
        destination = GOF.File.@get (_destination);
        destination.query_update ();
        var thumbnailer = Marlin.Thumbnailer.get ();
        thumbnailer.finished.connect (() => {
            destination_image.gicon = destination.get_icon_pixbuf (64, get_scale_factor (),
                                                                   GOF.File.IconFlags.USE_THUMBNAILS);
        });

        thumbnailer.queue_file (destination, null, false);
        destination_size_label.label = destination.format_size;
        destination_time_label.label = destination.formated_modified;

        dest_dir = GOF.File.@get (_dest_dir);

        var files = new GLib.List<GOF.File> ();
        files.prepend (source);
        files.prepend (destination);
        files.prepend (dest_dir);

        new GOF.CallWhenReady (files, file_list_ready_cb);
    }

    construct {
        set_border_width (6);

        var image = new Gtk.Image.from_icon_name ("dialog-warning", Gtk.IconSize.DIALOG) {
            valign = Gtk.Align.START
        };

        primary_label = new Gtk.Label (null) {
            selectable = true,
            max_width_chars = 50,
            wrap = true,
            xalign = 0
        };

        primary_label.get_style_context ().add_class (Granite.STYLE_CLASS_PRIMARY_LABEL);

        secondary_label = new Gtk.Label (null) {
            use_markup = true,
            selectable = true,
            max_width_chars = 50,
            wrap = true,
            xalign = 0
        };

        destination_image = new Gtk.Image () {
            pixel_size = 64
        };

        var destination_label = new Gtk.Label ("<b>%s</b>".printf (_("Original file"))) {
            margin_top = 0,
            margin_bottom = 6,
            use_markup = true,
            xalign = 0
        };

        var destination_size_title_label = new Gtk.Label (_("Size:")) {
            valign = Gtk.Align.END,
            xalign = 1
        };

        destination_size_label = new Gtk.Label (null) {
            valign = Gtk.Align.END,
            xalign = 0
        };

        var destination_type_title_label = new Gtk.Label (_("Type:")) {
            xalign = 1
        };

        destination_type_label = new Gtk.Label (null) {
            xalign = 0
        };

        var destination_time_title_label = new Gtk.Label (_("Last modified:")) {
            valign = Gtk.Align.START,
            xalign = 1
        };

        destination_time_label = new Gtk.Label (null) {
            valign = Gtk.Align.START,
            xalign = 0
        };

        source_image = new Gtk.Image () {
            pixel_size = 64
        };

        var source_label = new Gtk.Label ("<b>%s</b>".printf (_("Replace with"))) {
            margin_bottom = 6,
            use_markup = true,
            xalign = 0
        };

        var source_size_title_label = new Gtk.Label (_("Size:")) {
            valign = Gtk.Align.END,
            xalign = 1
        };

        source_size_label = new Gtk.Label (null) {
            valign = Gtk.Align.END,
            xalign = 0
        };

        var source_type_title_label = new Gtk.Label (_("Type:")) {
            xalign = 1
        };

        source_type_label = new Gtk.Label (null) {
            xalign = 0
        };

        var source_time_title_label = new Gtk.Label (_("Last modified:")) {
            valign = Gtk.Align.START,
            xalign = 1
        };

        source_time_label = new Gtk.Label (null) {
            valign = Gtk.Align.START,
            xalign = 0
        };

        rename_entry = new Gtk.Entry () {
            hexpand = true
        };

        var reset_button = new Gtk.Button.with_label (_("Reset"));

        var expander_grid = new Gtk.Grid () {
            margin_top = 6,
            margin_bottom = 6,
            column_spacing = 6,
            orientation = Gtk.Orientation.HORIZONTAL
        };

        expander_grid.add (rename_entry);
        expander_grid.add (reset_button);

        var expander = new Gtk.Expander.with_mnemonic (_("_Select a new name for the destination"));
        expander.add (expander_grid);

        apply_all_checkbutton = new Gtk.CheckButton.with_label (_("Apply this action to all files"));

        add_button (_("_Skip"), ResponseType.SKIP);
        var rename_button = (Gtk.Button) add_button (_("Re_name"), ResponseType.RENAME);

        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        keep_newest_button = (Gtk.Button) add_button (_("Keep Newest"), ResponseType.NEWEST);
        keep_newest_button.set_tooltip_text (_("Skip if original was modified more recently"));

        replace_button = (Gtk.Button) add_button (_("Replace"), ResponseType.REPLACE);
        replace_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

        var comparison_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 0,
            margin_top = 18
        };

        comparison_grid.attach (destination_label, 0, 0, 3, 1);
        comparison_grid.attach (destination_image, 0, 1, 1, 3);
        comparison_grid.attach (destination_size_title_label, 1, 1, 1, 1);
        comparison_grid.attach (destination_size_label, 2, 1, 1, 1);
        comparison_grid.attach (destination_type_title_label, 1, 2, 1, 1);
        comparison_grid.attach (destination_type_label, 2, 2, 1, 1);
        comparison_grid.attach (destination_time_title_label, 1, 3, 1, 1);
        comparison_grid.attach (destination_time_label, 2, 3, 1, 1);

        comparison_grid.attach (source_label, 0, 4, 3, 1);
        comparison_grid.attach (source_image, 0, 5, 1, 3);
        comparison_grid.attach (source_size_title_label, 1, 5, 1, 1);
        comparison_grid.attach (source_size_label, 2, 5, 1, 1);
        comparison_grid.attach (source_type_title_label, 1, 6, 1, 1);
        comparison_grid.attach (source_type_label, 2, 6, 1, 1);
        comparison_grid.attach (source_time_title_label, 1, 7, 1, 1);
        comparison_grid.attach (source_time_label, 2, 7, 1, 1);

        var grid = new Gtk.Grid () {
            margin = 0,
            margin_bottom = 24,
            column_spacing = 12,
            row_spacing = 6
        };

        grid.attach (image, 0, 0, 1, 2);
        grid.attach (primary_label, 1, 0, 1, 1);
        grid.attach (secondary_label, 1, 1, 1, 1);
        grid.attach (comparison_grid, 1, 2, 1, 1);
        grid.attach (expander, 1, 3, 1, 1);
        grid.attach (apply_all_checkbutton, 1, 4, 1, 1);
        grid.show_all ();

        get_content_area ().add (grid);

        source_type_label.bind_property ("visible", source_type_title_label, "visible");
        destination_type_label.bind_property ("visible", destination_type_title_label, "visible");

        expander.activate.connect (() => {
            if (expander.expanded && rename_entry.text == conflict_name) {
                rename_entry.grab_focus ();
                int start_offset;
                int end_offset;
                PF.FileUtils.get_rename_region (conflict_name, out start_offset, out end_offset, false);
                rename_entry.select_region (start_offset, end_offset);
            }
        });

        rename_entry.changed.connect (() => {
            /* The rename button is visible only if there's text
             * in the entry.
             */
            if (rename_entry.text != "" && rename_entry.text != conflict_name) {
                replace_button.hide ();
                rename_button.show ();
                apply_all_checkbutton.sensitive = false;
                set_default_response (ResponseType.RENAME);
            } else {
                replace_button.show ();
                rename_button.hide ();
                apply_all_checkbutton.sensitive = true;
                set_default_response (ResponseType.REPLACE);
            }
        });

        reset_button.clicked.connect (() => {
            rename_entry.text = conflict_name;
            rename_entry.grab_focus ();
            int start_offset;
            int end_offset;
            PF.FileUtils.get_rename_region (conflict_name, out start_offset, out end_offset, false);
            rename_entry.select_region (start_offset, end_offset);
        });

        apply_all_checkbutton.bind_property ("active", expander, "sensitive", GLib.BindingFlags.INVERT_BOOLEAN);
        apply_all_checkbutton.bind_property ("active", rename_button, "sensitive", GLib.BindingFlags.INVERT_BOOLEAN);
        apply_all_checkbutton.toggled.connect (() => {
            if (apply_all_checkbutton.active && rename_entry.text == "" && rename_entry.text != conflict_name) {
                replace_button.hide ();
                rename_button.show ();
            } else {
                rename_button.hide ();
                replace_button.show ();
            }
        });
    }

    private void file_list_ready_cb (GLib.List<GOF.File> files) {
        unowned string src_ftype = source.get_ftype ();
        unowned string dest_ftype = destination.get_ftype ();
        if (src_ftype == null) {
            critical ("Could not determine file type of source file: %s", source.uri);
        }

        if (dest_ftype == null) {
            critical ("Could not determine file type of source file: %s", destination.uri);
        }

        var should_show_type = src_ftype != dest_ftype;
        unowned string dest_name = destination.get_display_name ();
        unowned string dest_dir_name = dest_dir.get_display_name ();
        conflict_name = dest_name;

        string message_extra;
        string message;
        if (destination.is_directory) {
            if (source.is_directory) {
                primary_label.label = _("Merge folder \"%s\"?").printf (dest_name);
                message_extra = _("Merging will ask for confirmation before replacing any files in the folder that conflict with the files being copied."); //vala-lint=line-length
                if (source.modified > destination.modified) {
                    message = _("An older folder with the same name already exists in \"%s\".").printf (dest_dir_name);
                } else if (source.modified < destination.modified) {
                    message = _("A newer folder with the same name already exists in \"%s\".").printf (dest_dir_name);
                } else {
                    message = _("Another folder with the same name already exists in \"%s\".").printf (dest_dir_name);
                }
            } else {
                primary_label.label = _("Replace folder \"%s\"?").printf (dest_name);
                message_extra = _("Replacing it will remove all files in the folder.");
                message = _("A folder with the same name already exists in \"%s\".").printf (dest_dir_name);
            }
        } else {
            primary_label.label = _("Replace file \"%s\"?").printf (dest_name);
            message_extra = _("Replacing it will overwrite its content.");

            if (source.modified > destination.modified) {
                message = _("An older file with the same name already exists in \"%s\".").printf (dest_dir_name);
            } else if (source.modified < destination.modified) {
                message = _("A newer file with the same name already exists in \"%s\".").printf (dest_dir_name);
            } else {
                message = _("Another file with the same name already exists in \"%s\".").printf (dest_dir_name);
            }
        }

        secondary_label.label = "%s %s".printf (message, message_extra);
        source_image.gicon = source.get_icon_pixbuf (64, get_scale_factor (), GOF.File.IconFlags.USE_THUMBNAILS);
        source_size_label.label = source.format_size;
        source_time_label.label = source.formated_modified;
        if (should_show_type && src_ftype != null) {
            source_type_label.label = src_ftype;
        } else {
            source_type_label.visible = false;
            source_type_label.no_show_all = true;
        }

        if (should_show_type && dest_ftype != null) {
            destination_type_label.label = dest_ftype;
        } else {
            destination_type_label.visible = false;
            destination_type_label.no_show_all = true;
        }

        /* Populate the entry */

        rename_entry.text = conflict_name;
        if (source.is_directory && destination.is_directory) {
            replace_button.label = _("Merge");
        }

        source.changed.connect (() => {
            source_image.gicon = source.get_icon_pixbuf (64, get_scale_factor (), GOF.File.IconFlags.USE_THUMBNAILS);
        });

        destination.changed.connect (() => {
            destination_image.gicon = destination.get_icon_pixbuf (64, get_scale_factor (),
                                                                   GOF.File.IconFlags.USE_THUMBNAILS);
        });
    }
}
