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

// Represents a mount not associated with a volume or drive - usually a bind mount
// Also used for builtin row "FileSystem" which has null mount
/*FIXME Identify and deal with any other conditions resulting in a volumeless mount */
public class Sidebar.VolumelessMountRow : Sidebar.AbstractMountableRow, SidebarItemInterface {
    public VolumelessMountRow (string name, string uri, Icon gicon, SidebarListInterface list,
                               bool pinned, bool permanent,
                               string? _uuid, Mount? _mount) {
        Object (
            custom_name: name,
            uri: uri,
            gicon: gicon,
            list: list,
            pinned: pinned,
            permanent: permanent,
            uuid: _uuid,
            mount: _mount
        );

        if (mount != null) {
            custom_name = _("%s (%s)").printf (custom_name, _("Bind mount"));
            sort_key = MountableType.VOLUMELESS_MOUNT.to_string () + custom_name;
        } else {
            sort_key = ""; // Used for "FileSystem" entry which is always first.
        }
    }

    protected override async bool eject () {
        if (working) {
            return false;
        }

        bool success = false;
        if (mount != null) {
            success = yield eject_mount (mount);
        } else {
            success = true;
        }

        return success;
    }

    protected override void activated (Files.OpenFlag flag = Files.OpenFlag.DEFAULT) {
        // By definition this row represents a mounted mount (or local filesystem)
        if (!working) {
            list.open_item (this, flag);
            return;
        }
    }

    protected override void on_mount_removed (Mount removed_mount) {
        if (!valid) { //Already removed
            return;
        }

        if (mount == removed_mount) {
            valid = false;
            list.remove_item_by_id (id);
        }
    }

    protected override void show_mount_info () {
        if ((mount != null) || uri == Files.ROOT_FS_URI) {
            new Files.View.VolumePropertiesWindow (
                mount,
                Files.get_active_window ()
            );
        }
    }

    protected override void add_extra_menu_items (PopupMenuBuilder menu_builder) {
        add_extra_menu_items_for_mount (mount, menu_builder);
    }

    protected override async bool get_filesystem_space (Cancellable? update_cancellable) {
        File root;
        if (mount != null) {
            root = mount.get_root ();
        } else {
            root = File.new_for_uri ("file:///"); //Is this always "file:///" if no mount?
        }

        return yield get_filesystem_space_for_root (root, update_cancellable);
    }
}
