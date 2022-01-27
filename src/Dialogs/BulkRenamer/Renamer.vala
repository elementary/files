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
    public Gee.ArrayList<RenamerModifier> modifier_chain { get; construct; }
    public RenamerListBox listbox { get; construct; }

    private Gee.HashMap<string, Files.File> file_map;
    private Gee.HashMap<string, RenamerListBox.RenamerListRow> basename_row_map;
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

        listbox = new RenamerListBox ();

        notify["is-reversed"].connect (set_sort);
        notify["sortby"].connect (set_sort);
    }

    private void set_sort () {
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
                var row = listbox.add_file (f);
                basename_row_map.@set (basename, row);

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
    }

    public void rename_files () {
        listbox.get_children ().@foreach ((child) => {
            var row = (RenamerListBox.RenamerListRow)child;
            unowned string input_name = row.old_name;
            unowned string output_name = row.new_name;
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
    public void schedule_update (string? custom_basename) {
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

        listbox.get_children ().@foreach ((child) => {
            var row = (RenamerListBox.RenamerListRow)child;
            file_name = row.old_name;
            var file = file_map.@get (file_name);

            if (custom_basename != null) {
                input_name = custom_basename;
            } else {
                input_name = strip_extension (file_name, out extension);
            }

            foreach (var mod in modifier_chain) {
                output_name = mod.rename (input_name, index, file);
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

            row.new_name = final_name;
            previous_final_name = final_name;
            index++;
        });

        updating = false;
    }
}
