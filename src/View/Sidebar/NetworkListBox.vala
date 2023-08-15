/* NetworkListBox.vala
 *
 * Copyright 2020 elementary LLC. <https://elementary.io>
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

public class Sidebar.NetworkListBox : Gtk.Box, Sidebar.SidebarListInterface {
    public Files.SidebarInterface sidebar { get; construct; }
    public Gtk.ListBox list_box { get; internal set; }

    public NetworkListBox (Files.SidebarInterface sidebar) {
        Object (sidebar: sidebar);
    }

    construct {
        list_box = new Gtk.ListBox () {
            hexpand = true,
            selection_mode = Gtk.SelectionMode.SINGLE
        };

        add (list_box);

        var volume_monitor = VolumeMonitor.@get ();
        volume_monitor.mount_added.connect (bookmark_mount_if_not_shadowed);

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

        list_box.set_sort_func (network_sort_func);
    }

    private int network_sort_func (Gtk.ListBoxRow? row1, Gtk.ListBoxRow? row2) {
        var key1 = row1 != null && (row1 is AbstractMountableRow) ? ((AbstractMountableRow)row1).sort_key : "";
        var key2 = row2 != null && (row2 is AbstractMountableRow) ? ((AbstractMountableRow)row2).sort_key : "";

        return strcmp (key1, key2);
    }

    private BookmarkRow? add_bookmark (string label, string uri, Icon gicon, bool permanent, bool pinned, string? uuid, Mount? mount) {
        Gtk.ListBoxRow? row = null;

        if (!has_uri (uri, out row)) {
            row = new NetworkRow (
                label,
                uri,
                gicon,
                this,
                pinned,
                permanent,
                uuid != null ? uuid : uri, //uuid fallsback to uri
                mount
            );

            list_box.add (row);
        }

        return (BookmarkRow) row;
    }

    public override uint32 add_plugin_item (Files.SidebarPluginItem plugin_item) {
        var row = add_bookmark (plugin_item.name,
                                plugin_item.uri,
                                plugin_item.icon,
                                false,
                                true,
                                null,
                                plugin_item.mount);

        row.update_plugin_data (plugin_item);

        return row.id;
        //TODO Create a new class of NetworkPluginRow subclassed from NetworkRow
    }

    private void bookmark_mount_if_not_shadowed (Mount mount) {
        if (mount.is_shadowed ()) {
            return;
        };

        var scheme = Uri.parse_scheme (mount.get_root ().get_uri ());

        /* Some non-native schemes are still local e.g. mtp, ptp, gphoto2.  These are shown in the Device ListBox */
        if (scheme != null && "smb ftp sftp afp dav davs".contains (scheme)) {
                add_bookmark (
                mount.get_name (),
                mount.get_default_location ().get_uri (),
                mount.get_icon (),
                false,
                false,
                mount.get_name (),
                mount
            );
            //Show extra info in tooltip
        }
    }

    public void refresh () {
        clear ();

        if (Files.is_admin ()) { //Network operations fail for administrators
            return;
        }

        var row = add_bookmark (
            _("Entire Network"),
            Files.NETWORK_URI,
            new ThemedIcon (Files.ICON_NETWORK),
            true,
            true,
            null,
            null
        );

        row.set_tooltip_markup (
            Granite.markup_accel_tooltip ({"<Alt>N"}, _("Browse the contents of the network"))
        );

        foreach (unowned Mount mount in VolumeMonitor.@get ().get_mounts ()) {
            bookmark_mount_if_not_shadowed (mount);
        }
    }

    public void unselect_all_items () {
        list_box.unselect_all ();
    }

    public void select_item (Gtk.ListBoxRow? item) {
        if (item != null && item is NetworkRow) {
            list_box.select_row (item);
        } else {
            unselect_all_items ();
        }
    }
}
