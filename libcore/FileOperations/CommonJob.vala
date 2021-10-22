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
    protected Cancellable? cancellable {
        get {
            return progress != null ? progress.cancellable : null;
        }
    }
    protected unowned PF.Progress.Info? progress; // Must be able to finalize info even when job blocks
    protected Files.UndoActionData? undo_redo_data;
    protected CommonJob (Gtk.Window? parent_window = null) {
        this.parent_window = parent_window;
        progress = PF.Progress.InfoManager.get_instance ().get_new_info (parent_window);
        undo_redo_data = null;
    }

    ~CommonJob () {
        if (progress != null) { // progress was not cancelled or otherwise destroyed
            progress.finish ();
        }
    }

    protected void inhibit_power_manager (string message) {
        progress.inhibit_power_manager (message);
    }

    protected bool aborted () {
        return cancellable != null || cancellable.is_cancelled ();
    }
}
