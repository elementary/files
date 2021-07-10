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

public class Sidebar.VolumeRow : Sidebar.DeviceRow, SidebarItemInterface {

    public Volume volume {get; construct;}
    public string? drive_name {
        owned get {
            var drive = volume.get_drive ();
            return drive != null ? drive.get_name () : null;
        }
    }

    public override bool is_mounted {
        get {
assert (volume != null);
            return volume.get_mount () != null;
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
            volume: _volume
        );

        assert (volume != null && volume is Volume);
        tooltip_text = _("Volume %s on %s").printf (name, drive_name ?? "No Drive");
        var mount = volume.get_mount ();
        mount_eject_revealer.reveal_child = mount != null && mount.can_unmount ();
    }

    construct {
        volume_monitor.volume_removed.connect (volume_removed);
    }

    protected override async bool eject () {
        return yield eject_mount (volume.get_mount ());
    }

    protected override void activated (Files.OpenFlag flag = Files.OpenFlag.DEFAULT) {
warning ("activate");
        if (working) {
            return;
        }

        if (is_mounted) { //Permanent devices are always accessible
            list.open_item (this, flag);
            return;
        }

        working = true;
        volume.mount.begin (
            GLib.MountMountFlags.NONE,
            new Gtk.MountOperation (Files.get_active_window ()),
            null,
            (obj, res) => {
                try {
                    volume.mount.end (res);
                    var mount = volume.get_mount ();
                    if (mount != null) {
                        mount_eject_revealer.reveal_child = mount.can_unmount ();
                        uri = mount.get_default_location ().get_uri ();
                        if (volume.get_uuid () == null) {
                            uuid = uri;
                        }

                        list.open_item (this, flag);
                    }
                } catch (GLib.Error error) {
                    var primary = _("Error mounting volume '%s'").printf (volume.get_name ());
                    PF.Dialogs.show_error_dialog (primary, error.message, Files.get_active_window ());
                } finally {
                    working = false;
                    add_mountable_tooltip.begin ();
                }
            }
        );
    }

    private void volume_removed (Volume removed_volume) {
        if (!valid) { //Already removed
            return;
        }

        if (volume == removed_volume) {
            valid = false;
            list.remove_item_by_id (id);
        }
    }

    protected override void add_extra_menu_items (PopupMenuBuilder menu_builder) {
        add_extra_menu_items_for_mount (volume.get_mount (), menu_builder);
    }

    protected override async bool get_filesystem_space (Cancellable? update_cancellable) {
        if (is_mounted) {
            return yield get_filesystem_space_for_root (volume.get_mount ().get_root (), update_cancellable);
        } else {
            return false;
        }
    }
}
