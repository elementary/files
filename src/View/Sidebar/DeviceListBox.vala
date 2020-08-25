/* DeviceListBox.vala
 *
 * Copyright 2020 elementary LLC. <https://elementary.io>
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
        volume_monitor.volume_added.connect (volume_added);
        volume_monitor.mount_added.connect (mount_added);
        volume_monitor.drive_connected.connect (drive_added);
    }

    private DeviceRow? add_bookmark (string label, string uri, Icon gicon, SidebarListInterface list,
                                    string? uuid = null,
                                    Drive? drive = null,
                                    Volume? volume = null,
                                    Mount? mount = null) {
        var bm = new DeviceRow (
            label,
            uri,
            gicon,
            list,
            uuid,
            drive,
            volume,
            mount
        );

        if (!has_uuid (uuid, uri)) {
            add (bm);
            if (mount != null) {
                bm.mounted = true;
                bm.can_eject = mount.can_unmount () || mount.can_eject ();
            } else if (volume != null) {
                bm.mounted = volume.get_mount () != null;
                bm.can_eject = volume.can_eject ();
            } else if (drive != null) {
                bm.mounted = true;
                bm.can_eject = drive.can_eject () || drive.can_stop ();
            }
        } else {
            return null;
        }

        return bm;
    }

    public void refresh () {
        clear ();

        SidebarItemInterface? row;
        var root_uri = _(Marlin.ROOT_FS_URI);
        if (root_uri != "") {
            row = add_bookmark (
                _("FileSystem"),
                root_uri,
                new ThemedIcon.with_default_fallbacks (Marlin.ICON_FILESYSTEM),
                this
            );

            row.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>slash"}, _("View the root of the local filesystem"))
            );
        }

        add_all_local_volumes_and_mounts ();
    }

    private void add_volume (Volume volume) {
        var mount = volume.get_mount ();
        if (mount != null) {
            add_mount (mount);
        } else {
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
                volume.get_name (),
                volume.get_icon (),
                this,
                volume.get_uuid (),
                null,
                volume,
                null
            );
        }
    }

    private void add_mount (Mount mount) {
        var uuid = mount.get_uuid () ?? (mount.get_volume () != null ? mount.get_volume ().get_uuid () : null);
        add_bookmark (
            mount.get_name (),
            mount.get_default_location ().get_uri (),
            mount.get_icon (),
            this,
            uuid,
            mount.get_drive (),
            mount.get_volume (),
            mount
        );
        //Show extra info in tooltip
    }

   private void add_drive (Drive drive) {
       var volumes = drive.get_volumes ();
        if (volumes != null) {
            add_volumes (volumes);
        }

        if (drive.can_stop () || drive.can_eject () || volumes == null) {
            add_drive_without_volumes (drive);
        }
    }

    private void add_drive_without_volumes (Drive drive) {
    /* If the drive has no mountable volumes and we cannot detect media change.. we
     * display the drive in the sidebar so the user can manually poll the drive by
     * right clicking and selecting "Rescan..."
     *
     * This is mainly for drives like floppies where media detection doesn't
     * work.. but it's also for human beings who like to turn off media detection
     * in the OS to save battery juice.
     */
        if (drive.can_stop () ||
            (drive.is_media_removable () && !drive.is_media_check_automatic ())) {

            add_bookmark (
                drive.get_name (),
                drive.get_name (),
                drive.get_icon (),
                this,
                drive.get_name (), // Unclear what to use as a unique identifier for a drive so use name
                drive,
                null,
                null
            );
        }
    }

    private void drive_added (Drive drive_added) {
        if ((!drive_added.has_volumes () || drive_added.can_stop ()) &&
             !has_drive (drive_added, null)) {

            add_drive_without_volumes (drive_added);
        }
    }

    private void volume_added (Volume volume_added) {
        if (volume_added.get_mount () == null && !has_volume (volume_added, null)) {
            add_volume (volume_added);
        }
    }

    private void mount_added (Mount mount_added) {
        if (!mount_added.is_shadowed () &&
            mount_added.get_volume () == null &&
            !has_mount (mount_added, null)) {

            add_mount (mount_added);
        }
    }

    private void add_all_local_volumes_and_mounts () {
        add_connected_drives (); // Add drives and their associated volumes
        add_volumes_without_drive (); // Add volumes not associated with a drive
        add_native_mounts_without_volume ();
    }

    private void add_connected_drives () {
        foreach (GLib.Drive drive in volume_monitor.get_connected_drives ()) {
            add_drive (drive);
        }
    }

    private void add_volumes (List<Volume> volumes) {
        foreach (Volume volume in volumes) {
            add_volume (volume);
        }
    }

    private void add_volumes_without_drive () {
        foreach (Volume volume in volume_monitor.get_volumes ()) {
            if (volume.get_drive () == null) {
                add_volume (volume);
            }
        }
    }

    private void add_native_mounts_without_volume () {
        foreach (Mount mount in volume_monitor.get_mounts ()) {
            if (mount.is_shadowed ()) {
                continue;
            }

            var volume = mount.get_volume ();
            if (volume == null) {
                var root = mount.get_root ();
                if (root.is_native () && root.get_uri_scheme () != "archive") {
                    add_mount (mount);
                }
            }
        }
    }

    private bool has_uuid (string? uuid, string? fallback = null) {
        var search = uuid != null ? uuid : fallback;

        if (search == null) {
            return false;
        }

        foreach (var child in get_children ()) {
            if (child is DeviceRow) {
                if (((DeviceRow)child).uuid == uuid) {
                    return true;
                }
            }
        }

        return false;
    }

    private bool has_drive (Drive drive, out DeviceRow? row = null) {
        row = null;
        foreach (var child in get_children ()) {
            if (child is DeviceRow) {
                if (((DeviceRow)child).drive == drive) {
                    row = ((DeviceRow)child);
                    return true;
                }
            }
        }

        return false;
    }

    private bool has_volume (Volume vol, out DeviceRow? row = null) {
        row = null;
        foreach (var child in get_children ()) {
            if (child is DeviceRow) {
                if (((DeviceRow)child).volume == vol) {
                    row = ((DeviceRow)child);
                    return true;
                }
            }
        }

        return false;
    }

    private bool has_mount (Mount mount, out DeviceRow? row = null) {
        row = null;
        foreach (var child in get_children ()) {
            if (child is DeviceRow) {
                if (((DeviceRow)child).mount == mount) {
                    row = ((DeviceRow)child);
                    return true;
                }
            }
        }

        return false;
    }

    public override SidebarItemInterface? add_sidebar_row (string label, string uri, Icon gicon) {
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
