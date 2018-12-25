/* Copyright (c) 2018 elementary LLC (https://elementary.io)
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

namespace FM {
    public enum ColumnID {
        FILE_COLUMN, /* gof file */
        COLOR,  /* string */
        FILENAME,  /* string */
        SIZE,  /* string */
        TYPE,  /* string */
        MODIFIED,  /* string */
        NUM_COLUMNS,
        INVALID;

        public static ColumnID from_string (string? col_id) {
            if (col_id == null) {
                return ColumnID.INVALID;
            }

            switch (col_id) {
                case "name":
                    return ColumnID.FILENAME;
                case "size":
                    return ColumnID.SIZE;
                case "type":
                    return ColumnID.TYPE;
                case "modified":
                    return ColumnID.MODIFIED;
                default:
                    return ColumnID.FILENAME;
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

public interface DirectoryViewInterface : Object {
    public signal void subdirectory_unloaded (GOF.Directory.Async dir);
    public signal void sort_order_changed (FM.ColumnID new_sort_property, bool reversed, FM.ColumnID old_sort_property);

    public abstract int icon_size { get; set; }
    public abstract bool has_child { get; set; }
    public abstract bool sort_directories_first { get; set; }
    public abstract ColumnID sort_file_property { get; set; }
    public abstract bool reversed { get; set; }

    public abstract bool get_first_iter_for_file (GOF.File file, out Gtk.TreeIter? iter);
    public abstract bool add_file (GOF.File file, GOF.Directory.Async? dir = null);
    public abstract void file_changed (GOF.File file, GOF.Directory.Async? dir = null);
    public abstract bool remove_file (GOF.File file, GOF.Directory.Async? dir = null);
    public abstract GOF.File? file_for_path (Gtk.TreePath path);
    public abstract GOF.File? file_for_iter (Gtk.TreeIter iter);
    public abstract bool load_subdirectory (Gtk.TreePath path, out GOF.Directory.Async? dir);
    public abstract bool unload_subdirectory (Gtk.TreeIter iter);

    /* 'reversed' indicates whether the sort should be the natural order for that property
     * (defined by the sort function in gof.file) or not */
    public abstract bool get_order (out FM.ColumnID sort_file_property, out bool reversed);
    public abstract void set_order (FM.ColumnID sort_file_property, bool? reversed = null);
}

//    public signal void subdirectory_unloaded (GOF.Directory.Async directory);

public class DirectoryModel : Gtk.TreeStore, DirectoryViewInterface {

    public bool has_child { get; set; default = false; }
    public int icon_size { get; set; default = 32; }
    public ColumnID sort_file_property { get; set; default = FM.ColumnID.FILENAME;}
    public bool reversed { get; set; }
    public bool sort_directories_first { get; set; default = true;}

    construct {
        set_column_types ({
              typeof (GOF.File), /* File object */
            });

        sort_file_property = ColumnID.FILENAME;
        set_sort_func (ColumnID.FILE_COLUMN, directory_view_sort_func);
    }

    private int directory_view_sort_func (Gtk.TreeModel model, Gtk.TreeIter iter_a, Gtk.TreeIter iter_b) {
        GOF.File file_a, file_b;
        model.@get (iter_a, ColumnID.FILE_COLUMN, out file_a);
        model.@get (iter_b, ColumnID.FILE_COLUMN, out file_b);

        return file_a.compare_for_sort (file_b, (int)sort_file_property, sort_directories_first, reversed);
    }

    public new bool get_sort_column_id (out int sort_col, out Gtk.SortType sort_type) {
        /* We do not want the normal method to be called externally */
        /* Externally, 'get_order ()' should be called */
        sort_col = 0;
        sort_type = 0;
        assert (false);
        return true;
    }

    public new void set_sort_column_id (int sort_col, Gtk.SortType sort_type) {
        /* We do not want the normal method to be called externally */
        /* Externally, 'get_order ()' should be called */
        assert (false);
    }

    public bool get_order (out FM.ColumnID sort_file_property, out bool reversed) {
        reversed = this.reversed;
        sort_file_property = this.sort_file_property;
        return true;
    }

    /* If called with explicit "reversed" use that else if column changed use "true" else toggle existing order */
    public void set_order (FM.ColumnID _sort_file_property, bool? _reversed = null) {
        assert (_sort_file_property != FM.ColumnID.INVALID);
        var old_col = sort_file_property;
        sort_file_property = _sort_file_property;
        reversed = (_reversed == null ? (old_col == _sort_file_property ? !reversed : false) : _reversed);
        ((Gtk.TreeStore)(this)).set_sort_column_id (FM.ColumnID.FILE_COLUMN, Gtk.SortType.ASCENDING);
        set_sort_func (ColumnID.FILE_COLUMN, directory_view_sort_func);
        sort_order_changed (sort_file_property, reversed, old_col);
    }

//    private GLib.SequenceIter<FM.FileEntry> lookup_file (GOF.File file, GOF.Directory.Async? directory = null) {
//        GLib.SequenceIter<FM.FileEntry> parent_seq = null;
//        if (directory != null) {
//            parent_seq = directory_reverse_map.get (directory);
//        }

//        if (parent_seq != null) {
//            FM.FileEntry entry = parent_seq.get ();
//            return entry.reverse_map.get (file);
//        } else {
//            return top_reverse_map.get (file);
//        }
//    }

//    public bool get_tree_iter_from_file (GOF.File file, GOF.Directory.Async directory, out Gtk.TreeIter? iter) {
//        iter = null;
//        var seq = lookup_file (file, directory);
//        if (seq == null) {
//            iter = null;
//            return false;
//        }

//        sequenceiter_to_treeiter (seq, out iter);
//        return true;
//    }

    public void file_changed (GOF.File file, GOF.Directory.Async? dir = null) {
//        var seq = lookup_file (file, dir);
//        if (seq == null) {
//            return;
//        }

//        var pos_before = seq.get_position ();
//        seq.sort_changed (file_entry_compare_func);
//        var pos_after = seq.get_position ();

//        unowned GLib.Sequence<FM.FileEntry> current_files = files;
//        /* The file moved, we need to send rows_reordered */
//        if (pos_before != pos_after) {
//            Gtk.TreeIter? iter = null;
//            Gtk.TreePath parent_path = null;
//            FM.FileEntry parent_file_entry = seq.get ().parent;
//            if (parent_file_entry == null) {
//                parent_path = new Gtk.TreePath ();
//            } else {
//                sequenceiter_to_treeiter (parent_file_entry.seq, out iter);
//                parent_path = get_path (iter);
//                current_files = parent_file_entry.files;
//            }

//            var length = current_files.get_length ();
//            var new_order = new int[length];
//            int old = 0;
//            for (int i = 0; i < length; ++i) {
//                if (i == pos_after) {
//                    new_order[i] = pos_before;
//                } else {
//                    if (old == pos_before) {
//                        old++;
//                    }

//                    new_order[i] = old++;
//                }
//            }

//            rows_reordered (parent_path, iter, new_order);
//        }

//        Gtk.TreeIter iter;
//        sequenceiter_to_treeiter (seq, out iter);
//        row_changed (get_path (iter), iter);
    }

    public bool get_first_iter_for_file (GOF.File file, out Gtk.TreeIter? iter) {
//        var seq = top_reverse_map.get (file);
//        if (seq != null) {
//            sequenceiter_to_treeiter (seq, out iter);
//            return true;
//        }

//        foreach (var value in directory_reverse_map.values) {
//            FM.FileEntry dir_file_entry = value.get ();
//            var dir_seq = dir_file_entry.reverse_map.get (file);
//            if (dir_seq != null) {
//                sequenceiter_to_treeiter (dir_seq, out iter);
//                return true;
//            }
//        }

        iter = null;
        return false;
    }

//    public void set_should_sort_directories_first (bool sort_directories_first) {
//        if (this.sort_directories_first == sort_directories_first) {
//            return;
//        }

//        this.sort_directories_first = sort_directories_first;
//        sort ();
//    }

    public GOF.File? file_for_path (Gtk.TreePath path) {
        GOF.File? file = null;
        Gtk.TreeIter? iter;
        if (get_iter (out iter, path) && iter != null) {
            @get (iter, ColumnID.FILE_COLUMN, out file);
        }

        return file;
//        return null;
    }

    public GOF.File? file_for_iter (Gtk.TreeIter iter) {
        GOF.File? file = null;
        get (iter, ColumnID.FILE_COLUMN, out file);
        return file;
    }

//    public bool get_directory_file (Gtk.TreePath path, out unowned GOF.Directory.Async directory, out unowned GOF.File file) {
//        file = null;
//        directory = null;

//        Gtk.TreeIter? iter;
//        if (!get_iter (out iter, path)) {
//            return false;
//        }

//        FM.FileEntry file_entry = ((GLib.SequenceIter<FM.FileEntry>)iter.user_data).get ();
//        directory = file_entry.subdirectory;
//        file = file_entry.file;
//        return true;
//    }

    public bool load_subdirectory (Gtk.TreePath path, out GOF.Directory.Async? dir) {
        dir = null;

//        Gtk.TreeIter? iter;
//        if (!get_iter (out iter, path)) {
//            return false;
//        }

//        FM.FileEntry file_entry = ((GLib.SequenceIter<FM.FileEntry>)iter.user_data).get ();
//        if (file_entry.file == null || file_entry.subdirectory != null) {
//            return false;
//        }

//        dir = GOF.Directory.Async.from_file (file_entry.file);
//        file_entry.subdirectory = dir;
//        directory_reverse_map.set (dir, file_entry.seq);
        return true;
    }

    public bool unload_subdirectory (Gtk.TreeIter iter) {
//        FM.FileEntry file_entry = ((GLib.SequenceIter<FM.FileEntry>)iter.user_data).get ();
//        var subdir = file_entry.subdirectory;
//        if (file_entry.file == null || subdir == null) {
//            return false;
//        }

//        subdir.cancel ();
//        directory_reverse_map.unset (subdir);
//        file_entry.loaded = false;

//        /* Remove all children */
//        while (file_entry.files.get_length () > 0) {
//            var child_seq = file_entry.files.get_begin_iter ();
//            FM.FileEntry child_file_entry = child_seq.get ();
//            if (child_file_entry.file == null) {
//                /* Don't delete the dummy node */
//                break;
//            } else {
//                Gtk.TreeIter child_iter;
//                sequenceiter_to_treeiter (child_seq, out child_iter);
//                remove (ref child_iter);
//            }
//        }

//        subdirectory_unloaded (subdir);
        return true;
    }

    public bool add_file (GOF.File file, GOF.Directory.Async? dir = null) {
//warning ("add file %s", file.uri);
        Gtk.TreeIter? iter = null;
        append (out iter, null);
        @set (iter, ColumnID.FILE_COLUMN, file, -1);
//        var parent_seq = directory_reverse_map.get (dir);
//        GLib.SequenceIter<FM.FileEntry> seq = null;
//        if (parent_seq != null) {
//            FM.FileEntry file_entry = parent_seq.get ();
//            seq = file_entry.reverse_map.get (file);
//        } else {
//            seq = top_reverse_map.get (file);
//        }

//        if (seq != null) { /* already in model */
//            return false;
//        }

//        var file_entry = new FM.FileEntry ();
//        file_entry.file = file;

//        unowned GLib.Sequence<FM.FileEntry> current_files = files;
//        var parent_hash = top_reverse_map;
//        var replaced_dummy = false;

//        if (parent_seq != null) {
//            FM.FileEntry parent_entry = parent_seq.get ();
//            file_entry.parent = parent_entry;
//            /* At this point we set loaded. Either we saw
//             * "done" and ignored it waiting for this, or we do this
//             * earlier, but then we replace the dummy row anyway,
//             * so it doesn't matter */
//            parent_entry.loaded = true;
//            parent_hash = parent_entry.reverse_map;
//            current_files = parent_entry.files;
//            /* maybe the dummy row */
//            if (current_files.get_length () == 1) {
//                var dummy_seq = current_files.get_iter_at_pos (0);
//                FM.FileEntry dummy_entry = dummy_seq.get ();
//                /* If it is the dummy row  - replace it */
//                if (dummy_entry.file == null) {
//                    dummy_seq.remove ();
//                    replaced_dummy = true;
//                }
//            }
//        }

//        file_entry.seq = current_files.insert_sorted (file_entry, file_entry_compare_func);
//        parent_hash.set (file, file_entry.seq);

//        var iter = Gtk.TreeIter ();
//        iter.stamp = stamp;
//        iter.user_data = file_entry.seq;

//        var path = get_path (iter);
//        if (replaced_dummy) {
//            row_changed (path, iter);
//        } else {
//            row_inserted (path, iter);
//        }

//        if (file.is_folder ()) {
//            file_entry.files = new GLib.Sequence<FM.FileEntry> ();
//            add_dummy_row (file_entry);
//            row_has_child_toggled (path, iter);
//        }
        return true;
    }

    public bool remove_file (GOF.File file_a, GOF.Directory.Async? directory = null) {
        GOF.File?  file_b = null;
        bool valid_iter = false;

        @foreach ((model, path, iter) => {
            model.@get (iter, FM.ColumnID.FILE_COLUMN, out file_b);
            if (file_a == file_b) {
                valid_iter = remove (ref iter);
                return true;
            } else {
                return false;
            }
        });

        return valid_iter;
    }

//    private void clear_directory (GLib.Sequence<FM.FileEntry> dir_files) {
//        var iter = Gtk.TreeIter ();
//        while (dir_files.get_length () > 0) {
//            var seq = dir_files.get_begin_iter ();

//            FM.FileEntry file_entry = seq.get ();
//            if (file_entry.files != null) {
//                clear_directory (file_entry.files);
//            }

//            iter.user_data = seq;
//            iter.stamp = stamp;
//            remove (ref iter);
//        }
//    }

    public Gtk.TreeModelFlags get_flags () {
        return Gtk.TreeModelFlags.ITERS_PERSIST | Gtk.TreeModelFlags.LIST_ONLY;
    }

//    public int get_n_columns () {
//        return ColumnID.NUM_COLUMNS;
//    }

//    public Type get_column_type (int index) {
//        switch (index) {
//            case ColumnID.FILE_COLUMN:
//                return typeof (GOF.File);
//            case ColumnID.PIXBUF:
//                return typeof (Gdk.Pixbuf);
//            default:
//                if (index < ColumnID.NUM_COLUMNS) {
//                    return typeof (string);
//                } else {
//                    return GLib.Type.INVALID;
//                }
//        }
//    }

//    private void sequenceiter_to_treeiter (GLib.SequenceIter<FM.FileEntry> seq, out Gtk.TreeIter iter) {
//        assert (!seq.is_end ());
//        iter = Gtk.TreeIter ();
//        iter.stamp = stamp;
//        iter.user_data = seq;
//    }

//    public bool get_iter (out Gtk.TreeIter? iter, Gtk.TreePath path) {
//        iter = null;
//        unowned GLib.Sequence<FM.FileEntry> current_files = files;
//        var indices = path.get_indices ();
//        var depth = path.get_depth ();
//        iter = Gtk.TreeIter ();
//        GLib.SequenceIter<FM.FileEntry> seq = null;
//        for (int d = 0; d < depth; d++) {
//            int i = indices[d];

//            if (i >= current_files.get_length ()) {
//                return false;
//            }

//            seq = current_files.get_iter_at_pos (i);
//            current_files = seq.get ().files;
//        }

//        sequenceiter_to_treeiter (seq, out iter);
//        return false;
//    }

//    public Gtk.TreePath? get_path (Gtk.TreeIter iter) {
//        return_val_if_fail (iter.stamp == stamp, null);

//        var path = new Gtk.TreePath ();
//        var seq = (GLib.SequenceIter<FM.FileEntry>)iter.user_data;

//        if (seq.is_end ()) {
//            return null;
//        }

//        while (seq != null) {
//            path.prepend_index (seq.get_position ());
//            FM.FileEntry file_entry = seq.get ();
//            if (file_entry.parent != null) {
//                seq = file_entry.parent.seq;
//            } else {
//                seq = null;
//            }
//        }

//        return path;
//        return new Gtk.TreePath ();
//    }

//    public new void @get (Gtk.TreeIter iter, ...) {
//warning ("get");
//    }

    public new void get_value (Gtk.TreeIter iter, int column, out Value return_value) {
//warning ("get value col %s", ((ColumnID)column).to_string ());
        Value file_value;
        get_value (iter, ColumnID.FILE_COLUMN, out file_value);
        if (column == ColumnID.FILE_COLUMN) {
            return_value = file_value;

        } else {
            return_value = Value (GLib.Type.INVALID);
        }

        return;
//        var file = (GOF.File)(file_value.get_object ())
//;
//        switch (column) {
//            case ColumnID.COLOR:
//                return_value = Value (typeof (string));
//                break;
////            case ColumnID.PIXBUF:
////                return_value = Value (typeof (Gdk.Pixbuf));
////                break;
//            case ColumnID.FILENAME:
//                return_value = Value (typeof (string));
//                break;
//            case ColumnID.SIZE:
//                return_value = Value (typeof (string));
//                break;
//            case ColumnID.TYPE:
//                return_value = Value (typeof (string));
//                break;
//            case ColumnID.MODIFIED:
//                return_value = Value (typeof (string));
//                break;
//            default:
//                assert_not_reached ();
//        }

//        if (file == null) {
//            return;
//        }

//        switch (column) {
//            case ColumnID.FILE_COLUMN:
//                return_value.set_object (file);
//                break;
//            case ColumnID.COLOR:
//                return_value.set_string (GOF.Preferences.TAGS_COLORS[file.color]);
//                break;
////            case ColumnID.PIXBUF:
////                file.update_icon (icon_size, file.pix_scale);
////                if (file.pix != null) {
////                    return_value.set_object (file.pix);
////                }
////                break;
//            case ColumnID.FILENAME:
//                return_value.set_string (file.get_display_name ());
//                break;
//            case ColumnID.SIZE:
//                return_value.set_string (file.format_size);
//                break;
//            case ColumnID.TYPE:
//                return_value.set_string (file.formated_type);
//                break;
//            case ColumnID.MODIFIED:
//                return_value.set_string (file.formated_modified);
//                break;
//            default:
//                return_value = Value (GLib.Type.INVALID);
//                break;
//        }
    }

//    public bool iter_children (out Gtk.TreeIter iter, Gtk.TreeIter? parent) {
//        unowned GLib.Sequence<FM.FileEntry> current_files = files;
//        if (parent != null) {
//            current_files = ((GLib.SequenceIter<FM.FileEntry>) parent.user_data).get ().files;
//        }

//        iter = Gtk.TreeIter ();
//        if (current_files == null || current_files.get_length () == 0) {
//            return false;
//        }

//        iter.stamp = stamp;
//        iter.user_data = current_files.get_begin_iter ();

//        return true;
//    }

//    public bool iter_has_child (Gtk.TreeIter iter) {
//        if (has_child == false) {
//            return false;
//        }

//        FM.FileEntry file_entry = ((GLib.SequenceIter<FM.FileEntry>)(iter.user_data)).get ();

//        bool has_child = (file_entry.files != null && file_entry.files.get_length () > 0);
//        return has_child;
//    }

//    public int iter_n_children (Gtk.TreeIter? iter) {
//        unowned GLib.Sequence<FM.FileEntry> current_files = files;
//        if (iter != null) {
//            current_files = ((GLib.SequenceIter<FM.FileEntry>) iter.user_data).get ().files;
//        }

//        return current_files.get_length ();
//    }

//    public bool iter_next (ref Gtk.TreeIter iter) {
//        return_val_if_fail (iter.stamp == stamp, false);
//        iter.user_data = ((GLib.SequenceIter<FM.FileEntry>)iter.user_data).next ();

//        return !((GLib.SequenceIter<FM.FileEntry>)iter.user_data).is_end ();
//    }

//    public bool iter_nth_child (out Gtk.TreeIter iter, Gtk.TreeIter? parent, int n) {
//        iter = Gtk.TreeIter ();
//        unowned GLib.Sequence<FM.FileEntry> current_files = files;
//        if (parent != null) {
//            current_files = ((GLib.SequenceIter<FM.FileEntry>) parent.user_data).get ().files;
//        }

//        var child  = current_files.get_iter_at_pos (n);
//        if (child.is_end ()) {
//            return false;
//        }

//        iter.stamp = stamp;
//        iter.user_data = child;
//        return true;
//    }

//    public bool iter_parent (out Gtk.TreeIter iter, Gtk.TreeIter child) {
//        iter = Gtk.TreeIter ();
//        FM.FileEntry file_entry = ((GLib.SequenceIter<FM.FileEntry>) child.user_data).get ();
//        if (file_entry.parent == null) {
//            return false;
//        }

//        iter.stamp = stamp;
//        iter.user_data = file_entry.parent.seq;
//        return true;
//    }

//    public bool drag_data_received (Gtk.TreePath dest, Gtk.SelectionData selection_data) {
//        return false;
//    }

//    public bool row_drop_possible (Gtk.TreePath dest_path, Gtk.SelectionData selection_data) {
//        return false;
//    }

//    public bool has_default_sort_func () {
//        return false;
//    }

//    public bool get_sort_column_id (out int sort_column_id, out Gtk.SortType order) {
//        order = this.order;
//        sort_column_id = (ColumnID) sort_id;
//        return sort_id != -1;
//    }

//    public void set_default_sort_func (owned Gtk.TreeIterCompareFunc sort_func) {

//    }

//    public void set_sort_func (int sort_column_id, owned Gtk.TreeIterCompareFunc sort_func) {

//    }

//    public void set_sort_column_id (int sort_column_id, Gtk.SortType order) {
//        sort_id = (ColumnID) sort_column_id;
//        this.order = order;
//        sort ();
//        sort_column_changed ();
//    }

//    [CCode (instance_pos = -1)]
//    private int file_entry_compare_func (FM.FileEntry file_entry1, FM.FileEntry file_entry2) {
//        var file1 = file_entry1.file;
//        var file2 = file_entry2.file;
//        if (file1 != null && file2 != null &&
//            file1.location != null && file2.location != null) {
//            return file1.compare_for_sort (file2, sort_id, sort_directories_first, order == Gtk.SortType.DESCENDING);
//        } else if (file1 == null || file1.location == null) {
//            return -1;
//        } else {
//            return 1;
//        }
//    }

//    private void add_dummy_row (FM.FileEntry parent_entry) {
//        var dummy_file_entry = new FM.FileEntry ();
//        dummy_file_entry.parent = parent_entry;
//        dummy_file_entry.seq = parent_entry.files.insert_sorted (dummy_file_entry, file_entry_compare_func);

//        var iter = Gtk.TreeIter ();
//        iter.stamp = stamp;
//        iter.user_data = dummy_file_entry.seq;

//        row_inserted (get_path (iter), iter);
//    }

//    private void sort_file_entries (GLib.Sequence<FM.FileEntry> current_files, Gtk.TreePath path) {
//        var length = current_files.get_length ();
//        if (length < 1) {
//            return;
//        }

//        /* generate old order of GSequenceIter's */
//        GLib.SequenceIter<FM.FileEntry>[] old_order = new GLib.SequenceIter<FM.FileEntry>[length];
//        for (int i = 0; i < length; i++) {
//            var seq = current_files.get_iter_at_pos (i);
//            FM.FileEntry file_entry = seq.get ();
//            if (file_entry.files != null) {
//                path.append_index (i);
//                sort_file_entries (file_entry.files, path);
//                path.up ();
//            }

//            old_order[i] = seq;
//        }

//        /* sort */
//        current_files.sort (file_entry_compare_func);

//        /* generate new order */
//        int[] new_order = new int[length];
//        for (int i = 0; i < length; ++i) {
//            var old_position = old_order[i].get_position ();
//            new_order[old_position] = i;
//        }

//        Gtk.TreeIter? iter = null;
//        if (path.get_depth () != 0) {
//            assert (get_iter (out iter, path));
//        }

//        rows_reordered_with_length (path, iter, new_order);
//    }

//    private void sort () {
//        var path = new Gtk.TreePath ();
//        sort_file_entries (files, path);
//    }
}
}
