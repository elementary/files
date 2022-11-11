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

    public DeleteJob (Gtk.Window? parent_window, GLib.List<GLib.File> files, bool try_trash) {
        base (parent_window);
        this.files = files.copy_deep ((GLib.CopyFunc<GLib.File>) GLib.Object.ref);
        this.try_trash = try_trash;
        this.user_cancel = false;
    }
}
