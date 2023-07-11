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

protected abstract class Files.View.AbstractPropertiesDialog : Granite.Dialog {
    protected Gtk.Grid info_grid;
    protected Gtk.Grid layout;
    protected Gtk.Stack stack;
    protected Gtk.Widget header_title;

    protected enum PanelType {
        INFO,
        PERMISSIONS
    }

    protected AbstractPropertiesDialog (string _title, Gtk.Window parent) {
        Object (title: _title,
                transient_for: parent,
                destroy_with_parent: true
        );
    }

    construct {
        default_width = 220;

        var info_header = new Granite.HeaderLabel (_("Info"));

        info_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6
        };
        info_grid.attach (info_header, 0, 0, 2);

        stack = new Gtk.Stack ();
        stack.add_titled (info_grid, PanelType.INFO.to_string (), _("General"));

        layout = new Gtk.Grid () {
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12,
            column_spacing = 12,
            row_spacing = 6,
            vexpand = true
        };
        layout.attach (stack, 0, 2, 2);

        get_content_area ().add (layout);

        add_button (_("Close"), Gtk.ResponseType.CLOSE);
        response.connect ((source, type) => {
            switch (type) {
                case Gtk.ResponseType.CLOSE:
                    destroy ();
                    break;
            }
        });
    }

    protected void create_header_title () {
        header_title.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
        header_title.hexpand = true;
        header_title.margin_top = 6;
        header_title.valign = CENTER;

        if (header_title is Gtk.Label) {
            header_title.halign = START;
            ((Gtk.Label) header_title).selectable = true;
        }

        layout.attach (header_title, 1, 0);
    }

    protected void overlay_emblems (Gtk.Image file_icon, List<string>? emblems_list) {
        var file_overlay = new Gtk.Overlay () {
            child = file_icon
        };
        layout.attach (file_overlay, 0, 0);

        if (emblems_list != null) {
            int pos = 0;
            var emblem_box = new Gtk.Box (VERTICAL, 0) {
                halign = Gtk.Align.END,
                valign = Gtk.Align.END
            };

            foreach (string emblem_name in emblems_list) {
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

    protected void create_storage_bar (GLib.FileInfo file_info, int line) {
        var storage_header = new Granite.HeaderLabel (_("Device Usage"));
        info_grid.attach (storage_header, 0, line);

        if (file_info != null &&
            file_info.has_attribute (FileAttribute.FILESYSTEM_SIZE) &&
            file_info.has_attribute (FileAttribute.FILESYSTEM_FREE) &&
            file_info.has_attribute (FileAttribute.FILESYSTEM_USED)) {

            uint64 fs_capacity = file_info.get_attribute_uint64 (FileAttribute.FILESYSTEM_SIZE);
            uint64 fs_used = file_info.get_attribute_uint64 (FileAttribute.FILESYSTEM_USED);
            uint64 fs_available = file_info.get_attribute_uint64 (FileAttribute.FILESYSTEM_FREE);
            uint64 fs_reserved = fs_capacity - fs_used - fs_available;

            var storage_levelbar = new Gtk.LevelBar.for_interval (0, fs_capacity) {
                value = fs_used + fs_reserved,
                hexpand = true
            };
            storage_levelbar.add_offset_value (Gtk.LEVEL_BAR_OFFSET_LOW, 0.6 * fs_capacity);
            storage_levelbar.add_offset_value (Gtk.LEVEL_BAR_OFFSET_HIGH, 0.9 * fs_capacity);
            storage_levelbar.add_offset_value (Gtk.LEVEL_BAR_OFFSET_FULL, fs_capacity);
            storage_levelbar.get_style_context ().add_class ("inverted");

            var storage_label = new Gtk.Label (
                _("%s free out of %s").printf (format_size (fs_capacity - fs_used + fs_reserved), format_size (fs_capacity))
            );

            info_grid.attach (storage_levelbar, 0, line + 1, 4);
            info_grid.attach (storage_label, 0, line + 2, 4);
        } else {
            /* We're not able to gether the usage statistics, show an error
             * message to let the user know. */
            var capacity_label = make_key_label (_("Capacity:"));
            var capacity_value = make_value_label (_("Unknown"));

            var available_label = make_key_label (_("Available:"));
            var available_value = make_value_label (_("Unknown"));

            var used_label = make_key_label (_("Used:"));
            var used_value = make_value_label (_("Unknown"));

            info_grid.attach (capacity_label, 0, line + 1, 1, 1);
            info_grid.attach_next_to (capacity_value, capacity_label, Gtk.PositionType.RIGHT);
            info_grid.attach (available_label, 0, line + 2, 1, 1);
            info_grid.attach_next_to (available_value, available_label, Gtk.PositionType.RIGHT);
            info_grid.attach (used_label, 0, line + 3, 1, 1);
            info_grid.attach_next_to (used_value, used_label, Gtk.PositionType.RIGHT);
        }
    }
}
