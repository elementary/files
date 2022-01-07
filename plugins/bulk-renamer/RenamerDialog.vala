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

public class Files.RenamerDialog : Gtk.Dialog {
    private Files.Renamer renamer;
    private Gtk.Widget rename_button;
    public RenamerDialog (string _basename, GLib.File[] _files) {
        renamer.add_files (_files);
        renamer.set_base_name (_basename);
    }

    construct {
        deletable = true;
        set_title (_("Bulk Renamer"));
        var cancel_button = add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        rename_button = add_button (_("Rename"), Gtk.ResponseType.APPLY);
        rename_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);

        renamer = new Renamer ();
        renamer.margin = 12;
        renamer.set_sort_order (RenameSortBy.NAME, false);
        renamer.bind_property ("can-rename",
                                rename_button, "sensitive",
                                GLib.BindingFlags.DEFAULT | GLib.BindingFlags.SYNC_CREATE);

        get_content_area ().add (renamer);

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

            uint keyval = map_key (event);

            switch (keyval) {
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

        realize.connect (() => {
            resize (500, 300);  //Stops the window being larger than necessary
        });

        delete_event.connect (() => {
            response (Gtk.ResponseType.REJECT);
        });

        show_all ();
    }

    /* Code taken from pantheon-files  Copyright 2015-2020 elementary, Inc. (https://elementary.io) */
    /* Leave standard ASCII alone, else try to get Latin hotkey from keyboard state */
    /* This means that Latin hot keys for Latin Dvorak keyboards (e.g. Spanish Dvorak)
     * will be in their Dvorak position, not their QWERTY position.
     * For non-Latin (e.g. Cyrillic) keyboards however, the Latin hotkeys are mapped
     * to the same position as on a Latin QWERTY keyboard. If the conversion fails, the unprocessed
     * event.keyval is used. */
    private uint map_key (Gdk.EventKey event) {
        uint keyval = event.keyval;
        Gdk.ModifierType consumed_mods = 0;


        if (event.keyval > 127) {
            int eff_grp, level;

            if (!Gdk.Keymap.get_for_display (get_display ()).translate_keyboard_state (
                    event.hardware_keycode,
                    event.state, event.group,
                    out keyval, out eff_grp,
                    out level, out consumed_mods)) {

                warning ("translate keyboard state failed");
                keyval = event.keyval;
                consumed_mods = 0;
            } else {
                keyval = 0;
                for (uint key = 32; key < 128; key++) {
                    if (match_keycode (key, event.hardware_keycode, level)) {
                        keyval = key;
                        break;
                    }
                }

                if (keyval == 0) {
                    debug ("Could not match hardware code to ASCII hotkey");
                    keyval = event.keyval;
                    consumed_mods = 0;
                }
            }
        }

        return keyval;
    }

    /* Code taken from pantheon-files  Copyright 2015-2020 elementary, Inc. (https://elementary.io) */
    /* Returns true if the code parameter matches the keycode of the keyval parameter for
     * any keyboard group or level (in order to allow for non-QWERTY keyboards) */
    protected bool match_keycode (uint keyval, uint code, int level) {
        Gdk.KeymapKey [] keys;
        Gdk.Keymap keymap = Gdk.Keymap.get_for_display (get_display ());
        if (keymap.get_entries_for_keyval (keyval, out keys)) {
            foreach (var key in keys) {
                if (code == key.keycode && level == key.level) {
                    return true;
                }
            }
        }

        return false;
    }
}
