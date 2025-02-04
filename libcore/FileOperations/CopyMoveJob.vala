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
    }

    public CopyMoveJob.move (Gtk.Window? parent_window, GLib.List<GLib.File> files, GLib.File? destination) {
        base (parent_window);
        this.files = files.copy_deep ((GLib.CopyFunc<GLib.File>) GLib.Object.ref);
        this.destination = destination;
        is_move = true;
    }

    protected override unowned string get_scan_primary () {
        if (is_move) {
            return _("Error while moving.");
        } else {
            return _("Error while copying.");
        }
    }

    protected override void report_count_progress (CommonJob.SourceInfo source_info) {
        string s;
        string num_bytes_format = GLib.format_size (source_info.num_bytes);

        if (!is_move) {
            /// TRANSLATORS: %'d is a placeholder for a number. It must not be translated or removed.
            /// %s is a placeholder for a size like "2 bytes" or "3 MB".  It must not be translated or removed.
            /// So this represents something like "Preparing to copy 100 files (200 MB)"
            /// The order in which %'d and %s appear can be changed by using the right positional specifier.
            s = ngettext (
                "Preparing to copy %'d file (%s)",
                "Preparing to copy %'d files (%s)",
                source_info.num_files
            ).printf (source_info.num_files, num_bytes_format);
        } else {
            /// TRANSLATORS: %'d is a placeholder for a number. It must not be translated or removed.
            /// %s is a placeholder for a size like "2 bytes" or "3 MB".  It must not be translated or removed.
            /// So this represents something like "Preparing to move 100 files (200 MB)"
            /// The order in which %'d and %s appear can be changed by using the right positional specifier.
            s = ngettext (
                "Preparing to move %'d file (%s)",
                "Preparing to move %'d files (%s)",
                source_info.num_files
            ).printf (source_info.num_files, num_bytes_format);
        }

        progress.take_details (s);
        progress.pulse_progress ();
    }

    protected void report_link_progress (int total, int left) {
        /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
        /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
        var s = _("Creating links in \"%s\"").printf (destination.get_parse_name ());

        progress.take_status (s);
        progress.take_details (
            ngettext (
                "Making link to %'d file",
                "Making links to %'d files",
                left
            ).printf (left)
        );

        progress.update_progress (left, total);
    }

    protected void report_copy_progress (CommonJob.SourceInfo source_info, CommonJob.TransferInfo transfer_info) {
        int64 now = GLib.get_monotonic_time () * 1000; // in ns

        if (transfer_info.last_report_time != 0 &&
            ((int64)transfer_info.last_report_time - now).abs () < 100 * CommonJob.NSEC_PER_MSEC) {
            return;
        }

        /* See https://github.com/elementary/files/issues/464. The job data may become invalid, possibly
         * due to a race. */
        if (files.data == null || destination == null) {
            return;
        }

        var srcname = FileUtils.custom_basename_from_file (files.data);
        var destname = FileUtils.custom_basename_from_file (destination);

        transfer_info.last_report_time = now;

        int files_left = source_info.num_files - transfer_info.num_files;

        /* Races and whatnot could cause this to be negative... */
        if (files_left < 0) {
            return;
        }

        if (files_left != transfer_info.last_reported_files_left ||
            transfer_info.last_reported_files_left == 0) {
            string s;

            /* Avoid changing this unless files_left changed since last time */
            transfer_info.last_reported_files_left = files_left;

            if (source_info.num_files == 1) {
                if (destination != null) {
                    /// TRANSLATORS: \"%s\" is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed.
                    /// \" is an escaped quotation mark.  This may be replaced with another suitable character (escaped if necessary).
                    s = (is_move ? _("Moving \"%s\" to \"%s\"") : _("Copying \"%s\" to \"%s\"")).printf (srcname, destname);
                } else {
                    /// TRANSLATORS: \"%s\" is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed.
                    /// \" is an escaped quotation mark.  This may be replaced with another suitable character (escaped if necessary).
                    s = _("Duplicating \"%s\"").printf (srcname);
                }
            } else if (files != null && files.next == null) {
                if (destination != null) {
                    /// TRANSLATORS: \"%s\" is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed.
                    /// \" is an escaped quotation mark.  This may be replaced with another suitable character (escaped if necessary).
                    /// %'d is a placeholder for a number. It must not be translated or removed.
                    /// Placeholders must appear in the same order but otherwise may change position.
                    s = (is_move ?
                            ngettext (
                                "Moving %'d file (in \"%s\") to \"%s\"",
                                "Moving %'d files (in \"%s\") to \"%s\"",
                                files_left
                            ) :
                            ngettext (
                                "Copying %'d file (in \"%s\") to \"%s\"",
                                "Copying %'d files (in \"%s\") to \"%s\"",
                                files_left
                            )
                        ).printf (files_left, srcname, destname);
                } else {
                    /// TRANSLATORS: \"%s\" is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed.
                    /// \" is an escaped quotation mark.  This may be replaced with another suitable character (escaped if necessary).
                    s = ngettext (
                        "Duplicating %'d file (in \"%s\")",
                        "Duplicating %'d files (in \"%s\")",
                        files_left
                    ).printf (files_left, destname);
                }
            } else {
                if (destination != null) {
                    /// TRANSLATORS: \"%s\" is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed.
                    /// \" is an escaped quotation mark.  This may be replaced with another suitable character (escaped if necessary).
                    /// %'d is a placeholder for a number. It must not be translated or removed.
                    /// Placeholders must appear in the same order but otherwise may change position.
                    s = (is_move ?
                        ngettext (
                            "Moving %'d file to \"%s\"",
                            "Moving %'d files to \"%s\"",
                            files_left
                        ) :
                        ngettext (
                            "Copying %'d file to \"%s\"",
                            "Copying %'d files to \"%s\"",
                            files_left
                        )
                    ).printf (files_left, destname);
                } else {
                    s = ngettext (
                        "Duplicating %'d file",
                        "Duplicating %'d files",
                        files_left
                    ).printf (files_left);
                }
            }

            progress.take_status ((owned) s);
        }

        var total_size = int64.max (source_info.num_bytes, transfer_info.num_bytes);

        double elapsed = time.elapsed ();
        double transfer_rate = 0;
        if (elapsed > 0) {
            transfer_rate = transfer_info.num_bytes / elapsed;
        }

        if (elapsed < CommonJob.SECONDS_NEEDED_FOR_RELIABLE_TRANSFER_RATE &&
            transfer_rate > 0) {
            var num_bytes_format = GLib.format_size (transfer_info.num_bytes);
            var total_size_format = GLib.format_size (total_size);
            /// TRANSLATORS: %s is a placeholder for a size like "2 bytes" or "3 MB".  It must not be translated or removed. So this represents something like "4 kb of 4 MB".
            progress.take_details (_("%s of %s").printf (num_bytes_format, total_size_format));
        } else {
            var num_bytes_format = GLib.format_size (transfer_info.num_bytes);
            var total_size_format = GLib.format_size (total_size);
            var transfer_rate_format = GLib.format_size ((uint64) transfer_rate);
            int remaining_time = (int )((total_size - transfer_info.num_bytes) / transfer_rate);
            int formated_time_unit;
            var formated_remaining_time = FileUtils.format_time (remaining_time, out formated_time_unit);


            /// TRANSLATORS: The two first %s and the last %s will expand to a size
            /// like "2 bytes" or "3 MB", the third %s to a time duration like
            /// "2 minutes". It must not be translated or removed.
            /// So the whole thing will be something like "2 kb of 4 MB -- 2 hours left (4kb/sec)"
            /// The singular/plural form will be used depending on the remaining time (i.e. the "%s left" part).
            /// The order in which %s appear can be changed by using the right positional specifier.
            var s = ngettext (
                "%s of %s \xE2\x80\x94 %s left (%s/sec)",
                "%s of %s \xE2\x80\x94 %s left (%s/sec)",
                formated_time_unit
            ).printf (num_bytes_format, total_size_format, formated_remaining_time, transfer_rate_format); //FIXME Remove opaque hex
            progress.take_details ((owned) s);
        }

        progress.update_progress (transfer_info.num_bytes, total_size);
    }

    protected void report_move_progress (int total, int left) {
        var dest_basename = Files.FileUtils.custom_basename_from_file (destination);
        /// TRANSLATORS: '\"%s\"' is a placeholder for the quoted basename of a file.  It may change position but must not be translated or removed
        /// '\"' is an escaped quoted mark.  This may be replaced with another suitable character (escaped if necessary)
        var s = _("Preparing to move to \"%s\"").printf (dest_basename);

        progress.take_status (s);
        progress.take_details (
            ngettext (
                "Preparing to move %'d file",
                "Preparing to move %'d files",
                left
            ).printf (left)
        );

        progress.pulse_progress ();
    }
}
