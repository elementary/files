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

public class Files.FileOperations.DeleteJob : CommonJob {
    protected GLib.List<GLib.File> files;

    private bool try_trash;
    private bool delete_all;

    ~DeleteJob () {
        Files.FileChanges.consume_changes (true);
    }

    public static bool can_delete_without_confirm (GLib.File file) {
        return file.has_uri_scheme ("burn") ||
            file.has_uri_scheme ("x-nautilus-desktop") ||
            file.has_uri_scheme ("trash");
    }

    public DeleteJob (Gtk.Window? parent_window, Gee.LinkedList<string>? uris, bool try_trash) {
        base (parent_window);
        this.try_trash = try_trash;
        if (uris != null) {
            foreach (var uri in uris) {
                this.files.prepend (GLib.File.new_for_uri (uri));
            }
        }

        if (try_trash) {
            undo_redo_data = new Files.UndoActionData (MOVETOTRASH, (int) uris.size);
            undo_redo_data.set_src_dir (
                files.data.get_parent ()
            );
        }

        // Will be uninhibited in CommonJob destructor
        inhibit_power_manager (try_trash ? _("Trashing Files") : _("Deleting Files"));
    }

    protected override unowned string get_scan_primary () {
        return _("Error while deleting.");
    }

    protected bool confirm_delete_from_trash (GLib.List<GLib.File> to_delete_files) {
        string prompt;

        /* Only called if confirmation known to be required - do not second guess */
        uint file_count = to_delete_files.length ();
        if (file_count == 1) {
            string basename = Files.FileUtils.custom_basename_from_file (to_delete_files.data);
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            prompt = _("Are you sure you want to permanently delete \"%s\" from the trash?").printf (basename);
        } else {
            prompt = ngettext ("Are you sure you want to permanently delete the %'d selected item from the trash?",
                               "Are you sure you want to permanently delete the %'d selected items from the trash?",
                               file_count).printf (file_count);
        }

        return run_warning (prompt,
                            _("If you delete an item, it will be permanently lost."),
                            null,
                            false,
                            CANCEL, DELETE) == 1;
    }

    protected bool confirm_delete_directly (GLib.List<GLib.File> to_delete_files) {
        string prompt;

        /* Only called if confirmation known to be required - do not second guess */
        uint file_count = to_delete_files.length ();
        if (file_count == 1) {
            string basename = Files.FileUtils.custom_basename_from_file (to_delete_files.data);
            /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
            /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
            prompt = _("Permanently delete “%s”?").printf (basename);
        } else {
            prompt = ngettext ("Are you sure you want to permanently delete the %'d selected item?",
                               "Are you sure you want to permanently delete the %'d selected items?",
                               file_count).printf (file_count);
        }

        return run_warning (prompt,
                            _("Deleted items are not sent to Trash and are not recoverable."),
                            null,
                            false,
                            CANCEL, DELETE) == 1;
    }

    protected void report_delete_progress () requires (source_info != null && transfer_info != null) {
        int64 now = GLib.get_monotonic_time () * 1000; // in ns
        if (transfer_info.last_report_time != 0 &&
            ((int64)transfer_info.last_report_time - now).abs () < 100 * CommonJob.NSEC_PER_MSEC) {
            return;
        }

        transfer_info.last_report_time = now;

        int files_left = source_info.num_files - transfer_info.num_files;
        /* Races and whatnot could cause this to be negative... */
        if (files_left < 0) {
            files_left = 1;
        }

        string files_left_s = ngettext (
            "%'d file left to delete",
            "%'d files left to delete",
            files_left
        ).printf (files_left);

        progress.take_status (_("Deleting files"));

        double elapsed = time.elapsed ();
        if (elapsed < CommonJob.SECONDS_NEEDED_FOR_RELIABLE_TRANSFER_RATE) {
            progress.take_details ((owned) files_left_s);
        } else {
            double transfer_rate = transfer_info.num_files / elapsed;
            int remaining_time = (int) GLib.Math.floor (files_left / transfer_rate);
            int formated_time_unit;
            string formated_time = FileUtils.format_time (remaining_time, out formated_time_unit);

            /// TRANSLATORS: %s will expand to a time like "2 minutes". It must not be translated or removed.
            /// The singular/plural form will be used depending on the remaining time (i.e. the %s argument).
            string time_left_s = ngettext ("%s left", "%s left", formated_time_unit).printf (formated_time);

            string details = files_left_s.concat ("\xE2\x80\x94", time_left_s); //FIXME Remove opaque hex
            progress.take_details ((owned) details);
        }

        if (source_info.num_files != 0) {
            progress.update_progress (transfer_info.num_files, source_info.num_files);
        }
    }

