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
    private Gee.HashMap<string, SidebarExpander> drive_row_map;

    public Files.SidebarInterface sidebar { get; construct; }

    public DeviceListBox (Files.SidebarInterface sidebar) {
        Object (
            sidebar: sidebar
        );
    }

    construct {
        selection_mode = Gtk.SelectionMode.SINGLE; //One or none rows selected
        drive_row_map = new Gee.HashMap<string, SidebarExpander> ();
        hexpand = true;
        volume_monitor = VolumeMonitor.@get ();
        volume_monitor.drive_disconnected.connect (drive_removed);
        volume_monitor.mount_added.connect_after ((mount) => {
            /* This delay is needed to ensure that any corresponding volume row has finished updating after
             * mounting as a result of activating the row. Otherwise may get duplicate mount row e.g. for some MTP or
             * PTP mounts where the mount name differs from the volume name and get_uuid () yields null.
            */
            Timeout.add (100, () => {
                // bookmark_mount_if_not_shadowed (mount);
                bookmark_mount_if_native_and_not_shadowed (mount);
                return Source.REMOVE;
            });
        });

        volume_monitor.volume_added.connect (refresh);
        volume_monitor.drive_connected.connect (refresh);

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

        DeviceRow? bm = null;
        if (!has_uuid (uuid, uri, out bm) || bm.custom_name != label) { //Could be a bind mount with the same uuid
            var new_bm = new DeviceRow (
                label,
                uri,
                gicon,
                this,
                pinned, // Pin all device rows for now
                permanent || (bm != null && bm.permanent), //Ensure bind mount matches permanence of uuid
                uuid != null ? uuid : uri, //uuid fallsback to uri
                drive,
                volume,
                mount
            );

            add (new_bm);
            show_all ();
            bm = new_bm;
        }

        bm.update_free_space ();
        return bm;
    }

    public override uint32 add_plugin_item (Files.SidebarPluginItem plugin_item) {
        var bm = add_bookmark (plugin_item.name,
                                 plugin_item.uri,
                                 plugin_item.icon,
                                 null,
                                 plugin_item.drive,
                                 plugin_item.volume,
                                 plugin_item.mount,
                                 true,
                                 true);

        bm.update_plugin_data (plugin_item);
        return bm.id;
    }

    public void refresh () {
        clear ();
        SidebarItemInterface? row;
        var root_uri = _(Files.ROOT_FS_URI);
        if (root_uri != "") {
            var bm = add_bookmark (
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

            bm.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>slash"}, _("View the root of the local filesystem"))
            );
        }

        foreach (unowned GLib.Drive drive in volume_monitor.get_connected_drives ()) {
            bookmark_drive (drive);
        }

        foreach (unowned Volume volume in volume_monitor.get_volumes ()) {
            bookmark_volume_without_drive (volume);
        }

        foreach (unowned Mount mount in volume_monitor.get_mounts ()) {
            bookmark_mount_if_native_and_not_shadowed (mount);
        }
    }

    public override void refresh_info () {
        get_children ().@foreach ((item) => {
            if (item is DeviceRow) {
                ((DeviceRow)item).update_free_space ();
            } else if (item is SidebarExpander) {
                ((SidebarExpander)item).list.refresh_info ();
            }
        });
    }

    private void bookmark_drive (Drive drive) {
        /* If the drive has no mountable volumes and we cannot detect media change.. we
         * display the drive in the sidebar so the user can manually poll the drive by
         * right clicking and selecting "Rescan..."
         *
         * This is mainly for drives like floppies where media detection doesn't
         * work.. but it's also for human beings who like to turn off media detection
         * in the OS to save battery juice.
         */

        if (!drive_row_map.has_key (drive.get_name ())) {
            var drive_row = new SidebarExpander (drive.get_name (), new Sidebar.VolumeListBox (sidebar, drive));
            var n_volumes = drive.get_volumes ().length ();
            string volumes_text;
            volumes_text = ngettext ("%u volume", "%u volumes", n_volumes).printf (n_volumes);
            volumes_text = (
                "\n<span weight=\"600\" size=\"smaller\" alpha=\"75%\">%s</span>".printf (volumes_text)
            );

            drive_row.tooltip = (
                drive.is_removable () ? _("Removable Storage Device") : _("Fixed Storage Device") + volumes_text
            );

            drive_row_map.@set (drive.get_name (), drive_row);
            drive_row.set_gicon (drive.get_icon ());
            add (drive_row);
        }
    }

    private void bookmark_volume_without_drive (Volume volume) {
        Drive? drive = volume.get_drive ();
        if (drive != null) {
            return;
        }

        var mount = volume.get_mount ();
        add_bookmark (
            volume.get_name (),
            mount != null ? mount.get_default_location ().get_uri () : "",
            volume.get_icon (),
            volume.get_uuid (),
            volume.get_drive (),
            volume,
            mount
        );
    }

    private void bookmark_mount_if_native_and_not_shadowed (Mount mount) {
        if (mount.is_shadowed () ||
            !mount.get_root ().is_native () ||
            mount.get_volume () != null) {
            return;
        };

        var volume = mount.get_volume ();
        var uuid = mount.get_uuid ();
        if (uuid == null || uuid == "") {
            if (volume != null) {
                uuid = volume.get_uuid ();
            }
        }

        var path = mount.get_default_location ().get_uri ();
        if (uuid == null || uuid == "") {
            uuid = path;
        }

        add_bookmark (
            mount.get_name (),
            path,
            mount.get_icon (),
            mount.get_uuid (),
            mount.get_drive (),
            mount.get_volume (),
            mount
        );
    }

    private void drive_removed (Drive removed_drive) {
        var key = removed_drive.get_name ();
        if (drive_row_map.has_key (key)) {
            var drive_row = drive_row_map.@get (key);
            drive_row_map.unset (key);
            drive_row.destroy ();
        }
    }

    private bool has_uuid (string? uuid, string? fallback, out DeviceRow? row) {
        var search = uuid != null ? uuid : fallback;
        row = null;

        if (search == null) {
            return false;
        }

        foreach (unowned Gtk.Widget child in get_children ()) {
            if (child is DeviceRow) {
                if (((DeviceRow)child).uuid == uuid) {
                    row = (DeviceRow)child;
                    return true;
                }
            } else if (child is SidebarExpander) { //Search within Drives
                if (((VolumeListBox)((SidebarExpander)child).list).has_uuid (uuid, fallback, out row)) {
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

        foreach (SidebarExpander drive_row in drive_row_map.values) {
            ((VolumeListBox)(drive_row.list)).unselect_all_items ();
        }
    }

    public void select_item (SidebarItemInterface? item) {
        if (item != null && item is DeviceRow) {
            select_row ((DeviceRow)item);
        } else {
            unselect_all_items ();
        }
    }

    public override bool select_uri (string uri) {
        unselect_all_items ();
        bool found_uri = false;
        SidebarItemInterface? row = null;
        if (has_uri (uri, out row)) {
            select_item (row);
            found_uri = true;
        }

        foreach (SidebarExpander drive_row in drive_row_map.values) {
            found_uri = (((VolumeListBox)(drive_row.list)).select_uri (uri)) || found_uri;
        }

        return found_uri;
    }
}
