/***
    Copyright (c) 2021 elementary Inc <https://elementary.io>

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

namespace Files.EventUtils {
    public static Gdk.ModifierType get_event_modifiers (Gdk.Event event, Gdk.ModifierType consumed = 0) {
        Gdk.ModifierType mods;
        if (event.get_state (out mods)) {
            return (mods & ~consumed) & Gtk.accelerator_get_default_mod_mask ();
        } else {
            return 0;
        }
    }

    public static void get_event_coords (Gdk.Event event, out int ix, out int iy) {
        double dx, dy;
        if (event.get_coords (out dx, out dy)) {
            ix = (int)dx;
            iy = (int)dy;
            return;
        } else {
            ix = -1;
            iy = -1;
        }

        return;
    }

    public static uint get_event_button (Gdk.Event event) {
        uint button;
        if (event.get_state (out button)) {
            return button;
        } else {
            return -1;
        }
    }
}
