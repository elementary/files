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
    public class GridDirectoryView : AbstractDirectoryView {
        protected new FM.IconGridView tree;
        /* support for linear selection mode in icon view, overriding native behaviour of Gtk.IconView */
        protected bool previous_selection_was_linear = false;
        protected Gtk.TreePath? previous_linear_selection_path = null;
        protected int previous_linear_selection_direction = 0;
        protected bool linear_select_required = false;

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
            var p = Gdk.Point () {x = (int)event.x, y = (int)event.y};
            var item = tree.get_item_at_pos (p);
            if (item == null || item.data == null) {
                return FM.ClickZone.BLANK_NO_PATH;
            }

            path = new Gtk.TreePath.from_indices (tree.get_index_at_pos (p));

            int x = 0;
            int y = 0;
            item.get_window ().get_position (out x, out y);
            var widget_pos = Gdk.Point () {x = p.x - x, y = p.y - y};
            var griditem = (IconGridItem)item;

            return griditem.get_zone (widget_pos);
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

            linear_select_required = only_shift_pressed;
            if (linear_select_required) {
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

        /* Override native Gtk.IconView cursor handling */
        protected override bool move_cursor (uint keyval, bool only_shift_pressed) {
            Gtk.TreePath? path = get_path_at_cursor ();
            if (path != null) {
                if (path_is_selected (path)) {
                    if (keyval == Gdk.Key.Right) {
                        path.next (); /* Does not check if path is valid */
                    } else if (keyval == Gdk.Key.Left) {
                        path.prev ();
                    } else if (keyval == Gdk.Key.Up) {
                        path = up (path);
                    } else if (keyval == Gdk.Key.Down) {
                        path = down (path);
                    }

                    Gtk.TreeIter? iter = null;
                    /* Do not try to select invalid path */
                    if (model.get_iter (out iter, path)) {
                        if (only_shift_pressed && selected_files != null) {
                            linear_select_path (path);
                        } else {
                            unselect_all ();
                            set_cursor (path, false, true, false);
                            previous_linear_selection_path = path;
                        }
                    }
                } else {
                    set_cursor (path, false, true, false); /* Select without moving if only focussed */
                }
            } else {
                path = new Gtk.TreePath.from_indices (0);
                set_cursor (path, false, true, false);
                previous_linear_selection_path = path;
            }

            return true;
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
            Gtk.TreePath? path;
            tree.get_cursor (out path);
            return path;
        }

        protected void linear_select_path (Gtk.TreePath path) {
            if (path == null) {
                critical ("Ignoring attempt to select null path in linear_select_path");
                return;
            }

            if (previous_linear_selection_path != null && path.compare (previous_linear_selection_path) == 0) {
                /* Ignore if repeat click on same file as before. We keep the previous linear selection direction. */
                return;
            }

            var selected_paths = tree.get_selected_items ();
            /* Ensure the order of the selected files list matches the visible order */
            var first_selected = selected_paths.first ().data;
            var last_selected = selected_paths.last ().data;
            bool before_first = path.compare (first_selected) <= 0;
            bool after_last = path.compare (last_selected) >= 0;
            bool direction_change = false;

            direction_change = (before_first && previous_linear_selection_direction > 0) ||
                               (after_last && previous_linear_selection_direction < 0);

            var p = path.copy ();
            Gtk.TreePath p2 = null;

            unselect_all ();
            Gtk.TreePath? end_path = null;
            if (!previous_selection_was_linear && previous_linear_selection_path != null) {
                end_path = previous_linear_selection_path;
            } else if (before_first) {
                end_path = direction_change ? first_selected : last_selected;
            } else {
                end_path = direction_change ? last_selected : first_selected;
            }

            /* Cursor follows when selecting path */
            if (before_first) {
                do {
                    p2 = p.copy ();
                    select_path (p, true);
                    p.next ();
                } while (p.compare (p2) != 0 && p.compare (end_path) <= 0);
            } else if (after_last) {
                do {
                    select_path (p, true);
                    p2 = p.copy ();
                    p.prev ();
                } while (p.compare (p2) != 0 && p.compare (end_path) >= 0);
            } else {/* between first and last */
                do {
                    p2 = p.copy ();
                    select_path (p, true);
                    p.prev ();
                } while (p.compare (p2) != 0 && p.compare (first_selected) >= 0);

                p = path.copy ();
                do {
                    p2 = p.copy ();
                    p.next ();
                    unselect_path (p);
                } while (p.compare (p2) != 0 && p.compare (last_selected) <= 0);
            }

            previous_selection_was_linear = true;

            selected_paths = tree.get_selected_items ();

            first_selected = selected_paths.first ().data;
            last_selected = selected_paths.last ().data;

            if (path.compare (last_selected) == 0) {
                previous_linear_selection_direction = 1; /* clicked after the (visually) first selection */
            } else if (path.compare (first_selected) == 0) {
                previous_linear_selection_direction = -1; /* clicked before the (visually) first selection */
            } else {
                critical ("Linear selection did not become end point - this should not happen!");
                previous_linear_selection_direction = 0;
            }

            previous_linear_selection_path = path.copy ();
            /* Ensure cursor in correct place, regardless of any selections made in this function */
            tree.set_cursor (path, false);
            tree.scroll_to_path (path, false, 0.5f, 0.5f);
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
            /* TODO */
            return false;
        }
    }
}
