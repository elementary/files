/*
 Copyright (C) 

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
    //public class IconView : DirectoryView {
    public class IconView : AbstractTreeView {
        /* Golden ratio used */
        const double ITEM_WIDTH_TO_ICON_SIZE_RATIO = 1.62;
        protected new Gtk.IconView tree;

    /** Rename support */
        //protected new Gtk.TreeViewColumn name_column;
        //protected Gtk.CellRendererText name_renderer;
        //protected Gtk.Entry editable_widget;
        //protected GOF.File renaming_file = null;
        //protected bool rename_done = false;
        //protected string original_name = "";


        public IconView (Marlin.View.Slot _slot) {
message ("New Abstract IconView");
            base (_slot);
        }

        construct {
message ("Abstract IconView construct");
        }

        ~AbstractTreeView () {

        }

        protected override Gtk.Widget? create_view () {
message ("IV create view");
            tree = new Gtk.IconView ();
            tree.set_model (model);
            tree.set_selection_mode (Gtk.SelectionMode.MULTIPLE);
            tree.set_pixbuf_column (FM.ListModel.ColumnID.PIXBUF);

            create_and_set_up_name_column ();
            set_up_view ();
            return tree as Gtk.Widget;
        }

        protected override void create_and_set_up_name_column () {
            tree.set_text_column (FM.ListModel.ColumnID.FILENAME);
        }

//        private void set_up_view () {
//message ("IV tree view set up view");
//            tree.cell_area.add_editable.connect (on_cell_area_add_editable);
//            connect_tree_signals ();
//            Preferences.settings.bind ("single-click", tree, "activate-on-single-click", GLib.SettingsBindFlags.GET);   
//        }

//        private void connect_tree_signals () {
//message ("IV connect tree_signals");
//            tree.selection_changed.connect (on_view_selection_changed);
//            tree.button_press_event.connect (on_view_button_press_event); /* Abstract */
//            tree.button_release_event.connect (on_view_button_release_event); /* Abstract */
//            tree.draw.connect (on_view_draw);
//            tree.key_press_event.connect (on_view_key_press_event);
//            tree.item_activated.connect (on_items_activated);
//        }

/** Override parents virtual methods as required*/
        protected override Marlin.ZoomLevel get_set_up_zoom_level () {
message ("CV setup zoom_level");
            var zoom = Preferences.marlin_icon_view_settings.get_enum ("zoom-level");
            Preferences.marlin_icon_view_settings.bind ("zoom-level", this, "zoom-level", GLib.SettingsBindFlags.SET);
            return (Marlin.ZoomLevel)zoom;
        }

        public override Marlin.ZoomLevel get_normal_zoom_level () {
            var zoom = Preferences.marlin_icon_view_settings.get_enum ("default-zoom-level");
            Preferences.marlin_icon_view_settings.set_enum ("zoom-level", zoom);
            return (Marlin.ZoomLevel)zoom;
        }


/** Signal handlers */
    /** tree signals */
//        protected void on_view_row_activated () {
//message ("on tree row activated");
//            activate_selected_items (Marlin.OpenFlag.DEFAULT);
//        }

//        protected override void on_view_selection_changed () {
//message ("on tree selection changed");
//            update_selected_files ();
//            notify_selection_changed ();
//        }

        /** User signals */

//        /* Was key_press_call_back */
//        protected bool on_view_key_press_event (Gdk.EventKey event) {
//            bool control_pressed = ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0);
//            bool shift_pressed = ((event.state & Gdk.ModifierType.SHIFT_MASK) != 0);

//            switch (event.keyval) {
//                case Gdk.Key.F10:
//                    if (control_pressed) {
//                        show_or_queue_context_menu (event);
//                        return true;
//                    } else
//                        return false;

//                case Gdk.Key.space:
//                    if (!control_pressed && tree.has_focus) {
//                        if (shift_pressed)
//                            activate_selected_items (Marlin.OpenFlag.NEW_TAB);
//                        else
//                            preview_selected_items ();

//                        return true;
//                    } else
//                        return false;

//                case Gdk.Key.Return:
//                case Gdk.Key.KP_Enter:
//                    if (shift_pressed)
//                        activate_selected_items (Marlin.OpenFlag.NEW_TAB);
//                    else
//                         activate_selected_items (Marlin.OpenFlag.DEFAULT);

//                    return true;

//                default:
//                    break;
//            }
//            return false;
//        }

//        protected override bool on_scroll_event (Gdk.EventScroll event) {
//message ("Abstract List view scroll handler");

