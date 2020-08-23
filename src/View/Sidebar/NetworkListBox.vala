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

public class Sidebar.NetworkListBox : Sidebar.BookmarkListBox {
    public NetworkListBox (Sidebar.SidebarWindow sidebar) {
        base (sidebar);
    }

    construct {
        var volume_monitor = VolumeMonitor.@get ();
        volume_monitor.mount_added.connect (mount_added);
    }

    public new NetworkRow? add_bookmark (string label, string uri, Icon gicon) {
        var row = new NetworkRow (label, uri, gicon, sidebar);
        if (!has_uri (uri)) {
            add (row);
        } else {
            return null;
        }

        return row;
    }

    //TODO Use plugin for ConnectServer action?
    public ActionRow add_action_bookmark (string label, Icon gicon, ActionRowFunc action) {
        var row = new ActionRow (label, gicon, action);
        add (row);
        return row;
    }

    public void add_all_network_mounts () {
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

    private void mount_added (Mount mount)  {
        add_network_mount (mount);
    }
}

