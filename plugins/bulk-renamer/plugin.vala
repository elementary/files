/*
* Copyright 2022 elementary, Inc. (https://elementary.io)
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
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

public class Files.Plugins.RenamerMenuItem : Gtk.MenuItem {
    private GLib.File[] files;

    public RenamerMenuItem (GLib.File[] files) {
        this.files = files;

        label = _("Rename Selected Files");
    }

    public override void activate () {
        var dialog = new RenamerDialog ("", files);
        dialog.run ();
        dialog.destroy ();
    }
}

public class Files.Plugins.BulkRenamer : Files.Plugins.Base {
    private Gtk.Menu menu;
    private Files.File current_directory = null;

    public BulkRenamer () {
    }

    public override void context_menu (Gtk.Widget widget, List<Files.File> gof_files) {
warning ("BR: context mennu");
        menu = widget as Gtk.Menu;

        GLib.File[] files = null;
        if (gof_files == null || gof_files.next == null) {
warning ("no files");
            return;
        }

        /* We cannot assume all target files are in same folder (maybe recent folder in which case the view
            passes the original locations.  We also do not want to batch rename mixtures of files and folders.
        */
        unowned List<Files.File> remaining_files = gof_files.first ();
        GLib.File? parent_folder = remaining_files.data.directory;
        bool first_is_folder = remaining_files.data.is_folder ();
        GLib. File? first_folder = parent_folder.dup ();
        bool can_batch_rename = true;
        while (can_batch_rename) {
            remaining_files = remaining_files.next;
            if (remaining_files == null) {
                break;
            }
            parent_folder = remaining_files.data.directory;
            can_batch_rename = parent_folder.equal (first_folder) &&
                               remaining_files.data.is_folder () == first_is_folder;
        }

        if (!can_batch_rename) {
warning ("cannot batch rename");
            return;
        }


        FileInfo? info = null;
        try {
            info = parent_folder.query_info (FileAttribute.ACCESS_CAN_WRITE, FileQueryInfoFlags.NOFOLLOW_SYMLINKS);
        } catch (Error e) {}

        if (info != null && info.has_attribute (FileAttribute.ACCESS_CAN_WRITE)) {
            if (!info.get_attribute_boolean (FileAttribute.ACCESS_CAN_WRITE)) {
warning ("cannot write");
                return;
            }
        } // Else assume parent is writable and rely on error dialog.


        files = get_file_array (gof_files);

        var menu_item = new RenamerMenuItem (files);
warning ("adding menuitem");
        add_menuitem (menu, menu_item);
    }

    public override void directory_loaded (Gtk.ApplicationWindow window, Files.AbstractSlot view, Files.File directory) {
        current_directory = directory;
    }

    private void add_menuitem (Gtk.Menu menu, Gtk.MenuItem menu_item) {
        menu.append (menu_item);
        menu_item.show ();
        plugins.menuitem_references.add (menu_item);
    }


    private static GLib.File[] get_file_array (List<Files.File> files) {
        GLib.File[] file_array = new GLib.File[0];

        foreach (unowned Files.File file in files) {
            if (file.location != null) {
                if (file.location.get_uri_scheme () == "recent") {
                    file_array += GLib.File.new_for_uri (file.get_display_target_uri ());
                } else {
                    file_array += file.location;
                }
            }
        }

        return file_array;
    }
}

public Files.Plugins.Base module_init () {
    return new Files.Plugins.BulkRenamer ();
}
