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

public class Files.FileOperations.CopyMoveJob : CommonJob {
    protected bool is_move = false;
    protected GLib.List<GLib.File> files;
    protected GLib.File? destination;
    protected GLib.HashTable<GLib.File,bool> debuting_files = new GLib.HashTable<GLib.File,bool> (GLib.File.hash, GLib.File.equal);
    protected bool replace_all = false;
    protected bool merge_all = false;
    protected bool keep_all_newest = false;
    protected bool skip_all_conflict = false;

    ~CopyMoveJob () {
        Files.FileChanges.consume_changes (true);
    }

    public CopyMoveJob (Gtk.Window? parent_window, GLib.List<GLib.File> files, GLib.File? destination) {
        base (parent_window);
        this.files = files.copy_deep ((GLib.CopyFunc<GLib.File>) GLib.Object.ref);
        this.destination = destination;

        undo_redo_data = new UndoActionData (Files.UndoActionType.COPY, files.length ());
        undo_redo_data.set_src_dir (files.data.get_parent ());
        undo_redo_data.set_dest_dir (destination);
    }

    public CopyMoveJob.move (Gtk.Window? parent_window, GLib.List<GLib.File> files, GLib.File? destination) {
        base (parent_window);
        this.files = files.copy_deep ((GLib.CopyFunc<GLib.File>) GLib.Object.ref);
        this.destination = destination;
        is_move = true;

        if (files.data.has_uri_scheme ("trash")) {
            undo_redo_data = new UndoActionData (Files.UndoActionType.RESTOREFROMTRASH, files.length ());
        } else {
            undo_redo_data = new UndoActionData (Files.UndoActionType.MOVE, files.length ());
        }

        undo_redo_data.set_src_dir (files.data.get_parent ());
    }

    public CopyMoveJob.link (Gtk.Window? parent_window, GLib.List<GLib.File> files, GLib.File destination) {
        base (parent_window);
        this.files = files.copy_deep ((GLib.CopyFunc<GLib.File>) GLib.Object.ref);
        this.destination = destination;

        undo_redo_data = new UndoActionData (Files.UndoActionType.CREATELINK, files.length ());
        undo_redo_data.set_src_dir (files.data.get_parent ());
        undo_redo_data.set_dest_dir (destination);
    }

    public CopyMoveJob.duplicate (Gtk.Window? parent_window, GLib.List<GLib.File> files) {
        base (parent_window);
        this.files = files.copy_deep ((GLib.CopyFunc<GLib.File>) GLib.Object.ref);

        undo_redo_data = new UndoActionData (Files.UndoActionType.DUPLICATE, files.length ());
        var parent_dir = files.data.get_parent ();
        undo_redo_data.set_src_dir (parent_dir);
        undo_redo_data.set_dest_dir (parent_dir);
    }

    public async bool do_link (GLib.Cancellable? _cancellable) throws GLib.Error {
        if (_cancellable != null) {
            _cancellable.connect (() => { cancellable.cancel (); });
            cancellable.connect (() => { _cancellable.cancel (); });
        }

        progress.start ();
        verify_destination (destination, null, -1);
        if (aborted ()) {
            return false;
        }

        int total, left;
        total = left = (int) files.length ();
        report_link_progress (total, left);
        string? dest_fs_type = null;
        foreach (unowned var src in files) {
            if (aborted ()) {
                return false;
            }

            link_file (src, destination, ref dest_fs_type, left);
            report_link_progress (total, --left);
        }

        return true;
    }

