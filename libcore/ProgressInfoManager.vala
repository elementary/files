/* Copyright (c) 2018 elementary LLC (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

public class PF.Progress.InfoManager : GLib.Object {
    public signal void new_progress_info (PF.Progress.Info info);

    private Gee.LinkedList<PF.Progress.Info> progress_infos;

    private static PF.Progress.InfoManager progress_info_manager;
    public static PF.Progress.InfoManager get_instance () {
        if (progress_info_manager == null) {
            progress_info_manager = new Progress.InfoManager ();
        }

        return progress_info_manager;
    }

    construct {
        progress_infos = new Gee.LinkedList<PF.Progress.Info> ();
    }

    public void add_new_info (PF.Progress.Info info) {
        if (info in progress_infos) {
            warning ("Adding two times the same progress info object to the manager");
            return;
        }

        progress_infos.add (info);
        info.finished.connect_after (on_info_finished);
        new_progress_info (info);
    }

    private void on_info_finished (Info info) {
        info.finished.disconnect (on_info_finished);
        progress_infos.remove (info);
    }

    public Gee.LinkedList<PF.Progress.Info> get_all_infos () {
        return progress_infos;
    }
}
