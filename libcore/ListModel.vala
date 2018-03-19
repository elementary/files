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

public class FM.ListModel : GLib.Object, Gtk.TreeModel, Gtk.TreeDragDest, Gtk.TreeSortable {
    public enum ColumnID {
        FILE_COLUMN,
        COLOR,
        PIXBUF,
        FILENAME,
        SIZE,
        TYPE,
        MODIFIED,
        NUM_COLUMNS;

        public static ColumnID from_string (string colid) {
            switch (colid) {
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

    private struct FileEntry {
        unowned GOF.File file;
        Gee.TreeMap<GOF.File, GLib.SequenceIter<FileEntry?>> reverse_map;    /* map from files to GSequenceIter's */
        unowned GOF.Directory.Async subdirectory;
        unowned FileEntry* parent;
        unowned GLib.Sequence<FileEntry?> files;
        GLib.SequenceIter<FileEntry?> seq;
        bool loaded;
    }

    public signal void subdirectory_unloaded (GOF.Directory.Async directory);

    public bool has_child { get; set; default = false; }
    public int icon_size { get; set; default = 32; }

    private GLib.Sequence<FileEntry?> files;
    private Gee.TreeMap<GOF.File, GLib.SequenceIter<FileEntry?>> top_reverse_map;
    private Gee.TreeMap<GOF.Directory.Async, GLib.SequenceIter<FileEntry?>> directory_reverse_map;
    private int stamp;
    private bool sort_directories_first = true;
    private ColumnID sort_id;
    private Gtk.SortType order;

    construct {
        files = new GLib.Sequence<FileEntry?> ();
        top_reverse_map = new Gee.TreeMap<GOF.File, GLib.SequenceIter<FileEntry?>> ();
        directory_reverse_map = new Gee.TreeMap<GOF.Directory.Async, GLib.SequenceIter<FileEntry?>> ();
        stamp = (int)GLib.Random.next_int ();
        sort_id = ColumnID.FILENAME;
        order = Gtk.SortType.ASCENDING;
    }

    private GLib.SequenceIter<FileEntry?> lookup_file (GOF.File file, GOF.Directory.Async? directory = null) {
        GLib.SequenceIter<FileEntry?> parent_seq = null;
        if (directory != null) {
            parent_seq = directory_reverse_map.get (directory);
        }

        if (parent_seq != null) {
            unowned FileEntry entry = parent_seq.get ();
            return entry.reverse_map.get (file);
        } else {
            return top_reverse_map.get (file);
        }
    }

    public bool get_tree_iter_from_file (GOF.File file, GOF.Directory.Async directory, out Gtk.TreeIter? iter) {
        var seq = lookup_file (file, directory);
        if (seq == null) {
            iter = null;
            return false;
        }

        sequenceiter_to_treeiter (seq, out iter);
        return true;
    }

    public void file_changed (GOF.File file, GOF.Directory.Async dir) {
        var seq = lookup_file (file, dir);
        if (seq == null) {
            return;
        }

        var pos_before = seq.get_position ();
        seq.sort_changed (file_entry_compare_func);
        var pos_after = seq.get_position ();

        unowned GLib.Sequence<FileEntry?> current_files = files;
        /* The file moved, we need to send rows_reordered */
        if (pos_before != pos_after) {
            Gtk.TreeIter? iter = null;
            Gtk.TreePath parent_path = null;
            unowned FileEntry* parent_file_entry = seq.get ().parent;
            if (parent_file_entry == null) {
                parent_path = new Gtk.TreePath ();
            } else {
                sequenceiter_to_treeiter (parent_file_entry.seq, out iter);
                parent_path = get_path (iter);
                current_files = parent_file_entry.files;
            }

            var length = current_files.get_length ();
            var new_order = new int[length];
            int old = 0;
            for (int i = 0; i < length; ++i) {
                if (i == pos_after) {
                    new_order[i] = pos_before;
                } else {
                    if (old == pos_before) {
                        old++;
                    }

                    new_order[i] = old++;
                }
            }

            rows_reordered (parent_path, iter, new_order);
        }

        Gtk.TreeIter iter;
        sequenceiter_to_treeiter (seq, out iter);
        row_changed (get_path (iter), iter);
    }

    public bool get_first_iter_for_file (GOF.File file, out Gtk.TreeIter? iter) {
        var seq = top_reverse_map.get (file);
        if (seq != null) {
            sequenceiter_to_treeiter (seq, out iter);
            return true;
        }

        foreach (var value in directory_reverse_map.values) {
            unowned FileEntry dir_file_entry = value.get ();
            var dir_seq = dir_file_entry.reverse_map.get (file);
            if (dir_seq != null) {
                sequenceiter_to_treeiter (dir_seq, out iter);
                return true;
            }
        }

        iter = null;
        return false;
    }

    public void set_should_sort_directories_first (bool sort_directories_first) {
        if (this.sort_directories_first == sort_directories_first) {
            return;
        }

        this.sort_directories_first = sort_directories_first;
        sort ();
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

    public bool get_directory_file (Gtk.TreePath path, out unowned GOF.Directory.Async directory, out unowned GOF.File file) {
        file = null;
        directory = null;

        Gtk.TreeIter? iter;
        if (!get_iter (out iter, path)) {
            return false;
        }

        unowned FileEntry file_entry = ((GLib.SequenceIter<FileEntry?>)iter.user_data).get ();
        directory = file_entry.subdirectory;
        file = file_entry.file;
        return true;
    }

    public bool load_subdirectory (Gtk.TreePath path, out GOF.Directory.Async dir) {
        dir = null;

        Gtk.TreeIter? iter;
        if (!get_iter (out iter, path)) {
            return false;
        }

        unowned FileEntry file_entry = ((GLib.SequenceIter<FileEntry?>)iter.user_data).get ();
        if (file_entry.file == null || file_entry.subdirectory != null) {
            return false;
        }

        dir = GOF.Directory.Async.from_file (file_entry.file);
        file_entry.subdirectory = dir;
        directory_reverse_map.set (dir, file_entry.seq);
        file_entry.reverse_map = new Gee.TreeMap<GOF.File, GLib.SequenceIter<FileEntry?>> ();
        return true;
    }

    public bool unload_subdirectory (Gtk.TreeIter iter) {
        unowned FileEntry file_entry = ((GLib.SequenceIter<FileEntry?>)iter.user_data).get ();
        var subdir = file_entry.subdirectory;
        if (file_entry.file == null || subdir == null) {
            return false;
        }

        subdir.cancel ();
        directory_reverse_map.unset (subdir);
        file_entry.loaded = false;

        /* Remove all children */
        while (file_entry.files.get_length () > 0) {
            var child_seq = file_entry.files.get_begin_iter ();
            unowned FileEntry child_file_entry = child_seq.get ();
            if (child_file_entry.file == null) {
                /* Don't delete the dummy node */
                break;
            } else {
                Gtk.TreeIter child_iter;
                sequenceiter_to_treeiter (child_seq, out child_iter);
                remove (child_iter);
            }
        }

        subdirectory_unloaded (subdir);
        return true;
    }

    public bool add_file (GOF.File file, GOF.Directory.Async dir) {
        var parent_seq = directory_reverse_map.get (dir);
        GLib.SequenceIter<FileEntry?> seq = null;
        if (parent_seq != null) {
            unowned FileEntry file_entry = parent_seq.get ();
            seq = file_entry.reverse_map.get (file);
        } else {
            seq = top_reverse_map.get (file);
        }

        if (seq != null) {
            return false;
        }

        var file_entry = FileEntry ();
        file_entry.file = file;

        unowned GLib.Sequence<FileEntry?> current_files = files;
        var parent_hash = top_reverse_map;
        var replaced_dummy = false;

        if (parent_seq != null) {
            unowned FileEntry parent_entry = parent_seq.get ();
            file_entry.parent = &parent_entry;
            /* At this point we set loaded. Either we saw
             * "done" and ignored it waiting for this, or we do this
             * earlier, but then we replace the dummy row anyway,
             * so it doesn't matter */
            parent_entry.loaded = true;
            parent_hash = parent_entry.reverse_map;
            current_files = parent_entry.files;
            /* maybe the dummy row */
            if (current_files.get_length () == 1) {
                var dummy_seq = current_files.get_iter_at_pos (0);
                unowned FileEntry dummy_entry = dummy_seq.get ();
                /* it is the dummy row  - replace it */
                if (dummy_entry.file == null) {
                    dummy_seq.remove ();
                    replaced_dummy = true;
                }
            }
        }

        file_entry.seq = current_files.insert_sorted (file_entry, file_entry_compare_func);
        parent_hash.set (file, file_entry.seq);

        var iter = Gtk.TreeIter ();
        iter.stamp = stamp;
        iter.user_data = file_entry.seq;

        var path = get_path (iter);
        if (replaced_dummy) {
            row_changed (path, iter);
        } else {
            row_inserted (path, iter);
        }

        if (file.is_folder ()) {
            var file_entry_files = new GLib.Sequence<FileEntry?> ();
            file_entry.files = file_entry_files;
            add_dummy_row (file_entry);
            row_has_child_toggled (path, iter);
        }

        return true;
    }

    public uint get_length () {
        return files.get_length ();
    }

    public void clear () {
        clear_directory (files);
    }

    private void remove (Gtk.TreeIter iter) {
        return_val_if_fail (iter.stamp == stamp, null);

        var path = get_path (iter);
        var seq = (GLib.SequenceIter<FileEntry?>)iter.user_data;
        unowned FileEntry file_entry = seq.get ();
        unowned GLib.Sequence<FileEntry?> entry_files = file_entry.files;
        if (entry_files != null) {
            while (entry_files.get_length () > 0) {
                var child_seq = entry_files.get_begin_iter ();
                unowned FileEntry child_file_entry = child_seq.get ();
                if (child_file_entry.file != null) {
                    remove_file (child_file_entry.file, file_entry.subdirectory);
                } else {
                    path.append_index (0);
                    child_seq.remove ();
                    row_deleted (path);
                }
            }
        }

        unowned FileEntry* parent = file_entry.parent;
        var file_entry_file = file_entry.file;
        if (file_entry_file != null) {
            if (parent != null) {
                parent.reverse_map.unset (file_entry_file);
            } else {
                top_reverse_map.unset (file_entry_file);
            }
        }

        if (parent != null && parent.files.get_length () == 1 && file_entry_file != null) {
            /* this is the last non-dummy child, add a dummy node */
            /* We need to do this before removing the last file to avoid
             * collapsing the row.
             */
             add_dummy_row (*parent);
        }

        var subdir = file_entry.subdirectory;
        if (subdir != null) {
            subdirectory_unloaded (subdir);
            directory_reverse_map.unset (subdir);
        }

        seq.remove ();
        row_deleted (path);
    }

    public bool remove_file (GOF.File file, GOF.Directory.Async directory) {
        Gtk.TreeIter? iter;
        if (get_tree_iter_from_file (file, directory, out iter)) {
            remove (iter);
            return true;
        } else {
            return false;
        }
    }

    private void clear_directory (GLib.Sequence<FileEntry?> dir_files) {
        var iter = Gtk.TreeIter ();
        while (dir_files.get_length () > 0) {
            var seq = dir_files.get_begin_iter ();

            unowned FileEntry file_entry = seq.get ();
            if (file_entry.files != null) {
                clear_directory (file_entry.files);
            }

            iter.user_data = seq;
            iter.stamp = stamp;
            remove (iter);
        }
    }

    public Gtk.TreeModelFlags get_flags () {
        return Gtk.TreeModelFlags.ITERS_PERSIST | Gtk.TreeModelFlags.LIST_ONLY;
    }

    public int get_n_columns () {
        return ColumnID.NUM_COLUMNS;
    }

    public Type get_column_type (int index) {
        switch (index) {
            case ColumnID.FILE_COLUMN:
                return typeof (GOF.File);
            case ColumnID.PIXBUF:
                return typeof (Gdk.Pixbuf);
            default:
                if (index < ColumnID.NUM_COLUMNS) {
                    return typeof (string);
                } else {
                    return GLib.Type.INVALID;
                }
        }
    }

    private void sequenceiter_to_treeiter (GLib.SequenceIter<FileEntry?> seq, out Gtk.TreeIter iter) {
        assert (!seq.is_end ());
        iter = Gtk.TreeIter ();
        iter.stamp = stamp;
        iter.user_data = seq;
    }

    public bool get_iter (out Gtk.TreeIter iter, Gtk.TreePath path) {
        unowned GLib.Sequence<FileEntry?> current_files = files;
        var indices = path.get_indices ();
        var depth = path.get_depth ();
        iter = Gtk.TreeIter ();
        GLib.SequenceIter<FileEntry?> seq = null;
        for (int d = 0; d < depth; d++) {
            int i = indices[d];

            if (i >= current_files.get_length ()) {
                return false;
            }

            seq = current_files.get_iter_at_pos (i);
            current_files = seq.get ().files;
        }

        sequenceiter_to_treeiter (seq, out iter);
        return true;
    }

    public Gtk.TreePath? get_path (Gtk.TreeIter iter) {
        return_val_if_fail (iter.stamp == stamp, null);

        var path = new Gtk.TreePath ();
        var seq = (GLib.SequenceIter<FileEntry?>)iter.user_data;

        if (seq.is_end ()) {
            return null;
        }

        while (seq != null) {
            path.prepend_index (seq.get_position ());
            unowned FileEntry file_entry = seq.get ();
            if (file_entry.parent != null) {
                seq = file_entry.parent.seq;
            } else {
                seq = null;
            }
        }

        return path;
    }

    public void get_value (Gtk.TreeIter iter, int column, out Value value) {
        assert (iter.stamp == stamp);
        var seq = (GLib.SequenceIter<FileEntry?>)iter.user_data;
        var file = seq.get ().file as GOF.File;

        return_if_fail (!seq.is_end ());
        return_if_fail (file != null);

        switch (column) {
            case ColumnID.FILE_COLUMN:
                value = Value (typeof (GOF.File));
                value.set_object (file);
                break;
            case ColumnID.COLOR:
                value = Value (typeof (string));
                if (file.color < GOF.Preferences.TAGS_COLORS.length) {
                    value.set_string (GOF.Preferences.TAGS_COLORS[file.color]);
                }
                break;
            case ColumnID.PIXBUF:
                value = Value (typeof (Gdk.Pixbuf));
                file.update_icon (icon_size, file.pix_scale);
                if (file.pix != null) {
                    value.set_object (file.pix);
                }

                break;
            case ColumnID.FILENAME:
                value = Value (typeof (string));
                value.set_string (file.get_display_name ());
                break;
            case ColumnID.SIZE:
                value = Value (typeof (string));
                value.set_string (file.format_size);
                break;
            case ColumnID.TYPE:
                value = Value (typeof (string));
                value.set_string (file.formated_type);
                break;
            case ColumnID.MODIFIED:
                value = Value (typeof (string));
                value.set_string (file.formated_modified);
                break;
            default:
                value = Value (GLib.Type.INVALID);
                break;
        }
    }

    public bool iter_children (out Gtk.TreeIter iter, Gtk.TreeIter? parent) {
        unowned GLib.Sequence<FileEntry?> current_files = files;
        if (parent != null) {
            current_files = ((GLib.SequenceIter<FileEntry?>) parent.user_data).get ().files;
        }

        iter = Gtk.TreeIter ();
        if (current_files == null || current_files.get_length () == 0) {
            return false;
        }

        iter.stamp = stamp;
        iter.user_data = current_files.get_begin_iter ();

        return true;
    }

    public bool iter_has_child (Gtk.TreeIter iter) {
        if (has_child == false) {
            return false;
        }

        unowned FileEntry file_entry = ((GLib.SequenceIter<FileEntry?>)iter.user_data).get ();
        return (file_entry.files != null && file_entry.files.get_length () > 0);
    }

    public int iter_n_children (Gtk.TreeIter? iter) {
        unowned GLib.Sequence<FileEntry?> current_files = files;
        if (iter != null) {
            current_files = ((GLib.SequenceIter<FileEntry?>) iter.user_data).get ().files;
        }

        return current_files.get_length ();
    }

    public bool iter_next (ref Gtk.TreeIter iter) {
        return_val_if_fail (iter.stamp == stamp, false);
        iter.user_data = ((GLib.SequenceIter<FileEntry?>)iter.user_data).next ();

        return !((GLib.SequenceIter<FileEntry?>)iter.user_data).is_end ();
    }

    public bool iter_nth_child (out Gtk.TreeIter iter, Gtk.TreeIter? parent, int n) {
        iter = Gtk.TreeIter ();
        unowned GLib.Sequence<FileEntry?> current_files = files;
        if (parent != null) {
            current_files = ((GLib.SequenceIter<FileEntry?>) parent.user_data).get ().files;
        }

        var child = current_files.get_iter_at_pos (n);
        if (child.is_end ()) {
            return false;
        }

        iter.stamp = stamp;
        iter.user_data = child;
        return true;
    }

    public bool iter_parent (out Gtk.TreeIter iter, Gtk.TreeIter child) {
        iter = Gtk.TreeIter ();
        unowned FileEntry file_entry = ((GLib.SequenceIter<FileEntry?>) child.user_data).get ();
        if (file_entry.parent == null) {
            return false;
        }

        iter.stamp = stamp;
        iter.user_data = file_entry.parent.seq;
        return true;
    }

    public bool drag_data_received (Gtk.TreePath dest, Gtk.SelectionData selection_data) {
        return false;
    }

    public bool row_drop_possible (Gtk.TreePath dest_path, Gtk.SelectionData selection_data) {
        return false;
    }

    public bool has_default_sort_func () {
        return false;
    }

    public bool get_sort_column_id (out int sort_column_id, out Gtk.SortType order) {
        order = this.order;
        sort_column_id = (ColumnID) sort_id;
        return sort_id != -1;
    }

    public void set_default_sort_func (owned Gtk.TreeIterCompareFunc sort_func) {
    }

    public void set_sort_func (int sort_column_id, owned Gtk.TreeIterCompareFunc sort_func) {
    }

    public void set_sort_column_id (int sort_column_id, Gtk.SortType order) {
        sort_id = (ColumnID) sort_column_id;
        this.order = order;
        sort ();
        sort_column_changed ();
    }

    [CCode (instance_pos = -1)]
    private int file_entry_compare_func (FileEntry? file_entry1, FileEntry? file_entry2) {
        var file1 = file_entry1.file;
        var file2 = file_entry2.file;
        if (file1 != null && file2 != null &&
            file1.location != null && file2.location != null) {
            return file1.compare_for_sort (file2, sort_id, sort_directories_first, order == Gtk.SortType.DESCENDING);
        } else if (file1 == null || file1.location == null) {
            return -1;
        } else {
            return 1;
        }
    }

    private void add_dummy_row (FileEntry parent_entry) {
        var dummy_file_entry = FileEntry ();
        dummy_file_entry.parent = &parent_entry;
        dummy_file_entry.seq = parent_entry.files.insert_sorted ((owned)dummy_file_entry, file_entry_compare_func);
        var iter = Gtk.TreeIter ();
        iter.stamp = stamp;
        iter.user_data = dummy_file_entry.seq;

        row_inserted (get_path (iter), iter);
    }

    private void sort_file_entries (GLib.Sequence<FileEntry?> current_files, Gtk.TreePath path) {
        var length = current_files.get_length ();
        if (length < 1) {
            return;
        }

        /* generate old order of GSequenceIter's */
        GLib.SequenceIter<FileEntry?>[] old_order = new GLib.SequenceIter<FileEntry?>[length];
        for (int i = 0; i < length; i++) {
            var seq = current_files.get_iter_at_pos (i);
            unowned FileEntry file_entry = seq.get ();
            if (file_entry.files != null) {
                path.append_index (i);
                sort_file_entries (file_entry.files, path);
                path.up ();
            }

            old_order[i] = seq;
        }

        /* sort */
        current_files.sort (file_entry_compare_func);

        /* generate new order */
        int[] new_order = new int[length];
        for (int i = 0; i < length; ++i) {
            var old_position = old_order[i].get_position ();
            new_order[old_position] = i;
        }

        Gtk.TreeIter? iter = null;
        if (path.get_depth () != 0) {
            assert (get_iter (out iter, path));
        }

        rows_reordered_with_length (path, iter, new_order);
    }

    private void sort () {
        var path = new Gtk.TreePath ();
        sort_file_entries (files, path);
    }
}
