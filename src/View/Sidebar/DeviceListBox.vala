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

    public Marlin.SidebarInterface sidebar { get; construct; }

    public DeviceListBox (Marlin.SidebarInterface sidebar) {
        Object (
            sidebar: sidebar
        );
    }

    construct {
        hexpand = true;
        volume_monitor = VolumeMonitor.@get ();
        volume_monitor.mount_added.connect_after ((mount) => {
            /* This delay is needed to ensure that any corresponding volume row has finished updating after
             * mounting as a result of activating the row. Otherwise may get duplicate mount row e.g. for some MTP or
             * PTP mounts where the mount name differs from the volume name and get_uuid () yields null.
            */
            Timeout.add (100, () => {
                bookmark_mount_if_not_shadowed (mount);
                return Source.REMOVE;
            });
        });

        volume_monitor.volume_added.connect (refresh);
        volume_monitor.drive_connected.connect (refresh);

        row_activated.connect ((row) => {
            if (row is SidebarItemInterface) {
                ((SidebarItemInterface) row).activated ();
            }
        });
        row_selected.connect ((row) => {
            if (row is SidebarItemInterface) {
                select_item ((SidebarItemInterface) row);
            }
        });
    }

    private DeviceRow? add_bookmark (string label, string uri, Icon gicon,
                                    string? uuid = null,
                                    Drive? drive = null,
                                    Volume? volume = null,
                                    Mount? mount = null,
                                    bool pinned = true,
                                    bool permanent = false) {

        DeviceRow? bm = has_uuid (uuid, uri);

        if (bm == null) {
            var new_bm = new DeviceRow (
                label,
                uri,
                gicon,
                this,
                pinned, // Pin all device rows for now
                permanent || (bm != null && bm.permanent), //Ensure bind mount matches permanence of uuid
                uuid != null ? uuid : uri, //uuid fallsback to uri
                drive,
                volume,
                mount
            );

            add (new_bm);

            return new_bm;
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
            bookmark_stoppable_or_removeable_drive_if_without_volumes (drive);
        } // Add drives not otherwise bookmarked

        foreach (unowned Volume volume in volume_monitor.get_volumes ()) {
            bookmark_volume_if_without_mount (volume);
        } // Add volumes not otherwise bookmarked

        foreach (unowned Mount mount in volume_monitor.get_mounts ()) {
            bookmark_mount_if_not_shadowed (mount);
        } // Bookmark all native mount points ();
    }

    public override void refresh_info () {
        get_children ().@foreach ((item) => {
            if (item is DeviceRow) {
                ((DeviceRow)item).update_free_space ();
            }
        });
    }

    private void bookmark_stoppable_or_removeable_drive_if_without_volumes (Drive drive) {
        /* If the drive has no mountable volumes and we cannot detect media change.. we
         * display the drive in the sidebar so the user can manually poll the drive by
         * right clicking and selecting "Rescan..."
         *
         * This is mainly for drives like floppies where media detection doesn't
         * work.. but it's also for human beings who like to turn off media detection
         * in the OS to save battery juice.
         */

        if (drive.get_volumes () == null &&
            drive.can_stop () || (drive.is_media_removable () && !drive.is_media_check_automatic ())) {
            add_bookmark (
                drive.get_name (),
                drive.get_name (),
                drive.get_icon (),
                drive.get_name (), // Unclear what to use as a unique identifier for a drive so use name
                drive,
                null,
                null
            );
        }
    }

    private void bookmark_volume_if_without_mount (Volume volume) {
        var mount = volume.get_mount ();
        if (mount == null) {
            /* Do show the unmounted volumes in the sidebar;
            * this is so the user can mount it (in case automounting
            * is off).
            *
            * Also, even if automounting is enabled, this gives a visual
            * cue that the user should remember to yank out the media if
            * he just unmounted it.
            */
            add_bookmark (
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

    private void bookmark_mount_if_not_shadowed (Mount mount) {
        if (mount.is_shadowed ()) {
            return;
        };

        var volume = mount.get_volume ();
        var uuid = mount.get_uuid ();
        if (uuid == null || uuid == "") {
            if (volume != null) {
                uuid = volume.get_uuid ();
            }
        }

        var path = mount.get_default_location ().get_uri ();
        if (uuid == null || uuid == "") {
            uuid = path;
        }

        add_bookmark (
            mount.get_name (),
            path,
            mount.get_icon (),
            uuid,
            mount.get_drive (),
            mount.get_volume (),
            mount
        );
        //Show extra info in tooltip
    }

    private DeviceRow? has_uuid (string? uuid, string? fallback = null) {
        var searched_uuid = uuid != null ? uuid : fallback;

        if (searched_uuid == null) {
            return null;
        }

        foreach (unowned Gtk.Widget child in get_children ()) {
            if (child is DeviceRow) {
                if (((DeviceRow)child).uuid == searched_uuid) {
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
