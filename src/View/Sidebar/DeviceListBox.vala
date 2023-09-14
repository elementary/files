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

public class Sidebar.DeviceListBox : Gtk.Box, Sidebar.SidebarListInterface {
    public Files.SidebarInterface sidebar { get; construct; }
    public Gtk.ListBox list_box { get; internal set; }

    private VolumeMonitor volume_monitor;

    public DeviceListBox (Files.SidebarInterface sidebar) {
        Object (sidebar: sidebar);
    }

    construct {
        list_box = new Gtk.ListBox () {
            hexpand = true,
            selection_mode = Gtk.SelectionMode.SINGLE
        };

        add (list_box);

        volume_monitor = VolumeMonitor.@get ();
        volume_monitor.drive_connected.connect (bookmark_drive);
        volume_monitor.mount_added.connect (bookmark_mount_without_volume);
        volume_monitor.volume_added.connect (bookmark_volume);

        list_box.row_activated.connect ((row) => {
            if (row is BookmarkRow) {
                ((BookmarkRow) row).activated ();
            }
        });

        list_box.row_selected.connect ((row) => {
            if (row is BookmarkRow) {
                select_item (row);
            }
        });

        list_box.set_sort_func (device_sort_func);
    }

    private int device_sort_func (Gtk.ListBoxRow? row1, Gtk.ListBoxRow? row2) {
        var key1 = (row1 != null && (row1 is AbstractMountableRow)) ? ((AbstractMountableRow)row1).sort_key : "";
        var key2 = (row2 != null && (row2 is AbstractMountableRow)) ? ((AbstractMountableRow)row2).sort_key : "";

        return strcmp (key1, key2);
    }

    private AbstractMountableRow add_bookmark (string label, string uri, Icon gicon,
                                    string? uuid = null,
                                    Drive? drive = null,
                                    Volume? volume = null,
                                    Mount? mount = null,
                                    bool pinned = true,
                                    bool permanent = false) {

        AbstractMountableRow? bm = null; // Existing bookmark with same uuid
        if (!has_uuid (uuid, uri, out bm) || bm.custom_name != label) { //Could be a bind mount with the same uuid
            AbstractMountableRow new_bm;
            if (drive != null && volume == null) {
                new_bm = new DriveRow (
                    label,
                    uri,
                    gicon,
                    this,
                    pinned, // Pin all device rows for now
                    permanent || (bm != null && bm.permanent), //Ensure bind mount matches permanence of uuid
                    uuid != null ? uuid : uri, //uuid fallsback to uri
                    drive
                );
            } else if (volume == null ) {
                new_bm = new VolumelessMountRow (
                    label,
                    uri,
                    gicon,
                    this,
                    pinned, // Pin all device rows for now
                    permanent || (bm != null && bm.permanent), //Ensure bind mount matches permanence of uuid
                    uuid != null ? uuid : uri, //uuid fallsback to uri
                    mount
                );
            } else {
                new_bm = new VolumeRow (
                    label,
                    uri,
                    gicon,
                    this,
                    pinned, // Pin all device rows for now
                    permanent || (bm != null && bm.permanent), //Ensure bind mount matches permanence of uuid
                    uuid != null ? uuid : uri, //uuid fallsback to uri
                    volume
                );
            }

            list_box.add (new_bm);

            show_all ();
            bm = new_bm;
            bm.update_free_space ();
        }

        assert (bm != null);
        return bm; // Should not be null (either an existing bookmark or a new one)
    }

    public override uint32 add_plugin_item (Files.SidebarPluginItem plugin_item) {
        var row = add_bookmark (plugin_item.name,
                                 plugin_item.uri,
                                 plugin_item.icon,
                                 null,
                                 plugin_item.drive,
                                 plugin_item.volume,
                                 plugin_item.mount,
                                 true,
                                 true);

        row.update_plugin_data (plugin_item);
        return row.id;
    }

    public void refresh () {
        clear ();

        var root_uri = _(Files.ROOT_FS_URI);
        if (root_uri != "") {
            var row = add_bookmark (
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

            row.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>slash"}, _("View the root of the local filesystem"))
            );
        }

        foreach (var volume in volume_monitor.get_volumes ()) {
            bookmark_volume (volume);
        }

        foreach (var drive in volume_monitor.get_connected_drives ()) {
            bookmark_drive (drive);
        }

        foreach (var mount in volume_monitor.get_mounts ()) {
            bookmark_mount_without_volume (mount);
        }
    }

    public override void refresh_info () {
        list_box.get_children ().@foreach ((item) => {
            if (item is AbstractMountableRow) {
                ((AbstractMountableRow)item).update_free_space ();
            }
        });
    }

    private void bookmark_drive (Drive drive) {
        // Bookmark all drives but only those that do not have a volume (unformatted or no media) are shown.
        add_bookmark (
            drive.get_name (),
            "", // No uri available from drive??
            drive.get_icon (),
            drive.get_name (), // Unclear what to use as a unique identifier for a drive so use name
            drive,
            null,
            null
        );
    }

    private void bookmark_volume (Volume volume) {
        var mount = volume.get_mount ();
        add_bookmark (
            volume.get_name (),
            mount != null ? mount.get_default_location ().get_uri () : "",
            volume.get_icon (),
            volume.get_uuid (),
            null,
            volume,
            null
        );
    }

    private void bookmark_mount_without_volume (Mount mount) {
        if (mount.is_shadowed () ||
            !mount.get_root ().is_native () ||
            mount.get_volume () != null) {

            return;
        }

        var uuid = mount.get_uuid ();
        var path = mount.get_default_location ().get_uri ();
        if (uuid == null || uuid == "") {
            uuid = path;
        }

        add_bookmark (
            mount.get_name (),
            path,
            mount.get_icon (),
            uuid,
            null,
            null,
            mount
        );
    }

    private bool has_uuid (string? uuid, string? fallback, out AbstractMountableRow? row) {
        var searched_uuid = uuid != null ? uuid : fallback;

        if (searched_uuid != null) {
            foreach (unowned var child in list_box.get_children ()) {
                row = null;
                if (child is AbstractMountableRow) {
                    row = (AbstractMountableRow)child;
                    if (row.uuid == searched_uuid) {
                        return true;
                    }
                }
            }
        }

        row = null;
        return false;
    }

    public BookmarkRow? add_sidebar_row (string label, string uri, Icon gicon) {
        //We do not want devices to be added by external agents
        return null;
    }

    public void unselect_all_items () {
        foreach (unowned var child in list_box.get_children ()) {
            if (child is AbstractMountableRow) {
                list_box.unselect_row ((AbstractMountableRow)child);
            }
        }
    }

    public void select_item (Gtk.ListBoxRow? item) {
        if (item != null && item is AbstractMountableRow) {
            list_box.select_row (item);
        } else {
            unselect_all_items ();
        }
    }
}
