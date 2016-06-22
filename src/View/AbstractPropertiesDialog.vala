/*
* Copyright (c) 2011 Marlin Developers (http://launchpad.net/marlin)
* Copyright (c) 2015-2016 elementary LLC (http://launchpad.net/pantheon-files)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA 02111-1307, USA.
*
* Authored by: ammonkey <am.monkeyd@gmail.com>
*/

protected abstract class Marlin.View.AbstractPropertiesDialog : Gtk.Dialog {
    protected Gtk.Grid info_grid;
    protected Gtk.Grid layout;
    protected Gtk.Overlay file_img;
    protected Gtk.Stack stack;
    protected Gtk.StackSwitcher stack_switcher;
    protected Gtk.Widget header_title;

    protected enum PanelType {
        INFO,
        PERMISSIONS,
        PREVIEW
    }

    public AbstractPropertiesDialog (string _title, Gtk.Window parent) {
        title = _title;
        resizable = false;
        deletable = false;
        set_default_size (220, -1);
        transient_for = parent;
        window_position = Gtk.WindowPosition.CENTER_ON_PARENT;
        border_width = 6;
        destroy_with_parent = true;

        file_img = new Gtk.Overlay ();
        file_img.set_size_request (48, 48);
        file_img.valign = Gtk.Align.CENTER;

        var info_header = new Gtk.Label (_("Info"));
        info_header.halign = Gtk.Align.START;
        info_header.get_style_context ().add_class ("h4");

        info_grid = new Gtk.Grid ();
        info_grid.column_spacing = 6;
        info_grid.row_spacing = 6;
        info_grid.attach (info_header, 0, 0, 2, 1);

        stack = new Gtk.Stack ();
        stack.margin_bottom = 12;
        stack.add_titled (info_grid, PanelType.INFO.to_string (), _("General"));

        stack_switcher = new Gtk.StackSwitcher ();
        stack_switcher.halign = Gtk.Align.CENTER;
        stack_switcher.margin_top = 12;
        stack_switcher.no_show_all = true;
        stack_switcher.stack = stack;

        layout = new Gtk.Grid ();
        layout.margin = 6;
        layout.margin_top = 0;
        layout.column_spacing = 12;
        layout.row_spacing = 6;
        layout.attach (file_img, 0, 0, 1, 1);
        layout.attach (stack_switcher, 0, 1, 2, 1);
        layout.attach (stack, 0, 2, 2, 1);

        var content_area = get_content_area () as Gtk.Box;
        content_area.add (layout);

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
        header_title.get_style_context ().add_class ("h2");
        header_title.hexpand = true;
        header_title.margin_top = 6;
        header_title.valign = Gtk.Align.CENTER;
        layout.attach (header_title, 1, 0, 1, 1);
    }

    protected void overlay_emblems (Gdk.Pixbuf icon, List<string>? emblems_list) {
        var file_icon = new Gtk.Image.from_pixbuf (icon);
        file_img.add_overlay (file_icon);

        if (emblems_list != null) {
            int pos = 0;
            var emblem_grid = new Gtk.Grid ();
            emblem_grid.orientation = Gtk.Orientation.VERTICAL;
            emblem_grid.halign = Gtk.Align.END;
            emblem_grid.valign = Gtk.Align.END;

            foreach (string emblem_name in emblems_list) {

                var emblem = new Gtk.Image.from_icon_name (emblem_name, Gtk.IconSize.BUTTON);
                emblem_grid.add (emblem);

                pos++;
                if (pos > 3) { /* Only room for 3 emblems */
                    break;
                }
            }

            file_img.add_overlay (emblem_grid);
        }
    }

    protected void add_section (Gtk.Stack stack, string title, string name, Gtk.Container content) {
        if (content != null) {
            stack.add_titled (content, name, title);
        }

        /* Only show the stack switcher when there's more than a single tab */
        if (stack.get_children ().length () > 1) {
            stack_switcher.show ();
        }
    }

    protected void create_head_line (Gtk.Widget head_label, Gtk.Grid information, ref int line) {
        head_label.set_halign (Gtk.Align.START);
        head_label.get_style_context ().add_class ("h4");
        information.attach (head_label, 0, line, 1, 1);

        line++;
    }

    protected void create_info_line (Gtk.Widget key_label, Gtk.Label value_label, Gtk.Grid information, ref int line, Gtk.Widget? value_container = null) {
        key_label.margin_start = 20;
        value_label.set_selectable (true);
        value_label.set_use_markup (true);
        value_label.set_can_focus (false);
        value_label.set_halign (Gtk.Align.START);

        information.attach (key_label, 0, line, 1, 1);
        if (value_container != null) {
            value_container.set_size_request (150, -1);
            information.attach_next_to (value_container, key_label, Gtk.PositionType.RIGHT, 3, 1);
        } else {
            information.attach_next_to (value_label, key_label, Gtk.PositionType.RIGHT, 3, 1);
        }

        line++;
    }

    protected void create_storage_bar (GLib.FileInfo info, ref int line) {
        var storage_header = new Gtk.Label (_("Usage"));
        storage_header.halign = Gtk.Align.START;
        storage_header.get_style_context ().add_class ("h4");
        info_grid.attach (storage_header, 0, line, 1, 1);

        line++;

        if (info != null &&
            info.has_attribute (FileAttribute.FILESYSTEM_SIZE) &&
            info.has_attribute (FileAttribute.FILESYSTEM_FREE)) {

            uint64 fs_capacity = info.get_attribute_uint64 (FileAttribute.FILESYSTEM_SIZE);
            uint64 fs_used = info.get_attribute_uint64 (FileAttribute.FILESYSTEM_USED);

            var storagebar = new Granite.Widgets.StorageBar (fs_capacity);
            storagebar.update_block_size (Granite.Widgets.StorageBar.ItemDescription.OTHER, fs_used);

            info_grid.attach (storagebar, 0, line, 4, 1);
        } else {
            /* We're not able to gether the usage statistics, show an error
             * message to let the user know. */
            var key_label = new Gtk.Label (_("Capacity:"));
            key_label.halign = Gtk.Align.END;

            var value_label = new Gtk.Label (_("Unknown"));
            create_info_line (key_label, value_label, info_grid, ref line);

            key_label = new Gtk.Label (_("Available:"));
            key_label.halign = Gtk.Align.END;

            value_label = new Gtk.Label (_("Unknown"));
            create_info_line (key_label, value_label, info_grid, ref line);

            key_label = new Gtk.Label (_("Used:"));
            key_label.halign = Gtk.Align.END;

            value_label = new Gtk.Label (_("Unknown"));
            create_info_line (key_label, value_label, info_grid, ref line);
        }
    }
}
