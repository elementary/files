/*
 * SPDX-License-Identifier: GPL-2.0+
 * SPDX-FileCopyrightText: 2020-2023 elementary, Inc. (https://elementary.io)
 *
 * Authors : Jeremy Wootten <jeremywootten@gmail.com>
 */


public class Sidebar.BasicSidebarWindow : Gtk.Box, Files.SidebarInterface {
    private Gtk.ScrolledWindow scrolled_window;
    private BasicBookmarkListBox bookmark_listbox;
    private BasicDeviceListBox device_listbox;
    // private NetworkListBox network_listbox;

    private string selected_uri = "";
    private bool loading = false;
    public bool ejecting_or_unmounting = false;

    public new bool has_focus {
        get {
            return bookmark_listbox.has_focus;
        }
    }

    construct {
        bookmark_listbox = new BasicBookmarkListBox (this);
        device_listbox = new BasicDeviceListBox (this);

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

        var bookmarklists_box = new Gtk.Box (VERTICAL, 0) {
            vexpand = true
        };
        bookmarklists_box.add (bookmark_expander);
        bookmarklists_box.add (bookmark_revealer);
        bookmarklists_box.add (device_expander);
        bookmarklists_box.add (device_revealer);

        scrolled_window = new Gtk.ScrolledWindow (null, null) {
            child = bookmarklists_box,
            hscrollbar_policy = Gtk.PolicyType.NEVER
        };

        orientation = Gtk.Orientation.VERTICAL;
        get_style_context ().add_class (Gtk.STYLE_CLASS_SIDEBAR);
        add (scrolled_window);

        reload ();

        show_all ();

        var prefs = Files.Preferences.get_default ();
        prefs.bind_property ("sidebar-bookmarks-expanded", bookmark_revealer, "reveal-child", BIDIRECTIONAL);
        prefs.bind_property ("sidebar-storage-expanded", device_revealer, "reveal-child", BIDIRECTIONAL);
        bookmark_expander.bind_property ("active", bookmark_revealer, "reveal-child", BIDIRECTIONAL);
        device_expander.bind_property ("active", device_revealer, "reveal-child", BIDIRECTIONAL);
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

        loading = false;
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
            // network_listbox.select_uri (location);

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

    public new void focus () {
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
