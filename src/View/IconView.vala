/***
    Copyright (c) 2015-2020 elementary LLC <https://elementary.io>

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

namespace Files {
    public class IconView : AbstractDirectoryView {
        protected new Gtk.IconView tree;
        /* support for linear selection mode in icon view, overriding native behaviour of Gtk.IconView */
        protected bool previous_selection_was_linear = false;
        protected Gtk.TreePath? previous_linear_selection_path = null;
        protected int previous_linear_selection_direction = 0;
        protected bool linear_select_required = false;
        protected Gtk.TreePath? most_recently_selected = null;

        public IconView (View.Slot _slot) {
            base (_slot);
        }

        ~IconView () {
            debug ("Icon View destruct");
        }

        private void set_up_view () {
            tree.set_model (model);
            tree.set_selection_mode (Gtk.SelectionMode.MULTIPLE);
            tree.set_columns (-1);

            name_renderer = new Files.TextRenderer (ViewMode.ICON);
            icon_renderer = new Files.IconRenderer (ViewMode.ICON);

            set_up_name_renderer ();

            tree.pack_start (icon_renderer, false);
            tree.pack_end (name_renderer, false);

            tree.add_attribute (name_renderer, "text", ListModel.ColumnID.FILENAME);
            tree.add_attribute (name_renderer, "file", ListModel.ColumnID.FILE_COLUMN);
            tree.add_attribute (name_renderer, "background", ListModel.ColumnID.COLOR);
            tree.add_attribute (icon_renderer, "file", ListModel.ColumnID.FILE_COLUMN);

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

        protected override void set_up_zoom_level () {
            Files.icon_view_settings.bind (
                "zoom-level",
                this, "zoom-level",
                GLib.SettingsBindFlags.DEFAULT
            );

            minimum_zoom = (ZoomLevel)Files.icon_view_settings.get_enum ("minimum-zoom-level");
            maximum_zoom = (ZoomLevel)Files.icon_view_settings.get_enum ("maximum-zoom-level");

            if (zoom_level < minimum_zoom) {
                zoom_level = minimum_zoom;
            }

            if (zoom_level > maximum_zoom) {
                zoom_level = maximum_zoom;
            }
        }

        public override ZoomLevel get_normal_zoom_level () {
            var zoom = Files.icon_view_settings.get_enum ("default-zoom-level");
            Files.icon_view_settings.set_enum ("zoom-level", zoom);

            return (ZoomLevel)zoom;
        }

        public override void change_zoom_level () {
            int spacing = (int)((double)icon_size * (0.3 - zoom_level * 0.03));
            int item_width = (int)((double)icon_size * (2.5 - zoom_level * 0.2));
            if (tree != null) {
                tree.set_column_spacing (spacing);
                tree.set_item_width (item_width);
            }

            name_renderer.item_width = item_width;

            base.change_zoom_level (); /* Sets name_renderer zoom_level */
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

        public override void tree_select_all () {
            tree.select_all ();
        }

        public override void tree_unselect_all () {
            tree.unselect_all ();
            previous_linear_selection_path = null;
            previous_linear_selection_direction = 0;
        }

        public override void tree_unselect_others () {
            Gtk.TreePath path = null;
            tree.get_cursor (out path, null);
            tree.unselect_all ();
            select_path (path, true);
        }

        /* Avoid using this function with "cursor_follows = true" to select large numbers of files one by one
         * It would take an exponentially long time. Use "select_files" function in parent class.
         */
        public override void select_path (Gtk.TreePath? path, bool cursor_follows = false) {
            if (path != null) {
                tree.select_path (path); /* This selects path but does not unselect the rest (unlike TreeView) */
                most_recently_selected = path.copy ();
                if (cursor_follows) {
                    tree.set_cursor (path, null, false);
                }
            }
        }

        public override void unselect_path (Gtk.TreePath? path) {
            if (path != null) {
                tree.unselect_path (path);
                most_recently_selected = null;
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

        protected override uint get_selected_files_from_model (out GLib.List<Files.File> selected_files) {
            GLib.List<Files.File> list = null;
            uint count = 0;

            tree.selected_foreach ((tree, path) => {
                Files.File? file = model.file_for_path (path);
                if (file != null) {
                    list.prepend ((owned)file);
                    count++;
                } else {
                    critical ("Null file in model");
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
            Gtk.CellRenderer? cell_renderer;
            uint zone;
            int x, y;
            path = null;

            x = (int)event.x;
            y = (int)event.y;

            tree.get_item_at_pos (x, y, out path, out cell_renderer);
            zone = (path != null ? ClickZone.BLANK_PATH : ClickZone.BLANK_NO_PATH);

            if (cell_renderer != null) {
                Gdk.Rectangle rect, area;
                tree.get_cell_rect (path, cell_renderer, out rect);
                area = cell_renderer.get_aligned_area (tree, Gtk.CellRendererState.PRELIT, rect);

                if (cell_renderer is Files.TextRenderer) {
                    var text_renderer = ((Files.TextRenderer) cell_renderer);
                    /* rectangles are in bin window coordinates - need to adjust event y coordinate
                     * for vertical scrolling in order to accurately detect which area of TextRenderer was
                     * clicked on */
                    y -= (int)(get_vadjustment ().value);
                    Gtk.TreeIter iter;
                    model.get_iter (out iter, path);
                    string? text = null;
                    model.@get (iter, ListModel.ColumnID.FILENAME, out text);

                    text_renderer.set_up_layout (text, area.width);

                    var is_on_blank = (
                        x < rect.x ||
                        x >= rect.x + rect.width ||
                        y < rect.y ||
                        y >= rect.y + text_renderer.text_height + text_renderer.text_y_offset
                    );
                    zone = is_on_blank ? zone : ClickZone.NAME;
                    if (is_on_blank && rubberband) {
                        /* Fake location outside centre bottom of item for rubberbanding because IconView
                         * unlike TreeView will not rubberband if clicked on an item. */
                        event.x = rect.x + rect.width / 2;
                        event.y = rect.y + rect.height + 10 + (int)(get_vadjustment ().value);
                    }
                } else {
                    bool on_helper = false;
                    Files.File? file = model.file_for_path (path);
                    if (file != null) {
                        bool on_icon = is_on_icon (x, y, ref on_helper);

                        if (on_helper) {
                            zone = ClickZone.HELPER;
                        } else if (on_icon) {
                            zone = ClickZone.ICON;
                        } else if (rubberband) {
                            zone = ClickZone.BLANK_NO_PATH;
                        }
                    } else {
                        zone = ClickZone.INVALID;
                    }
                }
            }

            return zone;
        }

        protected override void scroll_to_cell (Gtk.TreePath? path, bool scroll_to_top) {
            /* slot && directory should not be null but see lp:1595438  & https://github.com/elementary/files/issues/1699 */
            if (tree == null || path == null || slot == null || slot.directory == null ||
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
            if (selected_files != null && selected_files.first () != null) { //Could be very large - avoid length ()
                linear_select_path (path);
                return true;
            } else {
                return false;
            }
        }

        /* Override native Gtk.IconView cursor handling */
        protected override bool move_cursor (uint keyval, bool only_shift_pressed, bool control_pressed) {
            Gtk.TreePath? path = get_path_at_cursor ();
            if (path != null) {
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
                    } else if (control_pressed) {
                        set_cursor (path, false, false, false);
                        previous_linear_selection_path = path;
                    } else {
                        unselect_all ();
                        set_cursor (path, false, true, false);
                        previous_linear_selection_path = path;
                    }
                }
            } else {
                path = new Gtk.TreePath.from_indices (0);
                set_cursor (path, false, !control_pressed, false);
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

        protected void linear_select_path (Gtk.TreePath path) {
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
            Gtk.TreePath? first_selected, last_selected;
            get_first_and_last_selected (out first_selected, out last_selected);
            if (first_selected == null) {
                warning ("Linear select called with no initial selection");
                select_path (path, true);
                return;
            }

            bool before_first = path.compare (first_selected) <= 0;
            bool after_last = path.compare (last_selected) >= 0;

            var p = path.copy ();
            Gtk.TreePath p2 = null;
            Gtk.TreePath? end_path = null;

            if (before_first) {
                end_path = last_selected;
            } else if (after_last) {
                end_path = first_selected;
            } else if (previous_linear_selection_direction != 0) {/* between */
                end_path = previous_linear_selection_direction > 0 ? last_selected : first_selected;
                before_first = previous_linear_selection_direction > 0;
                after_last = previous_linear_selection_direction < 0;
            } else { /* fallback to most recent selection or if that is invalid, the first selected in the view */
                end_path = most_recently_selected != null ? most_recently_selected : first_selected;
            }

            unselect_all (); /* This clears previous linear selection details */

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
                bool after = p.compare (end_path) >= 0;
                select_path (p, true);

                p2 = p.copy ();
                p.prev ();
                while (p.compare (p2) != 0 && p.compare (first_selected) >= 0) {
                    if (after) {
                        select_path (p, true);
                    } else {
                        unselect_path (p);
                    }
                    p2 = p.copy ();
                    p.prev ();
                }

                p = path.copy ();
                p2 = p.copy ();
                p.next ();
                while (p.compare (p2) != 0 && p.compare (last_selected) <= 0) {
                    if (after) {
                        unselect_path (p);
                    } else {
                        select_path (p, true);
                    }
                    p2 = p.copy ();
                    p.next ();
                }
            }

            previous_selection_was_linear = true;

            get_first_and_last_selected (out first_selected, out last_selected);
            if (first_selected == null) {
                critical ("Linear select unselected all");
                return;
            }

            if (path.compare (last_selected) <= 0) {
                previous_linear_selection_direction = 1; /* clicked after the (visually) first selection */
            } else if (path.compare (first_selected) >= 0) {
                previous_linear_selection_direction = -1; /* clicked before the (visually) first selection */
            }

            previous_linear_selection_path = path.copy ();
            /* Ensure cursor in correct place, regardless of any selections made in this function */
            tree.set_cursor (path, null, false);
            tree.scroll_to_path (path, false, 0.5f, 0.5f);
        }

        private void get_first_and_last_selected (out Gtk.TreePath? first, out Gtk.TreePath? last) {
            first = last = null;
            var selected_paths = tree.get_selected_items ();
            if (selected_paths == null || selected_paths.first () == null) { //Could be large - avoid length ()
                return;
            }

            selected_paths.sort (Gtk.TreePath.compare);
            first = selected_paths.first ().data;
            last = selected_paths.last ().data;
        }

        protected override Gtk.TreePath up (Gtk.TreePath path) {
            int item_row = tree.get_item_row (path);
            if (item_row == 0) {
                return path;
            }
            int cols = get_n_cols ();
            int index = path.get_indices ()[0];
            Gtk.TreeIter? iter = null;
            var new_path = new Gtk.TreePath.from_indices (index - cols, -1);
            if (tree.model.get_iter (out iter, new_path)) {
                return new_path;
            } else {
                return path;
            }
        }

        protected override Gtk.TreePath down (Gtk.TreePath path) {
            int cols = get_n_cols ();
            int index = path.get_indices ()[0];
            var idx = (index + cols).clamp (0, (int)(model.get_length () - 1));
            Gtk.TreeIter? iter = null;
            var new_path = new Gtk.TreePath.from_indices (idx, -1);
            if (tree.model.get_iter (out iter, new_path)) {
                return new_path;
            } else {
                return path;
            }
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
