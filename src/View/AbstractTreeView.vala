/***
    Copyright (c) 2015-2017 elementary LLC (http://launchpad.net/elementary)

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
    /* Implement common features of ColumnView and ListView */
    public abstract class AbstractTreeView : AbstractDirectoryView {
        const int ICON_XPAD = 6;

        protected Gtk.TreeView tree;
        protected Gtk.TreeViewColumn name_column;

        public AbstractTreeView (Marlin.View.Slot _slot) {
            assert (_slot != null);
            base (_slot);
        }

        ~AbstractTreeView () {
            debug ("ATV destruct");
        }

        protected virtual void create_and_set_up_name_column () {
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
            icon_renderer.set_property ("follow-state",  true);
            icon_renderer.xpad = ICON_XPAD;
        }

        protected void set_up_view () {
            connect_tree_signals ();
            tree.realize.connect ((w) => {
                tree.grab_focus ();
                tree.columns_autosize ();
            });
        }

        protected override void set_up_name_renderer () {
            base.set_up_name_renderer ();
            name_renderer.@set ("wrap-width", -1);
            name_renderer.@set ("zoom-level", Marlin.ZoomLevel.NORMAL);
            name_renderer.@set ("ellipsize-set", true);
            name_renderer.@set ("ellipsize", Pango.EllipsizeMode.END);
            name_renderer.xalign = 0.0f;
            name_renderer.yalign = 0.5f;
        }

        protected override void connect_tree_signals () {
            tree.get_selection ().changed.connect (on_view_selection_changed);
        }
        protected override void disconnect_tree_signals () {
            tree.get_selection ().changed.disconnect (on_view_selection_changed);
        }

        protected override Gtk.Widget? create_view () {
            tree = new Gtk.TreeView ();
            tree.set_model (model);
            tree.set_headers_visible (false);
            tree.set_rules_hint (true);
            tree.get_selection ().set_mode (Gtk.SelectionMode.MULTIPLE);
            tree.set_rubber_banding (true);

            create_and_set_up_name_column ();
            set_up_view ();

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
            tree.set_drag_dest_row (path, Gtk.TreeViewDropPosition.INTO_OR_AFTER);
        }

        public override Gtk.TreePath? get_path_at_pos (int x, int y) {
            Gtk.TreePath? path = null;

            if (x >= 0 && y >= 0 && tree.get_dest_row_at_pos (x, y, out path, null))
                return path;
            else
                return null;
        }

        public override void select_all () {
            tree.get_selection ().select_all ();
            all_selected = true;
        }

        public override void unselect_all () {
            tree.get_selection ().unselect_all ();
            all_selected = false;
        }

        /* Avoid using this function with "cursor_follows = true" to select large numbers of files one by one
         * It would take an exponentially long time. Use "select_files" function in parent class.
         */
        public override void select_path (Gtk.TreePath? path, bool cursor_follows = false) {
            if (path != null) {
                var selection = tree.get_selection ();
                selection.select_path (path);
                if (cursor_follows) {
                    /* Unlike for IconView, set_cursor unselects previously selected paths (Gtk bug?),
                     * so we have to remember them and reselect afterwards */
                    GLib.List<Gtk.TreePath> selected_paths = null;
                    selection.selected_foreach ((m, p, i) => {
                        selected_paths.prepend (p);
                    });
                    /* Ensure cursor follows last selection */
                    tree.set_cursor (path, null, false);  /* This selects path but unselects rest! */

                    selected_paths.@foreach ((p) => {
                       selection.select_path (p);
                    });
                }
            }
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

        public override bool get_visible_range (out Gtk.TreePath? start_path,
                                                out Gtk.TreePath? end_path) {
            start_path = null;
            end_path = null;
            return tree.get_visible_range (out start_path, out end_path);
        }

        public override void sync_selection () {
            /* Not implemented - needed? No current bug reports. */
        }

        protected override void update_selected_files () {
            selected_files = null;

            tree.get_selection ().selected_foreach ((model, path, iter) => {
                GOF.File? file; /* can be null if click on blank row in list view */
                model.@get (iter, FM.ListModel.ColumnID.FILE_COLUMN, out file, -1);
                if (file != null) {
                    selected_files.prepend (file);
                }
            });
            selected_files.reverse ();
        }

        protected override bool view_has_focus () {
            return tree.has_focus;
        }

        protected override uint get_event_position_info (Gdk.EventButton event,
                                                         out Gtk.TreePath? path,
                                                         bool rubberband = false) {
            Gtk.TreePath? p = null;
            unowned Gtk.TreeViewColumn? c = null;
            uint zone;
            int x, y, cx, cy, depth;
            path = null;

            if (event.window != tree.get_bin_window ()) {
                return ClickZone.INVALID;
            }

            x = (int)event.x;
            y = (int)event.y;

            /* Determine whether there whitespace at this point.  Note: this function returns false when the
             * position is on the edge of the cell, even though this appears to be blank. We
             * deal with this below. */
            var is_blank = tree.is_blank_at_pos ((int)event.x, (int)event.y, null, null, null, null);

            tree.get_path_at_pos ((int)event.x, (int)event.y, out p, out c, out cx, out cy);
            path = p;
            depth = p != null ? p.get_depth () : 0;

            /* Determine whether on edge of cell and designate as blank */
            Gdk.Rectangle area;
            tree.get_cell_area (p, c, out area);
            int height = area.height;

            is_blank = is_blank || cy < 5 || cy > height - 5;

            /* Do not allow rubberbanding to start except on a row in tree view */
            zone = (p != null && is_blank ? ClickZone.BLANK_PATH : ClickZone.INVALID);

            if (p != null && c != null && c == name_column) {
                int orig_x = area.x + ICON_XPAD;
                if (x < orig_x + icon_size) { /* cannot be on name */
                    bool on_helper = false;
                    bool on_icon = is_on_icon (x, y, orig_x, area.y, ref on_helper);

                    if (on_helper) {
                        zone = ClickZone.HELPER;
                    } else if (on_icon) {
                        zone = ClickZone.ICON;

                    } else {
                        zone = ClickZone.EXPANDER;
                    }
                } else if (!is_blank) {
                        zone = ClickZone.NAME;
                }
            } else if (c != name_column)
                zone = ClickZone.INVALID; /* Cause unselect all to occur on other columns*/

            return zone;
        }

        protected override bool handle_secondary_button_click (Gdk.EventButton event) {
            /* In Column and List Views show background menu on all white space to allow
             * creation of new folder when view full. */
            if (click_zone == ClickZone.BLANK_PATH) {
                unselect_all ();
            }
            return base.handle_secondary_button_click (event);
        }

        protected override void scroll_to_cell (Gtk.TreePath? path, bool scroll_to_top) {
            if (tree == null || path == null || slot == null || /* slot should not be null but see lp:1595438 */
                slot.directory.permission_denied || slot.directory.is_empty ()) {

                return;
            }
            tree.scroll_to_cell (path, name_column, scroll_to_top, 0.5f, 0.5f);
        }

        protected override void set_cursor_on_cell (Gtk.TreePath path,
                                                    Gtk.CellRenderer renderer,
                                                    bool start_editing,
                                                    bool scroll_to_top) {
            scroll_to_cell (path, scroll_to_top);
            tree.set_cursor_on_cell (path, name_column, renderer, start_editing);
        }

        public override void set_cursor (Gtk.TreePath? path,
                                         bool start_editing,
                                         bool select,
                                         bool scroll_to_top) {
            if (path == null)
                return;

            Gtk.TreeSelection selection = tree.get_selection ();

            if (!select) {
                selection.changed.disconnect (on_view_selection_changed);
            } else {
                select_path (path);
            }

            set_cursor_on_cell (path, name_renderer, start_editing, scroll_to_top);

            if (!select) {
                selection.changed.connect (on_view_selection_changed);
            }
        }

        public override Gtk.TreePath? get_path_at_cursor () {
            Gtk.TreePath? path;
            tree.get_cursor (out path, null);
            return path;
        }

        /* These two functions accelerate the loading of Views especially for large folders
         * Views are not displayed until fully loaded */
        protected override void freeze_tree () {
            tree.freeze_child_notify ();
            tree_frozen = true;
        }

        protected override void thaw_tree () {
            if (tree_frozen) {
                tree.thaw_child_notify ();
                tree_frozen = false;
            }
        }

        protected override void freeze_child_notify () {
            tree.freeze_child_notify ();
        }

        protected override void thaw_child_notify () {
            tree.thaw_child_notify ();
        }

        protected override bool is_on_icon (int x, int y, int orig_x, int orig_y, ref bool on_helper) {
            /* orig_x and orig_y must be top left hand corner of icon (excluding helper) */
            int x_offset = x - orig_x;
            int y_offset = y - orig_y;

            bool on_icon =  (x_offset >= 0 &&
                             x_offset <= icon_size &&
                             y_offset >= 0 &&
                             y_offset <= icon_size);

            on_helper = false;
            if (icon_renderer.selection_helpers) {
                int x_helper_offset = x - icon_renderer.helper_x;
                int y_helper_offset = y - icon_renderer.helper_y;

                on_helper =  (x_helper_offset >= 0 &&
                             x_helper_offset <= icon_renderer.helper_size &&
                             y_helper_offset >= 0 &&
                             y_helper_offset <= icon_renderer.helper_size);
            }

            return on_icon;
        }
    }
}
