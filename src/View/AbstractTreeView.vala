/*
 Copyright (C) 

 This program is free software: you can redistribute it and/or modify it
 under the terms of the GNU Lesser General Public License version 3, as published
 by the Free Software Foundation.

 This program is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY; without even the implied warranties of
 MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 PURPOSE. See the GNU General Public License for more details.

 You should have received a copy of the GNU General Public License along
 with this program. If not, see <http://www.gnu.org/licenses/>.

 Authors : 
*/

namespace FM {
    /* Implement common features of MillerColumnView and ListView */
    public abstract class AbstractTreeView : DirectoryView {
        protected Gtk.TreeView tree;
        protected Gtk.CellRendererPixbuf pixbuf_renderer;

        public AbstractTreeView (Marlin.View.Slot _slot) {
//message ("New Abstract ListView");
            base (_slot);
        }

        protected virtual void create_and_set_up_name_column () {
            name_column = new Gtk.TreeViewColumn ();
            name_column.set_sort_column_id (FM.ListModel.ColumnID.FILENAME);
            name_column.set_expand (true);
            name_column.set_resizable (true);

            name_renderer.ellipsize_set = true;
            name_renderer.ellipsize = Pango.EllipsizeMode.MIDDLE;

            icon_renderer = new Marlin.IconRenderer ();
            set_up_icon_renderer ();
            name_column.pack_start (icon_renderer, false);
            name_column.set_attributes (icon_renderer,
                                        "file", FM.ListModel.ColumnID.FILE_COLUMN);

            name_column.pack_start (name_renderer, true);
            name_column.set_cell_data_func (name_renderer, filename_cell_data_func);

            tree.append_column (name_column);
        }

        protected void set_up_icon_renderer () {
//message ("ATV set up icon renderer");
            icon_renderer.set_property ("follow-state",  true);
            icon_renderer.set_property ("selection-helpers",  true);
        }

        protected void set_up_view () {
//message ("ATV tree view set up view");
            connect_tree_signals ();
            connect_name_renderer_signals ();
            Preferences.settings.bind ("single-click", tree, "activate-on-single-click", GLib.SettingsBindFlags.GET);   
        }

        protected void connect_tree_signals () {
//message ("ATV connect tree_signals");
            tree.get_selection ().changed.connect (on_view_selection_changed);
            tree.button_press_event.connect (on_view_button_press_event); /* Abstract */
            tree.button_release_event.connect (on_view_button_release_event); /* Abstract */
            tree.draw.connect (on_view_draw);
            tree.key_press_event.connect (on_view_key_press_event);
            tree.row_activated.connect (on_view_items_activated);
        }

        protected void connect_name_renderer_signals () {
//message ("ATV connect renderer_signals");
            name_renderer.edited.connect (on_name_edited);
            name_renderer.editing_canceled.connect (on_name_editing_canceled);
            name_renderer.editing_started.connect (on_name_editing_started);
        }

/** Override parent's abstract and virtual methods as required, where common to ListView and MillerColumnView*/

        protected override Gtk.Widget? create_view () {
//message ("ATV create view");
            tree = new Gtk.TreeView ();
            tree.set_model (model);
            tree.set_headers_visible (false);
            tree.set_search_column (FM.ListModel.ColumnID.FILENAME);
            tree.set_rules_hint (true);

            create_and_set_up_name_column ();
            set_up_view ();
            tree.get_selection ().set_mode (Gtk.SelectionMode.MULTIPLE);
            tree.set_rubber_banding (true);

            tree.add_events (Gdk.EventMask.POINTER_MOTION_MASK);
            tree.motion_notify_event.connect (on_motion_notify_event);

            return tree as Gtk.Widget;
        }

        public override void zoom_level_changed () {
            if (tree != null) {
                base.zoom_level_changed ();
                tree.columns_autosize ();
            }
        }

        public override GLib.List<Gtk.TreePath> get_selected_paths () {
            return tree.get_selection ().get_selected_rows (null);
        }

