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
    private enum Column {
        NAME,
        URI,
        DRIVE,
        VOLUME,
        MOUNT,
        ROW_TYPE,
        ICON,
        INDEX,
        CAN_EJECT,
        NO_EJECT,
        BOOKMARK,
        IS_CATEGORY,
        NOT_CATEGORY,
        TOOLTIP,
        ACTION_ICON,
        SHOW_SPINNER,
        SHOW_EJECT,
        SPINNER_PULSE,
        FREE_SPACE,
        DISK_SIZE,
        PLUGIN_CALLBACK,
        MENU_MODEL,
        ACTION_GROUP_NAMESPACE,
        ACTION_GROUP,
        COUNT
    }

    Gtk.TreeStore store;
    Gtk.Box content_box;
    Gtk.ListBox bookmark_listbox;
    Marlin.BookmarkList bookmark_list;
    Gee.HashMap<string, Marlin.Bookmark> bookmark_map;

    public new bool has_focus {
        get {
            return bookmark_listbox.has_focus;
        }
    }

    construct {
        /* ceates the Gtk.TreeModel store. */
        store = new Gtk.TreeStore (((int)Column.COUNT),
                                    typeof (string),            /* name */
                                    typeof (string),            /* uri */
                                    typeof (Drive),
                                    typeof (Volume),
                                    typeof (Mount),
                                    typeof (int),               /* row type*/
                                    typeof (Icon),              /* Primary icon */
                                    typeof (uint),              /* index*/
                                    typeof (bool),              /* can eject */
                                    typeof (bool),              /* cannot eject */
                                    typeof (bool),              /* is bookmark */
                                    typeof (bool),              /* is category */
                                    typeof (bool),              /* is not category */
                                    typeof (string),            /* tool tip */
                                    typeof (Icon),              /* Action icon (e.g. eject button) */
                                    typeof (bool),              /* Show spinner (not eject button) */
                                    typeof (bool),              /* Show eject button (not spinner) */
                                    typeof (uint),              /* Spinner pulse */
                                    typeof (uint64),            /* Free space */
                                    typeof (uint64),            /* For disks, total size */
                                    typeof (Marlin.SidebarCallbackFunc),
                                    typeof (GLib.MenuModel),    /* MenuModel for external menus */
                                    typeof (string),            /* Action group namespace */
                                    typeof (GLib.ActionGroup)   /* Action group with MenuModel's actions */
                                    );

        bookmark_listbox = new Gtk.ListBox ();
        content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        content_box.add (bookmark_listbox);
        this.add (content_box);

        bookmark_map = new Gee.HashMap<string, Marlin.Bookmark> ();

        bookmark_list = Marlin.BookmarkList.get_instance ();
        bookmark_list.loaded.connect (on_bookmark_list_loaded);

        show_all ();

        on_bookmark_list_loaded ();
    }

    private void on_bookmark_list_loaded () {
        clear_bookmarks ();
        foreach (Marlin.Bookmark bm in bookmark_list.list) {
            add_bookmark (bm.label, bm.uri);
        }

        insert_builtin_bookmarks ();
    }

    private void clear_bookmarks () {
        bookmark_map.clear ();
        foreach (Gtk.Widget child in bookmark_listbox.get_children ()) {
            child.destroy ();
        }
    }

    private void add_bookmark (string label, string uri) {
        var bookmark_row = new BookmarkRow (label, uri, this) ;
        bookmark_listbox.add (bookmark_row);
    }

    private void insert_builtin_bookmarks () {
        var home_uri = "";
        try {
            home_uri = GLib.Filename.to_uri (PF.UserUtils.get_real_user_home (), null);
        }
        catch (ConvertError e) {}

        if (home_uri != "") {
            add_bookmark (_("Home"), home_uri);
        }
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
        public unowned Marlin.SidebarInterface sidebar { get; construct; }

        public BookmarkRow (string name, string uri, Marlin.SidebarInterface sidebar) {
            Object (
                custom_name: name,
                uri: uri,
                sidebar: sidebar
            );
        }

        construct {
            var label = new Gtk.Button.with_label (custom_name) {
                xalign = 0.0f,
                tooltip_text = uri
            };

            label.clicked.connect (() => {
                sidebar.path_change_request (uri, Marlin.OpenFlag.DEFAULT);
            });

            add (label);

            show_all ();
        }
    }
}
