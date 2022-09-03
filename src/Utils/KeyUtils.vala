/***
    Copyright (c) 2022 elementary Inc <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation, Inc.,.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace KeyUtils {
    //These functions (or similar) now incorporated in Gtk4

    // /* Leave standard ASCII alone, else try to get Latin hotkey from keyboard state */
    // /* This means that Latin hot keys for Latin Dvorak keyboards (e.g. Spanish Dvorak)
    //  * will be in their Dvorak position, not their QWERTY position.
    //  * For non-Latin (e.g. Cyrillic) keyboards however, the Latin hotkeys are mapped
    //  * to the same position as on a Latin QWERTY keyboard. If the conversion fails, the unprocessed
    //  * event.keyval is used. */

    // //TODO Needs complete rewrite for Gtk4 so leaving some direct access of event struct
    // public static uint map_key (Gdk.Event event, out Gdk.ModifierType consumed_mods) {
    //     uint original_keyval, keyval;
    //     event.get_keyval (out original_keyval);
    //     keyval = original_keyval;
    //     consumed_mods = 0;

    //     if (keyval > 127) {
    //         int eff_grp, level;
    //         var display = event.get_device ().get_display ();
    //         var keymap = Gdk.Keymap.get_for_display (display);
    //         if (!keymap.translate_keyboard_state (
    //                 event.hardware_keycode,
    //                 event.state, event.group,
    //                 out keyval, out eff_grp,
    //                 out level, out consumed_mods)) {

    //             warning ("translate keyboard state failed");
    //             keyval = original_keyval;
    //             consumed_mods = 0;
    //         } else {
    //             keyval = 0;
    //             for (uint key = 32; key < 128; key++) {
    //                 if (match_keycode (keymap, key, event.hardware_keycode, level)) {
    //                     keyval = key;
    //                     break;
    //                 }
    //             }

    //             if (keyval == 0) {
    //                 debug ("Could not match hardware code to ASCII hotkey");
    //                 keyval = original_keyval;
    //                 consumed_mods = 0;
    //             }
    //         }
    //     }

    //     return keyval;
    // }

    // /** Returns true if the code parameter matches the keycode of the keyval parameter for
    //   * any keyboard group or level (in order to allow for non-QWERTY keyboards) **/
    // private static bool match_keycode (Gdk.Keymap keymap, uint keyval, uint code, int level) {
    //     Gdk.KeymapKey [] keys;
    //     if (keymap.get_entries_for_keyval (keyval, out keys)) {
    //         foreach (var key in keys) {
    //             if (code == key.keycode && level == key.level) {
    //                 return true;
    //             }
    //         }
    //     }

    //     return false;
    // }
}
