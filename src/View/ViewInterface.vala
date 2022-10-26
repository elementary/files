/*
* Copyright 2015-2020 elementary, Inc. (https://elementary.io)
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
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

public interface Files.ViewInterface : Gtk.Widget {
    public abstract ZoomLevel zoom_level { get; set; }
    public abstract ZoomLevel minimum_zoom { get; set; }
    public abstract ZoomLevel maximum_zoom { get; set; }
    public abstract bool sort_directories_first { get; set; }
    public abstract Files.SortType sort_type { get; set; }
    public abstract bool sort_reversed { get; set; }
    public abstract bool all_selected { get; set; }
    public abstract bool show_hidden_files { get; set; }
    public abstract bool is_renaming { get; set; }

    public signal void selection_changed ();
    public signal void path_change_request (GLib.File location);
    public signal void file_added (Files.File file);

    public virtual void set_up_zoom_level () {}
    public virtual void zoom_in () {}
    public virtual void zoom_out () {}
    public virtual void zoom_normal () {}

    public virtual void show_and_select_file (Files.File? file, bool select, bool unselect_others) {}
    public virtual void invert_selection () {}
    public virtual void select_all () {}
    public virtual void unselect_all () {}
    public virtual void file_icon_changed (Files.File file) {}
    public virtual void file_deleted (Files.File file) {}
    public virtual void file_changed (Files.File file) {}
    public virtual void add_file (Files.File file) {}
    public virtual void clear () {}

    public abstract uint get_selected_files (out List<Files.File> selected_files);
}
