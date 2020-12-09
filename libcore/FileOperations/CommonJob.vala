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

public class Marlin.FileOperations.CommonJob {
    protected unowned Gtk.Window? parent_window;
    protected uint inhibit_cookie;
    protected unowned GLib.Cancellable? cancellable;
    protected PF.Progress.Info progress;
    protected Marlin.UndoActionData? undo_redo_data;
    protected CommonJob (Gtk.Window? parent_window = null) {
        this.parent_window = parent_window;
        inhibit_cookie = 0;
        progress = new PF.Progress.Info ();
        cancellable = progress.cancellable;
        undo_redo_data = null;
    }

    ~CommonJob () {
        progress.finish ();
        uninhibit_power_manager ();
        if (undo_redo_data != null) {
            Marlin.UndoManager.instance ().add_action ((owned) undo_redo_data);
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
}
