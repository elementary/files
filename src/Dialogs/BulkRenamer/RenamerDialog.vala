/*
 * Copyright (C) 2010-2017  Vartan Belavejian
 * Copyright (C) 2019-2020 Jeremy Wootten
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

namespace Files {
    public enum RenameMode {
        TEXT,
        NUMBER,
        DATETIME,
        INVALID;

        public string to_string () {
            switch (this) {
                case RenameMode.NUMBER:
                    return _("Number sequence");

                case RenameMode.TEXT:
                    return _("Text");

                case RenameMode.DATETIME:
                    return _("Date");

                default:
                    assert_not_reached ();
            }
        }
    }

    public enum RenamePosition {
        SUFFIX,
        PREFIX,
        REPLACE;

        public string to_string () {
            switch (this) {
                case RenamePosition.SUFFIX:
                    return _("Suffix");

                case RenamePosition.PREFIX:
                    return _("Prefix");

                case RenamePosition.REPLACE:
                    return _("Replace");

                default:
                    assert_not_reached ();
            }
        }

        public string to_placeholder () {
            switch (this) {
                case RenamePosition.SUFFIX:
                    return _("Text to put at the end");

                case RenamePosition.PREFIX:
                    return _("Text to put at the start");

                case RenamePosition.REPLACE:
                    return _("Text to replace the target");

                default:
                    assert_not_reached ();
            }
        }
    }

    public enum RenameSortBy {
        NAME,
        CREATED,
        MODIFIED;

        public string to_string () {
            switch (this) {
                case RenameSortBy.NAME:
                    return _("Name");

                case RenameSortBy.CREATED:
                    return _("Creation Date");

                case RenameSortBy.MODIFIED:
                    return _("Last modification date");

                default:
                    assert_not_reached ();
            }
        }
    }

    public enum RenameDateFormat {
        DEFAULT_DATE,
        DEFAULT_DATETIME,
        LOCALE,
        ISO_DATE,
        ISO_DATETIME;

        public string to_string () {
            switch (this) {
                case RenameDateFormat.DEFAULT_DATE:
                    return _("Default Format - Date only");
                case RenameDateFormat.DEFAULT_DATETIME:
                    return _("Default Format - Date and Time");
                case RenameDateFormat.LOCALE:
                    return _("Locale Format - Date and Time");
                case RenameDateFormat.ISO_DATE:
                    return _("ISO 8601 Format - Date only");
                case RenameDateFormat.ISO_DATETIME:
                    return _("ISO 8601 Format - Date and Time");
                default:
                    assert_not_reached ();
            }
        }
    }

    public enum RenameDateType {
        NOW,
        CHOOSE;

        public string to_string () {
            switch (this) {
                case RenameDateType.NOW:
                    return _("Current Date");
                case RenameDateType.CHOOSE:
                    return _("Choose a date");
                default:
                    assert_not_reached ();
            }
        }
    }

    public enum RenameBase {
        ORIGINAL,
        CUSTOM;

        public string to_string () {
            switch (this) {
                case RenameBase.ORIGINAL:
                    return _("Original filename");
                case RenameBase.CUSTOM:
                    return _("Enter a base name");
                default:
                    assert_not_reached ();
            }
        }
    }
}

public class Files.RenamerDialog : Gtk.Dialog {
    private Files.Renamer renamer;
    private Gtk.ListBox modifiers_listbox;
    private Gtk.Entry base_name_entry;
    private Gtk.ComboBoxText base_name_combo;
    private Gtk.Switch sort_type_switch;
    private Gtk.ComboBoxText sort_by_combo;

    public RenamerDialog (List<Files.File> files, string? basename = null) {
        if (basename != null) {
            base_name_combo.set_active (RenameBase.CUSTOM);
            base_name_entry.text = basename;
        } else {
            base_name_combo.set_active (RenameBase.ORIGINAL);
            base_name_entry.text = "";
        }

        renamer.add_files (files);
    }

    construct {
        deletable = true;
        set_title (_("Bulk Renamer"));
        renamer = new Renamer ();
        renamer.sortby = RenameSortBy.NAME;
        renamer.is_reversed = false;

        /* Dialog actions */
        var rename_button = add_button (_("Rename"), Gtk.ResponseType.APPLY);
        rename_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        renamer.bind_property ("can-rename",
                                rename_button, "sensitive",
                                GLib.BindingFlags.DEFAULT | GLib.BindingFlags.SYNC_CREATE);

        var cancel_button = add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        /* Dialog content */
        /* Base name */
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

        /* Modifiers */
        var modifiers_label = new Granite.HeaderLabel (_("Modifiers"));
        modifiers_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        modifiers_listbox = new Gtk.ListBox ();

        var modifier_add_button = new Gtk.MenuButton () {
            valign = Gtk.Align.CENTER,
            image = new Gtk.Image.from_icon_name ("add", Gtk.IconSize.DND),
            tooltip_text = _("Add another modifier"),
            sensitive = true
        };
        modifier_add_button.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        var modifiers_action_bar = new Gtk.ActionBar () {
            margin_top = 12
        };
        modifiers_action_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_INLINE_TOOLBAR);
        modifiers_action_bar.pack_start (modifier_add_button);

        /* Old filename list */
        var cell = new Gtk.CellRendererText () {
            ellipsize = Pango.EllipsizeMode.MIDDLE,
            wrap_mode = Pango.WrapMode.CHAR,
            width_chars = 64
        };
        var old_file_names = new Gtk.TreeView.with_model (renamer.old_files_model) {
            hexpand = true,
            headers_visible = false
        };
        old_file_names.insert_column_with_attributes (
            -1,
            "ORIGINAL",
            new Gtk.CellRendererText () {
                ellipsize = Pango.EllipsizeMode.MIDDLE,
                wrap_mode = Pango.WrapMode.CHAR,
                width_chars = 64
            },
            "text",
            0
        );

        /* Old filenames header */
        var original_label = new Granite.HeaderLabel (_("Original Names")) {
            valign = Gtk.Align.CENTER
        };
        original_label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);

        var sort_by_label = new Gtk.Label (_("Sort by:"));
        sort_by_combo = new Gtk.ComboBoxText () {
            valign = Gtk.Align.CENTER,
            margin = 3
        };
        sort_by_combo.insert (RenameSortBy.NAME, "NAME", RenameSortBy.NAME.to_string ());
        sort_by_combo.insert (RenameSortBy.CREATED, "CREATED", RenameSortBy.CREATED.to_string ());
        sort_by_combo.insert (RenameSortBy.MODIFIED, "MODIFIED", RenameSortBy.MODIFIED.to_string ());
        sort_by_combo.set_active (RenameSortBy.NAME);
        var sort_by_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            halign = Gtk.Align.END,
            valign = Gtk.Align.CENTER
        };
        sort_by_box.pack_start (sort_by_label);
        sort_by_box.pack_start (sort_by_combo);

        var sort_type_label = new Gtk.Label (_("Reverse"));
        sort_type_switch = new Gtk.Switch () {
            valign = Gtk.Align.CENTER
        };
        var sort_type_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            halign = Gtk.Align.END,
            valign = Gtk.Align.CENTER,
            margin = 3
        };
        sort_type_box.pack_start (sort_type_switch);
        sort_type_box.pack_start (sort_type_label);

        var old_files_header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        old_files_header.pack_start (original_label);
        old_files_header.pack_end (sort_type_box);
        old_files_header.pack_end (sort_by_box);

        var old_scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hexpand = true,
            min_content_height = 300,
            max_content_height = 2000
        };
        old_scrolled_window.add (old_file_names);

        var old_files_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            valign = Gtk.Align.START,
        };
        old_files_box.pack_start (old_files_header);
        old_files_box.pack_start (old_scrolled_window);

        /* New filename list */
        var new_cell = new Gtk.CellRendererPixbuf () {
            gicon = new ThemedIcon.with_default_fallbacks ("dialog-warning"),
            visible =false,
            xalign = 1.0f
        };
        var text_col = new Gtk.TreeViewColumn.with_attributes (
            "NEW",
            new Gtk.CellRendererText () {
                ellipsize = Pango.EllipsizeMode.MIDDLE,
                wrap_mode = Pango.WrapMode.CHAR,
                width_chars = 64
            },
            "text",
            0
        );
        var new_file_names = new Gtk.TreeView.with_model (renamer.new_files_model) {
            headers_visible = false
        };
        new_file_names.insert_column (text_col, 0);
        new_file_names.insert_column_with_attributes (
            -1,
            "VALID",
            new_cell,
            "visible",
            1
        );
        text_col.set_cell_data_func (new_cell, (col, new_cell, model, iter) => {
            bool invalid;
            model.@get (iter, 1, out invalid);
            new_cell.sensitive = !invalid;
        });

        var new_scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hexpand = true,
            vadjustment = old_scrolled_window.get_vadjustment (),
            min_content_height = 300,
            max_content_height = 2000,
            overlay_scrolling = true
        };

        new_scrolled_window.add (new_file_names);
        new_scrolled_window.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.EXTERNAL);

        /* New filenames header */
        var new_files_header = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var new_label = new Granite.HeaderLabel (_("New Names"));
        new_label.get_style_context (). add_class (Granite.STYLE_CLASS_H2_LABEL);
        new_files_header.add (new_label);

        var new_files_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            valign = Gtk.Align.END,
        };
        new_files_box.pack_start (new_files_header);
        new_files_box.pack_start (new_scrolled_window);

        /* Assemble content */
        var controls_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.HORIZONTAL,
            column_spacing = 12,
            margin_bottom = 12
        };
        controls_grid.attach (base_name_label, 0, 0, 2, 1);
        controls_grid.attach (base_name_combo, 0, 1, 1, 1);
        controls_grid.attach (base_name_entry_revealer, 1, 1, 1, 1);

        var modifiers_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0) {
            margin_bottom = 12
        };
        modifiers_box.pack_start (modifiers_label);
        modifiers_box.pack_start (modifiers_listbox);
        modifiers_box.pack_start (modifiers_action_bar);
        var lists_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 32) {
            homogeneous = true,
        };
        lists_box.pack_start (old_files_box);
        lists_box.pack_start (new_files_box);

        var content_box = get_content_area ();
        content_box.pack_start (controls_grid);
        content_box.pack_start (modifiers_box);
        content_box.pack_start (lists_box);
        content_box.margin = 12;
        content_box.show_all ();
        reset ();

        /* Connect signals */
        sort_by_combo.changed.connect (() => {
            renamer.sortby = (RenameSortBy)(sort_by_combo.get_active ());
            schedule_view_update ();
        });

        sort_type_switch.notify ["active"].connect (() => {
            renamer.is_reversed = sort_type_switch.get_active ();
            schedule_view_update ();
        });

        base_name_combo.changed.connect (() => {
            base_name_entry_revealer.reveal_child = base_name_combo.get_active () == RenameBase.CUSTOM;
            schedule_view_update ();
        });

        base_name_entry.changed.connect (() => {
            schedule_view_update ();
        });

        modifier_add_button.clicked.connect (() => {
            add_modifier (true);
        });

        response.connect ((response_id) => {
            switch (response_id) {
                case Gtk.ResponseType.APPLY:
                    if (renamer.can_rename) {
                        try {
                            renamer.rename_files ();
                        } catch (Error e) {
                            var dlg = new Granite.MessageDialog (
                                "Error renaming files",
                                e.message,
                                new ThemedIcon ("dialog-error")
                            );
                            dlg.run ();
                            dlg.destroy ();
                        }
                    }

                    break;

                default:
                    close ();
                    break;
            }
        });

        key_press_event.connect ((event) => {
            var mods = event.state & Gtk.accelerator_get_default_mod_mask ();
            bool control_pressed = ((mods & Gdk.ModifierType.CONTROL_MASK) != 0);
            bool other_mod_pressed = (((mods & ~Gdk.ModifierType.SHIFT_MASK) & ~Gdk.ModifierType.CONTROL_MASK) != 0);
            bool only_control_pressed = control_pressed && !other_mod_pressed; /* Shift can be pressed */
            Gdk.ModifierType consumed_mods;
            switch (KeyUtils.map_key (event, out consumed_mods)) {
                case Gdk.Key.Escape:
                    if (mods == 0) {
                        response (Gtk.ResponseType.REJECT);
                    }
                    break;
                case Gdk.Key.Return:
                    if (mods == 0 && renamer.can_rename) {
                        response (Gtk.ResponseType.APPLY);
                    }
                default:
                    break;
            }


            return false;
        });

        delete_event.connect (() => {
            response (Gtk.ResponseType.REJECT);
        });

        add_modifier (false);
    }

    private void add_modifier (bool allow_remove) {
        var mod = new Modifier (allow_remove);
        renamer.modifier_chain.add (mod);
        modifiers_listbox.add (mod);
        mod.update_request.connect (schedule_view_update);
        mod.remove_request.connect (() => {
            renamer.modifier_chain.remove (mod);
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
        foreach (var mod in renamer.modifier_chain) {
            if (first) {
                mod.reset ();
                first = false;
            } else {
                mod.destroy ();
            }
        }

        schedule_view_update ();
    }

    public void schedule_view_update () {
        var custom_basename = base_name_combo.get_active () == RenameBase.CUSTOM ? base_name_entry.text : null;
        renamer.schedule_update (custom_basename);
    }
}
