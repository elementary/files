/* Copyright 2021 elementary LLC (https://elementary.io)
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
    protected GLib.List<GLib.File> files;
    protected GLib.File? destination;
    protected bool is_move;
    protected bool merge_all;
    protected bool replace_all;
    protected bool skip_all_conflict;
    protected bool keep_all_newest;

    public CopyMoveJob.copy (Gtk.Window? parent_window = null, owned GLib.List<GLib.File> files, GLib.File target_dir) {
        base (parent_window);
        this.files = (owned) files;
        this.destination = target_dir;
        timer = new GLib.Timer ();

        undo_redo_data = new UndoActionData (Files.UndoActionType.COPY, (int) this.files.length ());
        undo_redo_data.src_dir = this.files.nth_data (0).get_parent ();
        undo_redo_data.dest_dir = target_dir;
    }

    public CopyMoveJob.move (Gtk.Window? parent_window = null, owned GLib.List<GLib.File> files, GLib.File target_dir) {
        base (parent_window);
        this.files = (owned) files;
        this.destination = target_dir;
        timer = new GLib.Timer ();

        if (this.files.nth_data (0).has_uri_scheme ("trash")) {
            undo_redo_data = new UndoActionData (Files.UndoActionType.RESTOREFROMTRASH, (int) this.files.length ());
        } else {
            undo_redo_data = new UndoActionData (Files.UndoActionType.MOVE, (int) this.files.length ());
        }
        undo_redo_data.src_dir = this.files.nth_data (0).get_parent ();
        undo_redo_data.dest_dir = target_dir;
    }

    public CopyMoveJob.duplicate (Gtk.Window? parent_window = null, owned GLib.List<GLib.File> files) {
        base (parent_window);
        this.files = (owned) files;
        timer = new GLib.Timer ();

        undo_redo_data = new UndoActionData (Files.UndoActionType.DUPLICATE, (int) this.files.length ());
        undo_redo_data.src_dir = this.files.nth_data (0).get_parent ();
        undo_redo_data.dest_dir = undo_redo_data.src_dir;
    }

    public CopyMoveJob.link (Gtk.Window? parent_window = null, owned GLib.List<GLib.File> files, GLib.File target_dir) {
        base (parent_window);
        this.files = (owned) files;
        timer = new GLib.Timer ();

        undo_redo_data = new UndoActionData (Files.UndoActionType.CREATELINK, (int) this.files.length ());
        undo_redo_data.src_dir = this.files.nth_data (0).get_parent ();
        undo_redo_data.dest_dir = target_dir;
    }

    ~CopyMoveJob () {
        FileChanges.consume_changes (true);
    }
}
