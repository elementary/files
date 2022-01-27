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

public class Files.RenamerDialog : Gtk.Dialog {
    public enum RenameBase {
        ORIGINAL,
        REPLACE,
        CUSTOM;

        public string to_string () {
            switch (this) {
                case RenameBase.ORIGINAL:
                    return _("Original filename");
                case RenameBase.REPLACE:
                    return _("Original filename with replacement");
                case RenameBase.CUSTOM:
                    return _("Enter a basename");
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
    private Gtk.MenuButton prefix_button;
    private Gtk.MenuButton suffix_button;
    private Gtk.Entry basename_entry;
    private Gtk.Entry replace_entry;
    private Gtk.ComboBoxText basename_combo;
    private SimpleActionGroup actions;

    public RenamerDialog (List<Files.File> files, string? basename = null) {
        if (basename != null) {
            basename_combo.set_active (RenameBase.CUSTOM);
            basename_entry.text = basename;
        } else {
            basename_combo.set_active (RenameBase.ORIGINAL);
            basename_entry.text = "";
        }

        renamer.add_files (files);
        schedule_view_update ();
    }

    construct {
        actions = new SimpleActionGroup ();
        actions.add_action_entries (ACTION_ENTRIES, this);
        insert_action_group ("renamer", actions);

        deletable = true;
        set_title (_("Bulk Renamer"));
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

        prefix_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("add-symbolic", Gtk.IconSize.BUTTON),
            tooltip_text = _("Add Prefix"),
            menu_model = prefix_menumodel,
            halign = Gtk.Align.END
        };

        prefix_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        prefix_box.pack_end (prefix_button, false, false);

        suffix_button = new Gtk.MenuButton () {
            image = new Gtk.Image.from_icon_name ("add-symbolic", Gtk.IconSize.BUTTON),
            tooltip_text = _("Add Suffix"),
            menu_model = suffix_menumodel,
            halign = Gtk.Align.START
        };
        suffix_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
        suffix_box.pack_start (suffix_button, false, false);

        basename_combo = new Gtk.ComboBoxText () {
            valign = Gtk.Align.CENTER
        };
        basename_combo.insert (RenameBase.ORIGINAL, "ORIGINAL", RenameBase.ORIGINAL.to_string ());
        basename_combo.insert (RenameBase.REPLACE, "REPLACE", RenameBase.REPLACE.to_string ());
        basename_combo.insert (RenameBase.CUSTOM, "CUSTOM", RenameBase.CUSTOM.to_string ());
        basename_entry = new Gtk.Entry ();
        replace_entry = new Gtk.Entry () {
            placeholder_text = _("Enter replacement text")
        };
        var basename_entry_revealer = new Gtk.Revealer ();
        basename_entry_revealer.add (basename_entry);
        var replace_entry_revealer = new Gtk.Revealer ();
        replace_entry_revealer.add (replace_entry);

        /* Filename list */
        var list_scrolled_window = new Gtk.ScrolledWindow (null, null) {
            hexpand = true,
            min_content_width = 400,
            min_content_height = 200,
            hscrollbar_policy = Gtk.PolicyType.NEVER,
            can_focus = false
        };
        list_scrolled_window.add (renamer.listbox);

        /* Assemble content */
        controls_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.HORIZONTAL,
            hexpand = true,
            halign = Gtk.Align.CENTER,
            column_spacing = 6,
            margin_bottom = 12
        };
        controls_grid.attach (prefix_box, 0, 0, 1, 1);
        controls_grid.attach (basename_combo, 1, 0, 1, 1);
        controls_grid.attach (suffix_box, 2, 0, 1, 1);
        controls_grid.attach (basename_entry_revealer, 1, 1, 1, 1);
        controls_grid.attach (replace_entry_revealer, 1, 2, 1, 1);

        var content_box = get_content_area ();
        content_box.pack_start (controls_grid);
        content_box.pack_start (list_scrolled_window);
        content_box.margin = 12;
        content_box.show_all ();

        /* Connect signals */
        basename_combo.changed.connect (() => {
            switch (basename_combo.get_active ()) {
                case RenameBase.CUSTOM:
                    basename_entry.placeholder_text = _("Enter fixed name to replace the original");
                    basename_entry_revealer.reveal_child = true;
                    replace_entry_revealer.reveal_child = false;
                    break;
                case RenameBase.REPLACE:
                    basename_entry.placeholder_text = _("Enter text of original to be replaced");
                    basename_entry_revealer.reveal_child = true;
                    replace_entry_revealer.reveal_child = true;
                    break;
                default:
                    basename_entry_revealer.reveal_child = false;
                    replace_entry_revealer.reveal_child = false;
                    basename_entry.text = "";
                    replace_entry.text = "";
                    break;
            }

            schedule_view_update ();
        });

        basename_entry.changed.connect (() => {
            if (basename_entry_revealer.reveal_child) {
                schedule_view_update ();
            }
        });

        replace_entry.changed.connect (() => {
            if (replace_entry_revealer.reveal_child) {
                schedule_view_update ();
            }
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

        basename_combo.grab_focus ();
    }

    private void add_modifier (RenamerModifier mod) {
        renamer.modifier_chain.add (mod);
        var mod_button = new Gtk.Button.with_label (mod.mode.to_string ()) {
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

        if (mod.pos == RenamePosition.PREFIX) {
            // In Gtk3 required to keep add buttons on outside. In Gtk4, can use append and prepend
            prefix_box.remove (prefix_button);
            prefix_box.pack_end (mod_button, false, false);
            prefix_box.pack_end (prefix_button, false, false);
        } else {
            suffix_box.remove (suffix_button);
            suffix_box.pack_start (mod_button, false, false);
            suffix_box.pack_start (suffix_button, false, false);
        }

        controls_grid.show_all ();
        controls_grid.queue_draw ();
        schedule_view_update ();
    }

    public void schedule_view_update () {
        var custom_basename = basename_combo.get_active () != RenameBase.ORIGINAL ? basename_entry.text : null;
        var replacement_text = basename_combo.get_active () == RenameBase.REPLACE ? replace_entry.text : null;
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

    private void delete_modifier (RenamerModifier mod) {
        renamer.modifier_chain.remove (mod);
        var button = mod.get_data<Gtk.Button> ("button");
        button.destroy ();
        schedule_view_update ();
        return;
    }
}