    protected override void report_count_progress (CommonJob.SourceInfo source_info) {
        /// TRANSLATORS: %'d is a placeholder for a number. It must not be translated or removed.
        /// %s is a placeholder for a size like "2 bytes" or "3 MB".  It must not be translated or removed.
        /// So this represents something like "Preparing to delete 100 files (200 MB)"
        /// The order in which %'d and %s appear can be changed by using the right positional specifier.
        var s = ngettext (
            "Preparing to delete %'d file (%s)",
            "Preparing to delete %'d files (%s)",
            source_info.num_files
        ).printf (source_info.num_files, GLib.format_size (source_info.num_bytes));
        progress.take_details (s);
        progress.pulse_progress ();
    }

    private void report_trash_progress () {
        var total_files = source_info.num_files;
        var files_trashed = transfer_info.num_files;
        var files_left = total_files - files_trashed;

        progress.take_status (_("Moving files to trash"));

        var s = ngettext (
            "%'d file left to trash",
            "%'d files left to trash",
            files_left
        ).printf (files_left);
        progress.take_details (s);

        if (total_files != 0) {
            progress.update_progress (files_trashed, total_files);
        }
    }

    public async bool trash_or_delete_files (
        Cancellable? cancellable
    ) {
        int n_skipped = 0;
        List<GLib.File> delete_instead_of_trash = null;
        unowned List<GLib.File> to_delete = null;
        // List<GLib.File> to_trash = null;

        // Check whether we can trash and whether must confirm delete_all
        // Note: Some of these checks have already been done in e.g AbstractDirecoryView
        // Port C code as is for now
        //TODO: Deduplicate checks
        var must_confirm_delete = true;
        var must_confirm_delete_in_trash = true;
        GLib.File? file = files.data;
        // We can assume all files in a selection have the same uri scheme so just check first
        if (try_trash && file.has_uri_scheme ("trash")) {
            must_confirm_delete_in_trash = true;
            try_trash = false;
        } else if (can_delete_without_confirm (file)) {
            must_confirm_delete = false;
            try_trash = false;
        } else if (try_trash && file.has_uri_scheme ("smb")) {
            must_confirm_delete = true;
            try_trash = false;
        }

        if (try_trash) {
            if (trash_files (cancellable, out n_skipped, out delete_instead_of_trash)) {
                warning ("all trashed OK");
                return true; // All files successfully trashed - finish now
            } else if (aborted ()) {
                return false;
            } else {
                warning ("%i files skipped trash", n_skipped);
            }

            transfer_info.reset ();
            source_info.reset ();
        }

        // Try to delete files or failed trash files
        // unowned List<GLib.File> next_files = null;
        if (!try_trash) {
            to_delete = files;
        } else {
            to_delete = delete_instead_of_trash;
        }

        warning ("%u files to delete", to_delete.length ());
        int n_not_deleted;
        delete_files (to_delete, cancellable, out n_not_deleted);
        progress.finished ();
        //TODO Warn of any files that were not trash or deleted

        return n_not_deleted == 0;
    }

