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
// drives with removeable media that have no media inserted,
// USB sticks that have been ejected but not unplugged.

public class Sidebar.DriveRow : Sidebar.AbstractMountableRow, SidebarItemInterface {
    public Drive drive { get; construct; }

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
            pinned: pinned,
            permanent: permanent,
            uuid: _uuid,
            drive: _drive
        );

        no_show_all = true;
        set_visibility ();
    }

    construct {
        sort_key = MountableType.EMPTY_DRIVE.to_string () + custom_name;
        volume_monitor.drive_disconnected.connect (drive_removed);
        volume_monitor.volume_added.connect (volume_added);
        volume_monitor.volume_removed.connect (volume_removed);
    }

    protected override void activated (Files.OpenFlag flag = Files.OpenFlag.DEFAULT) {
        PF.Dialogs.show_warning_dialog (_("%s contains no accessible data.").printf (drive.get_name ()),
                                        _("To use this drive you may need to unplug then replug it, insert media or format it."),
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
        set_visibility ();
    }

    private void volume_removed () {
        set_visibility ();
    }

    private void set_visibility () {
        visible = !drive.has_volumes ();
        if (!drive.has_media () || !drive.has_volumes ()) {
            var details = !drive.has_media () ? _("Media ejected") : _("Unformatted");
            custom_name = drive.get_name () +
                          "\n" + details + " " +
                         (drive.is_removable () ? _("This device can be safely unplugged.") : "");

            add_mountable_tooltip.begin (); // Change tooltip to match new custom name.
        }

        update_visibilities (); // Show/hide eject button and sorage bar.
    }

    protected override void add_extra_menu_items (PopupMenuBuilder menu_builder) {
        if (drive == null) {
            return;
        }

        debug ("Getting Menu Items for DriveRow %s: can_eject %s, can_stop %s, can start %s, can start degraded %s, media_removable %s, drive removable %s",
            drive.get_name (), drive.can_eject ().to_string (), drive.can_stop ().to_string (), drive.can_start ().to_string (),
            drive.can_start_degraded ().to_string (), drive.is_media_removable ().to_string (), drive.is_removable ().to_string ());

        if (drive.can_stop ()) {
            menu_builder
                .add_separator ()
                .add_stop_drive (() => { eject_stop_drive (drive, true); });
        }
    }

    protected override async void add_mountable_tooltip () {
        set_tooltip_markup (custom_name);
    }

    protected override void popup_context_menu (Gdk.EventButton event) {
        // At present, this type of row only shows when there is no media or unformatted so there are no
        // usable actions.  In future, actions like "Format" might be added.
        var menu_builder = new PopupMenuBuilder ();
        add_extra_menu_items (menu_builder);

        menu_builder
            .build ()
            .popup_at_pointer (event);

        return;
    }
}