//            if ((event.state & Gdk.ModifierType.CONTROL_MASK) == 0) {
//                double increment = 0.0;
//                switch (event.direction) {
//                    case Gdk.ScrollDirection.LEFT:
//                        increment = 5.0;
//                        break;
//                    case Gdk.ScrollDirection.RIGHT:
//                        increment = -5.0;
//                        break;
//                    case Gdk.ScrollDirection.SMOOTH:
//                        double delta_x;
//                        event.get_scroll_deltas (out delta_x, null);
//                        increment = delta_x * 10.0;
//                        break;
//                    default:
//                        break;
//                }
//                if (increment != 0.0)
//                    slot.horizontal_scroll_event (increment);
//            }
//            return handle_scroll_event (event);
//        }

    /** name renderer signals */

        private void on_cell_area_add_editable (Gtk.CellRenderer renderer, Gtk.CellEditable editable, Gdk.Rectangle rect, string path) {
message ("cell_area add editable");
            on_name_editing_started (editable, path);
        }

//        private void on_name_editing_started (Gtk.CellEditable editable, string path) {
//message ("on name editing started");
//            renaming = true;
//            freeze_updates ();
//            editable_widget = editable as Gtk.Entry;
//            original_name = editable_widget.get_text ().dup ();
//            editable_widget.focus_out_event.connect ((event) => {
//                on_name_editing_canceled ();
//                return false;
//            });
//        }

//        private void on_name_editing_canceled () {
//message ("on name editing canceled");
//                editable_widget = null;
//                renaming = false;
//                unfreeze_updates ();
                
//        }

//        private void on_name_edited (string path_string, string new_name) {
//            /* Don't allow a rename with an empty string. Revert to original
//             * without notifying the user. */
//            if (new_name != "") {
//                var path = new Gtk.TreePath.from_string (path_string);
//                Gtk.TreeIter? iter = null;
//                model.get_iter (out iter, path);

//                GOF.File? file = null;
//                model.@get (iter,
//                            FM.ListModel.ColumnID.FILE_COLUMN, out file);

//                /* Only rename if name actually changed */
//                if (!(new_name == original_name)) {
//                    renaming_file = file;
//                    rename_done = false;
//                    original_name = new_name.dup ();
//                    file.rename (new_name, on_renaming_done);
//                }
//            }
//            renaming = false;
//        }

//        private void on_renaming_done (GOF.File file, GLib.File result_location, GLib.Error error, void* callback_data = null) {
//            if (renaming_file != null) {
//                rename_done = true;

//                if (error != null) {
//                    Eel.show_error_dialog (_("Failed to rename %s to %s").printf (file.info.get_name (), original_name), error.message, null);
//                    /* If the rename failed (or was cancelled), kill renaming_file.
//                     * We won't get a change event for the rename, so otherwise
//                     * it would stay around forever.
//                     */
//                    renaming_file = null;
//                }
//            }
//        }

