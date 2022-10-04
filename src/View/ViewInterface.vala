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

    public virtual void set_up_zoom_level () {}
    public virtual void change_zoom_level (ZoomLevel zoom) {}
    public virtual void zoom_in () {}
    public virtual void zoom_out () {}
    public virtual void zoom_normal () {}

    public virtual void show_and_select_file (Files.File file, bool show, bool select) {}
    public virtual void invert_selection () {}
    public virtual void set_should_sort_directories_first (bool sort_directories_first) {}
    public virtual void set_show_hidden_files (bool show_hidden_files) {}
    public virtual void set_sort (Files.ListModel.ColumnID? col_name, Gtk.SortType reverse) {}
    public virtual void get_sort (out string sort_column_id, out string sort_order) {}
    public virtual void start_renaming_file (Files.File file) {}
    public virtual void focus_first_for_empty_selection (bool select) {}
    public virtual void select_all () {}
    public virtual void unselect_all () {}
    public virtual void file_icon_changed (Files.File file) {}
    public virtual void file_deleted (Files.File file) {}
    public virtual void file_changed (Files.File file) {}
    public virtual List<Files.File>? get_files_to_thumbnail (out uint actually_visible) { return null; }
    public virtual void add_file (Files.File file) {}
    public virtual void clear () {}


    public abstract uint get_selected_files (out List<Files.File> selected_files);


}