        public override void highlight_path (Gtk.TreePath? path) {
//message ("AbstractTreeView highlight path");
            tree.set_drag_dest_row (path, Gtk.TreeViewDropPosition.INTO_OR_AFTER);
        }

        public override Gtk.TreePath? get_path_at_pos (int x, int y) {
//message ("ATV get path at pos");
            Gtk.TreePath? path = null;
            if (x >= 0 && y >= 0 && tree.get_dest_row_at_pos (x, y, out path, null))
                return path;
            else
                return null;
        }

        public override void select_all () {
            tree.get_selection ().select_all ();
        }

        public override void unselect_all () {
//message ("ATV unselect all");
            tree.get_selection ().unselect_all ();
        }

        public override void select_path (Gtk.TreePath? path) {
            if (path != null)
                tree.get_selection ().select_path (path);
        }
        public override void unselect_path (Gtk.TreePath? path) {
            if (path != null)
                tree.get_selection ().unselect_path (path);
        }
        public override bool path_is_selected (Gtk.TreePath? path) {
            if (path != null)
                return tree.get_selection ().path_is_selected (path);
            else
                return false;
        }

        public override void set_cursor (Gtk.TreePath? path, bool start_editing, bool select) {
//message ("ATV set cursor");
            if (path == null)
                return;

            Gtk.TreeSelection selection = tree.get_selection ();
            if (!select)
                selection.changed.disconnect (on_view_selection_changed);

            tree.set_cursor_on_cell (path, name_column, name_renderer, start_editing);

            if (!select)
                selection.changed.connect (on_view_selection_changed);

        }

        public override bool get_visible_range (out Gtk.TreePath? start_path, out Gtk.TreePath? end_path) {
            start_path = null;
            end_path = null;
            return tree.get_visible_range (out start_path, out end_path);
        }

        public override void sync_selection () {
            /* FIXME Not implemented - needed? */
        }

        protected override void update_selected_files () {
//message ("ATV update selected files");
            selected_files = null;
            tree.get_selection ().selected_foreach ((model, path, iter) => {
                GOF.File? file; /* can be null if click on blank row in list view */
                model.@get (iter, FM.ListModel.ColumnID.FILE_COLUMN, out file, -1);
                /* model does not return owned file */
                if (file != null) {
                    selected_files.prepend (file);
                }
            });
            selected_files.reverse ();
        }

        protected override bool view_has_focus () {
            return tree.has_focus;
        }

        protected override void get_click_position_info (int x, int y,
                                                out Gtk.TreePath? path,
                                                out bool on_name,
                                                out bool on_blank,
                                                out bool on_icon,
                                                out bool on_helper) {
            unowned Gtk.TreePath? p = null;
            unowned Gtk.TreeViewColumn? c = null;
            int cx, cy;

            on_blank = tree.is_blank_at_pos (x, y, out p, out c, out cx, out cy);
            path = p;

            int depth = p != null ? p.get_depth () : 0;
            on_icon = false;
            on_helper = false;
            on_name = false;
            if (c != null && c == name_column) {
                int? x_offset, width;
                c.cell_get_position (icon_renderer, out x_offset, out width);
                int expander_width = (tree.show_expanders ? 10 : 0) * (depth + 1); /* TODO Find a simpler way */
                if (cx > expander_width ) {
                    if (cx <= x_offset + width + expander_width)
                        on_icon = true;

                    if ((cx <= x_offset + expander_width + 18) && (cy <=18))
                        on_helper = true;

                    on_name = !on_icon && !on_blank;
                } else
                    on_blank = false;
            }
        }

        protected override void scroll_to_cell (Gtk.TreePath? path, Gtk.TreeViewColumn? col) {
            tree.scroll_to_cell (path, col, false, 0.0f, 0.0f);
        }
        protected override void set_cursor_on_cell (Gtk.TreePath path, Gtk.TreeViewColumn? col, Gtk.CellRenderer renderer, bool start_editing) {
            tree.set_cursor_on_cell (path, col, renderer, start_editing);
        }
    }
}