    private bool delete_files (
        List<GLib.File> to_delete,
        Cancellable? cancellable,
        out int n_not_deleted
    ) {
        n_not_deleted = 0;
        // Recursively check all files info available
        // Calculate number of files and number of bytes to transfer
        // Make a list of files the user chose to skip
        scan_sources (to_delete);
        if (aborted ()) {
            // There were problematic files (info unavailable) and the user chose to cancel
            return false;
        }

        //TODO Can we restart progress after finished in trash files?
        progress.started (); // Bypass delay

        GLib.File file = to_delete.data;

        // Permanent deletion is always confirmed except for certain schemes which are never confirmed
        // We can assume selection is always from the same folder (scheme). There is no way in Files to select from
        // different folders.
        if (!can_delete_without_confirm (file) && !confirm_delete_directly (to_delete)) {
            n_not_deleted = (int) to_delete.length ();
            return false;
        }

        unowned List<GLib.File> next_files = to_delete.first ();
        while (next_files != null && next_files.data != null) {
            file = next_files.data;
            next_files = next_files.next;

            if (should_skip_file (file)) {
                n_not_deleted++;
                continue;
            }

            if (!delete_file (file, cancellable)) {
                n_not_deleted++;
            }

            if (aborted ()) {
                break;
            }
        }

        return n_not_deleted == 0;
    }

    // Returns true if the file was actually deleted
    private bool delete_file (
        GLib.File file,
        Cancellable? cancellable
    ) {
        try {
            if (!file.@delete (cancellable)) {
                return false;
            }

            // We have to notify as monitor is blocked
            // Only top level files are recorded
            FileChanges.queue_file_removed (file);
        } catch (Error e) {
            if (e is IOError.CANCELLED) {
                abort_job ();
                return false;
            } else if (e is IOError.NOT_EMPTY) {
                return delete_non_empty_dir (file, cancellable);
                // success = delete_non_empty_dir (file, cancellable);
            } else if (skip_all_error) {
                return false;
            } else {
                // Files where info is unavailable are already skipped by scan sources
                bool? can_write, parent_can_write, readonly_fs, is_folder;
                var have_info = get_info_for_trash_delete_file_fail (
                    file,
                    out can_write,
                    out is_folder,
                    out parent_can_write,
                    out readonly_fs
                );

                // Choose suitable message strings and get response
                 var response = show_delete_fail_dialog (
                    have_info,
                    can_write ?? true,
                    is_folder ?? false,
                    parent_can_write ?? true,
                    readonly_fs ?? false,
                    e.message
                );

                if (response == 0 || response == Gtk.ResponseType.DELETE_EVENT) {
                    abort_job ();
                } else if (response == 1) { /* skip all */
                    skip_all_error = true;
                } else if (response == 2) { /* skip */
                    // Just continue
                    return false;
                } //TODO Offer RETRY?
            }
        } finally { // Runs even if return early inside try-catch?
            transfer_info.num_files++; // Increment files dealt with, not necessarily transferred
            report_delete_progress ();
        }

        return true;
    }

    private bool trash_files (
        Cancellable? cancellable,
        out int skipped,
        out List<GLib.File> to_delete
    ) {

        source_info.reset ();
        transfer_info.reset ();

        // We always try to trash all files in the selection
        source_info.num_files = (int) files.length ();

        GLib.File? file = null;
        unowned List<GLib.File> next_files = null;
        skipped = 0;
        to_delete = null;
        file = files.data;
        next_files = files.first ();

        progress.started (); // Bypass delay
        while (file != null) {
            var mtime = Files.FileUtils.get_file_modification_time (file);
            try {
                file.trash (cancellable);
                FileChanges.queue_file_removed (file); // We have to notify as monitor is blocked
                undo_redo_data.add_trashed_file (
                    file,
                    mtime
                );
            } catch (Error e) {
                if (e is IOError.CANCELLED) {
                    abort_job ();
                    break;
                } else if (skip_all_error) {
                    skipped++;
                } else if (delete_all) {
                    to_delete.prepend (file);
                } else {
                    // Try to get infos to determine why trashing failed
                    // Note: scan_sources is not called in advance for trashing
                    bool? can_write, parent_can_write, readonly_fs, is_folder;
                    var have_info = get_info_for_trash_delete_file_fail (
                        file,
                        out can_write,
                        out is_folder,
                        out parent_can_write,
                        out readonly_fs
                    );

                    // Choose suitable message strings and get response
                     var response = show_trash_fail_dialog (
                        have_info,
                        can_write ?? true,
                        is_folder ?? false,
                        parent_can_write ?? true,
                        readonly_fs ?? false,
                        e.message
                    );

                    if (response == 0 || response == Gtk.ResponseType.DELETE_EVENT) {
                        abort_job ();
                    } else if (response == 1) { /* skip all */
                        skipped++;
                        skip_all_error = true;
                    } else if (response == 2) { /* skip */
                        skipped++;
                    } else if (response == 3) { /* delete all */
                        to_delete.prepend (file);
                        delete_all = true;
                    } else if (response == 4) { /* delete */
                        to_delete.prepend (file);
                    }
                }
            } finally {
                transfer_info.num_files++;
                report_trash_progress ();
            }

            next_files = next_files.next;
            file = next_files != null ? next_files.data : null;
        }

        progress.finished ();

        if (skipped == source_info.num_files) {
            abort_job ();
        }

        return to_delete == null;
    }

