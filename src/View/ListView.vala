/***
    Copyright (c) 2015-2022 elementary LLC <https://elementary.io>

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
    public class ListView : AbstractTreeView {
        /* We wait two seconds after row is collapsed to unload the subdirectory */
        const int COLLAPSE_TO_UNLOAD_DELAY = 2;

        static string [] column_titles = {
            _("Filename"),
            _("Size"),
            _("Type"),
            _("Modified")
        };

        /* ListView manages the loading and unloading of subdirectories displayed */
        private uint unload_file_timeout_id = 0;
        private GLib.List<Gtk.TreeRowReference> subdirectories_to_unload = null;
        private GLib.List<Directory> loaded_subdirectories = null;

        public ListView (View.Slot _slot) {
            base (_slot);
        }

        construct {
            model.has_child = true;
            model.subdirectory_unloaded.connect (on_model_subdirectory_unloaded);

            tree.set_show_expanders (true);
            tree.set_headers_visible (true);
            tree.set_rubber_banding (true);
            tree.row_expanded.connect (on_row_expanded);
            tree.row_collapsed.connect (on_row_collapsed);

            /* Set up columns in addition to filename (set up by parent class) */
            int fnc = ColumnID.FILENAME;
            int preferred_column_width = Files.column_view_settings.get_int ("preferred-column-width");
            for (int k = fnc; k < ColumnID.NUM_COLUMNS; k++) {
                if (k == fnc) {
                    /* name_column already created by AbstractTreeVIew */
                    name_column.set_title (column_titles [0]);
                    name_column.min_width = preferred_column_width;
                } else {
                    var renderer = new Gtk.CellRendererText ();
                    var col = new Gtk.TreeViewColumn.with_attributes (column_titles [k - fnc],
                                                                        renderer,
                                                                        "text", k) {
                        sort_column_id = k,
                        resizable = false,
                        expand = false,
                        min_width = 24
                    };

                    if (k == ColumnID.SIZE || k == ColumnID.MODIFIED) {
                        renderer.@set ("xalign", 1.0f);
                    } else {
                        renderer.@set ("xalign", 0.0f);
                    }

                    tree.append_column (col);
                }
            }
        }

        private void on_row_expanded (Gtk.TreeIter iter, Gtk.TreePath path) {
            set_path_expanded (path, true);
            /* If a new subdirectory is loaded, connect it, load it
             * and add it to the list of subdirectories */
            Files.Directory? dir = null;
            if (model.get_subdirectory (path, out dir)) { // Returns true if dir non null
                connect_directory_handlers (dir);
                dir.init ();
                /* Maintain our own reference on dir, independent of the model */
                /* Also needed for updating show hidden status */
                loaded_subdirectories.prepend (dir);
            }
        }

        private void on_row_collapsed (Gtk.TreeIter iter, Gtk.TreePath path) {
            set_path_expanded (path, false);
            schedule_unload_subdirectory_at_path (path);
        }

        private void on_model_subdirectory_unloaded (Directory dir) {
            /* ensure the model and our list of subdirectories are kept in sync */
            if (dir != null) {
                disconnect_directory_handlers (dir);
                /* Release our reference on dir */
                loaded_subdirectories.remove (dir);
            } else {
                warning ("List View: directory null in remove_subdirectory");
            }
        }

        private void schedule_unload_subdirectory_at_path (Gtk.TreePath path) {
                /* unload subdirectory from model and remove from our list of subdirectories
                 * after a delay, in case of rapid collapsing and re-expanding of rows */
                subdirectories_to_unload.append (new Gtk.TreeRowReference (model, path));
                schedule_model_unload_directories ();
        }

        private void set_path_expanded (Gtk.TreePath path, bool expanded) {
            Files.File? file = model.file_for_path (path);

            if (file != null) {
                file.set_expanded (expanded);
            }
        }

        private void schedule_model_unload_directories () {
            cancel_file_timeout ();
            unload_file_timeout_id = GLib.Timeout.add_seconds (COLLAPSE_TO_UNLOAD_DELAY,
                                                               unload_directories);
        }

        private bool unload_directories () {
            foreach (unowned Gtk.TreeRowReference rowref in subdirectories_to_unload) {
                Gtk.TreeIter? iter = null;
                Gtk.TreePath path;
                if (rowref.valid ()) {
                    path = rowref.get_path ();
                } else {
                    warning ("TreeRowRef invalid when unloading subdirectory");
                    continue;
                }

                if (((Gtk.TreeView)tree).is_row_expanded (path)) {
                    continue;
                }

                if (model.get_iter (out iter, path) && iter != null) {
                        model.unload_subdirectory (iter);
                } else {
                    warning ("Subdirectory to unload not found in model");
                }
            }

            subdirectories_to_unload.@foreach ((rowref) => {
                subdirectories_to_unload.remove (rowref);
            });

            unload_file_timeout_id = 0;
            return false;
        }

        private void cancel_file_timeout () {
            if (unload_file_timeout_id > 0) {
                GLib.Source.remove (unload_file_timeout_id);
                unload_file_timeout_id = 0;
            }
        }

        //TODO Use EventControllers
        // protected override bool on_view_key_press_event (Gdk.EventKey event) {
        //     Gdk.ModifierType state;
        //     event.get_state (out state);
        //     bool control_pressed = ((state & Gdk.ModifierType.CONTROL_MASK) != 0);
        //     bool shift_pressed = ((state & Gdk.ModifierType.SHIFT_MASK) != 0);

        //     if (!control_pressed && !shift_pressed) {
        //         uint keyval;
        //         event.get_keyval (out keyval);
        //         switch (keyval) {
        //             case Gdk.Key.Right:
        //                 Gtk.TreePath? path = null;
        //                 tree.get_cursor (out path, null);

        //                 if (path != null) {
        //                     tree.expand_row (path, false);
        //                 }

        //                 return true;

        //             case Gdk.Key.Left:
        //                 Gtk.TreePath? path = null;
        //                 tree.get_cursor (out path, null);

        //                 if (path != null) {
        //                     if (tree.is_row_expanded (path)) {
        //                         tree.collapse_row (path);
        //                     } else if (path.up ()) {
        //                         tree.collapse_row (path);
        //                     }
        //                 }

        //                 return true;

        //             default:
        //                 break;
        //         }
        //     }

        //     return base.on_view_key_press_event (event);
        // }

        // protected override Gtk.Widget? create_view () {
        //     model.has_child = true;
        //     tree.set_show_expanders (true);
        //     tree.set_headers_visible (true);
        //     tree.set_rubber_banding (true);
        //     append_extra_tree_columns ();


        // }

        protected override void set_up_zoom_level () {
            Files.list_view_settings.bind (
                "zoom-level",
                this, "zoom-level",
                GLib.SettingsBindFlags.DEFAULT
            );

            maximum_zoom = (ZoomLevel)Files.list_view_settings.get_enum ("maximum-zoom-level");

            if (zoom_level < minimum_zoom) { /* Defaults to ZoomLevel.SMALLEST */
                zoom_level = minimum_zoom;
            }

            if (zoom_level > maximum_zoom) {
                zoom_level = maximum_zoom;
            }
        }

        public override ZoomLevel get_normal_zoom_level () {
            var zoom = Files.list_view_settings.get_enum ("default-zoom-level");
            Files.list_view_settings.set_enum ("zoom-level", zoom);

            return (ZoomLevel)zoom;
        }

        protected bool expand_collapse (Files.File dir) {
            //TODO get path
            // if (tree.is_row_expanded (path)) {
            //     tree.collapse_row (path);
            // } else {
            //     tree.expand_row (path, false);
            // }

            return true;
        }

        // protected override bool get_next_visible_iter (ref Gtk.TreeIter iter, bool recurse = true) {
        //     Gtk.TreePath? path = model.get_path (iter);
        //     Gtk.TreeIter start = iter;

        //     if (path == null) {
        //         return false;
        //     }

        //     if (recurse && tree.is_row_expanded (path)) {
        //         Gtk.TreeIter? child_iter = null;
        //         if (model.iter_children (out child_iter, iter)) {
        //             iter = child_iter;
        //             return true;
        //         }
        //     }

        //     if (model.iter_next (ref iter)) {
        //         return true;
        //     } else {
        //         Gtk.TreeIter? parent = null;
        //         if (model.iter_parent (out parent, start)) {
        //             iter = parent;
        //             return get_next_visible_iter (ref iter, false);
        //         }
        //     }
        //     return false;
        // }

        public override void cancel () {
            cancel_file_timeout ();
            base.cancel ();
            loaded_subdirectories.@foreach ((dir) => {
                on_model_subdirectory_unloaded (dir);
            });
        }
    }
}
