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
    protected const int NSEC_PER_MSEC = 1000000;
    protected const int SECONDS_NEEDED_FOR_RELIABLE_TRANSFER_RATE = 15;

    [Compact]
    [CCode (cname = "SourceInfo")]
    protected class SourceInfo {
        internal int num_files;
        internal int64 num_bytes;
        internal int num_files_since_progress;

        public SourceInfo copy () {
            return new SourceInfo () {
                num_files = this.num_files,
                num_bytes = this.num_bytes,
                num_files_since_progress = this.num_files_since_progress,
            };
        }
    }

    [Compact]
    [CCode (cname = "TransferInfo")]
    protected class TransferInfo {
        internal int num_files;
        internal int64 num_bytes;
        internal uint64 last_report_time;
        internal int last_reported_files_left;
    }

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

    protected virtual unowned string get_scan_primary () {
        GLib.warn_if_reached ();
        return _("Error while copying.");
    }

    protected virtual void report_count_progress (CommonJob.SourceInfo source_info) {
        GLib.warn_if_reached ();
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

                run_error (primary,
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

            int response = run_error (primary,
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

                    int response = run_warning (primary,
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

                run_error (primary,
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

    private void count_file (GLib.FileInfo info, SourceInfo source_info) {
        source_info.num_files += 1;
        source_info.num_bytes += info.get_size ();
        if (source_info.num_files_since_progress++ > 100) {
            report_count_progress (source_info);
            source_info.num_files_since_progress = 0;
        }
    }

    private void scan_dir (GLib.File dir, SourceInfo source_info, GLib.Queue<GLib.File> dirs) {
        var saved_source_info = source_info.copy ();
        GLib.FileEnumerator? enumerator = null;
        try {
            enumerator = dir.enumerate_children (GLib.FileAttribute.STANDARD_NAME + "," +
                                                 GLib.FileAttribute.STANDARD_TYPE + "," +
                                                 GLib.FileAttribute.STANDARD_SIZE,
                                                 GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                                                 cancellable);
        } catch (Error e) {
            if (e is GLib.IOError.CANCELLED) {
                // Do nothing
            } else {
                var dir_basename = FileUtils.custom_basename_from_file (dir);
                unowned string primary = get_scan_primary ();
                string secondary;
                string? details = null;
                if (e is GLib.IOError.PERMISSION_DENIED) {
                    /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                    /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                    secondary = _("The folder \"%s\" cannot be handled because you do not have permissions to read it.").printf (dir_basename);
                } else {
                    /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                    /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                    secondary = _("There was an error reading the folder \"%s\".").printf (dir_basename);
                    details = e.message;
                }

                var response = run_warning (primary, secondary, details, false, CANCEL, RETRY, SKIP);

                if (response == 0 || response == Gtk.ResponseType.DELETE_EVENT) {
                    abort_job ();
                } else if (response == 1) {
                    source_info.num_files = saved_source_info.num_files;
                    source_info.num_bytes = saved_source_info.num_bytes;
                    source_info.num_files_since_progress = saved_source_info.num_files_since_progress;
                    scan_dir (dir, source_info, dirs);
                } else if (response == 2) {
                    skip_readdir_error (dir);
                } else {
                    GLib.assert_not_reached ();
                }
            }

            return;
        }

        try {
            unowned GLib.FileInfo? info = null;
            while ((info = enumerator.next_file (cancellable)) != null) {
                count_file (info, source_info);
                if (info.get_file_type () == FileType.DIRECTORY) {
                    /* Push to head, since we want depth-first */
                    var subdir = dir.get_child (info.get_name ());
                    dirs.push_head (subdir);
                }
            }
        } catch (Error e) {
            if (e is GLib.IOError.CANCELLED) {
                // Do nothing
            } else {
                var dir_basename = FileUtils.custom_basename_from_file (dir);
                unowned string primary = get_scan_primary ();
                string secondary;
                string? details = null;
                if (e is GLib.IOError.PERMISSION_DENIED) {
                    /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                    /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                    secondary = _("Files in the folder \"%s\" cannot be handled because you do not have permissions to see them.").printf (dir_basename);
                } else {
                    /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                    /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                    secondary = _("There was an error getting information about the files in the folder \"%s\".").printf (dir_basename);
                    details = e.message;
                }

                var response = run_warning (primary, secondary, details, false, CANCEL, SKIP_ALL, SKIP, RETRY);

                if (response == 0 || response == Gtk.ResponseType.DELETE_EVENT) {
                    abort_job ();
                } else if (response == 1) {
                    source_info = saved_source_info;
                    scan_dir (dir, source_info, dirs);
                } else if (response == 2) {
                    skip_readdir_error (dir);
                } else {
                    GLib.assert_not_reached ();
                }
            }
        }
    }

    private void scan_file (GLib.File file, SourceInfo source_info, GLib.Queue<GLib.File> dirs = new GLib.Queue<GLib.File> ()) {
        try {
            var info = file.query_info (GLib.FileAttribute.STANDARD_TYPE + "," + GLib.FileAttribute.STANDARD_SIZE, NOFOLLOW_SYMLINKS, cancellable);
            count_file (info, source_info);
            if (info.get_file_type () == GLib.FileType.DIRECTORY) {
                dirs.push_head (file);
            }
        } catch (Error e) {
            if (skip_all_error) {
                skip_file (file);
            } else if (e is GLib.IOError.CANCELLED) {
                // Do nothing
            } else {
                var file_basename = FileUtils.custom_basename_from_file (file);
                unowned string? primary = get_scan_primary ();
                string secondary;
                string? details = null;

                if (e is GLib.IOError.PERMISSION_DENIED) {
                    /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                    /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                    secondary = _("The file \"%s\" cannot be handled because you do not have permissions to read it.").printf (file_basename);
                } else {
                    /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
                    /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
                    secondary = _("There was an error getting information about \"%s\".").printf (file_basename);
                    details = e.message;
                }

                /* set show_all to TRUE here, as we don't know how many
                 * files we'll end up processing yet.
                 */
                var response = run_warning (primary, secondary, details, true, CANCEL, SKIP_ALL, SKIP, RETRY);

                if (response == 0 || response == Gtk.ResponseType.DELETE_EVENT) {
                    abort_job ();
                } else if (response == 1 || response == 2) {
                    if (response == 1) {
                        skip_all_error = true;
                    }

                    skip_file (file);
                } else if (response == 3) {
                    scan_file (file, source_info, dirs);
                } else {
                    GLib.assert_not_reached ();
                }
            }
        }

        GLib.File? dir = null;
        while (!aborted () && (dir = dirs.pop_head ()) != null) {
            scan_dir (dir, source_info, dirs);
        }
    }

    protected SourceInfo scan_sources (GLib.List<GLib.File> files) {
        var source_info = new SourceInfo ();

        report_count_progress (source_info);
        foreach (var file in files) {
            if (aborted ()) {
                return source_info;
            }

            scan_file (file, source_info);
        }

        /* Make sure we report the final count */
        report_count_progress (source_info);
        return source_info;
    }


    private int run_simple_dialog_va (Gtk.MessageType message_type,
                                      owned string primary_text,
                                      owned string secondary_text,
                                      string? details_text,
                                      bool show_all,
                                      va_list varargs) {
        int result = 0;
        time.stop ();
        progress.pause ();

        unowned string image_name;
        switch (message_type) {
            case Gtk.MessageType.ERROR:
                image_name = "dialog-error";
                break;
            case Gtk.MessageType.WARNING:
                image_name = "dialog-warning";
                break;
            case Gtk.MessageType.QUESTION:
                image_name = "dialog-question";
                break;
            default:
                image_name = "dialog-information";
                break;
        }

        var main_loop = new GLib.MainLoop ();
        var buttons = new GLib.List<string> ();
        for (unowned string? title = varargs.arg<string?> (); title != null ; title = varargs.arg<string?> ()) {
            buttons.append (title);
        }

        Idle.add (() => {
            var dialog = new Granite.MessageDialog.with_image_from_icon_name (primary_text,
                                                                              secondary_text,
                                                                              image_name,
                                                                              Gtk.ButtonsType.NONE);
            dialog.transient_for = parent_window;
            int response_id = 0;
            foreach (unowned string title in buttons) {
                unowned Gtk.Widget button = dialog.add_button (title, response_id);
                if (title == DELETE || title == DELETE_ALL || title == EMPTY_TRASH) {
                    button.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
                }

                response_id++;
            }

            if (response_id == 0) {
                dialog.add_button (_("Close"), 0);
            }

            //FIXME: Granite.MessageDialog.show_error_details call Gtk.Widget.show_all ()
            // which breaks the current implementation in marlin-file-operation.c
            // as the dialog is being created in a thread but presented in the
            // Gtk thread. Remove the Idle.add once everything is done in the Gtk thread.
            if (details_text != null) {
                dialog.show_error_details (details_text);
            }

            dialog.response.connect ((response_id) => {
                result = response_id;
                main_loop.quit ();
                dialog.destroy ();
            });

            dialog.show ();
            return Source.REMOVE;
        });

        main_loop.run ();
        progress.resume ();
        time.continue ();
        return result;
    }

    public int run_error (owned string primary_text,
                          owned string secondary_text,
                          string? details_text,
                          bool show_all,
                          ...) {
        return run_simple_dialog_va (Gtk.MessageType.ERROR,
                                     (owned) primary_text,
                                     (owned) secondary_text,
                                     details_text,
                                     show_all,
                                     va_list ());
    }

    public int run_warning (owned string primary_text,
                            owned string secondary_text,
                            string? details_text,
                            bool show_all,
                            ...) {
        return run_simple_dialog_va (Gtk.MessageType.WARNING,
                                     (owned) primary_text,
                                     (owned) secondary_text,
                                     details_text,
                                     show_all,
                                     va_list ());
    }

    public int run_question (owned string primary_text,
                             owned string secondary_text,
                             string? details_text,
                             bool show_all,
                             ...) {
        return run_simple_dialog_va (Gtk.MessageType.QUESTION,
                                     (owned) primary_text,
                                     (owned) secondary_text,
                                     details_text,
                                     show_all,
                                     va_list ());
    }

    public int run_conflict_dialog (GLib.File src,
                                    GLib.File dest,
                                    GLib.File dest_dir,
                                    out string? new_name,
                                    out bool apply_to_all) {
        int result = 0;
        string? _new_name = null;
        bool _apply_to_all = false;

        time.stop ();
        progress.pause ();

        var main_loop = new GLib.MainLoop (MainContext.get_thread_default ());

        Idle.add (() => {
            var dialog = new Files.FileConflictDialog (parent_window, src, dest, dest_dir);
            dialog.response.connect ((response_id) => {
                result = response_id;
                _apply_to_all = dialog.apply_to_all;
                if (response_id == Files.FileConflictDialog.ResponseType.RENAME) {
                    _new_name = dialog.new_name;
                }
                main_loop.quit ();
                dialog.destroy ();
            });

            dialog.show ();
            return Source.REMOVE;
        });

        main_loop.run ();

        new_name = _new_name;
        apply_to_all = _apply_to_all;
        progress.resume ();
        time.continue ();
        return result;
    }
}
