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
        private new Gtk.CellRendererText name_renderer;

        public IconView (Marlin.View.Slot _slot) {
//message ("New IconView");
            base (_slot);
            slot.directory.load ();
        }

        protected override Gtk.Widget? create_view () {
//message ("IV create view");
            tree = new Gtk.IconView ();

            tree.set_model (model);
            tree.set_selection_mode (Gtk.SelectionMode.MULTIPLE);
            tree.set_pixbuf_column (FM.ListModel.ColumnID.PIXBUF);

            create_and_set_up_name_column ();
            set_up_view ();

            var cell_area = tree.cell_area;
            bool stop = false;
            cell_area.@foreach ((renderer) => {
                if (renderer is Gtk.CellRendererText) {
                    name_renderer = renderer as Gtk.CellRendererText;
                    set_up_name_renderer ();
                    stop = true;
                } 

                return stop;
            });

            return tree as Gtk.Widget;
        }

        private void create_and_set_up_name_column () {
            tree.set_text_column (FM.ListModel.ColumnID.FILENAME);
        }

        private void set_up_view () {
//message ("IV tree view set up view");
            connect_tree_signals ();
            Preferences.settings.bind ("single-click", tree, "activate-on-single-click", GLib.SettingsBindFlags.GET);   
        }

        protected void set_up_name_renderer () {
//message ("ATV connect renderer_signals");
            name_renderer.editable_set = true;
            name_renderer.editable = true;
            name_renderer.edited.connect (on_name_edited);
            name_renderer.editing_canceled.connect (on_name_editing_canceled);
            name_renderer.editing_started.connect (on_name_editing_started);
        }

        private void connect_tree_signals () {
message ("IV connect tree_signals");
            tree.selection_changed.connect (on_view_selection_changed);
            tree.button_press_event.connect (on_view_button_press_event); /* Abstract */
            tree.button_release_event.connect (on_view_button_release_event); /* Abstract */
            tree.draw.connect (on_view_draw);
            tree.key_press_event.connect (on_view_key_press_event);
            tree.item_activated.connect (on_view_items_activated);
        }

/** Override parents virtual methods as required*/
        protected override Marlin.ZoomLevel get_set_up_zoom_level () {
//message ("CV setup zoom_level");
            var zoom = Preferences.marlin_icon_view_settings.get_enum ("zoom-level");
            Preferences.marlin_icon_view_settings.bind ("zoom-level", this, "zoom-level", GLib.SettingsBindFlags.SET);
            return (Marlin.ZoomLevel)zoom;
        }

        public override Marlin.ZoomLevel get_normal_zoom_level () {
            var zoom = Preferences.marlin_icon_view_settings.get_enum ("default-zoom-level");
            Preferences.marlin_icon_view_settings.set_enum ("zoom-level", zoom);
            return (Marlin.ZoomLevel)zoom;
        }

/** Override DirectoryView virtual methods as required, where common to IconView and MillerColumnView*/

        public override void zoom_level_changed () {
            if (tree != null) {
//message ("IV zoom level changed");
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
//message ("AbstractTreeView highlight path");
            tree.set_drag_dest_item (path, Gtk.IconViewDropPosition.DROP_INTO);
        }

        public override Gtk.TreePath? get_path_at_pos (int x, int y) {
//message ("IV get path at pos");
            unowned Gtk.TreePath path;
            Gtk.IconViewDropPosition pos; 
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
        }

        public override void set_cursor (Gtk.TreePath? path, bool start_editing, bool select) {
//message ("IV set cursor");
            if (path == null)
                return;

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


/**  Helper functions */
        public new void freeze_updates () {
//message ("freeze updates");
            //name_renderer.@set ("editable", true, null);
            base.freeze_updates ();
        }

        public new void unfreeze_updates () {
//message ("unfreeze updates");
            //name_renderer.@set ("editable", false, null);
            base.unfreeze_updates ();
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
        }

        protected override bool view_has_focus () {
            return tree.has_focus;
        }

        protected override bool on_view_button_press_event (Gdk.EventButton event) {
//message ("IV button press");
            grab_focus (); /* cancels any renaming */

            Gtk.TreePath? path = null;
            Gtk.CellRenderer? renderer = null;

            bool on_blank = !tree.get_item_at_pos ((int) event.x, (int) event.y, out path, out renderer);
            bool no_mods = (event.state & Gtk.accelerator_get_default_mod_mask ()) == 0;
            bool result = false;
            bool on_editable = (renderer != null && (renderer is Gtk.CellRendererText));

            if (no_mods) {
                unselect_all ();
                if (path != null) {
                    tree.select_path (path);
//message ("IV reselect path");
                }
            }

            switch (event.button) {
                case Gdk.BUTTON_PRIMARY:
                    if (path == null)
                        result = true;

                    else if (Preferences.settings.get_boolean ("single-click") && no_mods) {
                        result = handle_primary_button_single_click_mode (event, null, path, null, no_mods, on_blank, !on_editable);

                    }
                    /* In double-click mode on path the default Gtk.TreeView handler is used */
                    break;

                case Gdk.BUTTON_MIDDLE: 
                    result = handle_middle_button_click (event, on_blank);
                    break;

                case Gdk.BUTTON_SECONDARY:
                    result = handle_secondary_button_click (event);
                    break;

                default:
                    result = handle_default_button_click ();
                    break;
            }
//message ("IV button press leaving");
            return result;
        }

        protected override bool handle_primary_button_single_click_mode (Gdk.EventButton event, Gtk.TreeSelection? selection, Gtk.TreePath? path, Gtk.TreeViewColumn? col, bool no_mods, bool on_blank, bool on_icon) {
//message ("IV handle left button");
            assert (selection == null); /* not consistent with icon view */
            assert (col == null); /* not consistent with icon view */

            bool result = true;
            if (path != null) {
                /*Determine where user clicked - this will be the sole selection */

                if (!on_icon)
                    rename_file (selected_files.data); /* Is this desirable? */
                else
                    result = false; /* Use default handler */

            } /* No action if left click on blank area */

            return result;
        }

        protected override bool handle_middle_button_click (Gdk.EventButton event, bool on_blank) {
                /* opens folder(s) in new tab */
                if (!on_blank) {
                    //message (" (Marlin.OpenFlag.NEW_TAB);
                    return true;
                } else
                    return false;
        }

        public override void start_renaming_file (GOF.File file, bool preselect_whole_name) {
//message ("ATV start renaming file");
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
            tree.scroll_to_path (path, true, (float) 0.0, (float) 0.0);
            /* set cursor_on_cell also triggers editing-started, where we save the editable widget */
            tree.set_cursor (path, name_renderer, true);

            int start_offset= 0, end_offset = -1;
            if (editable_widget != null) {
                Marlin.get_rename_region (original_name, out start_offset, out end_offset, preselect_whole_name);
                editable_widget.select_region (start_offset, end_offset);
            }
        }

        //protected override bool on_view_button_press_event (Gdk.EventButton event) {return false;}
        //protected override bool handle_primary_button_single_click_mode (Gdk.EventButton event, Gtk.TreeSelection? selection, Gtk.TreePath? path, Gtk.TreeViewColumn? col, bool no_mods, bool on_blank) {return false;}
        //protected override bool handle_secondary_button_click (Gdk.EventButton event, Gtk.TreeSelection selection, Gtk.TreePath? path, Gtk.TreeViewColumn? col, bool no_mods, bool on_blank) {return false;}

    }
}
