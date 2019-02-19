/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

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
    public class ListView : AbstractTreeView {
        /* We wait two seconds after row is collapsed to unload the subdirectory */
        const int COLLAPSE_TO_UNLOAD_DELAY = 2;

        /* ListView manages the loading and unloading of subdirectories displayed */
        private uint unload_file_timeout_id = 0;
        private GLib.List<Gtk.TreeRowReference> subdirectories_to_unload = null;
        private GLib.List<GOF.Directory.Async> loaded_subdirectories = null;

        construct {
            model.sort_order_changed.connect ((new_, reversed, old_) => {
                foreach (Gtk.TreeViewColumn col in tree.get_columns ()) {
                    FM.ColumnID id = col.get_data ("id");
                    if (id == old_) {
                        col.sort_indicator = false;
                    }

                    if (id == new_) {
                        col.sort_indicator = true;
                        col.sort_order = reversed ? Gtk.SortType.DESCENDING : Gtk.SortType.ASCENDING;
                    }
                }
            });
        }

        public ListView (Marlin.View.Slot _slot) {
            base (_slot);
        }

        private void connect_additional_signals () {
            tree.row_expanded.connect (on_row_expanded);
            tree.row_collapsed.connect (on_row_collapsed);
            tree.model.row_inserted.connect ((path,iter) => {
            });
            model.subdirectory_unloaded.connect (on_model_subdirectory_unloaded);

            slot.notify["directory"].connect (() => {
                model.root_dir = slot.directory;
            });
        }

        private void append_extra_tree_columns () {
            int preferred_column_width = Preferences.marlin_column_view_settings.get_int ("preferred-column-width");
            name_column.title = _("Filename");
            name_column.min_width = preferred_column_width;
            name_column.clickable = true;
            name_column.expand = true;
            name_column.clicked.connect (on_column_clicked);
            name_column.sort_indicator = true;
            name_column.set_data ("id", FM.ColumnID.FILENAME);

            make_extra_column (FM.ColumnID.SIZE, _("Size"));
            make_extra_column (FM.ColumnID.TYPE, _("Type"));
            make_extra_column (FM.ColumnID.MODIFIED, ("_Modified"));
        }

        private void make_extra_column (FM.ColumnID id, string title) {
            var renderer = new Gtk.CellRendererText ();
            var col = new Gtk.TreeViewColumn ();
            col.pack_end (renderer, true);
            col.title = title;
            col.set_data ("id", id);
            col.set_cell_data_func (renderer,
                                    (layout, renderer, model, iter) => {
                                        set_file_data (renderer, model, iter, id);
                                    });

            col.clickable = true;
            col.clicked.connect (on_column_clicked);
            col.sort_indicator = false;
            col.set_resizable (false);
            col.set_expand (false);
            col.min_width = 24;

            if (id == FM.ColumnID.SIZE || id == FM.ColumnID.MODIFIED) {
                renderer.xalign = 1.0f;
            } else {
                renderer.xalign = 0.0f;
            }

            tree.append_column (col);
        }

        private void on_column_clicked (Gtk.TreeViewColumn col) {
            FM.ColumnID col_id = col.get_data ("id");;
            model.set_order (col_id);
        }

        private void set_file_data (Gtk.CellRenderer cell, Gtk.TreeModel model, Gtk.TreeIter iter, FM.ColumnID col_id) {
            string text = "??????";
            GOF.File? file = null;
            model.@get(iter, FM.ColumnID.FILE_COLUMN, out file);
            if (file != null) {
                switch (col_id) {
                    case FM.ColumnID.SIZE:
                        text = file.format_size;
                        break;
                    case FM.ColumnID.TYPE:
                        text = file.formated_type;
                        break;
                    case FM.ColumnID.MODIFIED:
                        text = file.formated_modified;
                        break;
                    default:
                        break;
                }
            }

            ((Gtk.CellRendererText)(cell)).text = text;
        }

        private void on_row_expanded (Gtk.TreeIter iter, Gtk.TreePath path) {
            add_subdirectory_at_path (path);
            set_path_expanded (path, true);
        }

        private void on_row_collapsed (Gtk.TreeIter iter, Gtk.TreePath path) {
            set_path_expanded (path, false);
            schedule_unload_subdirectory_at_path (path);
        }

        private void on_model_subdirectory_unloaded (GOF.Directory.Async dir) {
            /* ensure the model and our list of subdirectories are kept in sync */
            remove_subdirectory (dir);
        }

        private void schedule_unload_subdirectory_at_path (Gtk.TreePath path) {
                /* unload subdirectory from model and remove from our list of subdirectories
                 * after a delay, in case of rapid collapsing and re-expanding of rows */
                subdirectories_to_unload.append (new Gtk.TreeRowReference (model, path));
                schedule_model_unload_directories ();
        }

        private void set_path_expanded (Gtk.TreePath path, bool expanded) {
            GOF.File? file = model.file_for_path (path);

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
                if (!tree.is_row_expanded (rowref.get_path ())) {
                    model.unload_subdirectory (rowref);
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

        protected override bool on_view_key_press_event (Gdk.EventKey event) {
            bool control_pressed = ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0);
            bool shift_pressed = ((event.state & Gdk.ModifierType.SHIFT_MASK) != 0);

            if (!control_pressed && !shift_pressed) {
                switch (event.keyval) {
                    case Gdk.Key.Right:
                        Gtk.TreePath? path = null;
                        tree.get_cursor (out path, null);

                        if (path != null) {
                            tree.expand_row (path, false);
                        }

                        return true;

                    case Gdk.Key.Left:
                        Gtk.TreePath? path = null;
                        tree.get_cursor (out path, null);

                        if (path != null) {
                            if (tree.is_row_expanded (path)) {
                                tree.collapse_row (path);
                            } else if (path.up ()) {
                                tree.collapse_row (path);
                            }
                        }

                        return true;

                    default:
                        break;
                }
            }

            return base.on_view_key_press_event (event);
        }

        protected override Gtk.Widget? create_and_add_view () {
            model.set_property ("has-child", true);
            model.root_dir = slot.directory;
            base.create_and_add_view ();
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

            minimum_zoom = (Marlin.ZoomLevel)Preferences.marlin_list_view_settings.get_enum ("minimum-zoom-level");
            maximum_zoom = (Marlin.ZoomLevel)Preferences.marlin_list_view_settings.get_enum ("maximum-zoom-level");

            if (zoom_level < minimum_zoom) {
                zoom_level = minimum_zoom;
            }

            if (zoom_level > maximum_zoom) {
                zoom_level = maximum_zoom;
            }

            return (Marlin.ZoomLevel)zoom;
        }

        public override Marlin.ZoomLevel get_normal_zoom_level () {
            var zoom = Preferences.marlin_list_view_settings.get_enum ("default-zoom-level");
            Preferences.marlin_list_view_settings.set_enum ("zoom-level", zoom);

            return (Marlin.ZoomLevel)zoom;
        }

        private void add_subdirectory_at_path (Gtk.TreePath path) {
            /* If a new subdirectory is to be loaded, connect it, load it
             * and add it to the list of subdirectories */
            GOF.File file = model.file_for_path (path);
            assert (file.is_directory);
            var dir = GOF.Directory.Async.from_file (file);

            if (loaded_subdirectories.find (dir) != null) {
                return;
            }

            connect_directory_handlers (dir);
            Idle.add (() => {dir.init (); return Source.REMOVE;});
            /* Maintain our own reference on dir, independent of the model */
            /* Also needed for updating show hidden status */
            loaded_subdirectories.prepend (dir);
        }

        private void remove_subdirectory (GOF.Directory.Async? dir) {
            if (dir != null) {
                disconnect_directory_handlers (dir);
                /* Release our reference on dir */
                loaded_subdirectories.remove (dir);
            } else {
                warning ("List View: directory null in remove_subdirectory");
            }
        }

        protected override bool expand_collapse (Gtk.TreePath? path) {
            if (tree.is_row_expanded (path)) {
                tree.collapse_row (path);
            } else {
                tree.expand_row (path, false);
            }

            return true;
        }

        protected override bool get_next_visible_iter (ref Gtk.TreeIter iter, bool recurse = true) {
            Gtk.TreePath? path = model.get_path (iter);
            Gtk.TreeIter start = iter;

            if (path == null) {
                return false;
            }

            if (recurse && tree.is_row_expanded (path)) {
                Gtk.TreeIter? child_iter = null;
                if (model.iter_children (out child_iter, iter)) {
                    iter = child_iter;
                    return true;
                }
            }

            if (model.iter_next (ref iter)) {
                return true;
            } else {
                Gtk.TreeIter? parent = null;
                if (model.iter_parent (out parent, start)) {
                    iter = parent;
                    return get_next_visible_iter (ref iter, false);
                }
            }
            return false;
        }

        public override void cancel () {
            cancel_file_timeout ();
            base.cancel ();
            loaded_subdirectories.@foreach ((dir) => {
                remove_subdirectory (dir);
            });
        }


    }
}