    private static GLib.File get_target_file_for_link (GLib.File src, GLib.File dest_dir, string? dest_fs_type, int count) {
        GLib.File? dest = null;
        int max_length = Files.FileUtils.get_max_name_length (dest_dir);
        unowned string? editname = null;
        try {
            var info = src.query_info (GLib.FileAttribute.STANDARD_EDIT_NAME, GLib.FileQueryInfoFlags.NONE);
            editname = info.get_attribute_string (GLib.FileAttribute.STANDARD_EDIT_NAME);
        } catch (Error e) {
            debug (e.message);
        }

        if (editname != null) {
            var new_name = Files.FileUtils.get_link_name (editname, count, max_length);
            Files.FileUtils.make_file_name_valid_for_dest_fs (ref new_name, dest_fs_type);
            try {
                dest = dest_dir.get_child_for_display_name (new_name);
            } catch (Error e) {
                debug (e.message);
            }
        }

        if (dest == null) {
            var basename = src.get_basename ();
            Files.FileUtils.make_file_name_valid_for_dest_fs (ref basename, dest_fs_type);
            if (basename.validate ()) {
                var new_name = Files.FileUtils.get_link_name (basename, count, max_length);
                Files.FileUtils.make_file_name_valid_for_dest_fs (ref new_name, dest_fs_type);
                try {
                    dest = dest_dir.get_child_for_display_name (new_name);
                } catch (Error e) {
                    debug (e.message);
                }
            }

            if (dest == null) {
                var new_name = count == 1 ? "%s.lnk".printf (basename) : "%s.lnk%d".printf (basename, count);
                dest = dest_dir.get_child (new_name);
            }
        }

        return dest;
    }

    private void link_file (GLib.File src, GLib.File dest_dir, ref string? dest_fs_type, int files_left) {
        int count = 0;

        var src_dir = src.get_parent ();
        if (src_dir.equal (dest_dir)) {
            count = 1;
        }

        bool handled_invalid_filename = dest_fs_type != null;
        var dest = get_target_file_for_link (src, dest_dir, dest_fs_type, count);

        bool not_local = false;
        var path = Files.FileUtils.get_path_for_symlink (src);
        if (path == null) {
            not_local = true;
        }

        while (true) {
            try {
                if (!not_local && dest.make_symbolic_link (path, cancellable)) {
                    undo_redo_data.add_origin_target_pair (src, dest);
                    debuting_files.replace (dest, true);
                    Files.FileChanges.queue_file_added (dest);
                    return;
                }

            } catch (Error e) {
                if (e is GLib.IOError.CANCELLED) {
                    break;
                } else if (e is GLib.IOError.EXISTS) { /* Conflict */
                    dest = get_target_file_for_link (src, dest_dir, dest_fs_type, count++);
                    continue;
                } else if (e is GLib.IOError.INVALID_FILENAME && !handled_invalid_filename) {
                    handled_invalid_filename = true;
                    dest_fs_type = query_fs_type (dest_dir, cancellable);
                    var new_dest = get_target_file_for_link (src, dest_dir, dest_fs_type, count);

                    if (!dest.equal (new_dest)) {
                        dest = new_dest;

                        continue;
                    }
                } else {
                    if (skip_all_error) {
                        return;
                    }

                    var src_basename = Files.FileUtils.custom_basename_from_file (src);
                    /// TRANSLATORS: %s is a placeholder for the basename of a file.  It may change position but must not be translated or removed
                    string primary = _("Error while creating link to %s.").printf (src_basename);
                    string secondary;
                    unowned string? details = null;
                    if (not_local) {
                        secondary = _("Symbolic links only supported for local files");
                    } else if (e is GLib.IOError.NOT_SUPPORTED) {
                        secondary = _("The target doesn't support symbolic links.");
                    } else {
                        /// TRANSLATORS: %s is a placeholder for the full path of a file.  It may change position but must not be translated or removed
                        secondary = _("There was an error creating the symlink in %s.").printf (dest_dir.get_parse_name ());
                        details = e.message;
                    }

                    var response = run_warning (
                        primary,
                        secondary,
                        details,
                        files_left > 1,
                        CANCEL, SKIP_ALL, SKIP);

                    if (response == 0 || response == Gtk.ResponseType.DELETE_EVENT) {
                        abort_job ();
                    } else if (response == 1) { /* skip all */
                        skip_all_error = true;
                    } else if (response == 2) { /* skip */
                        /* do nothing */
                    } else {
                        GLib.assert_not_reached ();
                    }
                }
            }

            break;
        }
    }

    private void report_link_progress (int total, int left) {
        /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
        /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
        progress.take_status (_("Creating links in \"%s\"").printf (destination.get_parse_name ()));
        progress.take_details (ngettext ("Making link to %'d file",
                                         "Making links to %'d files",
                                         left).printf (left));

        progress.update_progress (left, total);
    }
}