    private int show_delete_fail_dialog (
        bool have_info,
        bool can_write,
        bool is_folder,
        bool parent_can_write,
        bool readonly_fs,
        string error_message
    ) {
        var primary = _("Cannot delete file");
        var secondary = "";
        if (readonly_fs) {
            secondary = _("It is not permitted to delete files on a read only filesystem.");
        } else if (parent_can_write) {
            secondary = _("It is not permitted to delete files inside folders for which you do not have write privileges.");
        } else if (is_folder && !can_write) {
            secondary = _("It is not permitted to delete folders for which you do not have write privileges.");
        } else {
            secondary = _("This file could not be deleted. See details below for further information.");
        }

        int response = run_question (
            primary,
            secondary,
            error_message,
            (source_info.num_files - transfer_info.num_files) > 1,
            CANCEL, SKIP_ALL, SKIP,
            null
        );

        return response;
    }

    private int show_trash_fail_dialog (
        bool have_info,
        bool can_write,
        bool is_folder,
        bool parent_can_write,
        bool readonly_fs,
        string error_message
    ) {
        var primary = "";
        var secondary = "";
        bool can_delete = false;
        if (readonly_fs) {
            primary = _("Cannot move file to trash or delete it");
            secondary = _("It is not permitted to trash or delete files on a read only filesystem.");
        } else if (parent_can_write) {
            primary = _("Cannot move file to trash or delete it");
            secondary = _("It is not permitted to trash or delete files inside folders for which you do not have write privileges.");
        } else if (is_folder && !can_write) {
            primary = _("Cannot move file to trash or delete it");
            secondary = _("It is not permitted to trash or delete folders for which you do not have write privileges.");
        } else {
            primary = _("Cannot move file to trash. Try to delete it immediately?");
            if (have_info) {
                secondary = _("This file could not be moved to trash. See details below for further information.");
            } else { // Cannot tell if possible to delete (but try anyway)
                secondary = _("This file could not be moved to trash. You may not be able to delete it either.");
            }

            can_delete = true;
        }

        int response;
        if (can_delete) {
            ///TRANSLATORS %s represents a complete translated sentence
            secondary = _("%s\n Deleting a file removes it permanently").printf (secondary);
            response = run_question (
                primary,
                secondary,
                error_message,
                (source_info.num_files - transfer_info.num_files) > 1,
                CANCEL, SKIP_ALL, SKIP, DELETE_ALL, DELETE,
                null);
        } else {
            response = run_question (
                primary,
                secondary,
                error_message,
                (source_info.num_files - transfer_info.num_files) > 1,
                CANCEL, SKIP_ALL, SKIP,
                null);
        }

        return response;
    }

