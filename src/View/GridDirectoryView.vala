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

/** A subclass of AbstractDirectoryView that uses WidgetGrid (adapted) **/

namespace FM {
    public class GridDirectoryView : AbstractDirectoryView {
        protected new FM.IconGridView tree;

        public GridDirectoryView (Marlin.View.Slot _slot) {
            assert (_slot != null);
            base (_slot);
        }

        ~GridDirectoryView () {
            debug ("Icon Grid View destruct");
        }

        private void set_up_view () {
            connect_tree_signals ();
            tree.realize.connect ((w) => {
                tree.grab_focus ();
            });
        }

        protected override void connect_tree_signals () {
            tree.selection_changed.connect (on_view_selection_changed);
        }

        protected override void disconnect_tree_signals () {
            tree.selection_changed.disconnect (on_view_selection_changed);
        }

        protected override Gtk.Widget? create_and_add_view () {
            var factory = new IconGridItemFactory ();
            tree = new FM.IconGridView (factory, model);
            set_up_view ();
            add (tree);

            tree.adjustment_value_changed.connect_after (() => {
                schedule_thumbnail_timeout ();
            });

            return tree as Gtk.Widget;
        }

        protected override Marlin.ZoomLevel get_set_up_zoom_level () {
            var zoom = Preferences.marlin_icon_view_settings.get_enum ("zoom-level");
            Preferences.marlin_icon_view_settings.bind ("zoom-level", this, "zoom-level", GLib.SettingsBindFlags.SET);

            minimum_zoom = (Marlin.ZoomLevel)Preferences.marlin_icon_view_settings.get_enum ("minimum-zoom-level");
            maximum_zoom = (Marlin.ZoomLevel)Preferences.marlin_icon_view_settings.get_enum ("maximum-zoom-level");

            if (zoom_level < minimum_zoom) {
                zoom_level = minimum_zoom;
            }

            if (zoom_level > maximum_zoom) {
                zoom_level = maximum_zoom;
            }

            return (Marlin.ZoomLevel)zoom;
        }

        public override Marlin.ZoomLevel get_normal_zoom_level () {
            var zoom = Preferences.marlin_icon_view_settings.get_enum ("default-zoom-level");
            Preferences.marlin_icon_view_settings.set_enum ("zoom-level", zoom);

            return (Marlin.ZoomLevel)zoom;
        }

        public override void change_zoom_level () {
            int spacing = (int)((double)icon_size * (0.3 - zoom_level * 0.03));
            int item_width = (int)((double)icon_size * (2.5 - zoom_level * 0.2));

            if (tree != null) {
                tree.set_column_spacing (spacing);
                tree.set_item_width (item_width);
            }
        }

        public override GLib.List<Gtk.TreePath> get_selected_paths () {
            return tree.get_selected_items ();
        }

        public override void highlight_path (Gtk.TreePath? path) {
            tree.set_drag_dest_item (path, Gtk.IconViewDropPosition.DROP_INTO);
        }

        public override Gtk.TreePath? get_path_at_pos (int win_x, int win_y) {
            return tree.get_path_at_pos (win_x, win_y);
        }

        public override void tree_select_all () {
            tree.select_all ();
        }

        public override void tree_unselect_all () {
            tree.unselect_all ();
        }

        public override void tree_unselect_others () {
            Gtk.TreePath path = null;
            tree.get_cursor (out path);
            tree.unselect_all ();
            select_path (path, true);
        }

        /* Avoid using this function with "cursor_follows = true" to select large numbers of files one by one
         * It would take an exponentially long time. Use "select_files" function in parent class.
         */
        public override void select_path (Gtk.TreePath? path, bool cursor_follows = false) {
            if (path != null) {
                tree.select_path (path); /* This selects path but does not unselect the rest (unlike TreeView) */

                if (cursor_follows) {
                    tree.set_cursor (path, false);
                }
            }
        }

        public override void unselect_path (Gtk.TreePath? path) {
            if (path != null) {
                tree.unselect_path (path);
            }
        }

        public override bool path_is_selected (Gtk.TreePath? path) {
            if (path != null) {
                return tree.path_is_selected (path);
            } else {
                return false;
            }
        }

        public override bool get_visible_range (out Gtk.TreePath? start_path, out Gtk.TreePath? end_path) {
            start_path = null;
            end_path = null;
            return tree.get_visible_range (out start_path, out end_path);
        }

        protected override uint get_selected_files_from_model (out GLib.List<GOF.File> selected_files) {
            var list = new GLib.List<GOF.File> ();
            uint count = tree.get_selected_files_from_model (ref list);

            selected_files = (owned)list;
            return count;
        }

