/*
 Copyright (C) 2014 elementary Developers

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
        protected int icon_renderer_xpad = 6;
        public AbstractTreeView (Marlin.View.Slot _slot) {
//message ("New Abstract ListView");
            base (_slot);
        }

        protected virtual void create_and_set_up_name_column () {
//message ("ATV create and set up name column");
            name_column = new Gtk.TreeViewColumn ();
            name_column.set_sort_column_id (FM.ListModel.ColumnID.FILENAME);
            name_column.set_expand (true);
            name_column.set_resizable (true);

            name_renderer = new Marlin.TextRenderer (Marlin.ViewMode.LIST);
            set_up_name_renderer ();
            set_up_icon_renderer ();
            name_column.pack_start (icon_renderer, false);
            name_column.set_attributes (icon_renderer,
                                        "file", FM.ListModel.ColumnID.FILE_COLUMN);

            name_column.pack_start (name_renderer, true);
            name_column.set_attributes (name_renderer,
                                        "text", FM.ListModel.ColumnID.FILENAME,
                                        "file", FM.ListModel.ColumnID.FILE_COLUMN,
                                        "background", FM.ListModel.ColumnID.COLOR);
            tree.append_column (name_column);
        }

        protected void set_up_icon_renderer () {
//message ("ATV set up icon renderer");
            icon_renderer.set_property ("follow-state",  true);
            icon_renderer.xpad = icon_renderer_xpad;
        }

        protected void set_up_view () {
//message ("ATV tree view set up view");
            connect_tree_signals ();
            Preferences.settings.bind ("single-click", tree, "activate-on-single-click", GLib.SettingsBindFlags.GET);
        }

        protected override void set_up_name_renderer () {
//message ("ATV set up name renderer");
            base.set_up_name_renderer ();
            name_renderer.@set ("wrap-width", -1);
            name_renderer.@set ("zoom-level", Marlin.ZoomLevel.NORMAL);
            name_renderer.@set ("ellipsize-set", true);
            name_renderer.@set ("ellipsize", Pango.EllipsizeMode.END);
            name_renderer.xalign = 0.0f;
            name_renderer.yalign = 0.5f; 
        }

        protected void connect_tree_signals () {
//message ("ATV connect tree_signals");
            tree.get_selection ().changed.connect (on_view_selection_changed);
            tree.realize.connect ((w) => {
                tree.grab_focus ();
                tree.columns_autosize ();
            });
        }

/** Override parent's abstract and virtual methods as required, where common to ListView and MillerColumnView*/

        protected override Gtk.Widget? create_view () {
//message ("ATV create view");
            tree = new Gtk.TreeView ();
            tree.set_model (model);
            tree.set_headers_visible (false);
            tree.set_rules_hint (true);

            create_and_set_up_name_column ();
            set_up_view ();
            tree.get_selection ().set_mode (Gtk.SelectionMode.MULTIPLE);
            tree.set_rubber_banding (true);
            return tree as Gtk.Widget;
        }

        public override void change_zoom_level () {
            if (tree != null) {
                base.change_zoom_level ();
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
            if (path != null) {
//message ("select path %s", path.to_string ());
                tree.get_selection ().select_path (path);
            }
        }
        public override void unselect_path (Gtk.TreePath? path) {
//message ("Unselect path");
            if (path != null)
                tree.get_selection ().unselect_path (path);
        }
        public override bool path_is_selected (Gtk.TreePath? path) {
            if (path != null)
                return tree.get_selection ().path_is_selected (path);
            else
                return false;
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
                if (file != null)
                    selected_files.prepend (file);

            });
            selected_files.reverse ();
//message ("ATV selected files length is %u", selected_files.length ());
        }

        protected override bool view_has_focus () {
            return tree.has_focus;
        }

        protected override uint get_event_position_info (Gdk.EventButton event, out Gtk.TreePath? path, bool rubberband = false) {
            unowned Gtk.TreePath? p = null;
            unowned Gtk.TreeViewColumn? c = null;
            uint zone;
            int cx, cy, depth;
            path = null;

            /* Check if clicked on headers */
            if (event.window != tree.get_bin_window ())
                return ClickZone.INVALID;

            bool on_blank = tree.is_blank_at_pos ((int)event.x, (int)event.y, out p, out c, out cx, out cy);
            path = p;
            depth = p != null ? p.get_depth () : 0;
            zone = (p != null ? ClickZone.BLANK_PATH : ClickZone.BLANK_NO_PATH);

            if (c != null && c == name_column) {
                int? x_offset, width;
                c.cell_get_position (icon_renderer, out x_offset, out width);
                int expander_width = (tree.show_expanders ? 10 : 0) * (depth +1); /* TODO Find a simpler way */
                expander_width += icon_renderer_xpad;
                if (cx > expander_width ) {
                    if (cx <= x_offset + width + expander_width) {
                        if (helpers_shown &&
                            ((cx -x_offset - expander_width) <= 18) &&
                            (cy <=18))
                            zone = ClickZone.HELPER;
                        else
                            zone = ClickZone.ICON;

                    } else if (!on_blank &&
                               cy < icon_size) { /* stop edge of row appearing as name */
                        zone = ClickZone.NAME;
                    } else {
                        c.cell_get_position (name_renderer, out x_offset, out width);
                        if (cx >= x_offset + width - 24)
                       zone = ClickZone.INVALID; /* Cause unselect all to occur on right margin */
                    }
                } else
                    zone = ClickZone.EXPANDER;
            } else
                zone = ClickZone.INVALID; /* Cause unselect all to occur on other columns*/

            return zone;
        }

        protected override void scroll_to_cell (Gtk.TreePath? path, Gtk.TreeViewColumn? col, bool scroll_to_top) {
//message ("ATV scroll to cell");
            if (tree == null || path == null || slot.directory.permission_denied)
                return;

            tree.scroll_to_cell (path, col, scroll_to_top, 0.0f, 0.0f);
        }
        protected override void set_cursor_on_cell (Gtk.TreePath path, Gtk.TreeViewColumn? col, Gtk.CellRenderer renderer, bool start_editing, bool scroll_to_top) {
//message ("ATV set cursor on cell");
            scroll_to_cell (path, name_column, scroll_to_top);
            tree.set_cursor_on_cell (path, col, renderer, start_editing);
        }

        public override void set_cursor (Gtk.TreePath? path, bool start_editing, bool select, bool scroll_to_top) {
            if (path == null)
                return;
//message ("ATV set cursor, select is %s", select ? "true" : "false");
            Gtk.TreeSelection selection = tree.get_selection ();

            if (!select)
                selection.changed.disconnect (on_view_selection_changed);

            set_cursor_on_cell (path, name_column, name_renderer, start_editing, scroll_to_top);

            if (!select)
                selection.changed.connect (on_view_selection_changed);

        }

        public override Gtk.TreePath? get_path_at_cursor () {
            Gtk.TreePath? path;
            tree.get_cursor (out path, null);
            return path;
        }
    }
}
