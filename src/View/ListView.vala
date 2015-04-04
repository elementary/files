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
    public class ListView : AbstractTreeView {

        /* We wait two seconds after row is collapsed to unload the subdirectory */
        static const int COLLAPSE_TO_UNLOAD_DELAY = 2;

        static string [] column_titles = {
            _("Filename"),
            _("Size"),
            _("Type"),
            _("Modified")
        };

        private uint unload_file_timeout_id = 0;

        public ListView (Marlin.View.Slot _slot) {
            base (_slot);
        }

        private void connect_additional_signals () {
            tree.row_expanded.connect (on_row_expanded);
            tree.row_collapsed.connect (on_row_collapsed);
        }

        private void append_extra_tree_columns () {
            int fnc = FM.ListModel.ColumnID.FILENAME;

            int preferred_column_width = Preferences.marlin_column_view_settings.get_int ("preferred-column-width");
            for (int k = fnc; k < FM.ListModel.ColumnID.NUM_COLUMNS; k++) {
                if (k == fnc) {
                    /* name_column already created by AbstractTreeVIew */
                    name_column.set_title (column_titles [0]);
                    name_column.min_width = preferred_column_width;
                } else {
                    var renderer = new Gtk.CellRendererText ();
                    var col = new Gtk.TreeViewColumn.with_attributes (column_titles [k - fnc],
                                                                      renderer,
                                                                      "text", k);     
                    col.set_sort_column_id (k);
                    col.set_resizable (false);
                    col.set_expand (false);
                    col.min_width = 24;
                    if (k == FM.ListModel.ColumnID.SIZE || k == FM.ListModel.ColumnID.MODIFIED)
                        renderer.@set ("xalign", 1.0f);
                    else
                        renderer.@set ("xalign", 0.0f);

                    tree.append_column (col);
                }
            }
        }

        private void on_row_expanded (Gtk.TreeIter iter, Gtk.TreePath path) {
            GOF.Directory.Async dir;
            set_path_expanded (path, true);

            if (model.load_subdirectory (path, out dir) && dir is GOF.Directory.Async)
                add_subdirectory (dir);
        }

        private void on_row_collapsed (Gtk.TreeIter iter, Gtk.TreePath path) {
            unowned GOF.Directory.Async dir;
            unowned GOF.File file;
            set_path_expanded (path, false);

            if (model.get_directory_file (path, out dir, out file)) {
                schedule_model_unload_directory (file, dir);
                remove_subdirectory (dir);
            } else
                critical ("failed to get directory/file");
        }

        private void set_path_expanded (Gtk.TreePath path, bool expanded) {
            GOF.File? file = model.file_for_path (path);

            if (file != null)
                file.set_expanded (expanded);
        }

        private void schedule_model_unload_directory (GOF.File file, GOF.Directory.Async directory) {
            unload_file_timeout_id = GLib.Timeout.add_seconds (COLLAPSE_TO_UNLOAD_DELAY, () => {
                Gtk.TreeIter iter;
                Gtk.TreePath path;

                if (model.get_first_iter_for_file (file, out iter)) {
                    path = ((Gtk.TreeModel)model).get_path (iter);
                    if (path != null && !((Gtk.TreeView)tree).is_row_expanded (path))
                        model.unload_subdirectory (iter);
                } else
                    critical ("Failed to get iter");

                unload_file_timeout_id = 0;
                return false;
            });
        }

        private void cancel_file_timeout () {
            if (unload_file_timeout_id > 0) {
                GLib.Source.remove (unload_file_timeout_id);
                unload_file_timeout_id = 0;
            }
        }

        protected override bool on_view_key_press_event (Gdk.EventKey event) {
            bool control_pressed = ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0);
            bool shift_pressed = ((event.state & Gdk.ModifierType.SHIFT_MASK) != 0);

            if (!control_pressed && !shift_pressed) {

                switch (event.keyval) {
                    case Gdk.Key.Right:
                        Gtk.TreePath? path = null;
                        tree.get_cursor (out path, null);

                        if (path != null)
                            tree.expand_row (path, false);

                        return true;

                    case Gdk.Key.Left:
                        Gtk.TreePath? path = null;
                        tree.get_cursor (out path, null);

                        if (path != null) {
                            if (tree.is_row_expanded (path))
                                tree.collapse_row (path);
                            else if (path.up ())
                                tree.collapse_row (path);
                        }
                        return true;

                    default:
                        break;
                }
            }
            return base.on_view_key_press_event (event);
        }

        protected override Gtk.Widget? create_view () {
            model.set_property ("has-child", true);
            base.create_view ();
            tree.set_show_expanders (true);
            tree.set_headers_visible (true);
            tree.set_rubber_banding (true);
            append_extra_tree_columns ();
            connect_additional_signals ();

            return tree as Gtk.Widget;
        }

        protected override Marlin.ZoomLevel get_set_up_zoom_level () {
            var zoom = Preferences.marlin_list_view_settings.get_enum ("zoom-level");
            Preferences.marlin_list_view_settings.bind ("zoom-level", this, "zoom-level", GLib.SettingsBindFlags.SET);

            return (Marlin.ZoomLevel)zoom;
        }

        public override Marlin.ZoomLevel get_normal_zoom_level () {
            var zoom = Preferences.marlin_list_view_settings.get_enum ("default-zoom-level");
            Preferences.marlin_list_view_settings.set_enum ("zoom-level", zoom);

            return (Marlin.ZoomLevel)zoom;
        }

        protected override void add_subdirectory (GOF.Directory.Async dir) {
            connect_directory_handlers (dir);
            dir.load ();
            /* Maintain our own reference on dir, independent of the model */
            /* Also needed for updating show hidden status */
            loaded_subdirectories.prepend (dir);
        }

        protected override void remove_subdirectory (GOF.Directory.Async dir) {
            assert (dir != null);
            disconnect_directory_handlers (dir);
            /* Release our reference on dir */
            loaded_subdirectories.remove (dir);
        }

        protected override bool expand_collapse (Gtk.TreePath? path) {
            if (tree.is_row_expanded (path))
                tree.collapse_row (path);
            else
                tree.expand_row (path, false);

            return true;
        }

        protected override bool get_next_visible_iter (ref Gtk.TreeIter iter, bool recurse = true) {
            Gtk.TreePath? path = model.get_path (iter);
            Gtk.TreeIter start = iter;
 
            if (path == null)
                return false;
 
            if (recurse && tree.is_row_expanded (path)) {
                Gtk.TreeIter? child_iter = null;
                if (model.iter_children (out child_iter, iter)) {
                    iter = child_iter;
                    return true;
                }
            }
 
            if (model.iter_next (ref iter))
                return true;
            else {
                Gtk.TreeIter? parent = null;
                if (model.iter_parent (out parent, start)) {
                    iter = parent;
                    return get_next_visible_iter (ref iter, false);
                }
            }
            return false;
        }

        public override void cancel () {
            base.cancel ();
            cancel_file_timeout ();
        }
    }
}
