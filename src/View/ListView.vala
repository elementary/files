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
//message ("New list view");
            base (_slot);
            slot.directory.load ();
        }

        private void connect_additional_signals () {
//message ("LV connect tree_signals");
            tree.row_expanded.connect (on_row_expanded);
            tree.row_collapsed.connect (on_row_collapsed);
            model.sort_column_changed.connect (on_sort_column_changed);
        }

        private void append_extra_tree_columns () {
//message ("add additional tree columns");
            int fnc = FM.ListModel.ColumnID.FILENAME;
            for (int k = fnc; k < FM.ListModel.ColumnID.NUM_COLUMNS; k++) {
                if (k == fnc) {
                    /* name_column already created by AbstractTreeVIew */
                    name_column.set_title (column_titles [0]);
                } else {
                    var renderer = new Gtk.CellRendererText ();
                    var col = new Gtk.TreeViewColumn.with_attributes (column_titles [k - fnc],
                                                                      renderer,
                                                                      "text", k,
                                                                      "background", FM.ListModel.ColumnID.COLOR);
                    col.set_sort_column_id (k);
                    col.set_resizable (true);
                    //col.set_cell_data_func (renderer, color_row_func);
                    tree.append_column (col);
                }
            }
        }

        private void color_row_func (Gtk.CellLayout column,
                                     Gtk.CellRenderer renderer,
                                     Gtk.TreeModel model,
                                     Gtk.TreeIter iter) {

        }

        private void on_row_expanded (Gtk.TreeIter iter, Gtk.TreePath path) {
//message ("on row expanded");
            GOF.Directory.Async dir;
            if (model.load_subdirectory (path, out dir) && dir is GOF.Directory.Async) {
                add_subdirectory (dir);
            }
        }

        private void on_row_collapsed (Gtk.TreeIter iter, Gtk.TreePath path) {
//message ("on row collapsed");
            unowned GOF.Directory.Async dir;
            unowned GOF.File file;
            if (model.get_directory_file (path, out dir, out file)) {
                schedule_model_unload_directory (file, dir);
                remove_subdirectory (dir);
            } else {
                critical ("failed to get directory/file");
            }

        }

        private void schedule_model_unload_directory (GOF.File file, GOF.Directory.Async directory) {
            unload_file_timeout_id = GLib.Timeout.add_seconds (COLLAPSE_TO_UNLOAD_DELAY, () => {
                Gtk.TreeIter iter;
                Gtk.TreePath path;
                /* FIXME model.get_tree_iter_from_file does not work for some reason */
                if (model.get_first_iter_for_file (file, out iter)) {
                    path = ((Gtk.TreeModel)model).get_path (iter);
                    if (path != null && !((Gtk.TreeView)tree).is_row_expanded (path)) {
                        model.unload_subdirectory (iter);
                    }
                } else {
                    critical ("Failed to get iter");
                }

                unload_file_timeout_id = 0;
                return false;
            });
        }

        private void on_sort_column_changed () {
//message ("on_sort_column_changed");
            int sort_column_id;
            Gtk.SortType sort_order;
            if (!model.get_sort_column_id (out sort_column_id, out sort_order))
                return;

            var info = new GLib.FileInfo ();
            info.set_attribute_string ("metadata::marlin-sort-column-id",
                                       get_string_from_column_id (sort_column_id));
            info.set_attribute_string ("metadata::marlin-sort-reversed",
                                       (sort_order == Gtk.SortType.DESCENDING ? "true" : "false"));

            var dir = slot.directory;
            dir.file.sort_column_id = sort_column_id;
            dir.file.sort_order = sort_order;

            dir.location.set_attributes_async.begin (info,
                                               GLib.FileQueryInfoFlags.NONE,
                                               GLib.Priority.DEFAULT,
                                               null,
                                               (obj, res) => {
                try {
                    GLib.FileInfo inf;
                    dir.location.set_attributes_async.end (res, out inf); 
                } catch (GLib.Error e) {
                    warning ("Could not set file attributes - %s", e.message);
                }
            });

        }

        private string get_string_from_column_id (int id) {
            switch (id) {
            case FM.ListModel.ColumnID.FILENAME:
                return "name";
            case FM.ListModel.ColumnID.SIZE:
                return "size";
            case FM.ListModel.ColumnID.TYPE:
                return "type";
            case FM.ListModel.ColumnID.MODIFIED:
                return "modified";
            default:
                warning ("column id not recognised - using 'name'");
                return "name";
            }
        }

/** Override parents abstract and virtual methods as required*/
        protected override Gtk.Widget? create_view () {
//message ("LV create view");
            model.set_property ("has-child", true);
            base.create_view ();
            tree.set_show_expanders (true);
            tree.set_headers_visible (true);
            append_extra_tree_columns ();
            connect_additional_signals ();
            return tree as Gtk.Widget;
        }

        protected override Marlin.ZoomLevel get_set_up_zoom_level () {
//message ("LV setup zoom_level");
            Preferences.marlin_list_view_settings.bind ("zoom-level", this, "zoom-level", GLib.SettingsBindFlags.SET);
            return (Marlin.ZoomLevel)(Preferences.marlin_list_view_settings.get_enum ("zoom-level"));
        }

        public override Marlin.ZoomLevel get_normal_zoom_level () {
            var zoom = Preferences.marlin_list_view_settings.get_enum ("default-zoom-level");
            Preferences.marlin_list_view_settings.set_enum ("zoom-level", zoom);
            return (Marlin.ZoomLevel)zoom;
        }

        protected override void add_subdirectory (GOF.Directory.Async dir) {
//message ("add subdirectory");
            connect_directory_handlers (dir);
            dir.load ();
            /* Maintain our own reference on dir, independent of the model */
            /* Also needed for updating show hidden status */
            loaded_subdirectories.prepend (dir);
        }

        protected override void remove_subdirectory (GOF.Directory.Async dir) {
//message ("remove subdirectory");
            assert (dir != null);
            disconnect_directory_handlers (dir);
            /* Release our reference on dir */
            loaded_subdirectories.remove (dir);
        }
    }
}
