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

public class Files.FileOperations.CommonJob {
    protected unowned Gtk.Window? parent_window;
    protected uint inhibit_cookie;
    protected unowned GLib.Cancellable? cancellable;
    protected PF.Progress.Info progress;
    protected Files.UndoActionData? undo_redo_data;
    protected GLib.Timer time;
    protected bool skip_all_error;
    private GLib.GenericSet<GLib.File>? skip_readdir_error_set;
    protected GLib.GenericSet<GLib.File>? skip_files;
    protected CommonJob (Gtk.Window? parent_window = null) {
        this.parent_window = parent_window;
        inhibit_cookie = 0;
        progress = new PF.Progress.Info ();
        cancellable = progress.cancellable;
        undo_redo_data = null;
        time = new GLib.Timer ();
    }

    ~CommonJob () {
        progress.finish ();
        uninhibit_power_manager ();
        if (undo_redo_data != null) {
            Files.UndoManager.instance ().add_action ((owned) undo_redo_data);
        }
    }

    protected void inhibit_power_manager (string message) {
        weak Gtk.Application app = (Gtk.Application) GLib.Application.get_default ();
        inhibit_cookie = app.inhibit (
            parent_window,
            Gtk.ApplicationInhibitFlags.LOGOUT | Gtk.ApplicationInhibitFlags.SUSPEND,
            message
        );
    }

    private void uninhibit_power_manager () {
        if (inhibit_cookie == 0) {
            return;
        }

        ((Gtk.Application) GLib.Application.get_default ()).uninhibit (inhibit_cookie);
        inhibit_cookie = 0;
    }

    protected bool aborted () {
        return cancellable.is_cancelled ();
    }

    protected void abort_job () {
        cancellable.cancel ();
    }

    protected void skip_file (GLib.File file) {
        if (skip_files == null) {
            skip_files = new GLib.GenericSet<GLib.File> (GLib.File.hash, GLib.File.equal);
        }

        skip_files.add (file);
    }

    protected void skip_readdir_error (GLib.File dir) {
        if (skip_readdir_error_set == null) {
            skip_readdir_error_set = new GLib.GenericSet<GLib.File> (GLib.File.hash, GLib.File.equal);
        }

        skip_readdir_error_set.add (dir);
    }

    protected bool should_skip_file (GLib.File file) {
        if (skip_files != null) {
            return skip_files.contains (file);
        }

        return false;
    }

    protected bool should_skip_readdir_error (GLib.File dir) {
        if (skip_readdir_error_set != null) {
            return skip_readdir_error_set.contains (dir);
        }

        return false;
    }

    protected void verify_destination (GLib.File dest, out string? dest_fs_id, int64 required_size) {
        dest_fs_id = null;
        try {
            var info = dest.query_info (GLib.FileAttribute.STANDARD_TYPE + "," +
                                        GLib.FileAttribute.ID_FILESYSTEM,
                                        GLib.FileQueryInfoFlags.NONE,
                                        cancellable);
            var file_type = info.get_file_type ();
            dest_fs_id = info.get_attribute_string (GLib.FileAttribute.ID_FILESYSTEM);

            if (file_type != GLib.FileType.DIRECTORY) {
                var dest_name = dest.get_parse_name ();
                /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                string primary = _("Error while copying to \"%s\".").printf (dest_name);
                unowned string secondary = _("The destination is not a folder.");

                PF.run_error (parent_window,
                              time,
                              progress,
                              primary,
                              secondary,
                              null,
                              false,
                              CANCEL,
                              null);

                abort_job ();
                return;
            }
        } catch (Error e) {
            if (e is GLib.IOError.CANCELLED) {
                return;
            }

            var dest_basename = Files.FileUtils.custom_basename_from_file (dest);
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            string primary = _("Error while copying to \"%s\".").printf (dest_basename);
            unowned string secondary;
            unowned string? details = null;

            if (e is GLib.IOError.PERMISSION_DENIED) {
                secondary = _("You do not have permissions to access the destination folder.");
            } else {
                secondary = _("There was an error getting information about the destination.");
                details = e.message;
            }

            int response = PF.run_error (parent_window,
                                         time,
                                         progress,
                                         primary,
                                         secondary,
                                         details,
                                         false,
                                         CANCEL, RETRY,
                                         null);

            if (response == 0 || response == Gtk.ResponseType.DELETE_EVENT) {
                abort_job ();
            } else if (response == 1) {
                verify_destination (dest, out dest_fs_id, required_size);
                return;
            } else {
                GLib.assert_not_reached ();
            }

            return;
        }

        try {
            var fsinfo = dest.query_filesystem_info (GLib.FileAttribute.FILESYSTEM_FREE + "," +
                                                     GLib.FileAttribute.FILESYSTEM_READONLY,
                                                     cancellable);

            if (required_size > 0 &&
                fsinfo.has_attribute (GLib.FileAttribute.FILESYSTEM_FREE)) {
                var free_size = fsinfo.get_attribute_uint64 (GLib.FileAttribute.FILESYSTEM_FREE);

                if (free_size < required_size) {
                    var dest_name = dest.get_parse_name ();
                    /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                    /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                    string primary = _("Error while copying to \"%s\".").printf (dest_name);
                    unowned string secondary = _("There is not enough space on the destination. Try to remove files to make space.");

                    var free_size_format = GLib.format_size (free_size);
                    var required_size_format = GLib.format_size (required_size);
                    /// TRANSLATORS: %s is a placeholder for a size like "2 bytes" or "3 MB".  It must not be translated or removed.
                    /// So this represents something like "There is 100 MB available, but 150 MB is required".
                    var details = _("There is %s available, but %s is required.").printf (free_size_format, required_size_format);

                    int response = PF.run_warning (parent_window,
                                                   time,
                                                   progress,
                                                   primary,
                                                   secondary,
                                                   details,
                                                   false,
                                                   CANCEL,
                                                   COPY_FORCE,
                                                   RETRY,
                                                   null);

                    if (response == 0 || response == Gtk.ResponseType.DELETE_EVENT) {
                        abort_job ();
                    } else if (response == 2) {
                        verify_destination (dest, out dest_fs_id, required_size);
                    } else if (response == 1) {
                        /* We are forced to copy - just fall through ... */
                    } else {
                        GLib.assert_not_reached ();
                    }
                }
            }

            if (!aborted () && fsinfo.get_attribute_boolean (GLib.FileAttribute.FILESYSTEM_READONLY)) {
                var dest_name = dest.get_parse_name ();
                /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                var primary = _("Error while copying to \"%s\".").printf (dest_name);
                unowned string secondary = _("The destination is read-only.");

                PF.run_error (parent_window,
                              time,
                              progress,
                              primary,
                              secondary,
                              null,
                              false,
                              CANCEL,
                              null);

                abort_job ();
            }
        } catch (Error e) {
            /* All sorts of things can go wrong getting the fs info (like not supported)
             * only check these things if the fs returns them
             */
            return;
        }
    }
}
