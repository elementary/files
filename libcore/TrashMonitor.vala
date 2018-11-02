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

public class Marlin.TrashMonitor : GLib.Object {
    public const string URI = "trash://";

    private static Marlin.TrashMonitor marlin_trash_monitor;
    public static unowned Marlin.TrashMonitor get_default () {
        if (marlin_trash_monitor == null) {
            marlin_trash_monitor = new Marlin.TrashMonitor ();
        }

        return marlin_trash_monitor;
    }

    public bool is_empty { get; private set; default=true; }
    private GLib.Icon icon;
    private GLib.FileMonitor file_monitor;
    private GLib.File trash_file;

    construct {
        icon = new GLib.ThemedIcon ("user-trash");
        trash_file = GLib.File.new_for_uri (TrashMonitor.URI);
        try {
            file_monitor = trash_file.monitor (GLib.FileMonitorFlags.NONE);
            file_monitor.changed.connect ((file, other_file, event_type) => {
                update_info.begin ();
            });
        } catch (Error e) {
            critical (e.message);
        }

        update_info.begin (() => { /* Ensure a notify signal is emitted when first set accurately */
            notify_property ("is-empty");
        });
    }

    public GLib.Icon get_icon () {
        return icon;
    }

    private async void update_info () {
        try {
            var attribs = GLib.FileAttribute.STANDARD_ICON + "," + GLib.FileAttribute.TRASH_ITEM_COUNT;
            var info = yield trash_file.query_info_async (attribs, GLib.FileQueryInfoFlags.NONE);
            var new_icon = info.get_icon ();
            if (new_icon != null) {
                icon = new_icon;
            }

            var toplevel_trash_count = info.get_attribute_uint32 (GLib.FileAttribute.TRASH_ITEM_COUNT);
            is_empty = toplevel_trash_count == 0;
        } catch (Error e) {
            critical (e.message);
        }
    }
}
