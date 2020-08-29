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

public class Sidebar.NetworkListBox : Gtk.ListBox, Sidebar.SidebarListInterface {
    public Marlin.SidebarInterface sidebar { get; construct; }
    public NetworkListBox (Marlin.SidebarInterface sidebar) {
        Object (
            sidebar: sidebar
        );
    }

    construct {
        var volume_monitor = VolumeMonitor.@get ();
        volume_monitor.mount_added.connect (mount_added);
    }

    private SidebarItemInterface? add_bookmark (string label, string uri, Icon gicon) {
        var row = new NetworkRow (label, uri, gicon, this, true, true); //Pin all network rows for now
        if (!has_uri (uri)) {
            add (row);
        } else {
            return null;
        }

        return row;
    }

    public override uint32 add_plugin_item (Marlin.SidebarPluginItem plugin_item) {
        var row = add_bookmark (plugin_item.name, plugin_item.uri, plugin_item.icon);

        row.update_plugin_data (plugin_item);

        return row.id;
        //TODO Create a new class of NetworkPluginRow subclassed from NetworkRow
    }

    private void add_all_network_mounts () {
        foreach (Mount mount in VolumeMonitor.@get ().get_mounts ()) {
            add_network_mount (mount);
        }
    }

    private void add_network_mount (Mount mount) {
        if (mount.is_shadowed ()) {
            return;
        }

        var volume = mount.get_volume ();
        if (volume != null) {
            return;
        }
        var root = mount.get_root ();
        if (!root.is_native ()) {
            /* show mounted volume in sidebar */
            var device_label = root.get_basename ();
            if (device_label != mount.get_name ()) {
                ///TRANSLATORS: The first string placeholder '%s' represents a device label, the second '%s' represents a mount name.
                device_label = _("%s on %s").printf (device_label, mount.get_name ());
            }

            add_bookmark (device_label, mount.get_default_location ().get_uri (), mount.get_icon ());
        }
    }

    private void mount_added (Mount mount) {
        add_network_mount (mount);
    }

    public void refresh () {
        clear ();

        if (Marlin.is_admin ()) { //Network operations fail for administrators
            return;
        }

        add_all_network_mounts ();

        var row = add_bookmark (
            _("Entire Network"),
            Marlin.NETWORK_URI,
            new ThemedIcon (Marlin.ICON_NETWORK)
        );

        row.set_tooltip_markup (
            Granite.markup_accel_tooltip ({"<Alt>N"}, _("Browse the contents of the network"))
        );
    }

    public void unselect_all_items () {
        unselect_all ();
    }

    public void select_item (SidebarItemInterface? item) {
        if (item != null && item is NetworkRow) {
            select_row ((NetworkRow)item);
        } else {
            unselect_all_items ();
        }
    }
}
