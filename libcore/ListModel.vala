/* Copyright 2021 elementary, Inc. (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

public class Files.ListModel : Gtk.TreeStore, Gtk.TreeModel {
    public enum ColumnID {
        FILE_COLUMN,
        COLOR,
        PIXBUF,
        FILENAME,
        SIZE,
        TYPE,
        MODIFIED,
        NUM_COLUMNS;

        public static ColumnID from_string (string column_id) {
            switch (column_id) {
                case "name":
                    return ColumnID.FILENAME;
                case "size":
                    return ColumnID.SIZE;
                case "type":
                    return ColumnID.TYPE;
                case "modified":
                    return ColumnID.MODIFIED;
                default:
                    return (ColumnID) (-1);
            }
        }

        public unowned string to_string () {
            switch (this) {
                case ColumnID.FILENAME:
                    return "name";
                case ColumnID.SIZE:
                    return "size";
                case ColumnID.TYPE:
                    return "type";
                case ColumnID.MODIFIED:
                    return "modified";
                default:
                    critical ("COLUMN id %u unsupported", this);
                    return "";
            }
        }
    }

    private enum PrivColumnID {
        DUMMY = ColumnID.NUM_COLUMNS
    }

    public signal void subdirectory_unloaded (Files.Directory directory);

    public int icon_size { get; set; default = 32; }
    public bool has_child { get; set; default = false; }
    private bool _show_hidden_files = false;
    public bool show_hidden_files {
        get {
            return _show_hidden_files;
        }

        set {
            _show_hidden_files = value;
            _displayed_files_count = -1;
        }
    }

    private int _displayed_files_count = -1;
    public uint displayed_files_count {
        get {
            if (_displayed_files_count < 0) {
                _displayed_files_count = iter_n_children (null);
            }

            return _displayed_files_count; // Only root files
        }
    }

    private bool sort_directories_first = true;

    construct {
        set_column_types ({
            typeof (Files.File),
            typeof (string),
            typeof (Gdk.Pixbuf),
            typeof (string),
            typeof (string),
            typeof (string),
            typeof (string),
            typeof (bool)
        });

        //We do not want a default sort order - one of the visible columns must always be sorted
        for (int i = 0; i < ColumnID.NUM_COLUMNS; i++) {
            set_sort_func (i, (Gtk.TreeIterCompareFunc) file_entry_compare_func);
        }
    }

    public Files.File? file_for_path (Gtk.TreePath path) {
        Files.File? file = null;
        Gtk.TreeIter? iter;
        if (get_iter (out iter, path)) {
            get (iter, ColumnID.FILE_COLUMN, ref file);
        }

        return file;
    }

    public Files.File? file_for_iter (Gtk.TreeIter iter) {
        Files.File? file = null;
        get (iter, ColumnID.FILE_COLUMN, ref file);
        return file;
    }

    public uint get_length () {
        return iter_n_children (null);
    }

    public bool get_first_iter_for_file (Files.File file, out Gtk.TreeIter? iter) {
        Gtk.TreeIter? tmp_iter = null;
        this.foreach ((model, path, i_iter) => {
            Files.File? iter_file = null;
            get (i_iter, ColumnID.FILE_COLUMN, ref iter_file);
            if (iter_file == file) {
                tmp_iter = i_iter;
                return true;
            }

            return false;
        });

        iter = tmp_iter;
        return tmp_iter != null;
    }

    public void get_value (Gtk.TreeIter iter, int column, out Value value) {
        Value file_value;
        base.get_value (iter, ColumnID.FILE_COLUMN, out file_value);
        unowned Files.File? file = (Files.File) file_value.get_object ();

        switch (column) {
            case ColumnID.FILE_COLUMN:
                value = Value (typeof (Files.File));
                value.set_object (file);
                break;
            case ColumnID.COLOR:
                value = Value (typeof (string));
                if (file != null && file.color < Files.Preferences.TAGS_COLORS.length) {
                    value.set_string (Files.Preferences.TAGS_COLORS[file.color]);
                } else {
                    value.set_string (Files.Preferences.TAGS_COLORS[0]);
                }

                break;
            case ColumnID.PIXBUF:
                value = Value (typeof (Gdk.Pixbuf));
                if (file != null) {
                    file.update_icon (icon_size, file.pix_scale);
                    if (file.pix != null) {
                        value.set_object (file.pix);
                    }
                }

                break;
            case ColumnID.FILENAME:
                value = Value (typeof (string));
                if (file != null) {
                    value.set_string (file.get_display_name ());
                } else {
                    value.set_static_string ("");
                }

                break;
            case ColumnID.SIZE:
                value = Value (typeof (string));
                if (file != null) {
                    value.set_string (file.format_size);
                } else {
                    value.set_static_string ("");
                }

                break;
            case ColumnID.TYPE:
                value = Value (typeof (string));
                if (file != null) {
                    value.set_string (file.formated_type);
                } else {
                    value.set_static_string ("");
                }

                break;
            case ColumnID.MODIFIED:
                value = Value (typeof (string));
                if (file != null) {
                    value.set_string (file.formated_modified);
                } else {
                    value.set_static_string ("");
                }

                break;
            case PrivColumnID.DUMMY:
                value = Value (typeof (bool));
                value.set_boolean (file == null);
                break;
            default:
                value = Value (GLib.Type.INVALID);
                break;
        }
    }

    public void file_changed (Files.File file, Files.Directory dir) {
        bool found = false;
        this.foreach ((model, path, iter) => {
            Files.File? iter_file = null;
            get (iter, ColumnID.FILE_COLUMN, ref iter_file);
            if (iter_file == file) {
                model.row_changed (path, iter);
                found = true;
                return true;
            }

            return false;
        });
    }

    public void set_should_sort_directories_first (bool sort_directories_first) {
        if (this.sort_directories_first == sort_directories_first) {
            return;
        }

        this.sort_directories_first = sort_directories_first;
        int sort_column_id;
        Gtk.SortType order;
        if (!get_sort_column_id (out sort_column_id, out order)) {
            sort_column_id = ColumnID.FILENAME;
            order = Gtk.SortType.ASCENDING;
        }

        set_sort_column_id (Gtk.TREE_SORTABLE_UNSORTED_SORT_COLUMN_ID, order);
        set_sort_column_id (sort_column_id, order);
    }

    public bool get_subdirectory (Gtk.TreePath path, out Files.Directory? dir) {
        dir = null;
        Files.File? file = null;
        Gtk.TreeIter? iter;
        if (get_iter (out iter, path)) {
            get (iter, ColumnID.FILE_COLUMN, out file);
            if (file != null) {
                dir = Files.Directory.from_file (file);
            }
        }

        return dir != null;
    }

    public void load_subdirectory (Directory dir) {
        Gtk.TreeIter? parent_iter = null, child_iter = null;
        bool change_dummy = true; // Default to unloaded
        if (get_first_iter_for_file (dir.file, out parent_iter)) {
            var files = dir.get_files ();
            if (iter_nth_child (out child_iter, parent_iter, 0)) { // Must always be at least one child
                get (child_iter, PrivColumnID.DUMMY, out change_dummy);
            } else {
                critical ("folder item with no child"); // The parent file must be a folder and have at lease a dummy entry
            }

            // May not be unloaded yet.
            // If not, assumed not changed in the short time hidden and use existing children
            if (!change_dummy) {
                return;
            }

            foreach (var file in files) {
                if (!show_hidden_files && file.is_hidden) {
                    continue;
                }

                if (change_dummy) {
                    // Instead of inserting a new row, change the dummy one
                    @set (child_iter, ColumnID.FILE_COLUMN, file, PrivColumnID.DUMMY, false, -1);
                    change_dummy = false;
                } else {
                    insert (out child_iter, parent_iter, -1);
                    @set (child_iter, ColumnID.FILE_COLUMN, file, PrivColumnID.DUMMY, false, -1);
                }

                if (file.is_folder ()) {
                    // Append a dummy child so expander will show even when folder is empty.
                    insert_with_values (out child_iter, child_iter, -1, PrivColumnID.DUMMY, true);
                }
            }
        }
    }

    public bool unload_subdirectory (Gtk.TreeIter parent_iter) {
        Files.File? file = null;
        get (parent_iter, ColumnID.FILE_COLUMN, out file);
        if (file != null) {
            var dir = Files.Directory.from_file (file);
            dir.cancel ();
            Gtk.TreeIter? child_iter = null;
            // Remove all child nodes so they are refreshed if subdirectory reloaded
            // Faster than checking for duplicates
            if (iter_children (out child_iter, parent_iter)) {
                while (remove (ref child_iter)) {};
            }

            // Insert dummy;
            insert_with_values (out child_iter, parent_iter, -1, PrivColumnID.DUMMY, true);
            subdirectory_unloaded (dir);
            return true;
        }

        return false;
    }

    public void load_root_directory (Files.Directory dir) {
        // To optimise performance we prepend to an empty unsorted model.
        // The model sorting is set afterwards by the UX.
        var now = get_monotonic_time ();
        set_sort_column_id (Gtk.TREE_SORTABLE_UNSORTED_SORT_COLUMN_ID, 0);
        clear ();
        _displayed_files_count = -1;

        foreach (var file in dir.get_files ()) {
            if (show_hidden_files || !file.is_hidden) {
                Gtk.TreeIter? iter = null, dummy_iter = null;
                prepend (out iter, null);
                @set (iter, ColumnID.FILE_COLUMN, file, PrivColumnID.DUMMY, false, -1);
                if (file.is_folder ()) {
                    // Append a dummy child so expander will show even when folder is empty.
                    insert_with_values (out dummy_iter, iter, -1, PrivColumnID.DUMMY, true);
                }
            }
        }

        debug ("FINISHED ADDING TO MODEL - time %f", (double)(get_monotonic_time () - now) / (double)1000000);
    }

    /* Normally the supplied files will already be deduplicated by associated Files.Directory */
    public void add_files (List<unowned Files.File> files_to_add, Files.Directory dir, bool deduplicate = false) {
        var now = get_monotonic_time ();
        int col_id = Gtk.TREE_SORTABLE_UNSORTED_SORT_COLUMN_ID;
        Gtk.SortType sort_type = 0;

        get_sort_column_id (out col_id, out sort_type);
        set_sort_column_id (Gtk.TREE_SORTABLE_UNSORTED_SORT_COLUMN_ID, 0);

        foreach (var file in files_to_add) {
            if (show_hidden_files || !file.is_hidden) {
                Gtk.TreeIter? iter = null, dummy_iter = null;
                if (deduplicate && get_first_iter_for_file (file, out iter)) {
                    continue; // The file is already in the model - ignore the request to add
                }

                prepend (out iter, null);
                @set (iter, ColumnID.FILE_COLUMN, file, PrivColumnID.DUMMY, false, -1);
                if (file.is_folder ()) {
                    // Append a dummy child so expander will show even when folder is empty.
                    insert_with_values (out dummy_iter, iter, -1, PrivColumnID.DUMMY, true);
                }
            }
        }

        files_to_add = null;
        warning ("FINISHED ADDING TO MODEL - time %f", (double)(get_monotonic_time () - now) / (double)1000000);
        set_sort_column_id (col_id, sort_type);
    }

    /* Returns true if the file was not in the model and was added */
    // Slow for large numbers of additions as the model is resorted on each addition.
    // Should only be used for addition of small numbers of files
    // Otherwise may be quicker to rebuild the whole model.

    // Not currently used - files are added as a collection by `add_files ()`
    private bool add_file_if_not_duplicate (Files.File file, Files.Directory dir) {
        _displayed_files_count = -1;

        Gtk.TreeIter? parent_iter = null, file_iter = null;
        if (get_first_iter_for_file (file, out file_iter)) {
            return false; // The file is already in the model - ignore the request to add
        }

        bool change_dummy = false;
        if (get_first_iter_for_file (dir.file, out parent_iter)) {
            if (iter_nth_child (out file_iter, parent_iter, 0)) { // Must always be at least one child
                get (file_iter, PrivColumnID.DUMMY, out change_dummy);
                if (change_dummy) {
                    // Instead of inserting a new row, change the dummy one
                    @set (file_iter, ColumnID.FILE_COLUMN, file, PrivColumnID.DUMMY, false, -1);
                }
            } else {
                critical ("folder item with no child"); // The parent file must be a folder and have at lease a dummy entry
            }
        } else {
            parent_iter = null; // Adding to model root
        }

        if (!change_dummy) {
            // There was no dummy row to replace so create a new entry for this file
            insert_with_values (out file_iter, parent_iter, 0, ColumnID.FILE_COLUMN, file, PrivColumnID.DUMMY, false);
        }

        if (file.is_folder ()) {
            // Append a dummy child so expander will show even when folder is empty.
            insert_with_values (out file_iter, file_iter, -1, PrivColumnID.DUMMY, true);
        }

        return true;
    }

    /* Returns true if the file was found and removed */
    // Slow for large numbers of removals as the model is resorted on each removal.
    // Should only be used for removal of small numbers of files
    // Otherwise may be quicker to rebuild the whole model.
    //TODO Add a method to remove a (large) array of files efficiently
    public bool remove_file (Files.File file, Files.Directory dir) {
        _displayed_files_count = -1;
        // Assumed that file is actually a child of dir
        Gtk.TreeIter? parent_iter, child_iter, file_iter, dummy_iter;
        if (!get_first_iter_for_file (file, out file_iter)) {
            return false;
        }

        if (file_iter != null) {
            if (get_first_iter_for_file (dir.file, out parent_iter)) {
                if (!iter_nth_child (out child_iter, parent_iter, 1)) {
                    // This is the last child so add a dummy;
                    insert_with_values (out dummy_iter, parent_iter, -1, PrivColumnID.DUMMY, true);
                }
            }

            remove (ref file_iter);
            return true;
        }

        return false;
    }

    private int file_entry_compare_func (Gtk.TreeIter a, Gtk.TreeIter b) {
        Files.File? file_a = null;
        Files.File? file_b = null;
        get (a, ColumnID.FILE_COLUMN, out file_a);
        get (b, ColumnID.FILE_COLUMN, out file_b);

        if (file_a != null && file_b != null &&
            file_a.location != null && file_b.location != null) {
            int sort_column_id;
            Gtk.SortType order;
            if (!get_sort_column_id (out sort_column_id, out order)) {
                sort_column_id = ColumnID.FILENAME;
                order = Gtk.SortType.ASCENDING;
            }

            return file_a.compare_for_sort (file_b, sort_column_id, sort_directories_first, order == Gtk.SortType.DESCENDING);
        } else if (file_a == null || file_a.location == null) {
            return -1;
        } else {
            return 1;
        }
    }
}
