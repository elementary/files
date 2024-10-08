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
    protected bool try_trash;
    protected bool user_cancel;
    protected bool delete_all;

    ~DeleteJob () {
        Files.FileChanges.consume_changes (true);
    }

    public static bool can_delete_without_confirm (GLib.File file) {
        return file.has_uri_scheme ("burn") ||
            file.has_uri_scheme ("x-nautilus-desktop") ||
            file.has_uri_scheme ("trash");
    }

    public DeleteJob (Gtk.Window? parent_window, GLib.List<GLib.File> files, bool try_trash) {
        base (parent_window);
        this.files = files.copy_deep ((GLib.CopyFunc<GLib.File>) GLib.Object.ref);
        this.try_trash = try_trash;
        this.user_cancel = false;
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

    protected void report_delete_progress (CommonJob.SourceInfo source_info, CommonJob.TransferInfo transfer_info) {
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

    protected void report_delete_count_progress (CommonJob.SourceInfo source_info) {
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

    protected void report_trash_progress (int files_trashed, int total_files) {
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
}
