/* DeviceRow.vala
 *
 * Copyright 2021 elementary LLC. <https://elementary.io>
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

// Use only for a Drive that has no volumes (otherwise display volumes as VolumeRows)
// This covers:
// unformatted drives,
// drives without partitions,
// drives with removeable media that have no media inserted.

/* FIXME Handle insertion of media into an empty drive (which will result in a volume row being created) The drive row should be hidden */
/* FIXME Handle ejection of media from a drive (which will result in a volume row disappearing). The drive row should reappear */
/* NOTE The above issues would not occur if we have expandable drive rows with nested volumes. */

/* It is uncertain whether this class is a good idea. Nautilus does not show any entry for unformatted drives. */

public class Sidebar.EmptyDriveRow : Sidebar.DeviceRow, SidebarItemInterface {
    public Drive drive { get; construct; }
    private bool can_eject = true;

    public override bool is_mounted {
        get {
            return false; // Volumeless drives are regarded as unmounted
        }
    }

    public EmptyDriveRow (string name, string uri, Icon gicon, SidebarListInterface list,
                         bool pinned, bool permanent,
                         string? _uuid, Drive _drive) {
        Object (
            custom_name: name,
            uri: uri,
            gicon: gicon,
            list: list,
            pinned: true,  //pinned
            permanent: permanent,
            uuid: _uuid,
            drive: _drive
        );

        assert (drive != null && drive.get_volumes () == null);
        // DriveRow represents a working drive so start it if necessary.
        // Unnecessary for most drives currently used?
        if (drive.can_start () || drive.can_start_degraded ()) {
            working = true;
            drive.start.begin (
               DriveStartFlags.NONE,
               new Gtk.MountOperation (null),
               null,
               (obj, res) => {
                    try {
                        drive.start.end (res);
                    } catch (Error e) {
                            var primary = _("Unable to start '%s'").printf (drive.get_name ());
                            PF.Dialogs.show_error_dialog (primary, e.message, Files.get_active_window ());
                            eject.begin ();
                    } finally {
                        working = false;
                        add_mountable_tooltip.begin ();
                    }
                }
            );
        }

        can_eject = drive.can_eject () || drive.can_stop ();
        mount_eject_revealer.reveal_child = can_eject && !permanent;
    }

    construct {
        volume_monitor.drive_disconnected.connect (drive_removed);
    }

    protected override void activated (Files.OpenFlag flag = Files.OpenFlag.DEFAULT) {
        PF.Dialogs.show_warning_dialog (_("This drive contains no data"),
                                        _("Insert media or format the drive"),
                                        null);
    }

    protected override async bool eject () {
        if (working || !valid || !can_eject) {
            return false;
        }

        var mount_op = new Gtk.MountOperation (Files.get_active_window ());

        if (drive.can_stop ()) {
            working = true;
            try {
                yield drive.stop (
                    GLib.MountUnmountFlags.NONE,
                    mount_op,
                    null
                );
                return true;
            } catch (Error e) {
                warning ("Could not stop drive '%s': %s", drive.get_name (), e.message);
                return false;
            } finally {
                working = false;
            }
        } else if (drive.can_eject ()) {
            working = true;
            try {
                yield drive.eject_with_operation (
                    GLib.MountUnmountFlags.NONE,
                    mount_op,
                    null
                );
                return true;
            } catch (Error e) {
                warning ("Could not eject drive '%s': %s", drive.get_name (), e.message);
                return false;
            } finally {
                working = false;
            }
        }

        return true;
    }

    private void drive_removed (Drive removed_drive) {
        if (!valid) { //Already removed
            return;
        }

        if (drive == removed_drive) {
            valid = false;
            list.remove_item_by_id (id);
        }
    }

    protected override void add_extra_menu_items (PopupMenuBuilder menu_builder) {
    }
}
