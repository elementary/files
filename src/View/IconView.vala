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

 Authors : Jeremy Wootten <jeremy@elementary.org>
*/

namespace FM {
    public class IconView : DirectoryView {
        const double COLUMN_SPACING_RATIO = 0.3;
        const double ROW_SPACING_RATIO = 0.3;
        const double WIDTH_ICON_SIZE_RATIO = 1.62;
        protected new Gtk.IconView tree;
        uint current_zone;

        public IconView (Marlin.View.Slot _slot) {
//message ("New IconView");
            base (_slot);
            minimum_zoom = Marlin.ZoomLevel.SMALLER;
            if (zoom_level < minimum_zoom)
                zoom_level = minimum_zoom;
        }

        ~IconView () {
//message ("IV desctructor");
        }

        private void set_up_view () {
//message ("IV tree view set up view");
            tree.set_model (model);
            tree.set_selection_mode (Gtk.SelectionMode.MULTIPLE);
            tree.set_columns (-1);
            tree.set_reorderable (false);
            (tree as Gtk.CellLayout).pack_start (icon_renderer, false);
            (tree as Gtk.CellLayout).pack_end (name_renderer, false);
            (tree as Gtk.CellLayout).add_attribute (name_renderer, "text", FM.ListModel.ColumnID.FILENAME);
            (tree as Gtk.CellLayout).add_attribute (name_renderer, "background", FM.ListModel.ColumnID.COLOR);
            (tree as Gtk.CellLayout).add_attribute (icon_renderer, "file", FM.ListModel.ColumnID.FILE_COLUMN);
            connect_tree_signals ();
            Preferences.settings.bind ("single-click", tree, "activate-on-single-click", GLib.SettingsBindFlags.GET);
        }

        protected override void set_up_name_renderer () {
//message ("IV set up name renderer");
            base.set_up_name_renderer ();
            name_renderer.wrap_mode = Pango.WrapMode.WORD_CHAR;
            name_renderer.xalign = 0.5f;
            name_renderer.yalign = 0.0f;
            name_renderer.set_fixed_size (-1, 54);
        }
        protected void set_up_icon_renderer () {
//message ("IV set up icon renderer");
            icon_renderer.set_property ("follow-state",  true);
        }


        private void connect_tree_signals () {
//message ("IV connect tree_signals");
            tree.selection_changed.connect (on_view_selection_changed);
            tree.realize.connect ((w) => {
                tree.grab_focus ();
            });
        }

/** Override parent's abstract and  virtual methods as required*/

        protected override Gtk.Widget? create_view () {
//message ("IV create view");
            tree = new Gtk.IconView ();
            set_up_view ();
            set_up_name_renderer ();
            set_up_icon_renderer ();
            return tree as Gtk.Widget;
        }

        protected override Marlin.ZoomLevel get_set_up_zoom_level () {
//message ("IV setup zoom_level");
            var zoom = Preferences.marlin_icon_view_settings.get_enum ("zoom-level");
            Preferences.marlin_icon_view_settings.bind ("zoom-level", this, "zoom-level", GLib.SettingsBindFlags.SET);
            return (Marlin.ZoomLevel)zoom;
        }

        public override Marlin.ZoomLevel get_normal_zoom_level () {
            var zoom = Preferences.marlin_icon_view_settings.get_enum ("default-zoom-level");
            Preferences.marlin_icon_view_settings.set_enum ("zoom-level", zoom);
            return (Marlin.ZoomLevel)zoom;
        }

        public override void zoom_level_changed () {
            if (tree != null) {
//message ("IV zoom level changed");
                tree.set_column_spacing ((int)((double)icon_size * COLUMN_SPACING_RATIO));
                tree.set_row_spacing ((int)((double)icon_size * ROW_SPACING_RATIO));
                name_renderer.set_property ("wrap-width", (int)(1.62 * icon_size));
                name_renderer.set_property ("zoom-level", zoom_level);
                base.zoom_level_changed ();
            }
        }

        public override GLib.List<Gtk.TreePath> get_selected_paths () {
            return tree.get_selected_items ();
        }

        public override void highlight_path (Gtk.TreePath? path) {
//message ("IconView highlight path");
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
//message ("IV unselect all");
            tree.unselect_all ();
        }

        public override void select_path (Gtk.TreePath? path) {
            if (path != null) {
//message ("IV select path %s", path.to_string ());
                tree.select_path (path);
            }
        }
        public override void unselect_path (Gtk.TreePath? path) {
//message ("IV unselect path");
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
            /* FIXME Not implemented - needed? */
        }