    private bool get_info_for_trash_delete_file_fail (
        GLib.File file,
        out bool? can_write,
        out bool? is_folder,
        out bool? parent_can_write,
        out bool? readonly_fs
    ) {

        var have_info = false;
        can_write = null;
        is_folder = null;
        parent_can_write = null;
        readonly_fs = null;
        try {
            var info = file.query_info (
                FileAttribute.ACCESS_CAN_WRITE + "," + FileAttribute.STANDARD_TYPE,
                0,
                null
            );

            have_info = info != null;
            if (have_info) {
                can_write = info.get_attribute_boolean (FileAttribute.ACCESS_CAN_WRITE);
                is_folder = info.get_file_type () == FileType.DIRECTORY;
            }

            var parent_info = file.get_parent ().query_info (FileAttribute.ACCESS_CAN_WRITE, 0, null);
            if (parent_info != null) {
                parent_can_write = parent_info.get_attribute_boolean (FileAttribute.ACCESS_CAN_WRITE);
            }

            var fsinfo = file.query_filesystem_info (FileAttribute.FILESYSTEM_READONLY, null);
            if (fsinfo != null) {
                fsinfo.get_attribute_boolean (FileAttribute.FILESYSTEM_READONLY);
            }
        } catch (Error e) {
            warning ("unable to get info about trash failure");
        }

        return have_info;
    }
    // This function calls and may be called back by delete_file
    private bool delete_non_empty_dir (GLib.File dir, Cancellable? cancellable) {
        if (delete_dir_children (dir, cancellable)) {
            return delete_file (dir, cancellable);
        }

        return false;
    }

    protected bool delete_dir_children (GLib.File dir, Cancellable? cancellable) {
        GLib.FileEnumerator? enumerator = null;
        try {
            enumerator = dir.enumerate_children (
                FileAttribute.STANDARD_NAME,
                FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                cancellable
            );
        } catch (Error e) {
            if (e is IOError.CANCELLED) {
                abort_job ();
                return false;
            } else {
                var primary = (_("Error while deleting"));
                //TODO Do we need this? - permission and other info related errors already picked up by
                //scan sources or AbstractDirectoryView before deleting?
                //Ported from marlin_file_operations for now
                string secondary;
                if (e is IOError.PERMISSION_DENIED) { // Includes permissions on children
                    ///TRANSLATORS: %s is a placeholder for the basename of a file.
                    secondary = _("The folder '%s' cannot be deleted because you do not have permissions to read it").printf (dir.get_basename ());
                } else {
                    secondary = _("There was an error reading the folder '%s'").printf (dir.get_basename ());
                }

                var response = run_warning (
                    primary,
                    secondary,
                    e.message,
                    false,
                    CANCEL, SKIP, RETRY
                );

                if (response <= 0) { // Cancel button or close dialog
                    abort_job ();
                    return false;
                } else if (response == 1) {
                    /* Skip: Do nothing, do not abort */
                    return false;
                } else if (response == 2) {
                    return delete_dir_children (dir, cancellable);
                } else {
                    assert_not_reached ();
                }
            }
        }

        //Note: Individual files may not be able to be deleted even when the parent directory has
        //the required permissions. e.g. due to an "immutable" flag being set.
        try {
            unowned GLib.FileInfo? info = null;
            while ((info = enumerator.next_file (cancellable)) != null) {
                var file = dir.get_child (info.get_name ());
                // if fail to delete file than cannot delete folder so abandon  now
                if (!delete_file (file, cancellable)) {  // This updates transfer_info and progress
                    return false;
                }
            }
        } catch (Error e) {
            //This only gets errors from enumerator.next_file (). The other contained functions do not throw errors
            if (e is IOError.CANCELLED) {
                abort_job ();
            } else {
                // Most other errors other than enushould already have been handled by scan_sources
                // or delete file. Just use a simple dialog for now and return failure
                var primary = _("Files in the folder '%s' cannot be deleted").printf (dir.get_basename ());
                var secondary = _("There was an error getting information about the files in the folder");

                // For consistency use run_warning
                var response = run_warning (
                    primary,
                    secondary,
                    e.message,
                    false,
                    CANCEL
                );
            }

            return false;
        }

        return true;
    }
}
