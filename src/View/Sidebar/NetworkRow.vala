/*
 * Copyright 2021-23 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later

 * Authored by: Jeremy Wootten <jeremy@elementaryos.org>
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

        if (mount != null) {
            string scheme, hostname;
            try {
                var connectable = NetworkAddress.parse_uri (uri, 0);
                scheme = connectable.scheme;
                hostname = connectable.hostname;
            } catch (Error e) {
                scheme = Uri.parse_scheme (uri) ?? "";
                hostname = "";
            }

            if (scheme != "") {
                custom_name = _("%s (%s)").printf (custom_name, scheme);
            }

            sort_key = hostname + scheme + name;
        } else {
            sort_key = ""; // Used for "Network" entry which is always first.
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
