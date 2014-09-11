/*
 Copyright (C) 2014 ELementary Developers

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
        /* Golden ratio used */
        const double ITEM_WIDTH_TO_ICON_SIZE_RATIO = 1.62;
        protected new Gtk.IconView tree;

        public IconView (Marlin.View.Slot _slot) {
//message ("New IconView");
            base (_slot);
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

        protected void set_up_name_renderer () {
//message ("IV set up name renderer");
            name_renderer.wrap_width = 12;
            name_renderer.wrap_mode = Pango.WrapMode.WORD_CHAR;
            name_renderer.xalign = 0.5f;
            name_renderer.editable_set = true;
            name_renderer.editable = true;
            name_renderer.edited.connect (on_name_edited);
            name_renderer.editing_canceled.connect (on_name_editing_canceled);
            name_renderer.editing_started.connect (on_name_editing_started);
        }
        protected void set_up_icon_renderer () {
//message ("IV set up icon renderer");
            icon_renderer.set_property ("follow-state",  true);
            icon_renderer.set_property ("selection-helpers",  true); /* do we always want helpers for accessibility? */
            //Preferences.settings.bind ("single-click", icon_renderer, "selection-helpers", GLib.SettingsBindFlags.DEFAULT);
        }


        private void connect_tree_signals () {
//message ("IV connect tree_signals");
            tree.selection_changed.connect (on_view_selection_changed);
            tree.button_press_event.connect (on_view_button_press_event); /* Abstract */
            tree.button_release_event.connect (on_view_button_release_event); /* Abstract */
            tree.draw.connect (on_view_draw);
            tree.key_press_event.connect (on_view_key_press_event);
            tree.item_activated.connect (on_view_items_activated);
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

            tree.add_events (Gdk.EventMask.POINTER_MOTION_MASK);
            tree.motion_notify_event.connect (on_motion_notify_event);

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
                int icon_size = (int) (Marlin.zoom_level_to_icon_size (zoom_level));
                tree.set_item_width ((int)((double) icon_size * ITEM_WIDTH_TO_ICON_SIZE_RATIO));
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
            Gtk.IconViewDropPosition pos; 
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

        public override void set_cursor (Gtk.TreePath? path, bool start_editing, bool select) {
            if (path == null)
                return;
//message ("IV set cursor path %s, select is %s", path.to_string (), select ? "true" : "false");
            if (!select)
                //GLib.SignalHandler.block_by_func (tree, (void*) on_view_selection_changed, null);
                tree.selection_changed.disconnect (on_view_selection_changed);

            set_cursor_on_cell (path, null, name_renderer, start_editing);
            select_path (path);
            if (!select)
//                GLib.SignalHandler.unblock_by_func (tree, (void*) on_view_selection_changed, null);
                tree.selection_changed.connect (on_view_selection_changed);
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
                if (file != null) {
                    selected_files.prepend (file);
                } else {
                    critical ("Null file in model");
                }
            });
            selected_files.reverse ();
//message ("select files length is %u", selected_files.length ());
        }

        protected override bool view_has_focus () {
            return tree.has_focus;
        }

        protected override void get_event_position_info (int x, int y,
                                                out Gtk.TreePath? path,
                                                out bool on_name,
                                                out bool on_blank,
                                                out bool on_icon,
                                                out bool on_helper) {
            unowned Gtk.TreePath? p = null;
            unowned Gtk.CellRenderer r;

            on_blank = !tree.get_item_at_pos (x, y, out p, out r);
            path = p;

            on_icon = false;
            on_helper = false;
            on_name = false;
            if (r != null) {
                if (r is Gtk.CellRendererText)
                    on_name = true;
                else {
                    Gdk.Rectangle rect, area;
                    tree.get_cell_rect  (p, r, out rect);
                    area = r.get_aligned_area (tree, Gtk.CellRendererState.PRELIT, rect);
                    if (x <= area.x + 18 && y <= area.y + 18) {
                        on_helper = true;
                    }
                }
            }
            on_icon = !on_name && !on_helper;
        }

        protected override void scroll_to_cell (Gtk.TreePath? path, Gtk.TreeViewColumn? col) {
//message ("IV scroll to cell");
            if (tree != null)
                tree.scroll_to_path (path, true, 0.0f, 0.0f);
        }
        protected override void set_cursor_on_cell (Gtk.TreePath path, Gtk.TreeViewColumn? col, Gtk.CellRenderer renderer, bool start_editing) {
            scroll_to_cell(path, name_column);
            tree.set_cursor (path, renderer, start_editing);
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
