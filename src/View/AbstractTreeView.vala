/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

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
        protected Marlin.TextRenderer? name_renderer = null;
        protected Marlin.IconRenderer? icon_renderer = null;

        protected Gtk.ScrolledWindow scrolled_window;
        protected FM.TreeView tree;
        protected Gtk.TreeViewColumn name_column;

        construct {
            icon_renderer = new Marlin.IconRenderer ();
            name_renderer = new Marlin.TextRenderer (Marlin.ViewMode.LIST);
            scrolled_window = new Gtk.ScrolledWindow (null, null);
            scrolled_window.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            scrolled_window.set_shadow_type (Gtk.ShadowType.NONE);

            scrolled_window.get_vadjustment ().value_changed.connect_after (() => {
                schedule_thumbnail_timeout ();
            });

            add (scrolled_window);
        }

        public AbstractTreeView (Marlin.View.Slot _slot) {
            assert (_slot != null);
            base (_slot);
        }

        ~AbstractTreeView () {
            debug ("ATV destruct");
        }

        protected virtual void create_and_set_up_name_column () {
            name_column = new Gtk.TreeViewColumn ();
            name_column.set_expand (true);
            name_column.set_resizable (true);

            set_up_name_renderer ();

            set_up_icon_renderer ();

            name_column.pack_start (icon_renderer, false);
            name_column.set_attributes (icon_renderer, "file", FM.ColumnID.FILE_COLUMN);

            name_column.pack_end (name_renderer, false);
            name_column.set_attributes (name_renderer, "file", FM.ColumnID.FILE_COLUMN);

            tree.append_column (name_column);
            tree.set_expander_column (name_column);
        }

        protected void set_up_icon_renderer () {
            icon_renderer.set_property ("follow-state", true);
        }

        protected override Gtk.Widget? create_view () {
            tree = new FM.TreeView ();
            tree.set_model (model);
            tree.set_headers_visible (false);
            tree.get_selection ().set_mode (Gtk.SelectionMode.MULTIPLE);
            tree.set_rubber_banding (true);

            create_and_set_up_name_column ();
            set_up_view ();

            scrolled_window.add (tree);

            return tree as Gtk.Widget;
        }

        protected void set_up_view () {
            connect_tree_signals ();
            tree.realize.connect ((w) => {
                tree.grab_focus ();
                tree.columns_autosize ();
            });
        }

        protected void set_up_name_renderer () {
            name_renderer.editable = false;
            name_renderer.edited.connect (on_name_edited);
            name_renderer.editing_canceled.connect (on_name_editing_canceled);
            name_renderer.editing_started.connect (on_name_editing_started);
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

        public override void change_zoom_level () {
            if (tree != null) {
                icon_renderer.set_property ("zoom-level", zoom_level);
                name_renderer.set_property ("zoom-level", zoom_level);
                tree.style_updated ();
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

            if (x >= 0 && y >= 0 && tree.get_dest_row_at_pos (x, y, out path, null)) {
                return path;
            } else {
                return null;
            }
        }

        public override void tree_select_all () {
            tree.get_selection ().select_all ();
        }

        public override void tree_unselect_all () {
            tree.get_selection ().unselect_all ();
        }

        public override Gtk.TreePath? get_single_selection () {
            var selected_paths = tree.get_selection ().get_selected_rows (null);
            if (selected_paths != null && selected_paths.next == null) {
                return selected_paths.data;
            } else {
                return null;
            }
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
                    tree.set_cursor (path, null, false); /* This selects path but unselects rest! */

                    selected_paths.@foreach ((p) => {
                       selection.select_path (p);
                    });
                }
            }
        }
        public override void unselect_path (Gtk.TreePath? path) {
            if (path != null) {
                tree.get_selection ().unselect_path (path);
            }
        }

        public override bool path_is_selected (Gtk.TreePath? path) {
            if (path != null) {
                return tree.get_selection ().path_is_selected (path);
            } else {
                return false;
            }
        }

        public override bool get_visible_range (out Gtk.TreePath? start_path,
                                                out Gtk.TreePath? end_path) {
            start_path = null;
            end_path = null;
            return tree.get_visible_range (out start_path, out end_path);
        }

        protected override uint get_selected_files_from_model (out GLib.List<GOF.File> selected_files) {
            uint count = 0;

            GLib.List<GOF.File> list = null;
            tree.get_selection ().selected_foreach ((model, path, iter) => {
                GOF.File? file; /* can be null if click on blank row in list view */
                model.@get (iter, FM.ColumnID.FILE_COLUMN, out file, -1);
                if (file != null) {
                    list.prepend ((owned) file);
                    count++;
                }
            });

            selected_files = (owned)list;
            return count;
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
            Gdk.Rectangle rect;
            tree.get_cell_area (p, c, out rect);
            int height = rect.height;

            is_blank = is_blank || cy < 5 || cy > height - 5;

            /* Do not allow rubberbanding to start except on a row in tree view */
            zone = (p != null && is_blank ? ClickZone.BLANK_PATH : ClickZone.INVALID);

            if (p != null && c != null && c == name_column) {
                GOF.File? file = model.file_for_path (p);

                if (file == null) {
                    zone = ClickZone.INVALID;
                } else {
                    var rtl = (get_direction () == Gtk.TextDirection.RTL);
                    if (rtl ? (x > rect.x + rect.width - icon_size) : (x < rect.x + icon_size)) {
                        /* cannot be on name */
                        bool on_helper = false;
                        bool on_icon = is_on_icon (x, y, ref on_helper);

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
                }
            } else if (c != name_column) {
                /* Cause unselect all to occur on other columns and allow rubberbanding */
                zone = ClickZone.BLANK_NO_PATH;
            }

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
                                                    bool start_editing,
                                                    bool scroll_to_top) {
            scroll_to_cell (path, scroll_to_top);
            tree.set_cursor_on_cell (path, name_column, name_renderer, start_editing);
            if (start_editing) {
                name_renderer.editable = true;
            }
        }

        public override void set_cursor (Gtk.TreePath? path,
                                         bool start_editing,
                                         bool select,
                                         bool scroll_to_top) {
            if (path == null) {
                return;
            }

            Gtk.TreeSelection selection = tree.get_selection ();
            bool no_selection = selected_files == null;

            if (!select) {
                selection.changed.disconnect (on_view_selection_changed);
            } else {
                select_path (path);
            }

            set_cursor_on_cell (path, start_editing, scroll_to_top);

            if (!select) {
                /* When just focusing first for empty selection we do not want the row selected.
                 * This makes behaviour consistent with Icon View */
                if (no_selection) {
                    unselect_path (path); /* Reverse automatic selection by set_cursor_on_cell for TreeView */
                }

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

        protected override void on_name_editing_canceled () {
            base.on_name_editing_canceled ();
            name_renderer.editable = false;
        }

        protected override bool on_view_button_press_event (Gdk.EventButton event) {
            if (renaming) {
                /* Commit any change if renaming (https://github.com/elementary/files/issues/641) */
                name_renderer.end_editing (false);
            }

            return base.on_view_button_press_event (event);
        }

        protected override void on_drag_leave (Gdk.DragContext context, uint timestamp) {
            /* reset the drop-file for the icon renderer */
            icon_renderer.set_property ("drop-file", GLib.Value (typeof (Object)));
            base.on_drag_leave (context, timestamp);
        }

        protected override void set_drop_file (GOF.File? file) {
            icon_renderer.@set ("drop-file", file);
        }

        protected override bool is_on_icon (int x, int y, ref bool on_helper) {
            /* x and y must be in same coordinate system as used by the IconRenderer */
            Gdk.Rectangle pointer_rect = {x - 2, y - 2, 4, 4}; /* Allow slight inaccuracy */
            bool on_icon = pointer_rect.intersect (icon_renderer.hover_rect, null);
            on_helper = pointer_rect.intersect (icon_renderer.hover_helper_rect, null);
            return on_icon;
        }

        protected override void scroll_if_near_edge (int pos, int dim, int threshold, Gtk.Orientation orientation) {
            Gtk.Adjustment adj = orientation == Gtk.Orientation.VERTICAL ? scrolled_window.get_vadjustment () : scrolled_window.get_hadjustment ();
            /* check if we are near the edge */
            int band = 2 * threshold;
            int offset = pos - band;
            if (offset > 0) {
                offset = int.max (band - (dim - pos), 0);
            }

            if (offset != 0) {
                /* change the adjustment appropriately */
                var val = adj.get_value ();
                var lower = adj.get_lower ();
                var upper = adj.get_upper ();
                var page = adj.get_page_size ();

                val = (val + 2 * offset).clamp (lower, upper - page);
                adj.set_value (val);
            }
        }
    }

    protected class TreeView : Gtk.TreeView {
        /* Override base class in order to disable the Gtk.TreeView local search functionality */
        public override bool key_press_event (Gdk.EventKey event) {
            /* We still need the base class to handle cursor keys first */
            switch (event.keyval) {
                case Gdk.Key.Up:
                case Gdk.Key.Down:
                case Gdk.Key.KP_Up:
                case Gdk.Key.KP_Down:
                case Gdk.Key.Page_Up:
                case Gdk.Key.Page_Down:
                case Gdk.Key.KP_Page_Up:
                case Gdk.Key.KP_Page_Down:
                case Gdk.Key.Home:
                case Gdk.Key.End:

                    return base.key_press_event (event);

                default:

                    return false; // Pass event to Window handler.
            }
        }
    }
}
