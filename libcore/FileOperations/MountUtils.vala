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
    public static async bool unmount_mount (Mount mount, Gtk.Window? parent) {
        if (mount.can_unmount ()) {
            var mount_op = new UnmountOperation (parent, mount.get_name ());
            try {
                var success = yield mount.unmount_with_operation (
                        GLib.MountUnmountFlags.NONE,
                        mount_op,
                        null
                );
                return success;
            } catch (GLib.Error e) {
                if (e is IOError.FAILED_HANDLED) {
                    return false;
                }
                PF.Dialogs.show_error_dialog (_("Unable to unmount '%s'").printf (mount.get_name ()),
                                              e.message,
                                              null);
                return false;
            }
        } else {
            return yield eject_mount (mount, parent);
        }
    }

    public static async bool eject_mount (Mount mount, Gtk.Window? parent) {
        if (mount.can_eject ()) {
            var mount_op = new UnmountOperation (parent, mount.get_name ());
            try {
                var success = yield mount.eject_with_operation (
                        GLib.MountUnmountFlags.NONE,
                        mount_op,
                        null
                );
                return success;
            } catch (GLib.Error e) {
                if (e is IOError.FAILED_HANDLED) {
                    return false;
                }

                PF.Dialogs.show_error_dialog (_("Unable to eject '%s'").printf (mount.get_name ()),
                                              e.message,
                                              null);
                return false;
            }
        } else {
            return false;
        }
    }

    public static async void eject_drive (Drive drive, Gtk.Window? parent) {
        // First unmount any mounted volumes
        foreach (var vol in drive.get_volumes ()) {
            var mount = vol.get_mount ();
            if (mount != null && !yield unmount_mount (mount, parent)) {
                return;
            }
        }

        var mount_op = new Gtk.MountOperation (parent);
        try {
            yield drive.eject_with_operation (
                GLib.MountUnmountFlags.NONE,
                mount_op,
                null
            );
        } catch (Error e) {
            warning ("Unable to eject drive %s: %s", drive.get_name (), e.message);
        }
    }

    public static async void safely_remove_drive (Drive drive, Gtk.Window? parent) {
        // First unmount any mounted volumes
        bool stopped = false;
        foreach (var vol in drive.get_volumes ()) {
            var mount = vol.get_mount ();
            if (mount != null && !yield unmount_mount (mount, parent)) {
                return;
            }
        }

        if (drive.can_stop ()) {
            var mount_op = new Gtk.MountOperation (parent);
            try {
                yield drive.stop (
                    GLib.MountUnmountFlags.NONE,
                    mount_op,
                    null
                );

                stopped = true;
            } catch (Error e) {
                warning ("Unable to stop drive %s: %s", drive.get_name (), e.message);
            }
        }

        if (!stopped && drive.can_eject ()) {
            yield eject_drive (drive, parent);
        }
    }

    public static async bool mount_volume_full (GLib.Volume volume, Gtk.Window? parent_window = null) {
        var mount_operation = new Gtk.MountOperation (parent_window);
        mount_operation.password_save = GLib.PasswordSave.FOR_SESSION;
        try {
            yield volume.mount (GLib.MountMountFlags.NONE, mount_operation, null);
        } catch (Error e) {
            PF.Dialogs.show_error_dialog (_("Unable to mount '%s'").printf (volume.get_name ()),
                                          e.message,
                                          null);
            return false;
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

    private class UnmountOperation : Gtk.MountOperation {

        public string mount_name { get; construct; }
        private Gtk.Dialog? dialog = null;

        public UnmountOperation (Gtk.Window? _parent, string _mount_name) {
            Object (
                parent: _parent,
                mount_name: _mount_name
            );
        }

        ~UnmountOperation () {
            dialog.close ();
            dialog.destroy ();
        }

        public override void show_processes (string message, Array<Pid> processes, string[] choices) {
            if (dialog != null) {
                return;
            }

            dialog = new BusyDialog (mount_name, processes);
            dialog.response.connect (() => {
                dialog.close ();
                dialog.destroy ();
                dialog = null;
                reply (MountOperationResult.ABORTED); // Results in IOError.FAILED_HANDLED
            });

            dialog.present ();
        }

        public override void aborted () {
            // We do not want another dialog shown
            return;
        }
     }

     private class BusyDialog : Granite.MessageDialog {
        public string mount_name { get; construct; }
        public Array<Pid> processes { get; construct; }
        public BusyDialog (string _mount_name, Array<Pid> _processes) {
            Object (
                mount_name: _mount_name,
                processes: _processes,
                buttons: Gtk.ButtonsType.CANCEL,
                image_icon: new ThemedIcon ("dialog-warning")

            );
        }

        construct {
            Pid self = Posix.getpid ();
            if (processes.length == 1 && processes.index (0) == self) {
                primary_text = _("The resource '%s' is in use").printf (mount_name);
                secondary_text = _("Please wait for it to unmount or you may cancel it");
            } else {
                primary_text = _("The resource '%s' is in use by other processes").printf (mount_name);
                secondary_text = _("Unmounting now might cause a process to fail or to lose data");
                var sb = new StringBuilder ("");
                sb.append (_("Other processes using '%s'… \n").printf (mount_name));
                foreach (var pid in processes) {
                    if (pid == self) {
                        continue;
                    }
                    sb.append (get_process_name_from_pid (pid));
                    sb.append ("\n");
                }

                show_error_details (sb.str);
            }
            show_all ();
        }

        private string? get_process_name_from_pid (int pid) {
            string process_path = "/proc/%d/exe".printf (pid);

            try {
                string path = GLib.FileUtils.read_link (process_path);
                return Path.get_basename (path);
            } catch (FileError e) {
                return _("Unknown");
            }
        }
     }
}
