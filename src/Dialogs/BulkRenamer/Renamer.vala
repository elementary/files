/*
 * Copyright (C) 2010-2017  Vartan Belavejian
 * Copyright (C) 2019-2022  elementary LLC. <https://elementary.io>
 *
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Authors:
 *  Vartan Belavejian <https://github.com/VartanBelavejian>
 *  Jeremy Wootten <jeremywootten@gmail.com>
 *
*/

public class Files.Renamer : Object {
    private const string QUERY_INFO_STRING = FileAttribute.STANDARD_TARGET_URI + "," +
                                             FileAttribute.TIME_CREATED + "," +
                                             FileAttribute.TIME_MODIFIED;

    public bool can_rename { get; set; default = false; }
    public string directory { get; private set; default = ""; }
    public Gtk.ListStore old_files_model { get; construct; }
    public Gtk.ListStore new_files_model { get; construct; }
    public Gee.ArrayList<RenamerModifier> modifier_chain { get; construct; }

    private Gee.HashMap<string, Files.File> file_map;
    private Gee.HashMap<string, FileInfo> file_info_map;
    private Mutex info_map_mutex;
    public SortBy sortby { get; set; default = SortBy.NAME; }
    public bool is_reversed { get; set; default = false; }

    construct {
        info_map_mutex = Mutex ();
        can_rename = false;
        file_map = new Gee.HashMap<string, Files.File> ();
        file_info_map = new Gee.HashMap<string, FileInfo> ();
        modifier_chain = new Gee.ArrayList<RenamerModifier> ();
        old_files_model = new Gtk.ListStore (1, typeof (string));
        set_sort ();
        old_files_model.set_sort_column_id (Gtk.SortColumn.DEFAULT, Gtk.SortType.ASCENDING);
        new_files_model = new Gtk.ListStore (2, typeof (string), typeof (bool));

        notify["is-reversed"].connect (set_sort);
        notify["sortby"].connect (set_sort);
    }

    private void set_sort () {
        old_files_model.set_default_sort_func (old_files_model_sorter);
    }

    public void add_files (List<Files.File> files) {
        if (files == null) {
            return;
        }

        if (directory == "") {
            directory = Path.get_dirname (files.first ().data.location.get_path ());
        }

        Gtk.TreeIter? iter = null;
        foreach (unowned var f in files) {
            var path = f.location.get_path ();
            var dir = Path.get_dirname (path);
            if (dir == directory) {
                var basename = Path.get_basename (path);
                file_map.@set (basename, f);
                old_files_model.append (out iter);
                old_files_model.set (iter, 0, basename);

                f.location.query_info_async.begin (
                    QUERY_INFO_STRING,
                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                    Priority.DEFAULT,
                    null, /* No cancellable for now */
                    (object, res) => {
                        try {
                            var info = f.location.query_info_async.end (res);
                            info_map_mutex.@lock ();
                            file_info_map.@set (basename, info.dup ());
                            info_map_mutex.@unlock ();
                        } catch (Error e) {
                            warning ("Error querying info %s", e.message);
                        }
                    }
                );
            }
        }

        old_files_model.set_default_sort_func (old_files_model_sorter);
    }

    public void rename_files () {
        old_files_model.@foreach ((m, p, i) => {
            string input_name = "";
            string output_name = "";
            Gtk.TreeIter? iter = null;
            old_files_model.get_iter (out iter, p);
            old_files_model.@get (iter, 0, out input_name);
            new_files_model.get_iter (out iter, p);
            new_files_model.@get (iter, 0, out output_name);
            var file = file_map.@get (input_name);

            if (file != null) {
                Files.FileUtils.set_file_display_name.begin (
                    file.location,
                    output_name,
                    null,
                    (obj, res) => {
                        try {
                            Files.FileUtils.set_file_display_name.end (res);
                        } catch (Error e) {} // Warning dialog already shown
                    }
                );
            }

            return false; /* Continue iteration (compare HashMap iterator which is opposite!) */
        });
    }

    private string strip_extension (string filename, out string extension) {
        var extension_pos = filename.last_index_of_char ('.', 0);
        if (filename.length < 4 || extension_pos < filename.length - 4) {
            extension = "";
            return filename;
        } else {
            extension = filename [extension_pos : filename.length];
            return filename [0 : extension_pos];
        }
    }

    public int old_files_model_sorter (Gtk.TreeModel m, Gtk.TreeIter a, Gtk.TreeIter b) {
        int res = 0;
        string name_a = "";
        string name_b = "";
        m.@get (a, 0, out name_a);
        m.@get (b, 0, out name_b);

        switch (sortby) {
            case SortBy.NAME:
                res = name_a.collate (name_b);
                break;

            case SortBy.CREATED:
                var time_a = file_info_map.@get (name_a).get_attribute_uint64 (FileAttribute.TIME_CREATED);
                var time_b = file_info_map.@get (name_b).get_attribute_uint64 (FileAttribute.TIME_CREATED);

                if (time_a == time_b) {
                    res = name_a.collate (name_b);
                } else {
                    res = time_a > time_b ? 1 : -1;
                }

                break;

            case SortBy.MODIFIED:
                var time_a = file_info_map.@get (name_a).get_attribute_uint64 (FileAttribute.TIME_MODIFIED);
                var time_b = file_info_map.@get (name_b).get_attribute_uint64 (FileAttribute.TIME_MODIFIED);

                if (time_a == time_b) {
                    res = name_a.collate (name_b);
                } else {
                    res = time_a > time_b ? 1 : -1;
                }

                break;

            default:
                assert_not_reached ();
        }

        if (is_reversed) {
            res = -res;
        }

        return res;
    }

    private bool invalid_name (string new_name, string input_name) {
        var old_file = file_map.@get (input_name);
        if (old_file == null) {
            return true;
        }

        var new_file = GLib.File.new_for_path (
            Path.build_filename (old_file.location.get_parent ().get_path (), new_name)
        );

        if (new_file.query_exists ()) {
            return true;
        }

        return false;
    }

    private uint update_timeout_id = 0;
    public void schedule_update (string? custom_basename = null) {
        if (update_timeout_id > 0) {
            Source.remove (update_timeout_id);
        }

        update_timeout_id = Timeout.add (250, () => {
            if (updating) {
                return Source.CONTINUE;
            }

            update_timeout_id = 0;
            update_new_filenames (custom_basename);

            return Source.REMOVE;
        });
    }

    private bool updating = false;
    private void update_new_filenames (string? custom_basename) {
        updating = true;
        can_rename = true;
        int index = 0;
        string output_name = "";
        string input_name = "";
        string file_name = "";
        string extension = "";
        string previous_final_name = "";

        new_files_model.clear ();

        Gtk.TreeIter? new_iter = null;
        old_files_model.@foreach ((m, p, iter) => {
            old_files_model.@get (iter, 0, out file_name);

            if (custom_basename != null) {
                input_name = custom_basename;
            } else {
                input_name = strip_extension (file_name, out extension);
            }

            foreach (var mod in modifier_chain) {
                output_name = mod.rename (input_name, index);
                input_name = output_name;
            }

            var final_name = output_name.concat (extension);
            bool name_invalid = false;

            if (final_name == previous_final_name ||
                final_name == file_name ||
                invalid_name (final_name, file_name)) {

                debug ("blank or duplicate or existing filename");
                name_invalid = true;
                can_rename = false;
            }

            new_files_model.append (out new_iter);
            new_files_model.@set (new_iter, 0, final_name, 1, name_invalid);

            previous_final_name = final_name;
            index++;
            return false;
        });

        updating = false;
    }
}
