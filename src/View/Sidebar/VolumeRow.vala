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

/* Most of the storage rows will be volumes associated with a drive.  However some devices (e.g. MP3 players may appear as a volume without a drive */
public class Sidebar.VolumeRow : Sidebar.AbstractMountableRow, SidebarItemInterface {
    public Volume volume {get; construct;}
    public string? drive_name {
        owned get {
            return drive != null ? drive.get_name () : null;
        }
    }

    public override bool is_mounted {
        get {
            return volume.get_mount () != null;
        }
    }

    public override bool can_unmount {
        get {
            return (is_mounted && volume.get_mount ().can_unmount ());
        }
    }

    public override bool can_eject {
        get {
            bool should_eject = drive != null ? drive.get_volumes ().length () == 1 : true;
            return (is_mounted && volume.get_mount ().can_eject () && should_eject);
        }
    }

    public VolumeRow (string name, string uri, Icon gicon, SidebarListInterface list,
                         bool pinned, bool permanent,
                         string? _uuid, Volume _volume) {
        Object (
            custom_name: name,
            uri: uri,
            gicon: gicon,
            list: list,
            pinned: true,  //pinned
            permanent: permanent,
            uuid: _uuid,
            volume: _volume,
            mount: _volume.get_mount (),
            drive: _volume.get_drive ()
        );

        string? drive_sort_key = drive != null ? drive.get_sort_key () : null;
        string? volume_id = volume.get_identifier (VolumeIdentifier.UNIX_DEVICE);
        string? volume_sort_key = volume.get_sort_key ();

        sort_key = drive_sort_key != null ? drive_sort_key : "";
        sort_key += volume_id != null ? volume_id : "";
        sort_key += volume_sort_key != null ? volume_sort_key : "";

        if (sort_key.length == 0) {
            sort_key = MountableType.VOLUME.to_string () + name;
        }

        if (drive_name != null && drive_name != "") {
            custom_name = _("%s (%s)").printf (custom_name, drive_name);
        }

        var mount_action = new SimpleAction ("mount", null);
        mount_action.activate.connect (() => mount_volume ());

        var action_group = new SimpleActionGroup ();
        action_group.add_action (mount_action);

        insert_action_group ("volume", action_group);
    }

    construct {
        volume_monitor.volume_removed.connect (on_volume_removed);
    }

    protected override void activated (Files.OpenFlag flag = Files.OpenFlag.DEFAULT) {
        if (working) {
            return;
        }

        if (is_mounted) { //Permanent devices are always accessible
            list.open_item (this, flag);
            return;
        }

        mount_volume (true, flag);
    }

    private void on_volume_removed (Volume removed_volume) {
        if (!valid) { //Already removed
            return;
        }

        if (volume == removed_volume) {
            valid = false;
            list.remove_item_by_id (id);
        }
    }

    protected override void on_mount_added (Mount added_mount) {
        if (added_mount == volume.get_mount ()) {
            mount = volume.get_mount ();
            update_visibilities ();
        }
    }

    protected override void on_mount_removed (Mount removed_mount) {
        if (volume.get_mount () == null) {
            mount = null;
            update_visibilities ();
        }
    }

    protected override void add_extra_menu_items (PopupMenuBuilder menu_builder) {
        if (working) {
            return;
        }

        add_extra_menu_items_for_mount (volume.get_mount (), menu_builder);
        add_extra_menu_items_for_drive (volume.get_drive (), menu_builder);
    }

    private void mount_volume (bool open = false, Files.OpenFlag flag = Files.OpenFlag.DEFAULT) {
        working = true;
        Files.FileOperations.mount_volume_full.begin (
            volume,
            null,
            (obj, res) => {
                Files.FileOperations.mount_volume_full.end (res);
                var mount = volume.get_mount ();
                if (mount != null) {
                    uri = mount.get_default_location ().get_uri ();
                    if (volume.get_uuid () == null) {
                        uuid = uri;
                    }

                    if (open) {
                        list.open_item (this, flag);
                    }
                }

                working = false;
                add_mountable_tooltip.begin ();
            }
        );
    }

    protected void add_extra_menu_items_for_drive (Drive? drive, PopupMenuBuilder menu_builder) {
        if (drive == null) {
            return;
        }

        if (!is_mounted) {
            menu_builder.add_with_action_name (_("Mount"), "volume.mount");
        }

        var sort_key = drive.get_sort_key ();
        if (sort_key != null && sort_key.contains ("hotplug")) {
            menu_builder.add_separator ();
            menu_builder.add_safely_remove ();
        } else if (mount == null && drive.can_eject ()) {
            menu_builder.add_separator ();
            // Do we need different text for USB sticks and optical drives?
            menu_builder.add_with_action_name (_("Eject Media"), "mountable.eject");
        }
    }

    protected override async bool get_filesystem_space (Cancellable? update_cancellable) {
        if (is_mounted) {
            return yield get_filesystem_space_for_root (volume.get_mount ().get_root (), update_cancellable);
        } else {
            return false;
        }
    }

    private void open_volume_property_window () {
        new Files.View.VolumePropertiesWindow (
            volume.get_mount (),
            Files.get_active_window ()
        );
    }

    protected override void show_mount_info () requires (!working) {
        if (!is_mounted) {
            /* Mount the device if possible, defer showing the dialog after
             * we're done */
            working = true;
            Files.FileOperations.mount_volume_full.begin (volume, null, (obj, res) => {
                Files.FileOperations.mount_volume_full.end (res);
                working = false;

                if (is_mounted) {
                    open_volume_property_window ();
                }
            });
        } else {
            open_volume_property_window ();
        }
    }
}
