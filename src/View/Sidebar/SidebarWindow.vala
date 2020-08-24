/* SidebarWindow.vala
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

public class Sidebar.SidebarWindow : Gtk.ScrolledWindow, Marlin.SidebarInterface {
    Gtk.Box content_box;
    Sidebar.BookmarkListBox bookmark_listbox;
    Sidebar.DeviceListBox device_listbox;
    Sidebar.NetworkListBox network_listbox;
    Marlin.BookmarkList bookmark_list;
    unowned Marlin.TrashMonitor trash_monitor;

    BookmarkRow? trash_bookmark;
    ulong trash_handler_id;

    private string selected_uri = "";
    private bool loading = false;
    public bool ejecting_or_unmounting = false;

    public new bool has_focus {
        get {
            return bookmark_listbox.has_focus;
        }
    }

    construct {
        bookmark_listbox = new BookmarkListBox (this);
        device_listbox = new DeviceListBox (this);
        network_listbox = new NetworkListBox (this);

        trash_monitor = Marlin.TrashMonitor.get_default ();

        var bookmark_expander = new Gtk.Expander ("<b>" + _("Bookmarks") + "</b>") {
            expanded = true,
            use_markup = true
        };

        var device_expander = new Gtk.Expander ("<b>" + _("Devices") + "</b>") {
            expanded = true,
            use_markup = true
        };

        var network_expander = new Gtk.Expander ("<b>" + _("Network") + "</b>") {
            expanded = true,
            use_markup = true
        };

        bookmark_expander.add (bookmark_listbox);
        device_expander.add (device_listbox);
        network_expander.add (network_listbox);

        content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        content_box.add (bookmark_expander);
        content_box.add (device_expander);
        content_box.add (network_expander);
        this.add (content_box);

        bookmark_list = Marlin.BookmarkList.get_instance ();

        plugins.sidebar_loaded (this);

        reload ();
        bookmark_list.loaded.connect (() => {
            refresh (true, false, false);
        });

        show_all ();
    }

    private void refresh (bool bookmarks = true, bool devices = true, bool network = true) {
        //Do not refresh already refreshing or if will be reloaded anyway
        if (loading || reload_timeout_id > 0) {
            return;
        }

        loading = true;
        if (bookmarks) {
        bookmark_listbox.clear ();
            var home_uri = "";
            try {
                home_uri = GLib.Filename.to_uri (PF.UserUtils.get_real_user_home (), null);
            }
            catch (ConvertError e) {}

            if (home_uri != "") {
                bookmark_listbox.add_bookmark (
                    _("Home"),
                    home_uri,
                    new ThemedIcon (Marlin.ICON_HOME)
                );
            }

            if (recent_is_supported ()) {
                bookmark_listbox.add_bookmark (
                    _(Marlin.PROTOCOL_NAME_RECENT),
                    Marlin.RECENT_URI,
                    new ThemedIcon (Marlin.ICON_RECENT)
                );
            }

            foreach (Marlin.Bookmark bm in bookmark_list.list) {
                bookmark_listbox.add_bookmark (bm.label, bm.uri, bm.get_icon ());
            }

            var trash_uri = _(Marlin.TRASH_URI);
            if (trash_uri != "") {
                trash_bookmark = bookmark_listbox.add_bookmark (
                    _("Trash"),
                    trash_uri,
                    trash_monitor.get_icon ()
                );
            }

            trash_handler_id = trash_monitor.notify["is-empty"].connect (() => {
                if (trash_bookmark != null) {
                    trash_bookmark.update_icon (trash_monitor.get_icon ());
                }
            });

        }

        if (devices) {
            foreach (Gtk.Widget child in device_listbox.get_children ()) {
                device_listbox.remove (child);
                ((BookmarkRow)child).destroy_bookmark ();
            }

            var root_uri = _(Marlin.ROOT_FS_URI);
            if (root_uri != "") {
                device_listbox.add_bookmark (
                    _("FileSystem"),
                    root_uri,
                    new ThemedIcon.with_default_fallbacks (Marlin.ICON_FILESYSTEM)
                );
            }

            device_listbox.add_all_local_volumes_and_mounts ();
        }

        if (network) {
            foreach (var child in network_listbox.get_children ()) {
                network_listbox.remove (child);
               ((NetworkRow)child).destroy_bookmark ();
            }

            if (Marlin.is_admin ()) { //Network operations fail for administrators
                return;
            }


            network_listbox.add_all_network_mounts ();

            var network_uri = _(Marlin.NETWORK_URI);
            if (network_uri != "") {
                network_listbox.add_bookmark (
                    _("Entire Network"),
                    Marlin.NETWORK_URI,
                    new ThemedIcon (Marlin.ICON_NETWORK)
                );
            }

            /* Add ConnectServer BUILTIN */
            var bm = network_listbox.add_action_bookmark (
                _("Connect Server"),
                new ThemedIcon.with_default_fallbacks ("network-server"),
                () => {connect_server_request ();}
            );

            bm.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>C"}, _("Connect to a network server"))
            );
        }

        loading = false;
    }

    private bool recent_is_supported () {
        string [] supported;

        supported = GLib.Vfs.get_default ().get_supported_uri_schemes ();
        for (int i = 0; supported[i] != null; i++) {
            if (supported[i] == "recent") {
                return true;
            }
        }

        return false;
    }

    /* SidebarInterface */
    public int32 add_plugin_item (Marlin.SidebarPluginItem item, Marlin.PlaceType category) {
        switch (category) {
            case Marlin.PlaceType.BOOKMARKS_CATEGORY:
                return bookmark_listbox.add_bookmark (item.name, item.uri, item.icon).id;
            case Marlin.PlaceType.STORAGE_CATEGORY:
                return device_listbox.add_bookmark (item.name, item.uri, item.icon).id;
            case Marlin.PlaceType.NETWORK_CATEGORY:
                return network_listbox.add_bookmark (item.name, item.uri, item.icon).id;
            default:
                return -1;
        }
    }

    public bool update_plugin_item (Marlin.SidebarPluginItem item, int32 item_id) {
        if (item_id < 0) {
            return false;
        }

        BookmarkRow? row = BookmarkRow.get_item (item_id);
        if (row == null) {
            return false;
        }

        row.name = item.name;
        row.uri = item.uri;
        row.update_icon (item.icon);
        return true;
    }

    public void remove_item_id (int32 item_id) {
        bookmark_listbox.remove_bookmark_id (item_id);
        device_listbox.remove_bookmark_id (item_id);
        network_listbox.remove_bookmark_id (item_id);
    }

    uint sync_timeout_id = 0;
    public void sync_uri (string location) {
        if (sync_timeout_id > 0) {
            Source.remove (sync_timeout_id);
        }

        selected_uri = location;
        sync_timeout_id = Timeout.add (100, () => {
            if (loading) { // Wait until bookmarks are constructed
                return Source.CONTINUE;
            }

            sync_timeout_id = 0;
            network_listbox.unselect_all ();
            device_listbox.unselect_all ();
            bookmark_listbox.unselect_all ();
            /* Need to process unselect_all signal first */
            Idle.add (() => {
                BookmarkRow? row = null;
                if (bookmark_listbox.has_uri (location, out row)) {
                    bookmark_listbox.select_row (row);
                } else if (device_listbox.has_uri (location, out row)) {
                    device_listbox.select_row (row);
                } else if (network_listbox.has_uri (location, out row)) {
                    network_listbox.select_row (row);
                }

                return Source.REMOVE;
            });

            return Source.REMOVE;
        });
    }

    /* Throttle rate of destroying and re-adding listbox rows */
    uint reload_timeout_id = 0;
    public void reload () {
        if (reload_timeout_id > 0) {
            return;
        }

        reload_timeout_id = Timeout.add (300, () => {
            reload_timeout_id = 0;
            refresh ();

            plugins.update_sidebar (this);
            sync_uri (selected_uri);
            return false;
        });
    }

    public void add_favorite_uri (string uri, string? label = null) {
        var bm = bookmark_list.insert_uri_at_end (uri, label);
        bookmark_listbox.add_bookmark (bm.label, bm.uri, bm.get_icon ());
    }

    public bool has_favorite_uri (string uri) {
        return bookmark_listbox.has_uri (uri);
    }

    public void on_free_space_change () {
    }
}
