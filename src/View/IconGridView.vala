/***
    Copyright (c) 2019 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace FM {
    /* Gtk.IconView functions used in Grid view mode needing to be emulated using libwidgetgrid (prior to possible refactoring) */
    public interface GtkIconViewInterface : Widget {
        public abstract void set_item_width (int item_width);
        public abstract void set_row_spacing (int row_spacing);
        public abstract void set_column_spacing (int column_spacing);
        public abstract GLib.List<Gtk.TreePath> get_selected_items ();
        public abstract void set_drag_dest_item (Gtk.TreePath? path, Gtk.IconViewDropPosition pos);
        public abstract Gtk.TreePath? get_path_at_pos (int x, int y);
        public abstract void select_path (Gtk.TreePath path);
        public abstract void unselect_path (Gtk.TreePath path);
        public abstract bool path_is_selected (Gtk.TreePath path);
        public abstract bool get_visible_range (out Gtk.TreePath? start_path, out Gtk.TreePath? end_path);
        public abstract uint get_selected_files_from_model (out GLib.List<GOF.File> selected_files);
        public abstract void scroll_to_path (Gtk.TreePath path, bool use_align, float xalign, float yalign);
        public abstract void set_cursor (Gtk.TreePath path, Gtk.CellRenderer? cell, bool start_editing);
        public abstract bool get_cursor (out Gtk.TreePath path, out unowned Gtk.CellRenderer cell);
        public abstract bool valid_path (Gtk.TreePath path);
        public abstract int get_n_columns ();
    }

    public class IconGridView : WidgetGrid.View, GtkIconViewInterface {

    }
}
