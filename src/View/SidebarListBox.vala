/***
    Copyright (c) 2020 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

public class Marlin.SidebarListBox : Gtk.ScrolledWindow, Marlin.SidebarInterface {
    Gtk.Box content_box;
    Gtk.ListBox bookmark_listbox;
    Gtk.ListBox device_listbox;
    Gtk.ListBox network_listbox;
    Marlin.BookmarkList bookmark_list;
    unowned Marlin.TrashMonitor monitor;
    BookmarkRow? trash_bookmark;

    private string selected_uri = "";

    public new bool has_focus {
        get {
            return bookmark_listbox.has_focus;
        }
    }

    construct {
        bookmark_listbox = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.SINGLE
        };
        device_listbox = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.SINGLE
        };
        network_listbox = new Gtk.ListBox () {
            selection_mode = Gtk.SelectionMode.SINGLE
        };
        monitor = Marlin.TrashMonitor.get_default ();
        monitor.notify["is-empty"].connect (() => {
            trash_bookmark.update_icon (monitor.get_icon ());
        });

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
        bookmark_list.loaded.connect (refresh_bookmark_listbox);

        show_all ();

        bookmark_listbox.row_selected.connect ((row) => {
            selected_uri = row != null ? ((BookmarkRow)row).uri : "";
        });

        device_listbox.row_selected.connect ((row) => {
            selected_uri = row != null ? ((BookmarkRow)row).uri : "";
        });

        network_listbox.row_selected.connect ((row) => {
            selected_uri = row != null ? ((BookmarkRow)row).uri : "";
        });

        reload ();
        plugins.sidebar_loaded (this);
    }

    private void refresh_bookmark_listbox () {
        foreach (Gtk.Widget child in bookmark_listbox.get_children ()) {
            bookmark_listbox.remove (child);
            ((BookmarkRow)child).destroy_bookmark ();
        }

        var home_uri = "";
        try {
            home_uri = GLib.Filename.to_uri (PF.UserUtils.get_real_user_home (), null);
        }
        catch (ConvertError e) {}

        if (home_uri != "") {
            add_bookmark (
                _("Home"),
                home_uri,
                new ThemedIcon (Marlin.ICON_HOME)
            );
        }

        var recent_uri = _(Marlin.PROTOCOL_NAME_RECENT);
        if (recent_uri != "") {
            add_bookmark (
                _("Recent"),
                recent_uri,
                new ThemedIcon (Marlin.ICON_RECENT)
            );
        }

        foreach (Marlin.Bookmark bm in bookmark_list.list) {
            add_bookmark (bm.label, bm.uri, bm.get_icon ());
        }

        var trash_uri = _(Marlin.TRASH_URI);
        if (trash_uri != "") {
            trash_bookmark = add_bookmark (
                _("Trash"),
                trash_uri,
                new ThemedIcon (Marlin.ICON_TRASH)
            );
        }
    }

    private void refresh_device_listbox () {
        foreach (Gtk.Widget child in device_listbox.get_children ()) {
            device_listbox.remove (child);
            ((BookmarkRow)child).destroy_bookmark ();
        }

        var root_uri = _(Marlin.ROOT_FS_URI);
        if (root_uri != "") {
            add_device (
                _("FileSystem"),
                root_uri,
                new ThemedIcon.with_default_fallbacks (Marlin.ICON_FILESYSTEM)
            );
        }
    }

    private void refresh_network_listbox () {
        foreach (Gtk.Widget child in network_listbox.get_children ()) {
            network_listbox.remove (child);
           ((BookmarkRow)child).destroy_bookmark ();
        }

        var network_uri = _(Marlin.NETWORK_URI);
        if (network_uri != "") {
            add_network_location (
                _("Entire Network"),
                Marlin.NETWORK_URI,
                new ThemedIcon (Marlin.ICON_NETWORK)
            );
        }

    }

    private BookmarkRow add_bookmark (string label, string uri, Icon gicon) {
        var bookmark_row = new BookmarkRow (label, uri, gicon, this);
        bookmark_listbox.add (bookmark_row);
        return bookmark_row;
    }
    private DeviceRow add_device (string label, string uri, Icon gicon) {
        var device_row = new DeviceRow (label, uri, gicon, this);
        device_listbox.add (device_row);
        return device_row;
    }
    private NetworkRow add_network_location (string label, string uri, Icon gicon) {
        var network_row = new NetworkRow (label, uri, gicon, this);
        network_listbox.add (network_row);
        return network_row;
    }

    /* SidebarInterface */
    public int32 add_plugin_item (Marlin.SidebarPluginItem item, PlaceType category) {
        switch (category) {
            case PlaceType.BOOKMARKS_CATEGORY:
                return add_bookmark (item.name, item.uri, item.icon).id;
            case PlaceType.STORAGE_CATEGORY:
                return add_device (item.name, item.uri, item.icon).id;
            case PlaceType.NETWORK_CATEGORY:
                return add_network_location (item.name, item.uri, item.icon).id;
            default:
                return -1;
        }
    }

    public bool update_plugin_item (Marlin.SidebarPluginItem item, int32 item_id) {
        if (item_id < 0) {
            return false;
        }

        var row = BookmarkRow.bookmark_id_map.@get (item_id);
        row.name = item.name;
        row.uri = item.uri;
        row.update_icon (item.icon);
        return true;
    }

    public void remove_plugin_item (int32 item_id) {
        BookmarkRow row = BookmarkRow.bookmark_id_map.@get (item_id);
        row.destroy_bookmark ();
    }

    public void sync_uri (string location) {
        if (selected_uri == location) {
            return;
        }

        Idle.add (() => { // Need to emit selection signals when idle as sync_uri can be called repeatedly rapidly
            network_listbox.unselect_all ();
            device_listbox.unselect_all ();
            bookmark_listbox.unselect_all ();
            foreach (BookmarkRow row in BookmarkRow.bookmark_id_map.values) {
                if (row.uri == location) {
                    network_listbox.select_row (row);
                    device_listbox.select_row (row);
                    bookmark_listbox.select_row (row);
                    break;
                }
            }
            return false;
        });
    }

    /* Throttle rate of destroying and re-adding listbox rows */
    uint reload_timeout_id = 0;
    public void reload () {
        if (reload_timeout_id > 0) {
            Source.remove (reload_timeout_id);
        }

        reload_timeout_id = Timeout.add (100, () => {
            reload_timeout_id = 0;
            refresh_bookmark_listbox ();
            refresh_device_listbox ();
            refresh_network_listbox ();
            plugins.update_sidebar (this);

            return false;
        });
    }

    public void add_favorite_uri (string uri, string? label = null) {

    }

    public bool has_favorite_uri (string uri) {
        return false;
    }

    private class BookmarkRow : Gtk.ListBoxRow {
        private static int row_id;
        public static Gee.HashMap<int, BookmarkRow> bookmark_id_map;

        protected static int get_next_row_id () {
            return ++row_id;
        }

        static construct {
            /* intialise the row_id to a large random number (is this necessary?)*/
            var rand = new Rand.with_seed (int.parse (get_real_time ().to_string ()));
            var min_size = int.MAX / 4;
            while (row_id < min_size) {
                row_id = (int32)(rand.next_int ());
            }

            bookmark_id_map = new Gee.HashMap<int, BookmarkRow> ();
        }

        public string custom_name { get; set construct; }
        public string uri { get; set construct; }
        public Icon gicon { get; construct; }
        public int32 id {get; construct; }
        private Gtk.Image icon;
        public unowned Marlin.SidebarInterface sidebar { get; construct; }

        public BookmarkRow (string name,
                            string uri,
                            Icon gicon,
                            Marlin.SidebarInterface sidebar) {
            Object (
                custom_name: name,
                uri: uri,
                gicon: gicon,
                sidebar: sidebar
            );
        }

        construct {
            selectable = true;
            id = BookmarkRow.get_next_row_id ();
            BookmarkRow.bookmark_id_map.@set (id, this);

            var event_box = new Gtk.EventBox () {
                above_child = true
            };

            var content_grid = new Gtk.Grid () {
                orientation = Gtk.Orientation.HORIZONTAL
            };

            var label = new Gtk.Label (custom_name) {
                xalign = 0.0f,
                tooltip_text = uri,
                margin_start = 6
            };

            button_press_event.connect_after (() => {
                sidebar.path_change_request (uri, Marlin.OpenFlag.DEFAULT);
                return false;
            });

            activate.connect (() => {
                sidebar.path_change_request (uri, Marlin.OpenFlag.DEFAULT);
            });

            icon = new Gtk.Image.from_gicon (gicon, Gtk.IconSize.MENU) {
                margin_start = 12
            };

            content_grid.add (icon);
            content_grid.add (label);
            event_box.add (content_grid);
            add (event_box);
            show_all ();
        }

        public void update_icon (Icon gicon) {
            icon.gicon = gicon;
        }

        public void destroy_bookmark () {
            BookmarkRow.bookmark_id_map.unset (id);
            base.destroy ();
        }
    }
    private class DeviceRow : BookmarkRow {
        public DeviceRow (string name, string uri, Icon gicon, SidebarInterface sidebar) {
            Object (
                custom_name: name,
                uri: uri,
                gicon: gicon,
                sidebar: sidebar
            );
        }
    }
    private class NetworkRow : BookmarkRow {
        public NetworkRow (string name, string uri, Icon gicon, SidebarInterface sidebar) {
            Object (
                custom_name: name,
                uri: uri,
                gicon: gicon,
                sidebar: sidebar
            );
        }
    }
}
