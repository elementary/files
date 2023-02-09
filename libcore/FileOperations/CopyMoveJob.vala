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
}
