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

        construct {
//message ("Abstract ListView construct");
        }

        ~AbstractTreeView () {

        }

        protected override Gtk.Widget? create_view () {
//message ("ATV create view");
            tree = new Gtk.TreeView ();
            tree.set_model (model);
            tree.set_headers_visible (false);
            tree.set_search_column (FM.ListModel.ColumnID.FILENAME);
            tree.set_rules_hint (true);
            tree.set_rubber_banding (true);
            tree.get_selection ().set_mode (Gtk.SelectionMode.MULTIPLE);

            create_and_set_up_name_column ();
            set_up_view ();
            return tree as Gtk.Widget;
        }

        protected virtual void create_and_set_up_name_column () {

            name_column = new Gtk.TreeViewColumn ();
            name_column.set_sort_column_id (FM.ListModel.ColumnID.FILENAME);
            name_column.set_expand (true);
            name_column.set_resizable (true);

            name_renderer = new Gtk.CellRendererText ();
            name_renderer.ellipsize_set = true;
            name_renderer.ellipsize = Pango.EllipsizeMode.MIDDLE;

            pixbuf_renderer = new Gtk.CellRendererPixbuf ();
            name_column.pack_start (pixbuf_renderer, false);
            name_column.set_attributes (pixbuf_renderer,
                                        "pixbuf", FM.ListModel.ColumnID.PIXBUF);

            name_column.pack_start (name_renderer, true);
            name_column.set_cell_data_func (name_renderer, filename_cell_data_func);

            tree.append_column (name_column);
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

/** Override DirectoryView virtual methods as required, where common to ListView and MillerColumnView*/

        public override void zoom_level_changed () {
            if (tree != null) {
                int icon_size = (int) (Marlin.zoom_level_to_icon_size (zoom_level));
                int xpad = 0, ypad = 0;
                pixbuf_renderer.get_padding (out xpad, out ypad);
                pixbuf_renderer.set_fixed_size (icon_size + 2 * xpad, icon_size + 2 * ypad);

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
            if (tree.get_dest_row_at_pos (x, y, out path, null))
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

        public override void set_cursor (Gtk.TreePath? path, bool start_editing, bool select) {
//message ("ATV set cursor");
            if (path == null)
                return;

            Gtk.TreeSelection selection = tree.get_selection ();
            if (!select)
                //GLib.SignalHandler.block_by_func (selection, (void*) on_view_selection_changed, null);
                selection.changed.disconnect (on_view_selection_changed);

            tree.set_cursor_on_cell (path, name_column, name_renderer, start_editing);

            if (!select)
                //GLib.SignalHandler.unblock_by_func (selection, (void*) on_view_selection_changed, null);
                selection.changed.connect (on_view_selection_changed);

        }

        public override bool get_visible_range (out Gtk.TreePath? start_path, out Gtk.TreePath? end_path) {
            start_path = null;
            end_path = null;
            return tree.get_visible_range (out start_path, out end_path);
        }

        public override void start_renaming_file (GOF.File file, bool preselect_whole_name) {
//message ("ATV start renaming file");
            /* Select whole name if we are in renaming mode already */
            if (name_column != null && editable_widget != null) {
                editable_widget.select_region (0, -1);
                return;
            }

            Gtk.TreeIter? iter = null;
            if (!model.get_first_iter_for_file (file, out iter)) {
                critical ("Failed to find rename file in model");
                return;
            }

            /* Freeze updates to the view to prevent losing rename focus when the tree view updates */
            freeze_updates ();

            Gtk.TreePath path = model.get_path (iter);
            tree.scroll_to_cell (null, name_column, true, (float) 0.0, (float) 0.0);
            /* set cursor_on_cell also triggers editing-started, where we save the editable widget */
            tree.set_cursor_on_cell (path, name_column, name_renderer, true);

            int start_offset= 0, end_offset = -1;
            if (editable_widget != null) {
                Marlin.get_rename_region (original_name, out start_offset, out end_offset, preselect_whole_name);
                editable_widget.select_region (start_offset, end_offset);
            }
        }

        public override void sync_selection () {
            /* FIXME Not implemented - needed? */
        }

/** Treeview functions */
        /* Was filename_cell_data_func */




/**  Helper functions */
        public new void freeze_updates () {
//message ("freeze updates");
            name_renderer.@set ("editable", true, null);
            base.freeze_updates ();
        }

        public new void unfreeze_updates () {
//message ("unfreeze updates");
            name_renderer.@set ("editable", false, null);
            base.unfreeze_updates ();
        }

        protected override void update_selected_files () {
//message ("ATV update selected files");
            selected_files = null;
            tree.get_selection ().selected_foreach ((model, path, iter) => {
                GOF.File file;
                model.@get (iter, FM.ListModel.ColumnID.FILE_COLUMN, out file, -1);
                /* model does not return owned file */
                if (file != null) {
//message ("prepending %s", file.uri);
                    selected_files.prepend (file);
                } else {
                    critical ("Null file in model");
                }
            });
            selected_files.reverse ();
        }

        protected override bool on_view_button_press_event (Gdk.EventButton event) {
//message ("ATV button press");

            /* check if the event is for the bin window */
            if (event.window != tree.get_bin_window ())
                return false; /* not for us */

            slot.active ();  /* grabs focus and cancels any renaming */

            unowned Gtk.TreeSelection selection = tree.get_selection ();
            Gtk.TreePath? path = null;
            Gtk.TreeViewColumn? col = null;

            int cell_x = -1, cell_y = -1; /* The gtk+-3.0.vapi requires these even though C interface does not */
            bool on_blank = tree.is_blank_at_pos ((int) event.x, (int) event.y, out path, out col, out cell_x, out cell_y);
            bool no_mods = (event.state & Gtk.accelerator_get_default_mod_mask ()) == 0;
            bool on_icon =  (path != null) ? clicked_on_icon (event, col) : false;
            bool result = false;

            if (no_mods) {
//message ("ATV button press unselect all");
                unselect_all ();
                if (path != null)
                    selection.select_path (path);
            }

            switch (event.button) {
                case Gdk.BUTTON_PRIMARY:
                    if (path == null)
                        result = true;

                    else if (Preferences.settings.get_boolean ("single-click") && no_mods) {
                        result = handle_primary_button_single_click_mode (event, selection, path, col, no_mods, on_blank, on_icon);
                    }
                    /* In double-click mode on path the default Gtk.TreeView handler is used */
                    break;

                case Gdk.BUTTON_MIDDLE: 
                    result = handle_middle_button_click (event, on_blank);
                    break;

                case Gdk.BUTTON_SECONDARY:
                    //result = handle_secondary_button_click (event, selection, path, col, no_mods, on_blank);
                    result = handle_secondary_button_click (event);
                    break;

                default:
                    result = handle_default_button_click ();
                    break;
            }
//message ("ATV button press leaving");
            return result;
        }

//        protected override bool handle_secondary_button_click (Gdk.EventButton event, Gtk.TreeSelection? selection, Gtk.TreePath? path, Gtk.TreeViewColumn? col, bool no_mods, bool on_blank) {
//message ("ATV handle right button");
//            show_or_queue_context_menu (event);
//            return true;
//        }

        protected override bool view_has_focus () {
            return tree.has_focus;
        }

        protected bool clicked_on_icon (Gdk.EventButton event, Gtk.TreeViewColumn? col) {
            bool result = false;
            int cell_x = -1, cell_y = -1; /* The gtk+-3.0.vapi requires these even though C interface does not */
            tree.convert_bin_window_to_widget_coords ((int)event.x, (int)event.y, out cell_x, out cell_y);
            if (col != null && col == name_column) {
                int? x_offset, width;
                int expander_width = (tree.show_expanders ? 10 : 0); /* TODO Get from style class */
                if (col.cell_get_position (pixbuf_renderer, out x_offset, out width) &&
                   (cell_x <= x_offset + width + expander_width))

                    result = true;
            }

            return result;
        }
    }
}
