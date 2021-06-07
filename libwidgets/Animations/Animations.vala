/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.

    This program is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
    more details.

    You should have received a copy of the GNU General Public License along with
    this program; if not, write to the Free Software Foundation, Inc.,
    51 Franklin Street, Fifth Floor Boston, MA 02110-1335 USA.
 ***/

namespace Files.Animation {

    private static uint timeout_source_id = 0;
    public static void smooth_adjustment_to (Gtk.Adjustment adj, int final) {
        cancel ();

        var initial = adj.value;
        var to_do = final - initial;

        int factor;
        (to_do > 0) ? factor = 1 : factor = -1;
        to_do = (double) (((int) to_do).abs () + 1);

        var newvalue = 0;
        var old_adj_value = adj.value;

        timeout_source_id = Timeout.add (1000 / 60, () => {
            /* If the user move it at the same time, just stop the animation */
            if (old_adj_value != adj.value) {
                timeout_source_id = 0;
                return GLib.Source.REMOVE;
            }

            if (newvalue >= to_do - 10) {
                /* to be sure that there is not a little problem */
                adj.value = final;
                timeout_source_id = 0;
                return GLib.Source.REMOVE;
            }

            newvalue += 10;

            adj.value = initial + factor *
                        Math.sin (((double) newvalue / (double) to_do) * Math.PI / 2) * to_do;

            old_adj_value = adj.value;
            return GLib.Source.CONTINUE;
        });
    }

    public static bool get_animating () {
        return timeout_source_id > 0;
    }

    public static void cancel () {
        if (timeout_source_id > 0) {
            Source.remove (timeout_source_id);
            timeout_source_id = 0;
        }
    }
}
