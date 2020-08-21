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

    public new bool has_focus {
        get {
            return bookmark_listbox.has_focus;
        }
    }

    construct {
        bookmark_listbox = new Gtk.ListBox ();
        device_listbox = new Gtk.ListBox ();
        network_listbox = new Gtk.ListBox ();
        monitor = Marlin.TrashMonitor.get_default ();

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

        refresh_bookmark_listbox ();
        refresh_device_listbox ();
        refresh_network_listbox ();
    }

    private void refresh_bookmark_listbox () {
        foreach (Gtk.Widget child in bookmark_listbox.get_children ()) {
            child.destroy ();
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
            add_bookmark (
                _("Trash"),
                trash_uri,
                new ThemedIcon (Marlin.ICON_TRASH)
            );
        }
    }

    private void refresh_device_listbox () {
        foreach (Gtk.Widget child in device_listbox.get_children ()) {
            child.destroy ();
        }

        var root_uri = _(Marlin.ROOT_FS_URI);
        if (root_uri != "") {
            add_bookmark (
                _("FileSystem"),
                root_uri,
                new ThemedIcon.with_default_fallbacks (Marlin.ICON_FILESYSTEM)
            );
        }
    }

    private void refresh_network_listbox () {
        foreach (Gtk.Widget child in network_listbox.get_children ()) {
            child.destroy ();
        }

        var network_uri = _(Marlin.NETWORK_URI);
        if (network_uri != "") {
            add_bookmark (
                _("Network"),
                Marlin.TrashMonitor.URI,
                monitor.get_icon ()
            );
        }

    }


    private void add_bookmark (string label, string uri, Icon gicon) {
        var bookmark_row = new BookmarkRow (label, uri, gicon, this);
        bookmark_listbox.add (bookmark_row);
    }
    /* SidebarInterface */
    public int32 add_plugin_item (Marlin.SidebarPluginItem item, PlaceType category) {
        return 0;
    }

    public bool update_plugin_item (Marlin.SidebarPluginItem item, int32 item_id) {
        return false;
    }

    public void remove_plugin_item (int32 item_id) {

    }

    public void sync_uri (string location) {

    }

    public void reload () {

    }

    public void add_favorite_uri (string uri, string? label = null) {

    }

    public bool has_favorite_uri (string uri) {
        return false;
    }

    private class BookmarkRow : Gtk.ListBoxRow {
        public string custom_name { get; construct; }
        public string uri { get; construct; }
        public Icon gicon { get; construct; }
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

            var event_box = new Gtk.EventBox () {
                above_child = true
            };

            var content_grid = new Gtk.Grid () {
                orientation = Gtk.Orientation.HORIZONTAL
            };

            var icon = new Gtk.Image.from_gicon (gicon, Gtk.IconSize.MENU) {
                margin_start = 12
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

            content_grid.add (icon);
            content_grid.add (label);
            event_box.add (content_grid);
            add (event_box);
            show_all ();
        }
    }
}
