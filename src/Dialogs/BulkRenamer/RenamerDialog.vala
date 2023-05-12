/*
 * Copyright (C) 2019-2022 Jeremy Wootten
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
 *  Jeremy Wootten <jeremywootten@gmail.com>
 *
*/

public class Files.RenamerDialog : Granite.Dialog {
    private const int MAX_PREFIX = 1;
    private const int MAX_SUFFIX = 1;

    public enum RenameBase {
        ORIGINAL,
        REPLACE,
        CUSTOM;

        public string to_string () {
            switch (this) {
                case RenameBase.ORIGINAL:
                    return _("Original filename");
                case RenameBase.REPLACE:
                    return _("Modified original");
                case RenameBase.CUSTOM:
                    return _("New basename");
                default:
                    assert_not_reached ();
            }
        }
    }

    private const ActionEntry[] ACTION_ENTRIES = {
        {"add-text", on_action_add_text, "u"},
        {"add-number", on_action_add_number, "u"},
        {"add-date", on_action_add_date, "u"}
    };

    private Files.Renamer renamer;
    private Gtk.Grid controls_grid;
    private Gtk.Box prefix_box;
    private Gtk.Box suffix_box;
    private Gtk.Revealer prefix_revealer;
    private Gtk.Revealer suffix_revealer;
    private Gtk.Entry basename_entry;
    private Gtk.Entry replacement_entry;
    private Granite.Widgets.ModeButton basename_modebutton;
    private Gtk.RadioButton replace_check;
    private Gtk.RadioButton new_check;
    private Gtk.RadioButton original_check;
    private Gtk.Revealer sortby_revealer;
    private SimpleActionGroup actions;

    public int n_number_seq { get; private set; default = 0; }
    public int n_prefix { get; private set; default = 0; }
    public int n_suffix { get; private set; default = 0; }

    public RenamerDialog (List<Files.File> files, string? basename = null) {
        renamer.add_files (files);
        schedule_view_update ();
    }

    construct {
        actions = new SimpleActionGroup ();
        actions.add_action_entries (ACTION_ENTRIES, this);
        insert_action_group ("renamer", actions);

        title = _("Bulk Rename");
        renamer = new Renamer ();

        /* Dialog actions */
        var cancel_button = add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        var rename_button = add_button (_("Rename"), Gtk.ResponseType.APPLY);
        rename_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
        renamer.bind_property (
            "can-rename", rename_button, "sensitive", GLib.BindingFlags.DEFAULT | GLib.BindingFlags.SYNC_CREATE
        );

        /* Template Controls */
        var prefix_menumodel = new Menu ();
        var prefix_var = new Variant.uint32 ((uint)RenamePosition.PREFIX);
        var suffix_var = new Variant.uint32 ((uint)RenamePosition.SUFFIX);
        prefix_menumodel.append (_("Number Sequence"), Action.print_detailed_name ("renamer.add-number", prefix_var));
        prefix_menumodel.append (_("Creation Date"), Action.print_detailed_name ("renamer.add-date", prefix_var));
        prefix_menumodel.append (_("Fixed Text"), Action.print_detailed_name ("renamer.add-text", prefix_var));
        var suffix_menumodel = new Menu ();
        suffix_menumodel.append (_("Number Sequence"), Action.print_detailed_name ("renamer.add-number", suffix_var));
        suffix_menumodel.append (_("Creation Date"), Action.print_detailed_name ("renamer.add-date", suffix_var));
        suffix_menumodel.append (_("Fixed Text"), Action.print_detailed_name ("renamer.add-text", suffix_var));

        var prefix_button = new Gtk.MenuButton () {
            always_show_image = true,
            image = new Gtk.Image.from_icon_name ("list-add", Gtk.IconSize.BUTTON),
            label = _("Add Prefix"),
            menu_model = prefix_menumodel
        };
        prefix_revealer = new Gtk.Revealer () {
            reveal_child = true
        };
        prefix_revealer.add (prefix_button);
        prefix_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        prefix_box.pack_end (prefix_revealer, false, false);

        var suffix_button = new Gtk.MenuButton () {
            always_show_image = true,
            image = new Gtk.Image.from_icon_name ("list-add", Gtk.IconSize.BUTTON),
            label = _("Add Suffix"),
            menu_model = suffix_menumodel
        };
        suffix_revealer = new Gtk.Revealer () {
            reveal_child = true
        };
        suffix_revealer.add (suffix_button);
        suffix_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        suffix_box.pack_start (suffix_revealer, false, false);

        var basename_label = new Gtk.Label (_("Basename:"));
        basename_modebutton = new Granite.Widgets.ModeButton ();
        /// TRANSLATORS: Used as "Basename: Unchanged"
        basename_modebutton.append_text (NC_("bulk-rename", "Unchanged"));
        /// TRANSLATORS: Used as "Basename: New"
        basename_modebutton.append_text (NC_("bulk-rename", "New"));
        /// TRANSLATORS: Used as "Basename: Modified"
        basename_modebutton.append_text (NC_("bulk-rename", "Modified"));
        basename_modebutton.selected = 0;

        var basename_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            halign = Gtk.Align.CENTER,
            margin_bottom = 24
        };

