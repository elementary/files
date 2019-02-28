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
    public interface GtkIconViewInterface : Gtk.Widget {
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
        public abstract void scroll_to_path (Gtk.TreePath path, bool use_align, float xalign, float yalign);
    }

    public class IconGridView : WidgetGrid.View, GtkIconViewInterface {
        construct {
            handle_cursor_keys = true;
        }

        public IconGridView (WidgetGrid.AbstractItemFactory _factory, WidgetGrid.Model<WidgetGrid.DataInterface>? _model = null) {
            base (_factory, _model);
        }

        public void set_item_width (int _item_width) {
            this.item_width = _item_width;
        }

        public void set_row_spacing (int row_spacing) {
            this.vpadding = 0;
            this.vpadding = row_spacing / 2;
        }

        public void set_column_spacing (int col_spacing) {
            this.hpadding = col_spacing / 2;
        }

        public GLib.List<Gtk.TreePath> get_selected_items () {
            var selected_data_indices = this.layout_handler.get_selected_indices ();
            var selected = new GLib.List<Gtk.TreePath> ();
            foreach (int i in selected_data_indices) {
                selected.prepend (new Gtk.TreePath.from_indices (i));
            }

            selected.reverse ();

            return selected;
        }

        public void set_drag_dest_item (Gtk.TreePath? path, Gtk.IconViewDropPosition pos) {
            /* TODO */
        }

        public Gtk.TreePath? get_path_at_pos (int x, int y) {
            int row = 0;
            int col = 0;
            Gdk.Point wp = {0, 0};

            if (layout_handler.get_row_col_at_pos (x, y, out row, out col, out wp)) {
                var index = row * layout_handler.cols + col;
                return new Gtk.TreePath.from_indices (index);
            } else {
                return null;
            }
        }

        public void select_path (Gtk.TreePath path) {
            var index = path.get_indices ()[0];
            select_index (index);
        }

        public void unselect_path (Gtk.TreePath path) {
            var index = path.get_indices ()[0];
            unselect_index (index);
        }

        public bool path_is_selected (Gtk.TreePath path) {
            var index = path.get_indices ()[0];
            var data = model.lookup_index (index);
            return data.is_selected;
        }

        public bool get_visible_range (out Gtk.TreePath? start_path, out Gtk.TreePath? end_path) {
            int first = 0;
            int last = 0;

            bool valid_paths = get_visible_range_indices (out first, out last);

            start_path = new Gtk.TreePath.from_indices (first);
            end_path = new Gtk.TreePath.from_indices (last);

            return valid_paths;
        }

        public uint get_selected_files_from_model (ref GLib.List<GOF.File> selected_files) {
            var selected_data = get_selected ();
            uint count = 0;
            foreach (WidgetGrid.DataInterface data in selected_data) {
                selected_files.prepend ((GOF.File)data);
                count++;
            }

            return count;
        }

        public void scroll_to_path (Gtk.TreePath path, bool use_align, float xalign, float yalign) {
            var index = path.get_indices ()[0];
            layout_handler.show_data_index (index, use_align, yalign);
        }

        public void set_cursor (Gtk.TreePath path, bool start_editing, bool select = false) {
            var index = path.get_indices ()[0];
            set_cursor_index (index, select);
            if (start_editing) {
                /* TODO - Obtain item and signal it to enter editing mode */
            }
        }

        public bool get_cursor (out Gtk.TreePath path) {
            path = null;
            var index = index_at_cursor ();
            if (index >=0 ) {
                path = new Gtk.TreePath.from_indices (index);
                return true;
            }

            return false;
        }

        public void linear_select_path (Gtk.TreePath path) {
            linear_select_index (path.get_indices()[0]);
        }
    }
}