/** Override DirectoryView virtual methods as required, where common to IconView and MillerColumnView*/

        public override void zoom_level_changed () {
            if (tree != null) {
message ("IV zoom level changed");
                int icon_size = (int) (Marlin.zoom_level_to_icon_size (zoom_level));
                tree.set_columns (-1);
                tree.set_item_width ((int)((double) icon_size * ITEM_WIDTH_TO_ICON_SIZE_RATIO));
                queue_draw ();
            }
        }

        public override GLib.List<Gtk.TreePath> get_selected_paths () {
            return tree.get_selected_items ();
        }

        public override void highlight_path (Gtk.TreePath? path) {
message ("AbstractTreeView highlight path");
            tree.set_drag_dest_item (path, Gtk.IconViewDropPosition.DROP_INTO);
        }

        public override Gtk.TreePath? get_path_at_pos (int x, int y) {
message ("IV get path at pos");
            unowned Gtk.TreePath path;
            Gtk.IconViewDropPosition pos; // = Gtk.IconViewDropPosition.DROP_INTO;
            if (tree.get_dest_item_at_pos  (x, y, out path, out pos))
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
            if (path != null)
                tree.select_path (path);
            else
                unselect_all ();
        }

        public override void set_cursor (Gtk.TreePath? path, bool start_editing, bool select) {
message ("IV set cursor");
            if (path == null)
                return;

            //Gtk.TreeSelection selection = tree.get_selection ();
            if (!select)
                GLib.SignalHandler.block_by_func (tree, (void*) on_view_selection_changed, null);

            tree.set_cursor (path, null, start_editing);

            if (!select)
                GLib.SignalHandler.unblock_by_func (tree, (void*) on_view_selection_changed, null);
        }

        public override bool get_visible_range (out Gtk.TreePath? start_path, out Gtk.TreePath? end_path) {
            start_path = null;
            end_path = null;
            return tree.get_visible_range (out start_path, out end_path);
        }

        public override void start_renaming_file (GOF.File file, bool preselect_whole_name) {
message ("IV start renaming file");
            /* Select whole name if we are in renaming mode already */
            if (name_column != null && editable_widget != null) {
                editable_widget.select_region (0, -1);
                return;
            }

            Gtk.TreeIter? iter = null;
            if (!model.get_first_iter_for_file (file, out iter)) {
                critical ("Failed to find rename file in model");
                return;
            }

            /* Freeze updates to the view to prevent losing rename focus when the tree view updates */
            freeze_updates ();

            Gtk.TreePath path = model.get_path (iter);
            //tree.scroll_to_cell (null, name_column, true, (float) 0.0, (float) 0.0);
            tree.scroll_to_path (path, true, (float) 0.0, (float) 0.0);
            /* set cursor_on_cell also triggers editing-started, where we save the editable widget */
            tree.set_cursor (path, null, true);

            int start_offset= 0, end_offset = -1;
            if (editable_widget != null) {
                Marlin.get_rename_region (original_name, out start_offset, out end_offset, preselect_whole_name);
                editable_widget.select_region (start_offset, end_offset);
            }
        }

        public override void sync_selection () {
            /* FIXME Not implemented - needed? */
        }

/** Treeview functions */
//        /* Was filename_cell_data_func */
//        protected void filename_cell_data_func (Gtk.CellLayout cell_layout,
//                                              Gtk.CellRenderer renderer,
//                                              Gtk.TreeModel model,
//                                              Gtk.TreeIter iter) {

//            Gdk.RGBA rgba = {0.0, 0.0, 0.0, 0.0};
//            string filename = "";
//            model.@get (iter, FM.ListModel.ColumnID.FILENAME, out filename, -1);
//            string? color = null;
//            model.@get (iter, FM.ListModel.ColumnID.COLOR, out color, -1);

//            if (color != null)
//                rgba.parse (color);

//            renderer.@set ("text", filename,
//                           "underline", Pango.Underline.NONE,
//                           "cell-background-rgba", rgba,
//                           null);
//        }

//        public bool on_view_draw (Cairo.Context cr) {
//message ("IV on tree draw");
//            /* If folder is empty, draw the empty message in the middle of the view
//             * otherwise pass on event */
//            if (slot.directory.is_empty ()) {
//                Pango.Layout layout = create_pango_layout (null);
//                layout.set_markup (slot.empty_message, -1);

//                Pango.Rectangle? extents = null;
//                layout.get_extents (null, out extents);

//                double width = Pango.units_to_double (extents.width);
//                double height = Pango.units_to_double (extents.height);

//                double x = (double) get_allocated_width () / 2 - width / 2;
//                double y = (double) get_allocated_height () / 2 - height / 2;

//                get_style_context ().render_layout (cr, x, y, layout);
//            }
//            return false;
//        }

/**  Helper functions */
        public new void freeze_updates () {
message ("freeze updates");
            //name_renderer.@set ("editable", true, null);
            base.freeze_updates ();
        }

        public new void unfreeze_updates () {
message ("unfreeze updates");
            //name_renderer.@set ("editable", false, null);
            base.unfreeze_updates ();
        }

        protected override void update_selected_files () {
message ("IV update selected files");
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
        }

        private void on_view_item_activated (Gtk.TreePath path) {}

        protected override bool view_has_focus () {
            return tree.has_focus;
        }

        protected override bool handle_primary_button_single_click_mode (Gdk.EventButton event, Gtk.TreeSelection selection, Gtk.TreePath? path, Gtk.TreeViewColumn? col, bool no_mods, bool on_blank) {return false;}
        protected override bool handle_middle_button_click (Gdk.EventButton event, Gtk.TreeSelection selection, Gtk.TreePath? path, Gtk.TreeViewColumn? col, bool no_mods, bool on_blank) {return false;}
        protected override bool handle_secondary_button_click (Gdk.EventButton event, Gtk.TreeSelection selection, Gtk.TreePath? path, Gtk.TreeViewColumn? col, bool no_mods, bool on_blank) {return false;}

    }
}
