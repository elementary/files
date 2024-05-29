/*
 * SPDX-License-Identifier: GPL-2.0+
 * SPDX-FileCopyrightText: 2020-2023 elementary, Inc. (https://elementary.io)
 *
 * Authors : Jeremy Wootten <jeremy@elementaryos.org>
 */


public class Sidebar.SidebarWindow : Gtk.Box, Files.SidebarInterface {
    private Gtk.ScrolledWindow scrolled_window;
    private BookmarkListBox bookmark_listbox;
    private DeviceListBox device_listbox;
    private NetworkListBox network_listbox;

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

        var bookmark_revealer = new Gtk.Revealer () {
            child = bookmark_listbox
        };

        /// TRANSLATORS: Generic term for collection of storage devices, mount points, etc.
        var device_expander = new SidebarExpander (_("Storage")) {
            tooltip_text = _("Internal and connected storage devices")
        };

        var device_revealer = new Gtk.Revealer () {
            child = device_listbox
        };

        var network_expander = new SidebarExpander (_("Network")) {
            tooltip_text = _("Devices and places available via a network"),
            no_show_all = Files.is_admin ()
        };

        var network_revealer = new Gtk.Revealer () {
            child = network_listbox
        };

        var bookmarklists_box = new Gtk.Box (VERTICAL, 0) {
            vexpand = true
        };
        bookmarklists_box.add (bookmark_expander);
        bookmarklists_box.add (bookmark_revealer);
        bookmarklists_box.add (device_expander);
        bookmarklists_box.add (device_revealer);
        bookmarklists_box.add (network_expander);
        bookmarklists_box.add (network_revealer);

        scrolled_window = new Gtk.ScrolledWindow (null, null) {
            child = bookmarklists_box,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        var connect_server_box = new Gtk.Box (HORIZONTAL, 0);
        connect_server_box.add (new Gtk.Image.from_icon_name ("network-server-symbolic", MENU));
        connect_server_box.add (new Gtk.Label (_("Connect Server…")));

        var connect_server_button = new Gtk.Button () {
            action_name = "win.go-to",
            action_target = "SERVER",
            child = connect_server_box,
            hexpand = true,
            tooltip_markup = Granite.markup_accel_tooltip (
                ((Gtk.Application) GLib.Application.get_default ()).get_accels_for_action ("win.go-to::SERVER")
            )
        };

        var action_bar = new Gtk.ActionBar ();
        action_bar.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        action_bar.add (connect_server_button);

        orientation = Gtk.Orientation.VERTICAL;
        width_request = Files.app_settings.get_int ("minimum-sidebar-width");
        get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);
        add (scrolled_window);

        //For now hide action bar when admin. This might need revisiting if other actions are added
        if (!Files.is_admin ()) {
            add (action_bar);
        }

        plugins.sidebar_loaded (this);

        reload ();

        show_all ();

        Files.app_settings.bind (
            "sidebar-cat-personal-expander", bookmark_expander, "active", SettingsBindFlags.DEFAULT
        );
        Files.app_settings.bind (
            "sidebar-cat-devices-expander", device_expander, "active", SettingsBindFlags.DEFAULT
        );
        Files.app_settings.bind (
            "sidebar-cat-network-expander", network_expander, "active", SettingsBindFlags.DEFAULT
        );

        bookmark_expander.bind_property ("active", bookmark_revealer, "reveal-child", GLib.BindingFlags.SYNC_CREATE);
        device_expander.bind_property ("active", device_revealer, "reveal-child", GLib.BindingFlags.SYNC_CREATE);
        network_expander.bind_property ("active", network_revealer, "reveal-child", GLib.BindingFlags.SYNC_CREATE);
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
    public uint32 add_plugin_item (Files.SidebarPluginItem plugin_item, Files.PlaceType category) {
        uint32 id = 0;
        switch (category) {
            case Files.PlaceType.BOOKMARKS_CATEGORY:
                id = bookmark_listbox.add_plugin_item (plugin_item);
                break;

            case Files.PlaceType.STORAGE_CATEGORY:
                id = device_listbox.add_plugin_item (plugin_item);
                break;

            case Files.PlaceType.NETWORK_CATEGORY:
                id = network_listbox.add_plugin_item (plugin_item);
                break;

            default:
                break;
        }

        return id;
    }

    public bool update_plugin_item (Files.SidebarPluginItem item, uint32 item_id) {
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
            /* select_uri () will unselect other uris in each listbox */
            bookmark_listbox.select_uri (location);
            device_listbox.select_uri (location);
            network_listbox.select_uri (location);

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

    public void add_favorite_uri (string uri, string custom_name = "") {
        bookmark_listbox.add_favorite (uri, custom_name);
    }

    public bool has_favorite_uri (string uri) {
        return bookmark_listbox.has_uri (uri);
    }

    public void on_free_space_change () {
        /* We cannot be sure which devices will experience a freespace change so refresh all */
        device_listbox.refresh_info ();
    }

    public void focus () {
        bookmark_listbox.focus ();
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

            var box = new Gtk.Box (HORIZONTAL, 0);
            box.add (title);
            box.add (arrow);

            child = box;

            unowned Gtk.StyleContext style_context = get_style_context ();
            style_context.add_class (Granite.STYLE_CLASS_H4_LABEL);
            style_context.add_class (Gtk.STYLE_CLASS_EXPANDER);
            style_context.add_provider (expander_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
    }
}
