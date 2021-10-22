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

/* Maintains a list of active infos and signals when a new one added */
/* Used by the ProgressUIHandler to update the progress window and launcher */
public class PF.Progress.InfoManager : GLib.Object {
    public signal void new_progress_info (PF.Progress.Info info);

    private Gee.LinkedList<PF.Progress.Info> progress_infos;

    private static PF.Progress.InfoManager progress_info_manager;
    public static unowned PF.Progress.InfoManager get_instance () {
        if (progress_info_manager == null) {
            progress_info_manager = new Progress.InfoManager ();
        }

        return progress_info_manager;
    }

    construct {
        progress_infos = new Gee.LinkedList<PF.Progress.Info> ();
    }

    public unowned PF.Progress.Info get_new_info (Gtk.Window parent_window) {
        var info = new PF.Progress.Info (parent_window);
        info.finished.connect (remove_info);
        progress_infos.add (info);
        new_progress_info (info);
        return (!)info;
    }

    private void remove_info (PF.Progress.Info info) {
    warning ("remove info");
        progress_infos.remove (info);
        info.finished.disconnect (remove_info); // Otherwise info will not be destroyed.
    }
    public unowned Gee.LinkedList<PF.Progress.Info> get_all_infos () {
        return progress_infos;
    }
}
