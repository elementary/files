namespace KeyUtils {
    public static uint map_key (Gdk.EventKey event, out Gdk.ModifierType consumed_mods) {
        uint keyval = event.keyval;
        consumed_mods = 0;

        if (event.keyval > 127) {
            int eff_grp, level;
            var display = event.get_device ().get_display ();
            var keymap = Gdk.Keymap.get_for_display (display);
            if (!keymap.translate_keyboard_state (
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
                    if (match_keycode (keymap, key, event.hardware_keycode, level)) {
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

    private static bool match_keycode (Gdk.Keymap keymap, uint keyval, uint code, int level) {
        Gdk.KeymapKey [] keys;
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
