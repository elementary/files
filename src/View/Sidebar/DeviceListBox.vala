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

public class Sidebar.DeviceListBox : Gtk.ListBox, Sidebar.SidebarListInterface {
    private VolumeMonitor volume_monitor;
    private Gee.HashMap<string, SidebarExpander> drive_row_map;

    public Marlin.SidebarInterface sidebar { get; construct; }

    public DeviceListBox (Marlin.SidebarInterface sidebar) {
        Object (
            sidebar: sidebar
        );
    }

    construct {
        drive_row_map = new Gee.HashMap<string, SidebarExpander> ();
        hexpand = true;
        volume_monitor = VolumeMonitor.@get ();
        volume_monitor.volume_added.connect (bookmark_volume_if_without_mount);
        volume_monitor.mount_added.connect (bookmark_mount_if_native_and_not_shadowed);
        volume_monitor.drive_connected.connect (bookmark_drive);
    }

    private DeviceRow? add_bookmark (string label, string uri, Icon gicon,
                                    string? uuid = null,
                                    Drive? drive = null,
                                    Volume? volume = null,
                                    Mount? mount = null,
                                    bool pinned = true,
                                    bool permanent = false) {
        DeviceRow? bm = has_uuid (uuid, uri);

        if (bm == null || bm.custom_name != label) { //Could be a bind mount with the same uuid
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
        }

        return bm;
    }

    public override uint32 add_plugin_item (Marlin.SidebarPluginItem plugin_item) {
        var row = add_bookmark (plugin_item.name,
                                 plugin_item.uri,
                                 plugin_item.icon,
                                 null,
                                 plugin_item.drive,
                                 plugin_item.volume,
                                 plugin_item.mount,
                                 true,
                                 true);

        row.update_plugin_data (plugin_item);
        return row.id;
    }

    public void refresh () {
        clear ();

        SidebarItemInterface? row;
        var root_uri = _(Marlin.ROOT_FS_URI);
        if (root_uri != "") {
            row = add_bookmark (
                _("File System"),
                root_uri,
                new ThemedIcon.with_default_fallbacks (Marlin.ICON_FILESYSTEM),
                null,
                null,
                null,
                null,
                true,  //Pinned
                true   //Permanent
            );

            row.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>slash"}, _("View the root of the local filesystem"))
            );
        }

        foreach (unowned GLib.Drive drive in volume_monitor.get_connected_drives ()) {
            bookmark_drive (drive);
        }

        foreach (unowned Volume volume in volume_monitor.get_volumes ()) {
            bookmark_volume_if_without_mount (volume);
        } // Add volumes not otherwise bookmarked

        foreach (unowned Mount mount in volume_monitor.get_mounts ()) {
            bookmark_mount_if_native_and_not_shadowed (mount);
        } // Bookmark all native mount points ();
    }

    public override void refresh_info () {
        get_children ().@foreach ((item) => {
            if (item is DeviceRow) {
                ((DeviceRow)item).update_free_space ();
            }
        });
    }

    private void bookmark_drive (Drive drive) {
        /* If the drive has no mountable volumes and we cannot detect media change.. we
         * display the drive in the sidebar so the user can manually poll the drive by
         * right clicking and selecting "Rescan..."
         *
         * This is mainly for drives like floppies where media detection doesn't
         * work.. but it's also for human beings who like to turn off media detection
         * in the OS to save battery juice.
         */
        var drive_row = new SidebarExpander (drive.get_name (), new Sidebar.DeviceListBox (sidebar));
        if (!drive_row_map.has_key (drive.get_name ())) {
            drive_row_map.@set (drive.get_name (), drive_row);
            drive_row.set_gicon (drive.get_icon ());
            add (drive_row);
        }
    }

    private void bookmark_volume_if_without_mount (Volume volume) {
        if (volume.get_drive () != null) {

            var key = volume.get_drive ().get_name ();
            DeviceListBox target;
            if (drive_row_map.has_key (key)) {
                var drive_row = drive_row_map.@get (key);
                target = (DeviceListBox)(drive_row.list);
                drive_row.active = true;  //Show newly added volume
            } else {
                target = this;
            }

            target.add_bookmark (
                    volume.get_name (),
                    "", // Do not know uri until mounted
                    volume.get_icon (),
                    volume.get_uuid (),
                    null,
                    volume,
                    null
            );
        }
    }

    private void bookmark_mount_if_native_and_not_shadowed (Mount mount) {
        if (mount.is_shadowed () || !mount.get_root ().is_native ()) {
            return;
        };

        var volume = mount.get_volume ();
        string? uuid = null;
        if (volume != null) {
            if (volume.get_drive () != null) {
                return; //Already listed under drive
            } else {
                uuid = volume.get_uuid ();
            }
        } else {
            uuid = mount.get_uuid ();
        }

        add_bookmark (
            mount.get_name (),
            mount.get_default_location ().get_uri (),
            mount.get_icon (),
            uuid,
            mount.get_drive (),
            mount.get_volume (),
            mount
        );
        //Show extra info in tooltip
    }

    private DeviceRow? has_uuid (string? uuid, string? fallback = null) {
        var search = uuid != null ? uuid : fallback;

        if (search == null) {
            return null;
        }

        foreach (unowned Gtk.Widget child in get_children ()) {
            if (child is DeviceRow) {
                if (((DeviceRow)child).uuid == uuid) {
                    return (DeviceRow)child;
                }
            }
        }

        return null;
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
