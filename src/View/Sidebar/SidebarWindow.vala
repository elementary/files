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
    Gtk.Grid content_grid;
    Gtk.Grid bookmarklists_grid;
    Gtk.Grid actions_grid;
    SidebarListInterface bookmark_listbox;
    SidebarListInterface device_listbox;
    SidebarListInterface network_listbox;

    private string selected_uri = "";
    private bool loading = false;
    public bool ejecting_or_unmounting = false;

    public new bool has_focus {
        get {
            return bookmark_listbox.has_focus;
        }
    }

    construct {
        width_request = Marlin.app_settings.get_int ("minimum-sidebar-width");

        bookmark_listbox = new BookmarkListBox (this);
        device_listbox = new DeviceListBox (this);
        network_listbox = new NetworkListBox (this);

        var bookmark_expander = new Gtk.Expander ("<b>" + _("Bookmarks") + "</b>") {
            use_markup = true,
            tooltip_text = _("Common places plus saved folders and files")
        };

        var device_expander = new Gtk.Expander ("<b>" + _("Devices") + "</b>") {
            use_markup = true,
            tooltip_text = _("Internal and connected storage devices")
        };

        var network_expander = new Gtk.Expander ("<b>" + _("Network") + "</b>") {
            use_markup = true,
            tooltip_text = _("Devices and places available via a network")
        };

        Marlin.app_settings.bind ("sidebar-cat-personal-expander", bookmark_expander, "expanded", SettingsBindFlags.DEFAULT);
        Marlin.app_settings.bind ("sidebar-cat-devices-expander", device_expander, "expanded", SettingsBindFlags.DEFAULT);
        Marlin.app_settings.bind ("sidebar-cat-network-expander", network_expander, "expanded", SettingsBindFlags.DEFAULT);

        bookmark_expander.add (bookmark_listbox);
        device_expander.add (device_listbox);
        network_expander.add (network_listbox);

        bookmarklists_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL,
            vexpand = true,
            valign = Gtk.Align.START
        };
        bookmarklists_grid.add (bookmark_expander);
        bookmarklists_grid.add (device_expander);
        bookmarklists_grid.add (network_expander);

        var connect_server_action = new ActionRow (
            _("Connect Server"),
            new ThemedIcon.with_default_fallbacks ("network-server"),
            (() => {connect_server_request ();})
        );

        connect_server_action.set_tooltip_markup (
            Granite.markup_accel_tooltip ({"<Alt>C"}, _("Connect to a network server"))
        );

        actions_grid = new Gtk.Grid () {
            vexpand = false,
            valign = Gtk.Align.END
        };
        actions_grid .attach (connect_server_action, 0, 0, 1, 1);

        content_grid = new Gtk.Grid ();
        content_grid.attach (bookmarklists_grid, 0, 0, 1, 1);
        content_grid.attach (actions_grid, 0, 1, 1, 1);

        this.add (content_grid);

        plugins.sidebar_loaded (this);

        reload ();
        show_all ();
    }

    private void refresh (bool bookmarks = true, bool devices = true, bool network = true) {
        //Do not refresh already refreshing or if will be reloaded anyway
        if (loading || reload_timeout_id > 0) {
            return;
        }

        loading = true;

        if (bookmarks) {
            bookmark_listbox.refresh ();
        }

        if (devices) {
            device_listbox.refresh ();
        }

        if (network) {
            network_listbox.refresh ();
        }

        loading = false;
    }

    /* SidebarInterface */
    public uint32 add_plugin_item (Marlin.SidebarPluginItem plugin_item, Marlin.PlaceType category) {
        switch (category) {
            case Marlin.PlaceType.BOOKMARKS_CATEGORY:
                return bookmark_listbox.add_plugin_item (plugin_item);
            case Marlin.PlaceType.STORAGE_CATEGORY:
                return device_listbox.add_plugin_item (plugin_item);
            case Marlin.PlaceType.NETWORK_CATEGORY:
                return network_listbox.add_plugin_item (plugin_item);
            default:
                return -1;
        }
    }

    public bool update_plugin_item (Marlin.SidebarPluginItem item, uint32 item_id) {
        if (item_id < 0) {
            return false;
        }

        SidebarItemInterface? row = SidebarItemInterface.get_item (item_id);
        if (row == null) {
            return false;
        }

        row.name = item.name;
        row.uri = item.uri;
        row.update_icon (item.icon);
        return true;
    }

    public bool remove_item_by_id (uint32 item_id) {
        // We do not know which listbox the row is in so try remove from each in turn
        return bookmark_listbox.remove_item_by_id (item_id) ||
            device_listbox.remove_item_by_id (item_id) ||
            network_listbox.remove_item_by_id (item_id);
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
            network_listbox.unselect_all_items ();
            device_listbox.unselect_all_items ();
            bookmark_listbox.unselect_all_items ();
            /* Need to process unselect_all signal first */
            Idle.add (() => {
                SidebarItemInterface? row = null;
                if (bookmark_listbox.has_uri (location, out row)) {
                    bookmark_listbox.select_item (row);
                } else if (device_listbox.has_uri (location, out row)) {
                    device_listbox.select_item (row);
                } else if (network_listbox.has_uri (location, out row)) {
                    network_listbox.select_item (row);
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
        bookmark_listbox.add_favorite (uri, label);
    }

    public bool has_favorite_uri (string uri) {
        return bookmark_listbox.has_uri (uri);
    }

    public void on_free_space_change () {
    }
}
