/*
* Copyright 2026 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Jeremy Wootten <jeremywootten@gmail.com>
*/

/* Classes using this interface are BasicAbstractDirectoryView and AbstractDirectoryView
*/

public interface Files.DirectoryViewInterface : Gtk.Widget {
    /* Slot interface */
    public abstract int icon_size { get; }
    public abstract bool renaming { get; protected set; default = false; }
    public abstract bool is_frozen { get; set; default = false; }

    public signal void path_change_request (GLib.File location, Files.OpenFlag flag, bool new_root);
    public signal void selection_changed (GLib.List<Files.File> gof_file);

    public abstract void prepare_reload (Directory dir);
    public abstract void change_directory (Directory old_dir, Directory new_dir);
    public abstract unowned GLib.List<Files.File> get_selected_files ();
    public abstract void select_glib_files_when_thawed (
        GLib.List<GLib.File> location_list,
        GLib.File? focus_location
    );
    public abstract void select_gof_file (Files.File file);
    public abstract void select_all ();
    public abstract void unselect_all ();
    public abstract void focus_first_for_empty_selection (bool select);
    public abstract void zoom_in ();
    public abstract void zoom_out ();
    public abstract void zoom_normal ();
    public abstract void close ();
}