        basename_box.pack_start (basename_label);
        basename_box.pack_end (basename_modebutton);

        var original_label = new Gtk.Label (_("Original Basename"));
        basename_entry = new Gtk.Entry ();
        replacement_entry = new Gtk.Entry () {
            placeholder_text = _("Replacement text")
        };

        var replacement_entry_stack = new Gtk.Stack () { homogeneous = true };
        replacement_entry_stack.add_named (replacement_entry, "entry");
        replacement_entry_stack.add_named (new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0), "box");

        var basename_entry_stack = new Gtk.Stack ();
        basename_entry_stack.add_named (original_label, "label");
        basename_entry_stack.add_named (basename_entry, "entry");

        /* Filename list */
        var list_scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hexpand = true,
            min_content_width = 400,
            min_content_height = 200,
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            can_focus = false
        };
        list_scrolled_window.add (renamer.listbox);

        var frame = new Gtk.Frame (null);
        frame.add (list_scrolled_window);

        var sortby_label = new Gtk.Label (_("Number in order of:"));

        //TODO Replace RadioButtons with linked ToggleButtons in Gtk4
        /// TRANSLATORS: Used as "Number in order of: Name"
        var name_check = new Gtk.RadioButton.with_label (null, NC_("bulk-rename", "Name")) {margin_start = 6};
        /// TRANSLATORS: Used as "Number in order of: Date created"
        var created_check = new Gtk.RadioButton.with_label_from_widget (name_check, NC_("bulk-rename", "Date created")) {margin_start = 6};
        /// TRANSLATORS: Used as "Number in order of: Date modified"
        var modified_check = new Gtk.RadioButton.with_label_from_widget (name_check, NC_("bulk-rename", "Date modified")) {margin_start = 6};
        /// TRANSLATORS: Used as "Number in order of: Size"
        var size_check = new Gtk.RadioButton.with_label_from_widget (name_check, NC_("bulk-rename", "Size")) {margin_start = 6};

        var sortby_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3) {
            margin_bottom = 6,
            margin_top = 12
        };
        sortby_box.pack_start (sortby_label);
        sortby_box.pack_start (name_check);
        sortby_box.pack_start (created_check);
        sortby_box.pack_start (modified_check);
        sortby_box.pack_start (size_check);

        sortby_revealer = new Gtk.Revealer () {
            hexpand = false,
            reveal_child = false,
            halign = Gtk.Align.START
        };
        sortby_revealer.add (sortby_box);

        var list_grid = new Gtk.Grid () {
            column_homogeneous = true
        };
        list_grid.attach (sortby_revealer, 0, 0);
        list_grid.attach (frame, 0, 1, 2, 1);

        /* Assemble content */
        controls_grid = new Gtk.Grid () {
            column_homogeneous = true,
            hexpand = true,
            halign = Gtk.Align.CENTER,
            column_spacing = 6,
            margin_bottom = 24
        };

        controls_grid.attach (prefix_box, 0, 0, 1, 1);
        controls_grid.attach (basename_entry_stack, 1, 0, 1, 1);
        controls_grid.attach (suffix_box, 2, 0, 1, 1);
        controls_grid.attach (replacement_entry_stack, 1, 1, 1, 1);

        var content_box = get_content_area ();
        content_box.pack_start (basename_box);
        content_box.pack_start (controls_grid);
        content_box.pack_start (list_grid);
        content_box.margin = 10;
        content_box.show_all ();


        basename_entry_stack.visible_child_name = "label";
        replacement_entry_stack.visible_child_name = "box";


        // /* Connect signals */
        basename_modebutton.notify["selected"].connect (() => {
            switch (basename_modebutton.selected) {
                case 0:
                    basename_entry_stack.visible_child_name = "label";
                    replacement_entry_stack.visible_child_name = "box";
                    break;
                case 1:
                    basename_entry_stack.visible_child_name = "entry";
                    basename_entry.placeholder_text = _("New basename");
                    replacement_entry_stack.visible_child_name = "box";
                    break;
                case 2:
                    basename_entry_stack.visible_child_name = "entry";
                    basename_entry.placeholder_text = _("Text to be replaced");
                    replacement_entry_stack.visible_child_name = "entry";
                    break;
                default:
                    assert_not_reached ();
            }

            schedule_view_update ();
        });

        basename_entry.changed.connect (() => {
            schedule_view_update ();
        });

        replacement_entry.changed.connect (() => {
            schedule_view_update ();
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

                    return true;
                default:
                    break;
            }


            return false;
        });

        delete_event.connect (() => {
            response (Gtk.ResponseType.REJECT);
        });

        notify["n-number-seq"].connect (() => {
            sortby_revealer.reveal_child = n_number_seq > 0;
            if (n_number_seq == 0) {
                name_check.active = true;
            }
        });

        name_check.toggled.connect (() => {
            if (size_check.active) {
                renamer.listbox.sortby = SortBy.SIZE;
            } else if (created_check.active) {
                renamer.listbox.sortby = SortBy.CREATED;
            } else if (modified_check.active) {
                renamer.listbox.sortby = SortBy.MODIFIED;
            } else {
                renamer.listbox.sortby = SortBy.NAME;
            }
        });
    }

    private void add_modifier (RenamerModifier mod) {
        if (mod.pos == RenamePosition.PREFIX) {
            prefix_revealer.reveal_child = ++n_prefix < MAX_PREFIX;
        } else {
            suffix_revealer.reveal_child = ++n_suffix < MAX_SUFFIX;
        }
        if (mod.mode == RenameMode.NUMBER_SEQUENCE) {
            n_number_seq++;
        }
        renamer.modifier_chain.add (mod);
        var mod_button = new Gtk.Button.with_label (mod.mode.to_string ()) {
            always_show_image = true,
            image = new Gtk.Image.from_icon_name ("pan-down-symbolic", Gtk.IconSize.MENU),
            image_position = Gtk.PositionType.RIGHT,
            margin_start = 3,
            margin_end = 3
        };
        mod.set_data<Gtk.Button> ("button", mod_button);
        mod_button.clicked.connect (() => {
            var edit_dialog = new Gtk.Popover (mod_button);
            var apply_button = new Gtk.Button.with_label (_("Apply"));
            apply_button.get_style_context ().add_class (Gtk.STYLE_CLASS_DEFAULT);
            apply_button.clicked.connect (() => {
                edit_dialog.popdown ();
            });
            var cancel_button = new Gtk.Button.with_label (_("Cancel"));
            cancel_button.clicked.connect (() => {
                mod.cancel_edit ();
                edit_dialog.popdown ();
            });
            var delete_button = new Gtk.Button.with_label (_("Delete"));
            delete_button.clicked.connect (() => {
                edit_dialog.popdown ();
                delete_modifier (mod);

            });
            var button_box = new Gtk.ActionBar ();
            button_box.pack_end (apply_button);
            button_box.pack_start (delete_button);
            button_box.pack_end (cancel_button);

            var edit_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
            edit_box.pack_start (mod.get_modifier_widget ());
            edit_box.pack_start (button_box);

            edit_dialog.add (edit_box);
            edit_dialog.closed.connect (() => {
                schedule_view_update ();
                edit_dialog.remove (edit_box);
                edit_dialog.destroy ();
                edit_box.destroy ();
            });

            edit_dialog.key_press_event.connect ((event) => {
                switch (event.keyval) {
                    case Gdk.Key.Return:
                    case Gdk.Key.KP_Enter:
                        edit_dialog.popdown ();

                        return true;
                    case Gdk.Key.Escape:
                        mod.cancel_edit ();
                        edit_dialog.popdown ();

                        return true;

                    default:
                        return false;
                }
            });
            edit_dialog.show_all ();
            edit_dialog.popup ();
            return;
        });

        mod_button.show_all ();

        if (mod.pos == RenamePosition.PREFIX) {
            // In Gtk3 required to keep add buttons on outside. In Gtk4, can use append and prepend
            prefix_box.remove (prefix_revealer);
            prefix_box.pack_end (mod_button, false, false);
            prefix_box.pack_end (prefix_revealer, false, false);
        } else {
            suffix_box.remove (suffix_revealer);
            suffix_box.pack_start (mod_button, false, false);
            suffix_box.pack_start (suffix_revealer, false, false);
        }

        controls_grid.show_all ();
        controls_grid.queue_draw ();
        schedule_view_update ();
    }


    private void delete_modifier (RenamerModifier mod) {
        if (mod.pos == RenamePosition.PREFIX) {
            prefix_revealer.reveal_child = --n_prefix < MAX_PREFIX;
        } else {
            suffix_revealer.reveal_child = --n_suffix < MAX_SUFFIX;
        }
        if (mod.mode == RenameMode.NUMBER_SEQUENCE) {
            n_number_seq--;
        }
        renamer.modifier_chain.remove (mod);
        var button = mod.get_data<Gtk.Button> ("button");
        button.destroy ();

        schedule_view_update ();
        return;
    }

    public void schedule_view_update () {
        foreach (var mod in renamer.modifier_chain) {
            var button = mod.get_data<Gtk.Button> ("button");
            button.label = mod.get_button_text ();
        };

        var custom_basename = basename_modebutton.selected == 0 ? null : basename_entry.text;
        var replacement_text = basename_modebutton.selected == 2 ? replacement_entry.text : null;
        renamer.schedule_update (custom_basename, replacement_text);
    }

    private void on_action_add_number (SimpleAction action, Variant? target) {
        RenamePosition pos = (RenamePosition)(target.get_uint32 ());
        var mod = new RenamerModifier.default_number (pos);
        add_modifier (mod);
    }

    private void on_action_add_date (SimpleAction action, Variant? target) {
        RenamePosition pos = (RenamePosition)(target.get_uint32 ());
        var mod = new RenamerModifier.default_date (pos);
        add_modifier (mod);
    }

    private void on_action_add_text (SimpleAction action, Variant? target) {
        RenamePosition pos = (RenamePosition)(target.get_uint32 ());
        var mod = new RenamerModifier.default_text (pos);
        add_modifier (mod);
    }
}
