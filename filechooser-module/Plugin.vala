// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2013 elementary LLC (http://launchpad.net/elementary)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
 *
 * Authored by: Corentin Noël <tintou@mailoo.org>
 */

private static Gee.HashMap<unowned Gtk.FileChooserDialog, CustomFileChooserDialog> hash_map;
private static bool window_state_event_hook (GLib.SignalInvocationHint ihint, GLib.Value[] param_values) {

    if (!param_values[0].type ().is_a (typeof (Gtk.FileChooserDialog))) {
        return true;
    }

    if (hash_map == null) {
        hash_map = new Gee.HashMap<unowned Gtk.FileChooserDialog, CustomFileChooserDialog> ();
    }

    // We grab a reference here
    Gtk.FileChooserDialog dialog = (Gtk.FileChooserDialog)param_values[0];
    if (!hash_map.has_key (dialog)) {
        var custom_dialog = new CustomFileChooserDialog (dialog);
        hash_map[dialog] = custom_dialog;
        dialog.destroy.connect (() => {
            hash_map.unset (dialog);
            if (hash_map.is_empty) {
                hash_map = null;
            }
        });
    }

    return true;
}

public void gtk_module_init ([CCode (array_length_cname = "argc", array_length_pos = 0.5)] ref unowned string[]? argv) {
    if (Gtk.check_version (3, 14, 0) == null) {
        var appinfo = AppInfo.get_default_for_type ("inode/directory", true);
        if (appinfo != null && appinfo.get_executable () == "io.elementary.files") {
            /* We need to register the Gtk.Dialog class first */
            (typeof (Gtk.Dialog)).class_ref ();
            /* It's the only way to get every new window */
            var map_id = GLib.Signal.lookup ("window-state-event", typeof (Gtk.Dialog));
#if VALA_0_42
            GLib.Signal.add_emission_hook (map_id, 0, window_state_event_hook);
#else
            GLib.Signal.add_emission_hook (map_id, 0, window_state_event_hook, null);
#endif
        }
    } else {
        warning ("The required GTK version is 3.14");
    }
}
