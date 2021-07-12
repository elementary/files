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

// Only show for a Drive that has no volumes (otherwise display volumes as VolumeRows)
// This covers:
// unformatted drives,
// drives without partitions,
// drives with removeable media that have no media inserted.

public class Sidebar.DriveRow : Sidebar.AbstractDeviceRow, SidebarItemInterface {
    public Drive drive { get; construct; }
    private bool can_eject = true;

    public override bool is_mounted {
        get {
            return false; // Volumeless drives are regarded as unmounted
        }
    }

    public DriveRow (string name, string uri, Icon gicon, SidebarListInterface list,
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

        assert (drive != null);

        can_eject = false;
        mount_eject_revealer.reveal_child = false;

        no_show_all = true;
        visible = !drive.has_volumes ();
    }

    construct {
        volume_monitor.drive_disconnected.connect (drive_removed);
        volume_monitor.volume_added.connect (volume_added);
        volume_monitor.volume_removed.connect (volume_removed);
    }

    protected override void activated (Files.OpenFlag flag = Files.OpenFlag.DEFAULT) {
        PF.Dialogs.show_warning_dialog (_("This drive contains no data"),
                                        _("Insert media or format the drive"),
                                        null);
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

    private void volume_added (Volume added_volume) {
        if (drive.get_volumes () != null) {
            visible = false;
        }
    }

    private void volume_removed () {
        if (drive.get_volumes () == null) {
            visible = true;
        }
    }

    protected override void add_extra_menu_items (PopupMenuBuilder menu_builder) {
    }

    protected override async void add_mountable_tooltip () {
        if (!drive.has_media ()) {
            set_tooltip_markup (_("%s (%s)").printf (custom_name, _("No media")));
        } else if (!drive.has_volumes ()) {
            set_tooltip_markup (_("%s (%s)").printf (custom_name, _("Unformatted")));
        } else {
            set_tooltip_markup (custom_name);
        }
    }
}
