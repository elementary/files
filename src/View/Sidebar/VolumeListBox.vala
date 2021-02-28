/* DeviceListBox.vala
 *
 * Copyright 2020 elementary, Inc (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 * Authors : Jeremy Wootten <jeremy@elementaryos.org>
 */

public class Sidebar.VolumeListBox : Gtk.ListBox, Sidebar.SidebarListInterface {
    public Drive drive { get; construct; }
    private VolumeMonitor volume_monitor;
    private Gee.HashMap<string, DeviceRow> volume_row_map;

    public Marlin.SidebarInterface sidebar { get; construct; }

    public VolumeListBox (Marlin.SidebarInterface sidebar, Drive drive) {
        Object (
            sidebar: sidebar,
            drive: drive
        );
    }

    construct {
        volume_row_map = new Gee.HashMap<string, DeviceRow> ();
        hexpand = true;
        volume_monitor = VolumeMonitor.@get ();
        refresh ();
        volume_monitor.volume_added.connect ((volume) => {
            var vol_drive = volume.get_drive ();
            if (vol_drive != null && vol_drive == drive) {
                bookmark_volume (volume);
            }
        });
    }

    private DeviceRow add_bookmark (string label, string uri, Icon gicon,
                                    string? uuid = null,
                                    Drive? drive = null,
                                    Volume? volume = null,
                                    Mount? mount = null,
                                    bool pinned = true,
                                    bool permanent = false) {

        DeviceRow? bm = null;
        if (!has_uuid (uuid, out bm, uri) || bm.custom_name != label) { //Could be a bind mount with the same uuid
            var new_bm = new DeviceRow (
                label,
                uri,
                gicon,
                this,
                pinned, // Pin all device rows for now
                permanent || (bm != null && bm.permanent), //Ensure bind mount matches permanence of uuid
                uuid,
                drive,
                volume,
                mount
            );

            add (new_bm);
            show_all ();
            bm = new_bm;
        }

        bm.update_free_space ();
        return bm;
    }

    public void refresh () {
        clear ();

        foreach (unowned Volume volume in drive.get_volumes ()) {
            bookmark_volume (volume);
        }
    }

    public override void refresh_info () {
        get_children ().@foreach ((item) => {
            if (item is DeviceRow) {
                ((DeviceRow)item).update_free_space ();
            }
        });
    }

    private void bookmark_volume (Volume volume) {
        var mount = volume.get_mount ();
        add_bookmark (
            volume.get_name (),
            mount != null ? mount.get_default_location ().get_uri () : "",
            volume.get_icon (),
            volume.get_uuid (),
            drive,
            volume,
            mount
        );
    }

    private bool has_uuid (string? uuid, out DeviceRow? row, string? fallback = null) {
        row = null;
        var search = uuid != null ? uuid : fallback;

        if (search == null) {
            return false;
        }

        foreach (unowned Gtk.Widget child in get_children ()) {
            if (child is DeviceRow) {
                if (((DeviceRow)child).uuid == uuid) {
                    row = (DeviceRow)child;
                    return true;
                }
            }
        }

        return false;
    }

    public SidebarItemInterface? add_sidebar_row (string label, string uri, Icon gicon) {
        //We do not want devices to be added by external agents
        return null;
    }

    public void unselect_all_items () {
        unselect_all ();
    }

    public void select_item (SidebarItemInterface? item) {
        if (item != null && item is DeviceRow) {
            select_row ((DeviceRow)item);
        } else {
            unselect_all_items ();
        }
    }
}
