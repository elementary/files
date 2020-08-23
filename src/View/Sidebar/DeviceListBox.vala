/*
 * Copyright 2020 Jeremy Paul Wootten <jeremy@jeremy-Kratos-Ubuntu>
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
 *
 */

public class Sidebar.DeviceListBox : Sidebar.BookmarkListBox {
    protected VolumeMonitor volume_monitor;
    public DeviceListBox (Sidebar.SidebarWindow sidebar) {
        base (sidebar);
    }

    construct {
        volume_monitor = VolumeMonitor.@get ();
        volume_monitor.volume_added.connect (volume_added);
        volume_monitor.mount_added.connect (mount_added);
        volume_monitor.drive_connected.connect (drive_added);
    }

    public new DeviceRow? add_bookmark (string label, string uri, Icon gicon,
                                       string? uuid = null,
                                       Drive? drive = null,
                                       Volume? volume = null,
                                       Mount? mount = null) {
        var bm = new DeviceRow (
            label,
            uri,
            gicon,
            sidebar,
            uuid,
            drive,
            volume,
            mount
        );

        if (!has_uuid (uuid, uri)) {
            add (bm);
            if (mount != null) {
                bm.mounted = true;
                bm.can_eject = mount.can_unmount ();
            } else if (volume != null) {
                bm.mounted = false;
                bm.can_eject = volume.can_eject () ||
                               volume.get_drive () != null && volume.get_drive ().can_eject ();
            } else if (drive != null) {
                bm.mounted = true;
                bm.can_eject = drive.can_eject ();
            }

            bm.add_tooltip.begin ();
        } else {
            return null;
        }

        return bm;
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
                volume.get_uuid (),
                null,
                volume,
                null
            );
        }
    }

    private void add_mount (Mount mount)  {
        /* show mounted volume in sidebar */
        var root = mount.get_root ();
        var device_label = root.get_basename ();
        if (device_label != mount.get_name ()) {
            ///TRANSLATORS: The first string placeholder '%s' represents a device label, the second '%s' represents a mount name.
            device_label = _("%s on %s").printf (device_label, mount.get_name ());
        }

        var uuid = mount.get_uuid () ?? (mount.get_volume () != null ? mount.get_volume ().get_uuid () : null);
        add_bookmark (
            device_label,
            mount.get_default_location ().get_uri (),
            mount.get_icon (),
            uuid,
            mount.get_drive (),
            mount.get_volume (),
            mount
        );
    }

   private void add_drive (Drive drive) {
       var volumes = drive.get_volumes ();
        if (volumes != null) {
            add_volumes (volumes);
        } else if (drive.is_media_removable () && !drive.is_media_check_automatic ()) {
        /* If the drive has no mountable volumes and we cannot detect media change.. we
         * display the drive in the sidebar so the user can manually poll the drive by
         * right clicking and selecting "Rescan..."
         *
         * This is mainly for drives like floppies where media detection doesn't
         * work.. but it's also for human beings who like to turn off media detection
         * in the OS to save battery juice.
         */
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

    private void drive_added (Drive drive)  {}

    private void volume_added (Volume vol)  {
        add_volume (vol);
    }

    private void mount_added (Mount mount)  {
        var uuid = mount.get_uuid () ?? (mount.get_volume () != null ? mount.get_volume ().get_uuid () : null);
        if (!has_uuid (uuid, mount.get_name ())) {
            add_mount (mount);
        }
    }

    public void add_all_local_volumes_and_mounts () {
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
}