        protected override bool view_has_focus () {
            return tree.has_focus;
        }

        protected override uint get_event_position_info (Gdk.EventButton event,
                                                         out Gtk.TreePath? path,
                                                         bool rubberband = false) {

            path = null;
            Gdk.Point p = {(int)(event.x), (int)(event.y)};
            Gdk.Point wp = {0, 0};
            var item = tree.get_item_at_pos (p, out wp);
            if (item == null || item.data == null) {
                return FM.ClickZone.BLANK_NO_PATH;
            }

            path = new Gtk.TreePath.from_indices (tree.get_index_at_pos (p));
            var zone = ((IconGridItem)item).get_zone (wp);
            return zone;
        }

        protected override void scroll_to_cell (Gtk.TreePath? path, bool scroll_to_top) {
            if (tree == null || path == null || slot == null || /* slot should not be null but see lp:1595438 */
                slot.directory.permission_denied || slot.directory.is_empty ()) {

                return;
            }

            tree.scroll_to_path (path, scroll_to_top, 0.5f, 0.5f);
        }

        protected override void set_cursor_on_cell (Gtk.TreePath path,
                                                    bool start_editing,
                                                    bool scroll_to_top) {
            scroll_to_cell (path, scroll_to_top);
            tree.set_cursor (path, start_editing);
        }

        protected override bool will_handle_button_press (bool no_mods, bool only_control_pressed,
                                                          bool only_shift_pressed) {

            if (only_shift_pressed) {/* Linear select */
                return true;
            } else {
                return base.will_handle_button_press (no_mods, only_control_pressed, only_shift_pressed);
            }
        }

        protected override bool handle_multi_select (Gtk.TreePath path) {
            if (selected_files.length () > 0) {
                linear_select_path (path);
                return true;
            } else {
                return false;
            }
        }

        public override void set_cursor (Gtk.TreePath? path,
                                         bool start_editing,
                                         bool select,
                                         bool scroll_to_top) {
            if (path == null) {
                return;
            }

            if (!select) {
                tree.selection_changed.disconnect (on_view_selection_changed);
            } else {
                select_path (path);
            }

            set_cursor_on_cell (path, start_editing, scroll_to_top);

            if (!select) {
                tree.selection_changed.connect (on_view_selection_changed);
            }
        }

        public override Gtk.TreePath? get_path_at_cursor () {
            Gtk.TreePath? path = null;
            tree.get_cursor (out path);
            return path;
        }

        protected void linear_select_path (Gtk.TreePath path) {
            tree.linear_select_path (path);
        }

        protected override Gtk.TreePath up (Gtk.TreePath path) {
            var index = path.get_indices ()[0];
            var index_above = tree.index_above (index);

            if (index_above >= 0) {
                return new Gtk.TreePath.from_indices (index_above);
            } else {
                return path;
            }
        }

        protected override Gtk.TreePath down (Gtk.TreePath path) {
            var index = path.get_indices ()[0];
            var index_below = tree.index_below (index);

            if (index_below >= 0) {
                return new Gtk.TreePath.from_indices (index_below);
            } else {
                return path;
            }
        }

        /* Not efficient - try to avoid */
        public override Gtk.TreePath? get_single_selection () {
            Gtk.TreePath? result = null;
            for (int i = 0; i < tree.model.get_n_items (); i++) {
                var data = tree.model.lookup_index (i);
                if (data.is_selected) {
                    if (result == null) {
                        result = new Gtk.TreePath.from_indices (i);
                    } else {
                        return null;
                    }
                }
            }

            return result;
        }

        protected override bool is_on_icon (int x, int y, ref bool on_helper) {
            on_helper = false;
            var p = Gdk.Point () {x = x, y = y};
            Gdk.Point wp = {0, 0};
            var item = tree.get_item_at_pos (p, out wp);
            if (item == null || item.data == null) {
                return false;
            } else {
                var zone = ((IconGridItem)item).get_zone (wp);
                on_helper = zone == FM.ClickZone.HELPER;
                if (on_helper || zone == FM.ClickZone.ICON) {
                    return true;
                }
            }

            return false;
        }

        protected override void freeze_tree () {
            tree.clear_selection ();
            tree.freeze_child_notify ();
        }

        protected override void thaw_tree () {
            tree.thaw_child_notify ();
        }

        protected override void thumbnails_updated () {
            tree.refresh_layout ();
            base.thumbnails_updated ();
        }
    }
}
