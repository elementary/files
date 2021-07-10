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

    public Files.SidebarInterface sidebar { get; construct; }

    public DeviceListBox (Files.SidebarInterface sidebar) {
        Object (
            sidebar: sidebar
        );
    }

    construct {
        hexpand = true;
        volume_monitor = VolumeMonitor.@get ();
        volume_monitor.drive_connected.connect (bookmark_drive_without_volume);
        volume_monitor.mount_added.connect (bookmark_mount_without_volume);
        volume_monitor.volume_added.connect (bookmark_volume);

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

    private DeviceRow add_bookmark (string label, string uri, Icon gicon,
                                    string? uuid = null,
                                    Drive? drive = null,
                                    Volume? volume = null,
                                    Mount? mount = null,
                                    bool pinned = true,
                                    bool permanent = false) {

        DeviceRow? bm = null; // Existing bookmark with same uuid
        if (!has_uuid (uuid, uri, out bm) || bm.custom_name != label) { //Could be a bind mount with the same uuid
            DeviceRow new_bm;
            if (drive != null && volume == null) {
warning ("add bm - DRIVE %s", label);
                new_bm = new DriveRow (
                    label,
                    uri,
                    gicon,
                    this,
                    pinned, // Pin all device rows for now
                    permanent || (bm != null && bm.permanent), //Ensure bind mount matches permanence of uuid
                    uuid != null ? uuid : uri, //uuid fallsback to uri
                    drive
                );
            } else if (volume == null ) {
warning ("add bm - MOUNT %s", label);
                new_bm = new MountRow (
                    label,
                    uri,
                    gicon,
                    this,
                    pinned, // Pin all device rows for now
                    permanent || (bm != null && bm.permanent), //Ensure bind mount matches permanence of uuid
                    uuid != null ? uuid : uri, //uuid fallsback to uri
                    mount
                );
            } else {
warning ("add bm - VOLUME %s", label);
                new_bm = new VolumeRow (
                    label,
                    uri,
                    gicon,
                    this,
                    pinned, // Pin all device rows for now
                    permanent || (bm != null && bm.permanent), //Ensure bind mount matches permanence of uuid
                    uuid != null ? uuid : uri, //uuid fallsback to uri
                    volume
                );
            }
            add (new_bm);

            show_all ();
            bm = new_bm;
            bm.update_free_space ();
        }

        return bm; // Should not be null (either an existing bookmark or a new one)
    }

    public override uint32 add_plugin_item (Files.SidebarPluginItem plugin_item) {
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

        var root_uri = _(Files.ROOT_FS_URI);
        if (root_uri != "") {
            var row = add_bookmark (
                _("File System"),
                root_uri,
                new ThemedIcon.with_default_fallbacks (Files.ICON_FILESYSTEM),
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

        foreach (Volume volume in volume_monitor.get_volumes ()) {
            bookmark_volume (volume);
        }

        foreach (GLib.Drive drive in volume_monitor.get_connected_drives ()) {
            bookmark_drive_without_volume (drive);
        }

        foreach (Mount mount in volume_monitor.get_mounts ()) {
            bookmark_mount_without_volume (mount);
        }
    }

    public override void refresh_info () {
        get_children ().@foreach ((item) => {
            if (item is DeviceRow) {
                ((DeviceRow)item).update_free_space ();
            }
        });
    }

    private void bookmark_drive_without_volume (Drive drive) {

        /* If the drive has no mountable volumes and we cannot detect media change.. we
         * display the drive in the sidebar so the user can manually poll the drive by
         * right clicking and selecting "Rescan..."
         *
         * This is mainly for drives like floppies where media detection doesn't
         * work.. but it's also for human beings who like to turn off media detection
         * in the OS to save battery juice.
         */

        if (drive.get_volumes () == null) {
warning ("DRIVE added %s", drive.get_name ());
            add_bookmark (
                drive.get_name (),
                "", // No uri available from drive??
                drive.get_icon (),
                drive.get_name (), // Unclear what to use as a unique identifier for a drive so use name
                drive,
                null,
                null
            );
        }
    }

    private void bookmark_volume (Volume volume) {
warning ("VOLUME added %s", volume.get_name ());
        var mount = volume.get_mount ();
        add_bookmark (
            volume.get_name (),
            mount != null ? mount.get_default_location ().get_uri () : "",
            volume.get_icon (),
            volume.get_uuid (),
            null,
            volume,
            null
        );
    }

    private void bookmark_mount_without_volume (Mount mount) {
        if (mount.is_shadowed () ||
            !mount.get_root ().is_native () ||
            mount.get_volume () != null) {

            return;
        };
warning ("MOUNT added %s", mount.get_name ());
        var uuid = mount.get_uuid ();
        var path = mount.get_default_location ().get_uri ();
        if (uuid == null || uuid == "") {
            uuid = path;
        }

        var bm = add_bookmark (
            mount.get_name (),
            path,
            mount.get_icon (),
            uuid,
            null,
            null,
            mount
        );
    }

    private bool has_uuid (string? uuid, string? fallback, out DeviceRow? row) {
        row = null;
        var searched_uuid = uuid != null ? uuid : fallback;

        if (searched_uuid == null) {
            return false;
        }

        foreach (unowned Gtk.Widget child in get_children ()) {
            if (child is DeviceRow) {
                if (((DeviceRow)child).uuid == searched_uuid) {
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
        foreach (unowned Gtk.Widget child in get_children ()) {
            if (child is DeviceRow) {
                unselect_row ((DeviceRow)child);
            }
        }
    }

    public void select_item (SidebarItemInterface? item) {
        if (item != null && item is DeviceRow) {
            select_row ((DeviceRow)item);
        } else {
            unselect_all_items ();
        }
    }
}
