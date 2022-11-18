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
    protected Gtk.Grid layout;
    protected Gtk.Stack stack;
    protected Gtk.StackSwitcher stack_switcher;
    protected Gtk.Widget header_title;
    protected Files.StorageBar? storagebar = null;

    protected enum PanelType {
        INFO,
        PERMISSIONS
    }

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

        var info_header = new Granite.HeaderLabel (_("Info"));

        info_grid = new Gtk.Grid () {
            column_spacing = 6,
            row_spacing = 6
        };

        info_grid.attach (info_header, 0, 0, 2, 1);

        stack = new Gtk.Stack ();
        stack.add_titled (info_grid, PanelType.INFO.to_string (), _("General"));

        stack_switcher = new Gtk.StackSwitcher () {
            margin_top = 12,
            stack = stack
        };

        layout = new Gtk.Grid () {
            margin_bottom = 12,
            margin_start = 12,
            margin_end = 12,
            margin_top = 0,
            column_spacing = 12,
            row_spacing = 6
        };

        layout.attach (stack_switcher, 0, 1, 2, 1);
        layout.attach (stack, 0, 2, 2, 1);

        get_content_area ().append (layout);

        add_button (_("Close"), Gtk.ResponseType.CLOSE);
        response.connect ((source, type) => {
            switch (type) {
                case Gtk.ResponseType.CLOSE:
                    destroy ();
                    break;
            }
        });
    }

    protected Gtk.Label make_key_label (string label) {
        return new Gtk.Label (label) {
            halign = Gtk.Align.END,
            margin_start = 12
        };
    }

    protected Gtk.Label make_value_label (string label) {
        return new Gtk.Label (label) {
            can_focus = true,
            halign = Gtk.Align.START,
            selectable = true,
            use_markup = true
        };
    }

    protected void create_header_title () {
        header_title.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
        header_title.hexpand = true;
        header_title.margin_top = 6;
        header_title.valign = Gtk.Align.CENTER;
        layout.attach (header_title, 1, 0, 1, 1);
    }

    protected void overlay_emblems (Gtk.Image file_icon, List<string>? emblems_list) {
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

            var file_img = new Gtk.Overlay () {
                valign = Gtk.Align.CENTER,
                width_request = 48,
                height_request = 48
            };

            file_img.add_overlay (file_icon);
            file_img.add_overlay (emblem_box);

            layout.attach (file_img, 0, 0, 1, 1);
        } else {
            layout.attach (file_icon, 0, 0, 1, 1);
        }
    }

    protected void add_section (Gtk.Stack stack, string title, string name, Gtk.Widget content) {
        if (content != null) {
            stack.add_titled (content, name, title);
        }

        /* Only show the stack switcher when there's more than a single tab */
        if (stack.get_pages ().get_n_items () > 1) {
            stack_switcher.show ();
        }
    }

    protected void create_storage_bar (GLib.FileInfo file_info, int line) {
        var storage_header = new Granite.HeaderLabel (_("Device Usage"));
        info_grid.attach (storage_header, 0, line, 1, 1);

        if (file_info != null &&
            file_info.has_attribute (FileAttribute.FILESYSTEM_SIZE) &&
            file_info.has_attribute (FileAttribute.FILESYSTEM_FREE) &&
            file_info.has_attribute (FileAttribute.FILESYSTEM_USED)) {

            uint64 fs_capacity = file_info.get_attribute_uint64 (FileAttribute.FILESYSTEM_SIZE);
            uint64 fs_used = file_info.get_attribute_uint64 (FileAttribute.FILESYSTEM_USED);
            uint64 fs_available = file_info.get_attribute_uint64 (FileAttribute.FILESYSTEM_FREE);
            uint64 fs_reserved = fs_capacity - fs_used - fs_available;

            storagebar = new Files.StorageBar.with_total_usage (fs_capacity, fs_used + fs_reserved);
            update_storage_block_size (fs_reserved, Files.StorageBar.ItemDescription.OTHER);

            info_grid.attach (storagebar, 0, line + 1, 4, 1);
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

    protected void update_storage_block_size (uint64 size,
                                              Files.StorageBar.ItemDescription item_description) {
        if (storagebar != null) {
            storagebar.update_block_size (item_description, size);
        }
    }
}