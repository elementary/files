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

public class FM.ListModel : Gtk.TreeStore, Gtk.TreeModel {
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

    public signal void subdirectory_unloaded (GOF.Directory.Async directory);

    public int icon_size { get; set; default = 32; }
    public bool has_child { get; set; default = false; }

    private bool sort_directories_first = true;

    construct {
        set_column_types ({
            typeof(GOF.File),
            typeof(string),
            typeof(Gdk.Pixbuf),
            typeof(string),
            typeof(string),
            typeof(string),
            typeof(string),
            typeof(bool)
        });

        set_default_sort_func ((Gtk.TreeIterCompareFunc) file_entry_compare_func);
        for (int i = 0; i < ColumnID.NUM_COLUMNS; i++) {
            set_sort_func (i, (Gtk.TreeIterCompareFunc) file_entry_compare_func);
        }

        set_sort_column_id (
            ColumnID.FILENAME,
            Gtk.SortType.ASCENDING
        );
    }

    public GOF.File? file_for_path (Gtk.TreePath path) {
        GOF.File? file = null;
        Gtk.TreeIter? iter;
        if (get_iter (out iter, path)) {
            get (iter, ColumnID.FILE_COLUMN, ref file);
        }

        return file;
    }

    public GOF.File? file_for_iter (Gtk.TreeIter iter) {
        GOF.File? file = null;
        get (iter, ColumnID.FILE_COLUMN, ref file);
        return file;
    }

    public uint get_length () {
        return iter_n_children (null);
    }

    public bool get_first_iter_for_file (GOF.File file, out Gtk.TreeIter? iter) {
        Gtk.TreeIter? tmp_iter = null;
        this.foreach ((model, path, i_iter) => {
            GOF.File? iter_file = null;
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
        unowned GOF.File? file = (GOF.File) file_value.get_object ();

        switch (column) {
            case ColumnID.FILE_COLUMN:
                value = Value (typeof (GOF.File));
                value.set_object (file);
                break;
            case ColumnID.COLOR:
                value = Value (typeof (string));
                if (file != null && file.color < GOF.Preferences.TAGS_COLORS.length) {
                    value.set_string (GOF.Preferences.TAGS_COLORS[file.color]);
                } else {
                    value.set_string (GOF.Preferences.TAGS_COLORS[0]);
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

    public void file_changed (GOF.File file, GOF.Directory.Async dir) {
        bool found = false;
        this.foreach ((model, path, iter) => {
            GOF.File? iter_file = null;
            get (iter, ColumnID.FILE_COLUMN, ref iter_file);
            if (iter_file == file) {
                model.row_changed (path, iter);
                found = true;
                return true;
            }

            return false;
        });

        if (!found) {
            add_file (file, dir);
        }
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

    public bool load_subdirectory (Gtk.TreePath path, out GOF.Directory.Async? dir) {
        GOF.File? file = null;
        Gtk.TreeIter? iter;
        if (get_iter (out iter, path)) {
            get (iter, ColumnID.FILE_COLUMN, out file);
            if (file != null) {
                dir = GOF.Directory.Async.from_file (file);
            } else {
                dir = null;
            }
        } else {
            dir = null;
        }

        warning ("load_subdirectory");
        return false;
    }
    public bool unload_subdirectory (Gtk.TreeIter iter) {
        warning ("unload_subdirectory");
        GOF.File? file = null;
        get (iter, ColumnID.FILE_COLUMN, out file);
        if (file != null) {
            var dir = GOF.Directory.Async.from_file (file);
            dir.cancel ();

            subdirectory_unloaded (dir);
            return true;
        }

        return false;
    }

    public bool add_file (GOF.File file, GOF.Directory.Async dir) {
        Gtk.TreeIter? iter;
        if (get_first_iter_for_file (file, out iter)) {
            return true;
        }

        insert_with_values (out iter, null, -1, ColumnID.FILE_COLUMN, file);

        if (file.is_folder ()) {
            // Append at least a dummy child
            Gtk.TreeIter child_iter;
            append (out child_iter, iter);
        }

        return true;
    }

    public bool remove_file (GOF.File file, GOF.Directory.Async directory) {
        Gtk.TreeIter? iter;
        get_first_iter_for_file (file, out iter);
        if (iter != null) {
            remove (ref iter);
            return true;
        }

        return false;
    }

    public bool iter_has_child (Gtk.TreeIter iter) {
        message("Has child?");
        if (has_child == false) {
            return false;
        }

        GOF.File? iter_file;
        get (iter, ColumnID.FILE_COLUMN, out iter_file);
        if (iter_file == null || !iter_file.is_directory) {
            return false;
        }

        return true;
    }

    private int file_entry_compare_func (Gtk.TreeIter a, Gtk.TreeIter b) {
        GOF.File? file_a = null;
        GOF.File? file_b = null;
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
