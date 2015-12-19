/***
    Copyright (C) 2015 elementary Developers

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

            name_renderer = new Marlin.TextRenderer (Marlin.ViewMode.ICON);
            set_up_name_renderer ();

            (tree as Gtk.CellLayout).pack_start (icon_renderer, false);
            (tree as Gtk.CellLayout).pack_end (name_renderer, false);

            (tree as Gtk.CellLayout).add_attribute (name_renderer, "text", FM.ListModel.ColumnID.FILENAME);
            (tree as Gtk.CellLayout).add_attribute (name_renderer, "file", FM.ListModel.ColumnID.FILE_COLUMN);
            (tree as Gtk.CellLayout).add_attribute (name_renderer, "background", FM.ListModel.ColumnID.COLOR);
            (tree as Gtk.CellLayout).add_attribute (icon_renderer, "file", FM.ListModel.ColumnID.FILE_COLUMN);

            connect_tree_signals ();
        }

        protected override void set_up_name_renderer () {
            base.set_up_name_renderer ();
            name_renderer.wrap_mode = Pango.WrapMode.WORD_CHAR;
            name_renderer.xalign = 0.5f;
            name_renderer.yalign = 0.0f;
            name_renderer.set_fixed_size (-1, 54);
        }

        protected void set_up_icon_renderer () {
            icon_renderer.set_property ("follow-state",  true);
        }


        private void connect_tree_signals () {
            tree.selection_changed.connect (on_view_selection_changed);

            tree.realize.connect ((w) => {
                tree.grab_focus ();
            });
        }

        protected override Gtk.Widget? create_view () {
            tree = new Gtk.IconView ();
            set_up_view ();
            set_up_name_renderer ();
            set_up_icon_renderer ();

            return tree as Gtk.Widget;
        }

        protected override Marlin.ZoomLevel get_set_up_zoom_level () {
            var zoom = Preferences.marlin_icon_view_settings.get_enum ("zoom-level");
            Preferences.marlin_icon_view_settings.bind ("zoom-level", this, "zoom-level", GLib.SettingsBindFlags.SET);

            minimum_zoom = (Marlin.ZoomLevel)Preferences.marlin_icon_view_settings.get_enum ("minimum-zoom-level");
            maximum_zoom = (Marlin.ZoomLevel)Preferences.marlin_icon_view_settings.get_enum ("maximum-zoom-level");

            if (zoom_level < minimum_zoom)
                zoom_level = minimum_zoom;

            if (zoom_level > maximum_zoom)
                zoom_level = maximum_zoom;

            return (Marlin.ZoomLevel)zoom;
        }

        public override Marlin.ZoomLevel get_normal_zoom_level () {
            var zoom = Preferences.marlin_icon_view_settings.get_enum ("default-zoom-level");
            Preferences.marlin_icon_view_settings.set_enum ("zoom-level", zoom);

            return (Marlin.ZoomLevel)zoom;
        }

        public override void change_zoom_level () {
            if (tree != null) {
                tree.set_column_spacing ((int)((double)icon_size * (0.3 - zoom_level * 0.03)));
                tree.set_row_spacing ((int)((double)icon_size * (0.2 - zoom_level * 0.03)));
                tree.set_item_width ((int)((double)icon_size * (2.5 - zoom_level * 0.2)));

                name_renderer.set_property ("wrap-width", tree.get_item_width ());
                name_renderer.set_property ("zoom-level", zoom_level);

                base.change_zoom_level ();
            }
        }

        public override GLib.List<Gtk.TreePath> get_selected_paths () {
            return tree.get_selected_items ();
        }

        public override void highlight_path (Gtk.TreePath? path) {
            tree.set_drag_dest_item (path, Gtk.IconViewDropPosition.DROP_INTO);
        }

        public override Gtk.TreePath? get_path_at_pos (int x, int y) {
            unowned Gtk.TreePath? path = null;
            Gtk.IconViewDropPosition? pos = null;

            /* The next line needs a patched gtk+-3.0.vapi file in order to compile as of valac version 0.25.4
             * - the fourth parameter should be an 'out' parameter */
            if (x >= 0 && y >= 0 && tree.get_dest_item_at_pos  (x, y, out path, out pos))
                return path;
            else
                return null;
        }

        public override void select_all () {
            tree.select_all ();
        }

        public override void unselect_all () {
            tree.unselect_all ();
        }

        public override void select_path (Gtk.TreePath? path) {
            if (path != null) {
                tree.select_path (path);
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

                    (r as Marlin.TextRenderer).set_up_layout (text, area);

                    if (x >= rect.x &&
                        x <= rect.x + rect.width &&
                        y >= rect.y &&
                        y <= rect.y + (r as Marlin.TextRenderer).text_height)

                        zone = ClickZone.NAME;
                    else if (rubberband) {
                        /* Fake location outside centre bottom of item for rubberbanding */
                        event.x = rect.x + rect.width / 2;
                        event.y = rect.y + rect.height + 10 + (int)(get_vadjustment ().value);
                        zone = ClickZone.BLANK_NO_PATH;
                    }
                } else {
                    bool on_helper = false;
                    bool on_icon = is_on_icon (x, y, area.x, area.y, ref on_helper);

                    if (on_helper)
                        zone = ClickZone.HELPER;
                    else if (on_icon)
                        zone = ClickZone.ICON;
                    else if (rubberband) {
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
            if (tree == null || path == null || slot.directory.permission_denied || slot.directory.is_empty ())
                return;

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
    }
}
