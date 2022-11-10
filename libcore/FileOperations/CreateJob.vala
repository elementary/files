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

    public CreateJob.file (Gtk.Window? parent_window, GLib.File dest_dir, string target_filename, [CCode (array_length_cname = "length")] uint8[] src_data) {
        base (parent_window);
        this.dest_dir = dest_dir;
        this.filename = target_filename;
        this.src_data = src_data;

        undo_redo_data = new UndoActionData (Files.UndoActionType.CREATEEMPTYFILE, 1);
    }
}
