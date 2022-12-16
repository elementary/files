/* Copyright 2022 elementary LLC (https://elementary.io)
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

public class Files.FileOperations.CreateJob : CommonJob {
    protected GLib.File dest_dir;
    protected string? filename;
    protected bool make_dir;
    protected GLib.File? src;
    [CCode (array_length_cname = "length")]
    protected uint8[]? src_data;
    protected GLib.File created_file;

    ~CreateJob () {
        Files.FileChanges.consume_changes (true);
    }

    public CreateJob.folder (Gtk.Window? parent_window, GLib.File dest_dir) {
        base (parent_window);
        this.dest_dir = dest_dir;
        this.make_dir = true;

        undo_redo_data = new UndoActionData (Files.UndoActionType.CREATEFOLDER, 1);
    }

    public CreateJob.file_from_template (Gtk.Window? parent_window, GLib.File dest_dir, string target_filename, GLib.File? src) {
        base (parent_window);
        this.dest_dir = dest_dir;
        this.filename = target_filename;
        this.src = src;

        undo_redo_data = new UndoActionData (Files.UndoActionType.CREATEFILEFROMTEMPLATE, 1);
    }

    public CreateJob.file (Gtk.Window? parent_window, GLib.File dest_dir, string? target_filename, [CCode (array_length_cname = "length")] uint8[] src_data) {
        base (parent_window);
        this.dest_dir = dest_dir;
        this.filename = target_filename;
        this.src_data = src_data;

        undo_redo_data = new UndoActionData (Files.UndoActionType.CREATEEMPTYFILE, 1);
    }

    public async GLib.File? do_create (GLib.Cancellable? _cancellable) throws GLib.Error {
        if (_cancellable != null) {
            _cancellable.connect (() => { cancellable.cancel (); });
            cancellable.connect (() => { _cancellable.cancel (); });
        }

        progress.start ();
        verify_destination (dest_dir, null, -1);
        if (aborted ()) {
            return null;
        }

        bool filename_is_utf8;
        if (filename == null) {
            if (make_dir) {
                /* localizers: the initial name of a new folder  */
                filename = _("untitled folder");
                filename_is_utf8 = true; /* Pass in utf8 */
            } else {
                if (src != null) {
                    filename = src.get_basename ();
                }

                if (filename == null) {
                    /* localizers: the initial name of a new empty file */
                    filename = _("new file");
                    filename_is_utf8 = true; /* Pass in utf8 */
                } else {
                    filename_is_utf8 = filename.validate ();
                }
            }
        } else {
            filename_is_utf8 = filename.validate ();
        }

        GLib.File? dest = null;
        Files.FileUtils.make_file_name_valid_for_dest_fs (ref filename, null); //FIXME No point - dest_fs_type always null?
        if (filename_is_utf8) {
            try {
                dest = dest_dir.get_child_for_display_name (filename);
            } catch (Error e) {
                debug (e.message);
            }
        }

        if (dest == null) {
            dest = dest_dir.get_child (filename);
        }

        uint count = 1;
        bool handled_invalid_filename = false;
        string? dest_fs_type = null;

        while (true) {
            try {
                if (make_dir) {
                    yield dest.make_directory_async (GLib.Priority.DEFAULT_IDLE, cancellable);
                    undo_redo_data.set_create_data (dest.get_uri ());
                } else {
                    if (src != null) {
                        yield src.copy_async (dest, GLib.FileCopyFlags.NONE, GLib.Priority.DEFAULT_IDLE, cancellable, null);
                        undo_redo_data.set_create_data (dest.get_uri (), src.get_uri ());
                    } else {
                        GLib.FileOutputStream out_stream = yield dest.create_async (GLib.FileCreateFlags.NONE, GLib.Priority.DEFAULT_IDLE, cancellable);
                        if (src_data != null) {
                            yield out_stream.write_all_async (src_data, GLib.Priority.DEFAULT_IDLE, cancellable, null);
                        }

                        yield out_stream.close_async (GLib.Priority.DEFAULT_IDLE, cancellable);
                        undo_redo_data.set_create_data (dest.get_uri (), (string)src_data);
                    }
                }

                created_file = dest;
                Files.FileChanges.queue_file_added (dest);
            } catch (Error e) {
                int max_length = Files.FileUtils.get_max_name_length (dest_dir);
                if (e is GLib.IOError.CANCELLED) {
                    break;
                } else if (e is GLib.IOError.EXISTS) { /* Conflict */
                    dest = null;
                    string new_filename;
                    if (make_dir) {
                        new_filename = "%s %u".printf (filename, ++count);
                        if (max_length > 0 && new_filename.length > max_length) {
                            new_filename = Files.FileUtils.shorten_utf8_string (new_filename, new_filename.length - max_length);
                        }
                    } else {
                        /*We are not creating link*/
                        new_filename = Files.FileUtils.get_duplicate_name (filename, count++, max_length, false);
                    }

                    Files.FileUtils.make_file_name_valid_for_dest_fs (ref new_filename, dest_fs_type);
                    if (filename_is_utf8) {
                        try {
                            dest = dest_dir.get_child_for_display_name (new_filename);
                        } catch (Error e) {
                            debug (e.message);
                        }
                    }

                    if (dest == null) {
                        dest = dest_dir.get_child (new_filename);
                    }

                    continue;
                } else if (e is GLib.IOError.INVALID_FILENAME && !handled_invalid_filename) {
                    handled_invalid_filename = true;
                    dest_fs_type = query_fs_type (dest_dir, cancellable);

                    string new_filename;
                    if (count == 1) {
                        new_filename = filename;
                    } else if (make_dir) {
                        var filename2 = "%s %u".printf (filename, count);
                        if (max_length > 0 && filename2.length > max_length) {
                            new_filename = Files.FileUtils.shorten_utf8_string (filename2, filename2.length - max_length);
                        } else {
                            new_filename = (owned)filename2;
                        }
                    } else {
                        /*We are not creating link*/
                        new_filename = Files.FileUtils.get_duplicate_name (filename, count, max_length, false);
                    }

                    if (Files.FileUtils.make_file_name_valid_for_dest_fs (ref new_filename, dest_fs_type)) {
                        if (filename_is_utf8) {
                            try {
                                dest = dest_dir.get_child_for_display_name (new_filename);
                            } catch (Error e) {
                                debug (e.message);
                            }
                        }

                        if (dest == null) {
                            dest = dest_dir.get_child (new_filename);
                        }

                        continue;
                    }
                } else {
                    var dest_basename = Files.FileUtils.custom_basename_from_file (dest);
                    string primary;
                    if (make_dir) {
                        /// TRANSLATORS: %s is a placeholder for the basename of a file.  It may change position but must not be translated or removed
                        primary = _("Error while creating directory %s.").printf (dest_basename);
                    } else {
                        /// TRANSLATORS: %s is a placeholder for the basename of a file.  It may change position but must not be translated or removed
                        primary = _("Error while creating file %s.").printf (dest_basename);
                    }

                    /// TRANSLATORS: %s is a placeholder for the full path of a file.  It may change position but must not be translated or removed
                    string secondary = _("There was an error creating the directory in %s.").printf (dest_dir.get_parse_name ());
                    unowned string details = e.message;

                    var response = run_warning (
                        primary,
                        secondary,
                        details,
                        false,
                        CANCEL, SKIP);

                    if (response == 0 || response == Gtk.ResponseType.DELETE_EVENT) {
                        abort_job ();
                    } else if (response == 1) { /* skip */
                        /* do nothing */
                    } else {
                        GLib.assert_not_reached ();
                    }
                }
            }

            break;
        }

        return created_file;
    }
}
