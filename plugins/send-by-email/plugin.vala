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

public class Files.Plugins.SendByEmail : Files.Plugins.Base {
    private GLib.File[] files;

    public override void context_menu (Gtk.PopoverMenu menu_widget, List<Files.File> gof_files) {
        if (gof_files == null || gof_files.length () == 0) {
            return;
        }

        files = get_file_array (gof_files);
        if (files.length > 0) {
            var send_action = new SimpleAction ("send", null);
            send_action.activate.connect (send_email);
            var email_action_group = new SimpleActionGroup ();
            email_action_group.add_action (send_action);
            menu_widget.insert_action_group ("email", email_action_group);
            var email_menu = new Menu ();
            var email_item = new MenuItem (_("Send by Email"), "email.send");
            email_menu.append_item (email_item);
            ((Menu)(menu_widget.menu_model)).append_section (null, email_menu);
        }
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

    private void send_email () {
        try {
            var portal = Portal.Email.get ();

            window_export.begin ((obj, res) => {
                var options = new HashTable<string, Variant> (str_hash, str_equal);
                options["handle_token"] = Portal.generate_token ();

                var files_builder = new VariantBuilder (new VariantType ("ah"));
                var file_descriptors = new UnixFDList ();
                foreach (var file in files) {
                    var fd = Posix.open (file.get_path (), Posix.O_RDONLY | Posix.O_CLOEXEC);
                    if (fd == -1) {
                        warning ("send-by-mail: cannot open file: '%s'", file.get_path ());
                        continue;
                    }

                    try {
                        files_builder.add ("h", file_descriptors.append (fd));
                    } catch (Error e) {
                        warning ("send-by-mail: cannot append file descriptor: %s", e.message);
                    }
                }

                options["attachment_fds"] = files_builder.end ();

                /** Even though the org.freedesktop.portal.Email portal specs
                * claims that "all the keys in the options are are optional",
                * the portal does not work if no "addresses" key is passed.
                * This is a bug in the Gtk backend of the portal:
                * https://github.com/flatpak/xdg-desktop-portal-gtk/issues/343
                */
                if (portal.version > 2) {
                    options["addresses"] = new Variant ("as", null);
                }

                try {
                    var handle = window_export.end (res);
                    portal.compose_email (handle, options, file_descriptors);

                } catch (Error e) {
                    warning (e.message);
                }
            });
        } catch (Error e) {
            warning (e.message);
        }
    }

    private async string window_export () {
        var surface = window.get_root ().get_surface ();

        if (surface is Gdk.X11.Surface) {
            var xid = ((Gdk.X11.Surface) surface).get_xid ();
            return "x11:%x".printf ((uint) xid);
        } else if (surface is Gdk.Wayland.Toplevel) {
            var handle = "wayland:";
            ((Gdk.Wayland.Toplevel) surface).export_handle ((toplevel, h) => {
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

public Files.Plugins.Base module_init () {
    return new Files.Plugins.SendByEmail ();
}
