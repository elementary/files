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

public class Sidebar.SidebarWindow : Gtk.Grid, Marlin.SidebarInterface {
    Gtk.ScrolledWindow scrolled_window;
    Gtk.Grid bookmarklists_grid;
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
        bookmark_listbox = new BookmarkListBox (this);
        device_listbox = new DeviceListBox (this);
        network_listbox = new NetworkListBox (this);

        var bookmark_expander = new SidebarExpander (_("Bookmarks")) {
            tooltip_text = _("Common places plus saved folders and files")
        };

        var bookmark_revealer = new Gtk.Revealer ();
        bookmark_revealer.add (bookmark_listbox);

        var device_expander = new SidebarExpander (_("Devices")) {
            tooltip_text = _("Internal and connected storage devices")
        };

        var device_revealer = new Gtk.Revealer ();
        device_revealer.add (device_listbox);

        var network_expander = new SidebarExpander (_("Network")) {
            tooltip_text = _("Devices and places available via a network"),
            no_show_all = true,
            visible = !Marlin.is_admin ()
        };

        var network_revealer = new Gtk.Revealer ();
        network_revealer.add (network_listbox);

        bookmarklists_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.VERTICAL,
            vexpand = true
        };
        bookmarklists_grid.add (bookmark_expander);
        bookmarklists_grid.add (bookmark_revealer);
        bookmarklists_grid.add (device_expander);
        bookmarklists_grid.add (device_revealer);
        bookmarklists_grid.add (network_expander);
        bookmarklists_grid.add (network_revealer);

        scrolled_window = new Gtk.ScrolledWindow (null, null);
        scrolled_window.add (bookmarklists_grid);

        var connect_server_button = new Gtk.Button.with_label (_("Connect Server…")) {
            always_show_image = true,
            image = new Gtk.Image.from_icon_name ("network-server-symbolic", Gtk.IconSize.MENU),
            tooltip_markup = Granite.markup_accel_tooltip ({"<Alt>C"}),
            no_show_all = true,
            visible = !Marlin.is_admin ()
        };

        var action_bar = new Gtk.ActionBar () {
            no_show_all = true
        };

        action_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        action_bar.add (connect_server_button);

        orientation = Gtk.Orientation.VERTICAL;
        width_request = Marlin.app_settings.get_int ("minimum-sidebar-width");
        get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);
        add (scrolled_window);
        add (action_bar);

        plugins.sidebar_loaded (this);

        reload ();

        //Hide actionbar for now when admin as only a hidden network related action is present
        action_bar.visible = !Marlin.is_admin ();
        show_all ();

        Marlin.app_settings.bind (
            "sidebar-cat-personal-expander", bookmark_expander, "active", SettingsBindFlags.DEFAULT
        );
        Marlin.app_settings.bind (
            "sidebar-cat-devices-expander", device_expander, "active", SettingsBindFlags.DEFAULT
        );
        Marlin.app_settings.bind (
            "sidebar-cat-network-expander", network_expander, "active", SettingsBindFlags.DEFAULT
        );

        bookmark_expander.bind_property ("active", bookmark_revealer, "reveal-child", GLib.BindingFlags.SYNC_CREATE);
        device_expander.bind_property ("active", device_revealer, "reveal-child", GLib.BindingFlags.SYNC_CREATE);
        network_expander.bind_property ("active", network_revealer, "reveal-child", GLib.BindingFlags.SYNC_CREATE);

        connect_server_button.clicked.connect (() => {
            connect_server_request ();
        });
    }

    private void refresh (bool bookmarks = true, bool devices = true, bool network = true) {
        //Do not refresh if already refreshing or if will be reloaded anyway
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
        uint32 id = 0;
        switch (category) {
            case Marlin.PlaceType.BOOKMARKS_CATEGORY:
                id = bookmark_listbox.add_plugin_item (plugin_item);
                break;

            case Marlin.PlaceType.STORAGE_CATEGORY:
                id = device_listbox.add_plugin_item (plugin_item);
                break;

            case Marlin.PlaceType.NETWORK_CATEGORY:
                id = network_listbox.add_plugin_item (plugin_item);
                break;

            default:
                break;
        }

        return id;
    }

    public bool update_plugin_item (Marlin.SidebarPluginItem item, uint32 item_id) {
        if (item_id == 0) {
            return false;
        }

        SidebarItemInterface? row = SidebarItemInterface.get_item (item_id);
        if (row == null) {
            return false;
        }

        row.update_plugin_data (item);

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
        /* We cannot be sure which devices will experience a freespace change so refresh all */
        device_listbox.refresh_info ();
    }

    private class SidebarExpander : Gtk.ToggleButton {
        public string expander_label { get; construct; }
        private static Gtk.CssProvider expander_provider;

        public SidebarExpander (string label) {
            Object (expander_label: label);
        }

        static construct {
            expander_provider = new Gtk.CssProvider ();
            expander_provider.load_from_resource ("/io/elementary/files/SidebarExpander.css");
        }

        construct {
            var title = new Gtk.Label (expander_label) {
                hexpand = true,
                xalign = 0
            };

            var arrow = new Gtk.Spinner ();

            unowned Gtk.StyleContext arrow_style_context = arrow.get_style_context ();
            arrow_style_context.add_class (Gtk.STYLE_CLASS_ARROW);
            arrow_style_context.add_provider (expander_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

            var grid = new Gtk.Grid ();
            grid.add (title);
            grid.add (arrow);

            add (grid);

            unowned Gtk.StyleContext style_context = get_style_context ();
            style_context.add_class (Granite.STYLE_CLASS_H4_LABEL);
            style_context.add_class (Gtk.STYLE_CLASS_EXPANDER);
            style_context.add_provider (expander_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
    }
}
