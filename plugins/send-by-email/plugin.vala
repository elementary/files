/*
* Copyright 2021 elementary, Inc. (https://elementary.io)
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

public class Files.Plugins.SendByEmailMenuItem : Gtk.MenuItem {
    private GLib.File[] files;

    public SendByEmailMenuItem (GLib.File[] files) {
        this.files = files;

        label = _("Send by Email");
    }

    public override void activate () {
        try {
            var portal = Portal.Email.get ();

            window_export.begin ((obj, res) => {
                var options = new HashTable<string, Variant> (str_hash, str_equal);
                options["handle_token"] = Portal.generate_token ();

                int[] file_descriptors = {};
                foreach (var file in files) {
                    file_descriptors += Posix.open (file.get_path (), Posix.O_RDONLY);
                }
                options["attachment_fds"] = file_descriptors;

                /** Even though the org.freedesktop.portal.Email portal specs
                * claims that "all the keys in the options are are optional",
                * the portal does not work if no "addresses" key is passed.
                * This is probably a bug in the Gtk backend of the portal.
                */
                options["addresses"] = new Variant ("as", null);

                try {
                    var handle = window_export.end (res);
                    portal.compose_email (handle, options);

                } catch (Error e) {
                    warning (e.message);
                }
            });

        } catch (Error e) {
            warning (e.message);
        }
    }

    private async string window_export () {
        var window = get_toplevel ().get_window ();

        if (window is Gdk.X11.Window) {
            var xid = ((Gdk.X11.Window) window).get_xid ();
            return "x11:%x".printf ((uint) xid);

        } else if (window is Gdk.Wayland.Window) {
            var handle = "wayland:";
            ((Gdk.Wayland.Window) window).export_handle ((w, h) => {
                handle += h;
                window_export.callback ();
            });
            yield;

            if (handle != "wayland:") {
                return handle;
            }
            return "";

        } else {
            warning ("Unknown windowing system, not exporting window");
            return "";
        }
    }
}

public class Files.Plugins.SendByEmail : Files.Plugins.Base {

    public override void context_menu (Gtk.Widget widget, List<Files.File> gof_files) {
        var menu = widget as Gtk.Menu;

        if (gof_files == null || gof_files.length () == 0) {
            return;
        }

        var files = get_file_array (gof_files);
        if (files != null && files.length > 0) {
            add_menuitem (menu, new Gtk.SeparatorMenuItem ());
            add_menuitem (menu, new SendByEmailMenuItem (files));
        }
    }

    private void add_menuitem (Gtk.Menu menu, Gtk.MenuItem menu_item) {
        menu.append (menu_item);
        menu_item.show ();
        plugins.menuitem_references.add (menu_item);
    }

    private static GLib.File[] get_file_array (List<Files.File> files) {
        GLib.File[] file_array = new GLib.File[0];

        foreach (unowned Files.File file in files) {
            if (file.location != null && !file.is_directory && file.is_readable ()) {
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
    return new Files.Plugins.SendByEmail ();
}