        protected override void update_selected_files () {
//message ("IV update selected files");
            selected_files = null;
            tree.selected_foreach ((tree, path) => {
                unowned GOF.File file;
                file = model.file_for_path (path);
                /* FIXME - model does not return owned object?  Is this correct? */
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

        protected override uint get_event_position_info (Gdk.EventButton event, out Gtk.TreePath? path) {
            unowned Gtk.TreePath? p = null;
            unowned Gtk.CellRenderer? r;
            uint zone;
            int x, y, mask;

            get_window ().get_device_position (event.get_device (), out x, out y, out mask);

            tree.get_item_at_pos ((int)event.x, (int)event.y, out p, out r);
            path = p;
            zone = (p != null ? ClickZone.BLANK_PATH : ClickZone.BLANK_NO_PATH);
            if (zone == current_zone)
                return zone;

            if (r != null) {
                Gdk.Rectangle rect, area;
                tree.get_cell_rect  (p, r, out rect);
                area = r.get_aligned_area (tree, Gtk.CellRendererState.PRELIT, rect);
                if (r is Marlin.TextRenderer) {
                    int text_width, text_height;
                    Gtk.TreeIter iter;
                    model.get_iter (out iter, path);
                    string? text = null;
                    model.@get (iter,
                            FM.ListModel.ColumnID.FILENAME, out text);

                    if (text == null)
                        text = "";

                    (r as Marlin.TextRenderer).set_up_layout (text, area, out text_width, out text_height);   
                    if (x >= rect.x &&
                        x <= rect.x + rect.width &&
                        y >= rect.y &&
                        y <= rect.y + text_height)

                        zone = ClickZone.NAME;
                    else {
                        event.x = rect.x + rect.width / 2;
                        event.y = rect.y + rect.height + 10;
                        zone = ClickZone.BLANK_NO_PATH;
                    }
                } else {
                    if (helpers_shown &&
                        x >= area.x &&
                        x <= area.x + 18 &&
                        y >= area.y &&
                        y <= area.y + 18)

                        zone = ClickZone.HELPER;
                    else if (x >= area.x &&
                        x <= area.x + icon_size &&
                        y >= area.y &&
                        y <= area.y + icon_size)

                        zone = ClickZone.ICON;
                    else {
                        event.x = rect.x + rect.width / 2;
                        event.y = rect.y - 10;
                        zone = ClickZone.BLANK_NO_PATH;
                    }
                }
            }
//message ("returning zone %u", zone);
            current_zone = zone;
            return zone;
        }

        protected override void scroll_to_cell (Gtk.TreePath? path, Gtk.TreeViewColumn? col,  bool scroll_to_top) {
//message ("IV scroll to cell");
            if (tree == null || path == null || slot.directory.permission_denied)
                return;

            tree.scroll_to_path (path, scroll_to_top, 0.0f, 0.0f);
        }
        protected override void set_cursor_on_cell (Gtk.TreePath path, Gtk.TreeViewColumn? col, Gtk.CellRenderer renderer, bool start_editing, bool scroll_to_top) {
//message ("IV set cursor on cell, start editing is %s", start_editing.to_string ());
            scroll_to_cell(path, name_column, scroll_to_top);
            tree.set_cursor (path, renderer, start_editing);
        }

        public override void set_cursor (Gtk.TreePath? path, bool start_editing, bool select, bool scroll_to_top) {
            if (path == null)
                return;
//message ("IV set cursor path %s, select is %s", path.to_string (), select ? "true" : "false");

            if (!select)
                tree.selection_changed.disconnect (on_view_selection_changed);

            set_cursor_on_cell (path, null, name_renderer, start_editing, scroll_to_top);
            select_path (path);
            if (!select)
                tree.selection_changed.connect (on_view_selection_changed);
        }

        public override Gtk.TreePath? get_path_at_cursor () {
            Gtk.TreePath? path;
            tree.get_cursor (out path, null);
            return path;
        }

        protected override void freeze_tree () {
//message ("IV freeze tree");
            tree.freeze_child_notify ();
            is_loading = true;
        }
        protected override void thaw_tree () {
            if (!is_loading)
                return;

//message ("IV thaw tree");
            tree.thaw_child_notify ();
            is_loading = false;
            queue_draw ();
        }
    }
}
