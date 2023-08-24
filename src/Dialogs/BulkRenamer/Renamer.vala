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
    public bool can_rename { get; set; default = false; }
    public string directory { get; private set; default = ""; }
    public Gee.ArrayList<RenamerModifier> modifier_chain { get; construct; }
    public Gtk.ListBox listbox { get; private set; }
    public SortBy sortby { get; set; default = SortBy.NAME; }

    construct {
        modifier_chain = new Gee.ArrayList<RenamerModifier> ();

        listbox = new Gtk.ListBox () {
            can_focus = false,
            selection_mode = Gtk.SelectionMode.NONE,
            hexpand = true,
            vexpand = true
        };
        listbox.set_sort_func (sort_func);
        listbox.invalidate_sort ();

        notify["sortby"].connect (listbox.invalidate_sort);
    }

    public void add_files (List<Files.File> files) {
        if (files == null) {
            return;
        }

        if (directory == "") {
            directory = Path.get_dirname (files.first ().data.location.get_path ());
        }

        foreach (unowned var f in files) {
            var path = f.location.get_path ();
            var dir = Path.get_dirname (path);
            if (dir == directory) {
                f.ensure_query_info ();
                var row = new RenamerListRow (f);
                listbox.append (row);
                row.new_name = Path.get_basename (path);
            }
        }
    }

    public void rename_files () {
        var child = listbox.get_first_child ();
        while (child != null) {
            var row = (RenamerListRow)child;
            unowned string output_name = row.new_name;
            var file = row.file;

            /* Ignore files that will not be renamed */
            if (file != null && file.location.get_basename () != output_name) {
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

            child = child.get_next_sibling ();
        }
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

    private bool invalid_name (string new_name, Files.File old_file) {
        var new_file = GLib.File.new_for_path (
            Path.build_filename (old_file.location.get_parent ().get_path (), new_name)
        );

        return !old_file.location.equal (new_file) && new_file.query_exists ();
    }

    private uint update_timeout_id = 0;
    private bool updating = false;
    public void schedule_update (string? custom_basename, string? replacement_text) {
        if (update_timeout_id > 0) {
            Source.remove (update_timeout_id);
        }

        update_timeout_id = Timeout.add (250, () => {
            if (updating) {
                return Source.CONTINUE;
            }

            update_timeout_id = 0;
            update_new_filenames (custom_basename, replacement_text);

            return Source.REMOVE;
        });
    }

    private void update_new_filenames (string? custom_basename, string? replacement_text) {
        updating = true;

        string previous_final_name = "";
        bool has_invalid = false;

        /* Apply basename to each item */
        var child = listbox.get_first_child ();
        var n_children = 0;
        while (child != null) {
            n_children++;
            var row = (RenamerListRow)child;
            string input_name = "";
            string extension = "";
            if (custom_basename != null && replacement_text == null) {
                input_name = custom_basename;
            } else {
                input_name = strip_extension (row.old_name, out extension);
                row.extension = extension;
            }

            if (replacement_text != null && custom_basename != null && custom_basename != "") {
                input_name = input_name.replace (custom_basename, replacement_text);
            }

            row.new_name = input_name;

            child = child.get_next_sibling ();
        }

        /* Apply each modifier to each item (in required order) */
        foreach (var mod in modifier_chain) {
            uint index = mod.is_reversed ? n_children - 1 : 0;
            int incr = mod.is_reversed ? -1 : 1;
            child = listbox.get_first_child ();
            while (child != null) {
                var row = (RenamerListRow)child;
                row.new_name = mod.rename (row.new_name, index, row.file);
                index += incr;

                child = child.get_next_sibling ();
            }
        }

        /* Reapply extension and check validity */
        child = listbox.get_first_child ();
        while (child != null) {
            var row = (RenamerListRow)child;
            row.new_name = row.new_name.concat (row.extension);
            if (row.new_name == previous_final_name ||
                invalid_name (row.new_name, row.file)) {

                row.status = RenameStatus.INVALID;
                has_invalid = true;
            } else if (row.new_name == row.old_name) {
                row.status = RenameStatus.IGNORED;
            } else {
                row.status = RenameStatus.VALID;
            }

            previous_final_name = row.new_name;

            child = child.get_next_sibling ();
        }

        can_rename = !has_invalid;
        updating = false;
    }

    private int sort_func (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        var file1 = ((RenamerListRow)row1).file;
        var file2 = ((RenamerListRow)row2).file;
        switch (sortby) {
            case SortBy.CREATED:
                return file1.compare_files_by_created (file2);
            case SortBy.MODIFIED:
                return file1.compare_files_by_time (file2);
            case SortBy.SIZE:
                return file1.compare_files_by_size (file2);
            default:
                return file1.compare_by_display_name (file2);
        }
    }
}
