/*
* Copyright (c) 2011 Marlin Developers (http://launchpad.net/marlin)
* Copyright (c) 2015-2018 elementary LLC <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation, Inc.,; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1335 USA.
*
* Authored by: ammonkey <am.monkeyd@gmail.com>
*/

protected abstract class Files.AbstractPropertiesDialog : Granite.Dialog {
    protected Gtk.Grid info_grid;
    protected int line; //Next free line in info grid
    protected Gtk.Grid layout;
    protected Gtk.LevelBar? storage_levelbar = null;

    protected AbstractPropertiesDialog (string _title, Gtk.Window parent) {
        Object (title: _title,
                transient_for: parent,
                resizable: false,
                deletable: false,
                destroy_with_parent: true
        );
    }

    construct {
        set_default_size (220, -1);
        layout = new Gtk.Grid () {
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12,
            margin_top = 0,
            column_spacing = 12,
            row_spacing = 6
        };
        info_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6
        };
        line = 0;
        info_grid.attach (new Granite.HeaderLabel (_("Info")), 0, line++, 2, 1);
        get_content_area ().append (layout);
        add_button (_("Close"), Gtk.ResponseType.CLOSE);

        storage_levelbar = new Gtk.LevelBar () {
            value = 0.5,
            hexpand = true,
            margin_top = 3
        };
        storage_levelbar.add_offset_value (Gtk.LEVEL_BAR_OFFSET_LOW, Files.DISK_OFFSET_LOW);
        storage_levelbar.add_offset_value (Gtk.LEVEL_BAR_OFFSET_HIGH, Files.DISK_OFFSET_HIGH);
        storage_levelbar.add_offset_value (Gtk.LEVEL_BAR_OFFSET_FULL, Files.DISK_OFFSET_FULL);

        unowned var storage_style_context = storage_levelbar.get_style_context ();
        storage_style_context.add_class ("flat");
        storage_style_context.add_class ("inverted");
    }

    protected Gtk.Label make_key_label (string label) {
        var key_label = new Gtk.Label (label) {
            halign = Gtk.Align.END,
            margin_start = 12
        };
        return key_label;
    }

    //Make value label focusable and selectable to enable copying to other app
    protected Gtk.Label make_value_label (string label) {
        var val_label = new Gtk.Label (label) {
            can_focus = true,
            halign = Gtk.Align.START,
            selectable = true,
            use_markup = true
        };
        return val_label;
    }

    protected void create_header (Gtk.Widget? image_widget, Gtk.Widget header_widget) {
        if (image_widget != null) {
            layout.attach (image_widget, 0, 0, 1, 1);
        }

        header_widget.add_css_class (Granite.STYLE_CLASS_H2_LABEL);
        header_widget.hexpand = true;
        header_widget.margin_top = 6;
        header_widget.valign = Gtk.Align.CENTER;
        header_widget.halign = Gtk.Align.START;
        layout.attach (header_widget, 1, 0, 1, 1);
    }

    protected Gtk.Widget create_image_widget (Gtk.Image file_image, List<string>? emblems_list) {
        if (emblems_list != null) {
            int pos = 0;
            var emblem_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
                halign = Gtk.Align.END,
                valign = Gtk.Align.END
            };

            foreach (string emblem_name in emblems_list) {
                var emblem = new Gtk.Image.from_icon_name (emblem_name);
                emblem_box.append (emblem);

                pos++;
                if (pos > 3) { /* Only room for 3 emblems */
                    break;
                }
            }

            var image_overlay = new Gtk.Overlay () {
                valign = Gtk.Align.CENTER,
                width_request = 48,
                height_request = 48
            };

            image_overlay.child = file_image;
            image_overlay.add_overlay (emblem_box);
            return image_overlay;
        } else {
            return file_image;
        }
    }

    protected void create_storage_bar (GLib.FileInfo file_info) {
        var storage_header = new Granite.HeaderLabel (_("Device Usage"));
        info_grid.attach (storage_header, 0, line++, 1, 1);

        if (file_info != null &&
            file_info.has_attribute (FileAttribute.FILESYSTEM_SIZE) &&
            file_info.has_attribute (FileAttribute.FILESYSTEM_FREE) &&
            file_info.has_attribute (FileAttribute.FILESYSTEM_USED)) {
            uint64 fs_capacity = file_info.get_attribute_uint64 (FileAttribute.FILESYSTEM_SIZE);
            uint64 fs_used = file_info.get_attribute_uint64 (FileAttribute.FILESYSTEM_USED);
            uint64 fs_available = file_info.get_attribute_uint64 (FileAttribute.FILESYSTEM_FREE);
            uint64 fs_reserved = fs_capacity - fs_used - fs_available;
            storage_levelbar.@value = (double)((fs_capacity - fs_available)) / (double) (fs_capacity);
            info_grid.attach (storage_levelbar, 0, line++, 4, 1);
        } else {
            /* We're not able to gether the usage statistics, show an error
             * message to let the user know. */
            var capacity_label = make_key_label (_("Capacity:"));
            var capacity_value = make_value_label (_("Unknown"));

            var available_label = make_key_label (_("Available:"));
            var available_value = make_value_label (_("Unknown"));

            var used_label = make_key_label (_("Used:"));
            var used_value = make_value_label (_("Unknown"));

            info_grid.attach (capacity_label, 0, line++, 1, 1);
            info_grid.attach_next_to (capacity_value, capacity_label, Gtk.PositionType.RIGHT);
            info_grid.attach (available_label, 0, line++, 1, 1);
            info_grid.attach_next_to (available_value, available_label, Gtk.PositionType.RIGHT);
            info_grid.attach (used_label, 0, line++, 1, 1);
            info_grid.attach_next_to (used_value, used_label, Gtk.PositionType.RIGHT);
        }
    }
}