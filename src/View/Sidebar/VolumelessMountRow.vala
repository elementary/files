/*
 * Copyright 2021-23 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later

 * Authored by: Jeremy Wootten <jeremy@elementaryos.org>
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
            var mount_sort_key = mount.get_sort_key ();
            if (mount_sort_key != null) {
                sort_key = mount_sort_key + custom_name;
            } else {
                sort_key = MountableType.VOLUMELESS_MOUNT.to_string () + custom_name;
            }
        } else {
            sort_key = ""; // Used for "FileSystem" entry which is always first.
        }
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
            list.remove_item (this, true);
        }
    }

    public override void show_mount_info () {
        if ((mount != null) || uri == Files.ROOT_FS_URI) {
            var properties_window = new Files.VolumePropertiesWindow (
                mount,
                Files.get_active_window ()
            );
            properties_window.response.connect ((res) => {
                properties_window.destroy ();
            });
            properties_window.present ();
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
