/* Copyright 2020 elementary LLC (https://elementary.io)
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

namespace Files.FileOperations {
    public static async bool mount_volume_full (GLib.Volume volume, Gtk.Window? parent_window = null) throws GLib.Error {
        var mount_operation = new Gtk.MountOperation (parent_window);
        mount_operation.password_save = GLib.PasswordSave.FOR_SESSION;
        try {
            yield volume.mount (GLib.MountMountFlags.NONE, mount_operation, null);
        } catch (Error e) {
            PF.Dialogs.show_error_dialog (_("Unable to mount '%s'").printf (volume.get_name ()),
                                          e.message,
                                          null);
            throw e;
        }

        return true;
    }

    public static void mount_volume (GLib.Volume volume, Gtk.Window? parent_window = null) {
        mount_volume_full.begin (volume, parent_window);
    }

    public static bool has_trash_files (GLib.Mount? mount) {
        if (mount == null) {
            return false;
        }

        var dirs = get_trash_dirs_for_mount (mount);
        foreach (unowned GLib.File dir in dirs) {
            if (dir_has_files (dir)) {
                return true;
            }
        }

        return false;
    }

    public static bool mount_has_trash (Mount mount) {
        var root = mount.get_root ();
        if (root.is_native ()) {
            var uid = (int)Posix.getuid ();
            if (root.resolve_relative_path ((".Trash/%d").printf (uid)) != null ||
                root.resolve_relative_path ((".Trash-%d").printf (uid)) != null) {
                return true;
            }
        }

        return false;
    }

    public static GLib.List<GLib.File> get_trash_dirs_for_mount (GLib.Mount mount) {
        var list = new GLib.List<GLib.File> ();
        var root = mount.get_root ();
        if (root.is_native ()) {
            var uid = (int)Posix.getuid ();
            GLib.File? trash = root.resolve_relative_path ((".Trash/%d").printf (uid));
            if (trash != null) {
                var child = trash.get_child ("files");
                if (child.query_exists ()) {
                    list.prepend (child);
                }

                child = trash.get_child ("info");
                if (child.query_exists ()) {
                    list.prepend (child);
                }
            }

            trash = root.resolve_relative_path ((".Trash-%d").printf (uid));
            if (trash != null) {
                var child = trash.get_child ("files");
                if (child.query_exists ()) {
                    list.prepend (child);
                }

                child = trash.get_child ("info");
                if (child.query_exists ()) {
                    list.prepend (child);
                }
            }
        }

        return list;
    }

    public static void empty_trash_for_mount (Gtk.Widget? parent_view, GLib.Mount mount) {
        GLib.List<GLib.File> dirs = get_trash_dirs_for_mount (mount);
        unowned Gtk.Window? parent_window = null;
        if (parent_view != null) {
            parent_window = (Gtk.Window) parent_view.get_ancestor (typeof (Gtk.Window));
        }

        var job = new EmptyTrashJob (parent_window, (owned) dirs);
        job.empty_trash.begin ();
    }

    private static bool dir_has_files (GLib.File dir) {
        try {
            var enumerator = dir.enumerate_children (GLib.FileAttribute.STANDARD_NAME, GLib.FileQueryInfoFlags.NONE);
            if (enumerator.next_file () != null) {
                return true;
            }
        } catch (Error e) {
            return false;
        }

        return false;
    }
}
