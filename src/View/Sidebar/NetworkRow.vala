/* NetworkRow.vala
 *
 * Copyright 2020-21 elementary LLC. <https://elementary.io>
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

public class Sidebar.NetworkRow : Sidebar.VolumelessMountRow {
    public NetworkRow (string name, string uri, Icon gicon, SidebarListInterface list,
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

        var scheme = Uri.parse_scheme (uri);
        if (mount != null) {
            custom_name = _("%s (%s)").printf (custom_name, scheme);
        }
    }

    protected override async bool get_filesystem_space (Cancellable? update_cancellable) {
        File root;
        if (mount != null) {
            root = mount.get_root ();
        } else {
            return false; // No realistic filespace for "network:///"
        }

        return yield get_filesystem_space_for_root (root, update_cancellable);
    }
}
