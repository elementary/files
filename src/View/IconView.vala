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
    public class IconView : AbstractDirectoryView {
        protected new Gtk.IconView tree;

        public IconView (Marlin.View.Slot _slot) {
            assert (_slot != null);
            base (_slot);
        }

        ~IconView () {
            debug ("Icon View destruct");
        }

        private void set_up_view () {
            tree.set_model (model);
            tree.set_selection_mode (Gtk.SelectionMode.MULTIPLE);
            tree.set_columns (-1);
            tree.set_reorderable (false);
            tree.set_item_padding (3);

            name_renderer = new Marlin.TextRenderer (Marlin.ViewMode.ICON);
            set_up_name_renderer ();

            set_up_icon_renderer ();

            (tree as Gtk.CellLayout).pack_start (icon_renderer, false);
            (tree as Gtk.CellLayout).pack_end (name_renderer, false);

            (tree as Gtk.CellLayout).add_attribute (name_renderer, "text", FM.ListModel.ColumnID.FILENAME);
            (tree as Gtk.CellLayout).add_attribute (name_renderer, "file", FM.ListModel.ColumnID.FILE_COLUMN);
            (tree as Gtk.CellLayout).add_attribute (name_renderer, "background", FM.ListModel.ColumnID.COLOR);
            (tree as Gtk.CellLayout).add_attribute (icon_renderer, "file", FM.ListModel.ColumnID.FILE_COLUMN);

            connect_tree_signals ();
            tree.realize.connect ((w) => {
                tree.grab_focus ();
            });
        }

        protected override void set_up_name_renderer () {
            base.set_up_name_renderer ();
            name_renderer.wrap_mode = Pango.WrapMode.WORD_CHAR;
            name_renderer.xalign = 0.5f;
            name_renderer.yalign = 0.0f;
        }

        protected void set_up_icon_renderer () {
            icon_renderer.set_property ("follow-state",  true);
        }


        protected override void connect_tree_signals () {
            tree.selection_changed.connect (on_view_selection_changed);
        }
        protected override void disconnect_tree_signals () {
            tree.selection_changed.disconnect (on_view_selection_changed);
        }

        protected override Gtk.Widget? create_view () {
            tree = new Gtk.IconView ();
            set_up_view ();

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
            name_renderer.item_width = item_width;
            name_renderer.set_property ("zoom-level", zoom_level);

            base.change_zoom_level ();
        }

        public override GLib.List<Gtk.TreePath> get_selected_paths () {
            return tree.get_selected_items ();
        }

        public override void highlight_path (Gtk.TreePath? path) {
            tree.set_drag_dest_item (path, Gtk.IconViewDropPosition.DROP_INTO);
        }

        public override Gtk.TreePath? get_path_at_pos (int win_x, int win_y) {
            /* Supplied coords are drag coords - need IconView bin window coords */
            /* Icon view does not scroll horizontally so no adjustment needed for x coord*/
            return tree.get_path_at_pos (win_x, win_y + (int)(get_vadjustment ().get_value ()));
        }

        public override void select_all () {
            tree.select_all ();
            all_selected = true;
        }

        public override void unselect_all () {
            tree.unselect_all ();
            all_selected = false;
        }

        /* Avoid using this function with "cursor_follows = true" to select large numbers of files one by one
         * It would take an exponentially long time. Use "select_files" function in parent class.
         */
        public override void select_path (Gtk.TreePath? path, bool cursor_follows = false) {
            if (path != null) {
                tree.select_path (path);  /* This selects path but does not unselect the rest (unlike TreeView) */

                if (cursor_follows) {
                    tree.set_cursor (path, null, false);
                }
            }
        }

        public override void unselect_path (Gtk.TreePath? path) {
            if (path != null)
                tree.unselect_path (path);
        }

        public override bool path_is_selected (Gtk.TreePath? path) {
            if (path != null)
                return tree.path_is_selected (path);
            else
                return false;
        }

        public override bool get_visible_range (out Gtk.TreePath? start_path, out Gtk.TreePath? end_path) {
            start_path = null;
            end_path = null;
            return tree.get_visible_range (out start_path, out end_path);
        }

        public override void sync_selection () {
            /* Not implemented - needed? No current bug reports */
        }

        protected override void update_selected_files () {
            selected_files = null;

            tree.selected_foreach ((tree, path) => {
                GOF.File? file;
                file = model.file_for_path (path);

                if (file != null)
                    selected_files.prepend (file);
                else
                    critical ("Null file in model");
            });

            selected_files.reverse ();
        }

        protected override bool view_has_focus () {
            return tree.has_focus;
        }

        protected override uint get_event_position_info (Gdk.EventButton event,
                                                         out Gtk.TreePath? path,
                                                         bool rubberband = false) {
            unowned Gtk.TreePath? p = null;
            unowned Gtk.CellRenderer? r;
            uint zone;
            int x, y;
            path = null;

            x = (int)event.x;
            y = (int)event.y;

            tree.get_item_at_pos (x, y, out p, out r);
            path = p;
            zone = (p != null ? ClickZone.BLANK_PATH : ClickZone.BLANK_NO_PATH);

            if (r != null) {
                Gdk.Rectangle rect, area;
                tree.get_cell_rect  (p, r, out rect);
                area = r.get_aligned_area (tree, Gtk.CellRendererState.PRELIT, rect);

                /* rectangles are in bin window coordinates - need to adjust event y coordinate
                 * for vertical scrolling in order to accurately detect whicn area of item was
                 * clicked on */
                y -= (int)(get_vadjustment ().value);

                if (r is Marlin.TextRenderer) {
                    Gtk.TreeIter iter;
                    model.get_iter (out iter, path);
                    string? text = null;
                    model.@get (iter,
                            FM.ListModel.ColumnID.FILENAME, out text);

                    (r as Marlin.TextRenderer).set_up_layout (text, area.width);

                    if (x >= rect.x &&
                        x <= rect.x + rect.width &&
                        y >= rect.y &&
                        y <= rect.y + (r as Marlin.TextRenderer).text_height) {

                        zone = ClickZone.NAME;
                    } else if (rubberband) {
                        /* Fake location outside centre bottom of item for rubberbanding */
                        event.x = rect.x + rect.width / 2;
                        event.y = rect.y + rect.height + 10 + (int)(get_vadjustment ().value);
                        zone = ClickZone.BLANK_NO_PATH;
                    }
                } else {
                    bool on_helper = false;
                    bool on_icon = is_on_icon (x, y, area.x, area.y, ref on_helper);

                    if (on_helper) {
                        zone = ClickZone.HELPER;
                    } else if (on_icon) {
                        zone = ClickZone.ICON;
                    } else if (rubberband) {
                        /* Fake location outside centre top of item for rubberbanding */
                        event.x = rect.x + rect.width / 2;
                        event.y = rect.y - 10 + (int)(get_vadjustment ().value);
                        zone = ClickZone.BLANK_NO_PATH;
                    }
                }
            }

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
                                                    Gtk.CellRenderer renderer,
                                                    bool start_editing,
                                                    bool scroll_to_top) {
            scroll_to_cell (path, scroll_to_top);
            tree.set_cursor (path, renderer, start_editing);
        }

        public override void set_cursor (Gtk.TreePath? path,
                                         bool start_editing,
                                         bool select,
                                         bool scroll_to_top) {
            if (path == null)
                return;

            if (!select) {
                tree.selection_changed.disconnect (on_view_selection_changed);
            } else {
                select_path (path);
            }

            set_cursor_on_cell (path, name_renderer, start_editing, scroll_to_top);

            if (!select) {
                tree.selection_changed.connect (on_view_selection_changed);
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
            tree_frozen = true;
            tree.freeze_child_notify ();
            tree.set_model (null);
        }

        protected override void thaw_tree () {
            if (tree_frozen) {
                tree.set_model (model);
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

        protected override void linear_select_path (Gtk.TreePath path) {
            /* We override the native Gtk.IconView behaviour when selecting files with Shift-Click */
            /* We wish to emulate the behaviour of ListView and ColumnView. This depends on whether the */
            /* the previous selection was made with the Shift key pressed */
            /* Note: 'first' and 'last' refer to position in selection, not the time selected */

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
            selected_paths.sort (Gtk.TreePath.compare);

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
            selected_paths.sort (Gtk.TreePath.compare);

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
            tree.set_cursor (path, null, false);
            tree.scroll_to_path (path, false, 0.5f, 0.5f);
        }

        protected override Gtk.TreePath up (Gtk.TreePath path) {
            int item_row = tree.get_item_row (path);
            if (item_row == 0) {
                return path;
            }
            int cols = get_n_cols ();
            int index = path.get_indices ()[0];
            Gtk.TreePath new_path;
            Gtk.TreeIter? iter = null;
            new_path = new Gtk.TreePath.from_indices (index - cols, -1);
            if (tree.model.get_iter (out iter, new_path)) {
                return new_path;
            } else {
                return path;
            }
        }
        protected override Gtk.TreePath down (Gtk.TreePath path) {
            int cols = get_n_cols ();
            int index = path.get_indices ()[0];

            Gtk.TreePath new_path;
            Gtk.TreeIter? iter = null;
            new_path = new Gtk.TreePath.from_indices (index + cols, -1);
            if (tree.model.get_iter (out iter, new_path)) {
                return new_path;
            } else {
                return path;
            }
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
                /* IconView provide IconRenderer with bin coords not widget coords (unlike TreeView) so we have to
                 * correct for scrolling */
                int y_helper_offset = y - icon_renderer.helper_y + (int)(get_vadjustment ().value);

                on_helper =  (x_helper_offset >= 0 &&
                             x_helper_offset <= icon_renderer.helper_size &&
                             y_helper_offset >= 0 &&
                             y_helper_offset <= icon_renderer.helper_size);

            }

            return on_icon;
        }


        /* When Icon View is automatically adjusting column number it does not expose the actual number of
         * columns (get_columns () returns -1). So we have to write our own method. This is the only way
         * (I can think of) that works on row 0.
         */
        private int get_n_cols () {
            var path = new Gtk.TreePath.from_indices (0, -1);
            int index = 0;
            while (tree.get_item_row (path) == 0) {
                index++;
                path.next ();
            }
            return index;
        }
    }
}
