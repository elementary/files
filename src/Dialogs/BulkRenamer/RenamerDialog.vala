/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2023 elementary, Inc. (https://elementary.io)
 *                         2019-2022 Jeremy Wootten
 *
 * Authored by: Jeremy Wootten <jeremywootten@gmail.com>
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
    private Gtk.RadioButton modify_basename_toggle;
    private Gtk.RadioButton new_basename_toggle;
    private Gtk.RadioButton original_basename_toggle;
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
            "can-rename", rename_button, "sensitive", DEFAULT | SYNC_CREATE
        );

        /* Template Controls */
        var prefix_var = new Variant.uint32 ((uint)RenamePosition.PREFIX);
        var prefix_menumodel = new Menu ();
        prefix_menumodel.append (_("Number Sequence"), Action.print_detailed_name ("renamer.add-number", prefix_var));
        prefix_menumodel.append (_("Creation Date"), Action.print_detailed_name ("renamer.add-date", prefix_var));
        prefix_menumodel.append (_("Fixed Text"), Action.print_detailed_name ("renamer.add-text", prefix_var));

        var suffix_var = new Variant.uint32 ((uint)RenamePosition.SUFFIX);
        var suffix_menumodel = new Menu ();
        suffix_menumodel.append (_("Number Sequence"), Action.print_detailed_name ("renamer.add-number", suffix_var));
        suffix_menumodel.append (_("Creation Date"), Action.print_detailed_name ("renamer.add-date", suffix_var));
        suffix_menumodel.append (_("Fixed Text"), Action.print_detailed_name ("renamer.add-text", suffix_var));

        var prefix_button_box = new Gtk.Box (HORIZONTAL, 0);
        prefix_button_box.add (new Gtk.Image.from_icon_name ("list-add-symbolic", BUTTON));
        prefix_button_box.add (new Gtk.Label (_("Add Prefix…")));

        var prefix_button = new Gtk.MenuButton () {
            child = prefix_button_box,
            menu_model = prefix_menumodel,
            use_popover = false
        };

        prefix_revealer = new Gtk.Revealer () {
            child = prefix_button,
            reveal_child = true,
            transition_type = SLIDE_LEFT
        };

        prefix_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        prefix_box.add (prefix_revealer);

        var suffix_button_box = new Gtk.Box (HORIZONTAL, 0);
        suffix_button_box.add (new Gtk.Image.from_icon_name ("list-add-symbolic", BUTTON));
        suffix_button_box.add (new Gtk.Label (_("Add Suffix…")));

        var suffix_button = new Gtk.MenuButton () {
            child = suffix_button_box,
            menu_model = suffix_menumodel,
            use_popover = false
        };

        suffix_revealer = new Gtk.Revealer () {
            child = suffix_button,
            reveal_child = true,
            transition_type = SLIDE_RIGHT
        };

        suffix_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        suffix_box.add (suffix_revealer);

        var basename_label = new Gtk.Label (_("Basename:"));
        // In Gtk4 replace RadioButtons with linked ToggleButtons
        original_basename_toggle = new Gtk.RadioButton (null) {
            label = NC_("bulk-rename", "Keep"),
            active = true
        };
        original_basename_toggle.set_mode (false);

        new_basename_toggle = new Gtk.RadioButton.from_widget (original_basename_toggle) {
            label = NC_("bulk-rename", "Replace")
        };
        new_basename_toggle.set_mode (false);

        modify_basename_toggle = new Gtk.RadioButton.from_widget (original_basename_toggle) {
            label = NC_("bulk-rename", "Modify")
        };
        modify_basename_toggle.set_mode (false);

        var toggle_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        toggle_box.get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        toggle_box.add (original_basename_toggle);
        toggle_box.add (new_basename_toggle);
        toggle_box.add (modify_basename_toggle);

        var basename_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6) {
            halign = Gtk.Align.CENTER,
            margin_bottom = 24
        };
        basename_box.pack_start (basename_label);
        basename_box.pack_end (toggle_box);

        basename_entry = new Gtk.Entry () {
            hexpand = true,
            sensitive = false,
            text = _("Original Basename")
        };

        replacement_entry = new Gtk.Entry () {
            margin_top = 6,
            placeholder_text = _("Replacement text")
        };

        var replacement_entry_revealer = new Gtk.Revealer () {
            child = replacement_entry
        };

        /* Filename list */
        var list_scrolled_window = new Gtk.ScrolledWindow (null, null) {
            child = renamer.listbox,
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            min_content_height = 200
        };

        var frame = new Gtk.Frame (null) {
            child = list_scrolled_window
        };

        var sortby_label = new Gtk.Label (_("Number in order of:"));

        //TODO Replace RadioButtons with linked RadioButtons in Gtk4
        /// TRANSLATORS: Used as "Number in order of: Name"
        var name_check = new Gtk.RadioButton.with_label (null, NC_("bulk-rename", "Name")) {margin_start = 6};
        /// TRANSLATORS: Used as "Number in order of: Date created"
        var created_check = new Gtk.RadioButton.with_label_from_widget (name_check, NC_("bulk-rename", "Date created")) {margin_start = 6};
        /// TRANSLATORS: Used as "Number in order of: Date modified"
        var modified_check = new Gtk.RadioButton.with_label_from_widget (name_check, NC_("bulk-rename", "Date modified")) {margin_start = 6};
        /// TRANSLATORS: Used as "Number in order of: Size"
        var size_check = new Gtk.RadioButton.with_label_from_widget (name_check, NC_("bulk-rename", "Size")) {margin_start = 6};

        var sortby_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 3) {
            margin_bottom = 12
        };
        sortby_box.pack_start (sortby_label);
        sortby_box.pack_start (name_check);
        sortby_box.pack_start (created_check);
        sortby_box.pack_start (modified_check);
        sortby_box.pack_start (size_check);

        sortby_revealer = new Gtk.Revealer () {
            child = sortby_box,
            reveal_child = false,
            halign = Gtk.Align.START
        };

        var list_box = new Gtk.Box (VERTICAL, 0);
        list_box.add (sortby_revealer);
        list_box.add (frame);

        /* Assemble content */
        controls_grid = new Gtk.Grid () {
            column_spacing = 6,
            margin_bottom = 24
        };

        controls_grid.attach (prefix_box, 0, 0);
        controls_grid.attach (basename_entry, 1, 0);
        controls_grid.attach (suffix_box, 2, 0);
        controls_grid.attach (replacement_entry_revealer, 1, 1);

        var content_box = get_content_area ();
        content_box.add (basename_box);
        content_box.add (controls_grid);
        content_box.add (list_box);
        content_box.margin_start = 10;
        content_box.margin_end = 10;
        content_box.margin_bottom = 10;
        content_box.show_all ();

        replacement_entry_revealer.reveal_child = false;

        // /* Connect signals */
        original_basename_toggle.toggled.connect (() => {
            if (original_basename_toggle.active) {
                basename_entry.sensitive = false;
                basename_entry.text = _("Original Basename");
                replacement_entry_revealer.reveal_child = false;
                schedule_view_update ();
            }
        });
        new_basename_toggle.toggled.connect (() => {
            if (new_basename_toggle.active) {
                basename_entry.sensitive = true;
                basename_entry.text = "";
                basename_entry.placeholder_text = _("New basename");
                replacement_entry_revealer.reveal_child = false;
                schedule_view_update ();
            }
        });
        modify_basename_toggle.toggled.connect (() => {
            if (modify_basename_toggle.active) {
                basename_entry.sensitive = true;
                basename_entry.text = "";
                basename_entry.placeholder_text = _("Text to be replaced");
                replacement_entry_revealer.reveal_child = true;
                schedule_view_update ();
            }
        });

        basename_entry.changed.connect (() => {
            schedule_view_update ();
        });

        replacement_entry.changed.connect (() => {
            schedule_view_update ();
        });

        response.connect ((response_id) => {
            if (response_id == Gtk.ResponseType.APPLY) {
                if (renamer.can_rename) {
                    try {
                        renamer.rename_files ();
                    } catch (Error e) {
                        var dlg = new Granite.MessageDialog (
                            "Error renaming files",
                            e.message,
                            new ThemedIcon ("dialog-error")
                        );
                        dlg.present ();
                        dlg.response.connect (dlg.destroy);
                    }
                }
            }

            close ();
        });

        notify["n-number-seq"].connect (() => {
            sortby_revealer.reveal_child = n_number_seq > 0;
            if (n_number_seq == 0) {
                name_check.active = true;
            }
        });

        name_check.toggled.connect (() => {
            if (size_check.active) {
                renamer.sortby = SortBy.SIZE;
            } else if (created_check.active) {
                renamer.sortby = SortBy.CREATED;
            } else if (modified_check.active) {
                renamer.sortby = SortBy.MODIFIED;
            } else {
                renamer.sortby = SortBy.NAME;
            }
        });

        schedule_view_update ();
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

        var apply_button = new Gtk.Button.with_label (_("Apply"));
        apply_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        var cancel_button = new Gtk.Button.with_label (_("Cancel"));

        var delete_button = new Gtk.Button.with_label (_("Delete"));

        var button_box = new Gtk.ActionBar ();
        button_box.pack_start (delete_button);
        button_box.pack_end (apply_button);
        button_box.pack_end (cancel_button);
        button_box.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);

        var edit_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        edit_box.pack_start (mod.get_modifier_widget ());
        edit_box.pack_start (button_box);
        edit_box.show_all ();

        var mod_popover = new Gtk.Popover (null) {
            child = edit_box
        };

        var mod_button = new Gtk.MenuButton () {
            always_show_image = true,
            image = new Gtk.Image.from_icon_name ("pan-down-symbolic", MENU),
            image_position = Gtk.PositionType.RIGHT,
            label = mod.mode.to_string (),
            popover = mod_popover
        };

        mod.set_data<Gtk.Button> ("button", mod_button);

        apply_button.clicked.connect (() => {
            mod_popover.popdown ();
        });

        delete_button.clicked.connect (() => {
            mod_popover.popdown ();
            delete_modifier (mod);
        });

        cancel_button.clicked.connect (() => {
            mod.cancel_edit ();
            mod_popover.popdown ();
        });

        mod_popover.key_press_event.connect ((event) => {
            switch (event.keyval) {
                case Gdk.Key.Return:
                case Gdk.Key.KP_Enter:
                    mod_popover.popdown ();

                    return true;
                case Gdk.Key.Escape:
                    mod.cancel_edit ();
                    mod_popover.popdown ();

                    return true;

                default:
                    return false;
            }
        });

        mod_popover.closed.connect (() => {
            schedule_view_update ();
        });

        if (mod.pos == RenamePosition.PREFIX) {
            prefix_box.add (mod_button);
        } else {
            // Gtk4: replace with prepend
            suffix_box.add (mod_button);
            suffix_box.reorder_child (suffix_revealer, -1);
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

        var custom_basename = original_basename_toggle.active ? null : basename_entry.text;
        var replacement_text = modify_basename_toggle.active ? replacement_entry.text : null;
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
