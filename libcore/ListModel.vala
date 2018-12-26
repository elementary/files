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

/* Uses Gtk.TreeStore instead of custom model to reduce code base to support */
/* Assumptions:
 *      User will not add duplicate files
 *      Traversing model to find/remove file sets will be fast enough for general use
 * If these assumptions prove false, then will have to add mechanisms for mapping files to rows and detecting duplicates
 */
namespace FM {
public interface DirectoryViewInterface : Object {
    public signal void subdirectory_unloaded (GOF.Directory.Async dir);
    public signal void sort_order_changed (FM.ColumnID new_sort_property, bool reversed, FM.ColumnID old_sort_property);

    public abstract int icon_size { get; set; }
    public abstract bool has_child { get; set; }
    public abstract bool sort_directories_first { get; set; }
    public abstract ColumnID sort_file_property { get; set; }
    public abstract bool reversed { get; set; }

    public abstract bool add_file (GOF.File file, GOF.Directory.Async? dir = null);
    public abstract bool remove_file (GOF.File file, GOF.Directory.Async? dir = null);
    public abstract bool remove_files (GLib.Sequence<GOF.File> files, GOF.Directory.Async? dir = null);
    public abstract Gtk.TreeRowReference? find_file_row (GOF.File file, GOF.Directory.Async? dir = null);
    public abstract GLib.List<Gtk.TreeRowReference> find_file_rows (GLib.Sequence<GOF.File> files, GOF.Directory.Async? dir = null);
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

        return file_match_func (file_a, file_b);
    }

    private int file_match_func (GOF.File a, GOF.File b) {
        return a.compare_for_sort (b, (int)sort_file_property, sort_directories_first, reversed);
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

    public GOF.File? file_for_path (Gtk.TreePath path) {
        GOF.File? file = null;
        Gtk.TreeIter? iter;
        if (get_iter (out iter, path) && iter != null) {
            @get (iter, ColumnID.FILE_COLUMN, out file);
        }

        return file;
    }

    public GOF.File? file_for_iter (Gtk.TreeIter iter) {
        GOF.File? file = null;
        get (iter, ColumnID.FILE_COLUMN, out file);
        return file;
    }

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
        Gtk.TreeIter? iter = null;
        append (out iter, null);
        @set (iter, ColumnID.FILE_COLUMN, file, -1);
        return true;
    }

    public bool remove_file (GOF.File file_a, GOF.Directory.Async? directory = null) {
        var files = new GLib.Sequence<GOF.File> ();
        files.append (file_a);
        return remove_files (files, directory);
    }

    public bool remove_files (GLib.Sequence<GOF.File> files, GOF.Directory.Async? dir = null) {
        files.sort (file_match_func);  /* Sort in same order as model */
        /* Should only need to pass through model once (or less) if all files are in model */
        GLib.List<Gtk.TreeRowReference> rows_to_remove = null;

        GLib.SequenceIter<GOF.File> seq_iter = files.get_begin_iter ();
        while (!seq_iter.is_end ()) {
            GOF.File file_a = seq_iter.@get ();

            @foreach ((model, path, iter) => {
                GOF.File? file_b = null;
                model.@get (iter, FM.ColumnID.FILE_COLUMN, out file_b);
                if (file_a == file_b) {
                    var row_ref = new Gtk.TreeRowReference (model, path);
                    rows_to_remove.prepend (row_ref);
                    seq_iter = seq_iter.next ();

                    if (seq_iter.is_end ()) {
                        return true;
                    } else {
                        file_a = seq_iter.@get ();
                    }
                }

                return false;
            });

            seq_iter = seq_iter.next (); /* file was not in model */
        }

        bool valid = false;
        foreach (Gtk.TreeRowReference row_ref in rows_to_remove) {
            Gtk.TreeIter iter;
            if (get_iter (out iter, row_ref.get_path ())) {
                valid = remove (ref iter);
            }
        }

        return valid;
    }

    public Gtk.TreeRowReference? find_file_row (GOF.File file_a, GOF.Directory.Async? dir = null) {
        var files = new GLib.Sequence<GOF.File> ();
        files.append (file_a);
        GLib.List<Gtk.TreeRowReference> result = find_file_rows (files, dir);
        if (result == null) {
            return null;
        } else {
            return result.data;
        }
    }

    public GLib.List<Gtk.TreeRowReference> find_file_rows (GLib.Sequence<GOF.File> files, GOF.Directory.Async? dir = null) {
        files.sort (file_match_func);  /* Sort in same order as model */

        GLib.List<Gtk.TreeRowReference> rows_found = null;

        GLib.SequenceIter<GOF.File> seq_iter = files.get_begin_iter ();
        while (!seq_iter.is_end ()) {
            GOF.File file_a = seq_iter.@get ();
            @foreach ((model, path, iter) => {
                GOF.File? file_b = null;
                model.@get (iter, FM.ColumnID.FILE_COLUMN, out file_b);
                if (file_a.location.equal (file_b.location)) {
                    var row_ref = new Gtk.TreeRowReference (model, path);
                    rows_found.prepend (row_ref);
                    seq_iter = seq_iter.next ();
                    if (seq_iter.is_end ()) {
                        return true;
                    } else {
                        file_a = seq_iter.@get ();
                    }
                }

                return false;
            });

            seq_iter = seq_iter.next (); /* file was not in model */
        }

        return (owned)rows_found;
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

    public new void get_value (Gtk.TreeIter iter, int column, out Value return_value) {
        Value file_value;
        get_value (iter, ColumnID.FILE_COLUMN, out file_value);
        if (column == ColumnID.FILE_COLUMN) {
            return_value = file_value;
        } else {
            critical ("Invalid column request in get_value ()");
            return_value = Value (GLib.Type.INVALID);
        }

        return;
    }

//    private void add_dummy_row (FM.FileEntry parent_entry) {
//        var dummy_file_entry = new FM.FileEntry ();
//        dummy_file_entry.parent = parent_entry;
//        dummy_file_entry.seq = parent_entry.files.insert_sorted (dummy_file_entry, file_entry_compare_func);

//        var iter = Gtk.TreeIter ();
//        iter.stamp = stamp;
//        iter.user_data = dummy_file_entry.seq;

//        row_inserted (get_path (iter), iter);
//    }
}
}
