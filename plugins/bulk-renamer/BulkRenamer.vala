/*
 * Copyright (C) 2010-2017  Vartan Belavejian
 * Copyright (C) 2019-2020     Jeremy Wootten
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

public class Files.Renamer : Gtk.Grid {
    private Gee.HashMap<string, GLib.File> file_map;
    private Gee.HashMap<string, FileInfo> file_info_map;
    private Gee.ArrayList<Modifier> modifier_chain;

    private Gtk.Grid modifier_grid;
    private Gtk.ListBox modifier_listbox;

    private Gtk.TreeView old_file_names;
    private Gtk.TreeView new_file_names;
    private Gtk.ListStore old_list;
    private Gtk.ListStore new_list;
    private Icon invalid_icon;

    private Gtk.Entry base_name_entry;
    private Gtk.ComboBoxText base_name_combo;
    private Gtk.Switch sort_type_switch;
    private Gtk.ComboBoxText sort_by_combo;

    private Mutex info_map_mutex;

    private int number_of_files = 0;

    public bool can_rename { get; set; default = false; }

    public string directory { get; private set; default = ""; }

    public Renamer (GLib.File[]? files = null) {
        if (files != null) {
            add_files (files);
        }
    }

    construct {
        info_map_mutex = Mutex ();
        invalid_icon = new ThemedIcon.with_default_fallbacks ("dialog-warning");
        can_rename = false;
        orientation = Gtk.Orientation.VERTICAL;
        directory = "";

        file_map = new Gee.HashMap<string, GLib.File> ();
        file_info_map = new Gee.HashMap<string, FileInfo> ();
        modifier_chain = new Gee.ArrayList<Modifier> ();

        var base_name_label = new Granite.HeaderLabel (_("Base"));
        base_name_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        base_name_combo = new Gtk.ComboBoxText () {
            valign = Gtk.Align.CENTER
        };
        base_name_combo.insert (RenameBase.ORIGINAL, "ORIGINAL", RenameBase.ORIGINAL.to_string ());
        base_name_combo.insert (RenameBase.CUSTOM, "CUSTOM", RenameBase.CUSTOM.to_string ());

        base_name_entry = new Gtk.Entry () {
            placeholder_text = _("Enter naming scheme"),
            hexpand = false,
            max_width_chars = 64,
            valign = Gtk.Align.CENTER
        };

        var base_name_entry_revealer = new Gtk.Revealer () {
            vexpand = false
        };
        base_name_entry_revealer.add (base_name_entry);

        var sort_by_label = new Gtk.Label (_("Sort by:"));

        sort_by_combo = new Gtk.ComboBoxText () {
            valign = Gtk.Align.CENTER,
            margin = 3
        };
        sort_by_combo.insert (RenameSortBy.NAME, "NAME", RenameSortBy.NAME.to_string ());
        sort_by_combo.insert (RenameSortBy.CREATED, "CREATED", RenameSortBy.CREATED.to_string ());
        sort_by_combo.insert (RenameSortBy.MODIFIED, "MODIFIED", RenameSortBy.MODIFIED.to_string ());
        sort_by_combo.set_active (RenameSortBy.NAME);

        var sort_by_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.HORIZONTAL,
            column_spacing = 6,
            halign = Gtk.Align.END,
            valign = Gtk.Align.CENTER
        };
        sort_by_grid.add (sort_by_label);
        sort_by_grid.add (sort_by_combo);

        var sort_type_label = new Gtk.Label (_("Reverse"));

        sort_type_switch = new Gtk.Switch () {
            valign = Gtk.Align.CENTER
        };

        var sort_type_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.HORIZONTAL,
            column_spacing = 6,
            halign = Gtk.Align.END,
            valign = Gtk.Align.CENTER,
            margin = 3
        };
        sort_type_grid.add (sort_type_switch);
        sort_type_grid.add (sort_type_label);

        var controls_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.HORIZONTAL,
            column_spacing = 12,
            margin_bottom = 12
        };

        controls_grid.attach (base_name_label, 0, 0, 2, 1);
        controls_grid.attach (base_name_combo, 0, 1, 1, 1);
        controls_grid.attach (base_name_entry_revealer, 1, 1, 1, 1);

        var modifiers_label = new Granite.HeaderLabel (_("Modifiers"));
        modifiers_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        modifier_listbox = new Gtk.ListBox ();

        var add_button = new Gtk.MenuButton () {
            valign = Gtk.Align.CENTER,
            image = new Gtk.Image.from_icon_name ("add", Gtk.IconSize.DND),
            tooltip_text = _("Add another modifier"),
            sensitive = true
        };
        add_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var action_bar = new Gtk.ActionBar () {
            margin_top = 12
        };
        action_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
        action_bar.pack_start (add_button);

        modifier_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL,
            margin_bottom = 12,
            row_spacing = 0
        };
        modifier_grid.add (modifiers_label);
        modifier_grid.add (modifier_listbox);
        modifier_grid.add (action_bar);

        var cell = new Gtk.CellRendererText () {
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            wrap_mode = Pango.WrapMode.CHAR,
            width_chars = 64
        };

        old_list = new Gtk.ListStore (1, typeof (string));
        old_list.set_default_sort_func (old_list_sorter);
        old_list.set_sort_column_id (Gtk.SortColumn.DEFAULT, Gtk.SortType.ASCENDING);

        old_file_names = new Gtk.TreeView.with_model (old_list) {
            hexpand = true,
            headers_visible = false
        };
        old_file_names.insert_column_with_attributes (-1, "ORIGINAL", cell, "text", 0);

        var original_label = new Granite.HeaderLabel (_("Original Names")) {
            valign = Gtk.Align.CENTER
        };
        original_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        var old_files_header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        old_files_header.add (original_label);

        old_files_header.pack_end (sort_type_grid, false, false, 6);
        old_files_header.pack_end (sort_by_grid, false, false, 6);

        var old_scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hexpand = true,
            min_content_height = 300,
            max_content_height = 2000
        };

        old_scrolled_window.add (old_file_names);


        var vadj = old_scrolled_window.get_vadjustment ();

        var old_files_grid = new Gtk.Grid () {
            valign = Gtk.Align.START,
            orientation = Gtk.Orientation.VERTICAL
        };
        old_files_grid.add (old_files_header);
        old_files_grid.add (old_scrolled_window);

        var invalid_renderer = new Gtk.CellRendererPixbuf () {
            gicon = invalid_icon,
            visible =false,
            xalign = 1.0f
        };

        var new_cell = new Gtk.CellRendererText () {
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            wrap_mode = Pango.WrapMode.CHAR,
            width_chars = 64
        };

        new_list = new Gtk.ListStore (2, typeof (string), typeof (bool));
        new_file_names = new Gtk.TreeView.with_model (new_list);
        var text_col = new Gtk.TreeViewColumn.with_attributes (
            "NEW", new_cell,
            "text", 0
        );

        text_col.set_cell_data_func (new_cell, (col, cell, model, iter) => {
            bool invalid;
            model.@get (iter, 1, out invalid);
            new_cell.sensitive = !invalid;
        });

        new_file_names.insert_column (text_col, 0);

        new_file_names.insert_column_with_attributes (
            -1, "VALID", invalid_renderer,
            "visible", 1
        );
        new_file_names.headers_visible = false;

        var new_scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hexpand = true,
            vadjustment = vadj,
            min_content_height = 300,
            max_content_height = 2000,
            overlay_scrolling = true
        };

        new_scrolled_window.add (new_file_names);
        new_scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.EXTERNAL);

        var new_files_header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var new_label = new Granite.HeaderLabel (_("New Names"));
        new_label.get_style_context (). add_class (Granite.STYLE_CLASS_H2_LABEL);
        new_files_header.add (new_label);

        var new_files_grid = new Gtk.Grid () {
            valign = Gtk.Align.END,
            orientation = Gtk.Orientation.VERTICAL
        };
        new_files_grid.add (new_files_header);
        new_files_grid.add (new_scrolled_window);

        var lists_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.HORIZONTAL,
            column_spacing = 32,
            column_homogeneous = true,
            margin = 12
        };
        lists_grid.add (old_files_grid);
        lists_grid.add (new_files_grid);

        add (controls_grid);
        add (modifier_grid);
        add (lists_grid);

        reset ();

        sort_by_combo.changed.connect (() => {
            old_list.set_default_sort_func (old_list_sorter);

            schedule_view_update ();
        });

        sort_type_switch.notify ["active"].connect (() => {
            old_list.set_default_sort_func (old_list_sorter);
            schedule_view_update ();
        });

        base_name_combo.changed.connect (() => {
            base_name_entry_revealer.reveal_child = base_name_combo.get_active () == RenameBase.CUSTOM;
            schedule_view_update ();
        });

        base_name_entry.changed.connect (() => {
            schedule_view_update ();
        });

        add_button.clicked.connect (() => {
            add_modifier (true);
        });

        add_modifier (false);

        show_all ();
    }

    public void add_files (GLib.File[] files) {
        if (files.length < 1 || files[0] == null) {
            return;
        }

        if (directory == "") {
            directory = Path.get_dirname (files[0].get_path ());
        }

        string query_info_string = string.join (",", FileAttribute.STANDARD_TARGET_URI,
                                                     FileAttribute.TIME_CREATED,
                                                     FileAttribute.TIME_MODIFIED);
        Gtk.TreeIter? iter = null;
        foreach (unowned var f in files) {
            var path = f.get_path ();
            var dir = Path.get_dirname (path);
            if (dir == directory) {
                var basename = Path.get_basename (path);
                file_map.@set (basename, f);
                old_list.append (out iter);
                old_list.set (iter, 0, basename);
                number_of_files++;

                f.query_info_async.begin (query_info_string,
                                          FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                                          Priority.DEFAULT,
                                          null, /* No cancellable for now */
                                          (object, res) => {

                    try {
                        var info = f.query_info_async.end (res);
                        info_map_mutex.@lock ();
                        file_info_map.@set (basename, info.dup ());
                        info_map_mutex.@unlock ();
                    } catch (Error e) {
                        warning ("Error querying info %s", e.message);
                    }
                });

            }
        }

        old_list.set_default_sort_func (old_list_sorter);
        schedule_view_update ();
    }

    public void add_modifier (bool allow_remove) {
        var mod = new Modifier (allow_remove);
        modifier_chain.add (mod);
        modifier_listbox.add (mod);
        mod.update_request.connect (schedule_view_update);
        mod.remove_request.connect (() => {
            modifier_chain.remove (mod);
            mod.destroy ();
            queue_draw ();
            schedule_view_update ();
        });

        schedule_view_update ();
    }

    public void reset () {
        base_name_combo.set_active (RenameBase.ORIGINAL);
        base_name_entry.text = "";

        bool first = true;
        foreach (var mod in modifier_chain) {
            if (first) {
                mod.reset ();
                first = false;
            } else {
                mod.destroy ();
            }
        }

        schedule_view_update ();
    }

    public void set_sort_order (RenameSortBy sort_by, bool reversed) {
        sort_by_combo.set_active (sort_by);
        sort_type_switch.active = reversed;
    }

    public void set_base_name (string? base_name) {
        if (base_name != null) {
            base_name_combo.set_active (RenameBase.CUSTOM);
            base_name_entry.text = base_name;
        } else {
            base_name_combo.set_active (RenameBase.ORIGINAL);
            base_name_entry.text = "";
        }
    }

    public void rename_files () {
        old_list.@foreach ((m, p, i) => {
            string input_name = "";
            string output_name = "";
            Gtk.TreeIter? iter = null;
            old_list.get_iter (out iter, p);
            old_list.@get (iter, 0, out input_name);
            new_list.get_iter (out iter, p);
            new_list.@get (iter, 0, out output_name);
            var file = file_map.@get (input_name);

            if (file != null) {
                    Files.FileUtils.set_file_display_name.begin (file, output_name, null, (obj, res) => {
                        try {
                            Files.FileUtils.set_file_display_name.end (res);
                        } catch (Error e) {} // Warning dialog already shown
                    });
            }

            return false; /* Continue iteration (compare HashMap iterator which is opposite!) */
        });
    }

    private uint view_update_timeout_id = 0;
    private void schedule_view_update () {
        if (view_update_timeout_id > 0) {
            Source.remove (view_update_timeout_id);
        }

        view_update_timeout_id = Timeout.add (250, () => {
            if (updating) {
                return Source.CONTINUE;
            }

            view_update_timeout_id = 0;
            update_view ();

            return Source.REMOVE;
        });
    }

    private bool updating = false;
    private void update_view () {
        updating = true;
        can_rename = true;
        int index = 0;
        string output_name = "";
        string input_name = "";
        string file_name = "";
        string extension = "";
        string previous_final_name = "";

        new_list.clear ();

        bool custom_basename = base_name_combo.get_active () == RenameBase.CUSTOM;
        Gtk.TreeIter? new_iter = null;
        old_list.@foreach ((m, p, iter) => {
            old_list.@get (iter, 0, out file_name);

            if (custom_basename) {
                input_name = base_name_entry.get_text ();
            } else {
                input_name = strip_extension (file_name, out extension);
            }

            foreach (Modifier mod in modifier_chain) {
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

            new_list.append (out new_iter);
            new_list.@set (new_iter, 0, final_name, 1, name_invalid);

            previous_final_name = final_name;
            index++;
            return false;
        });

        updating = false;
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

    public int old_list_sorter (Gtk.TreeModel m, Gtk.TreeIter a, Gtk.TreeIter b) {
        int res = 0;
        string name_a = "";
        string name_b = "";
        m.@get (a, 0, out name_a);
        m.@get (b, 0, out name_b);

        switch (sort_by_combo.get_active ()) {
            case RenameSortBy.NAME:
                res = name_a.collate (name_b);
                break;

            case RenameSortBy.CREATED:
                var time_a = file_info_map.@get (name_a).get_attribute_uint64 (FileAttribute.TIME_CREATED);
                var time_b = file_info_map.@get (name_b).get_attribute_uint64 (FileAttribute.TIME_CREATED);

                if (time_a == time_b) {
                    res = name_a.collate (name_b);
                } else {
                    res = time_a > time_b ? 1 : -1;
                }

                break;

            case RenameSortBy.MODIFIED:
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

        if (sort_type_switch.active) {
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
            Path.build_filename (old_file.get_parent ().get_path (), new_name)
        );

        if (new_file.query_exists ()) {
            return true;
        }

        return false;
    }
}
