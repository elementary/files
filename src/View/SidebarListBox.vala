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
    BookmarkListBox bookmark_listbox;
    DeviceListBox device_listbox;
    NetworkListBox network_listbox;
    Marlin.BookmarkList bookmark_list;
    unowned Marlin.TrashMonitor monitor;
    VolumeMonitor volume_monitor;

    BookmarkRow? trash_bookmark;

    private string selected_uri = "";
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

        monitor = Marlin.TrashMonitor.get_default ();
        monitor.notify["is-empty"].connect (() => {
            trash_bookmark.update_icon (monitor.get_icon ());
        });
        volume_monitor = VolumeMonitor.@get ();
        volume_monitor.volume_added.connect (device_listbox.add_volume);
        volume_monitor.volume_removed.connect (device_listbox.remove_volume);
        volume_monitor.volume_changed.connect (device_listbox.update_volume);

        volume_monitor.mount_added.connect (device_listbox.add_mount);
        volume_monitor.mount_removed.connect (device_listbox.remove_mount);
        volume_monitor.mount_changed.connect (device_listbox.update_mount);

        volume_monitor.drive_connected.connect (device_listbox.add_drive);
        volume_monitor.drive_disconnected.connect (device_listbox.remove_drive);
        volume_monitor.drive_changed.connect (device_listbox.update_drive);

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

        var recent_uri = _(Marlin.PROTOCOL_NAME_RECENT);
        if (recent_uri != "") {
            bookmark_listbox.add_bookmark (
                _("Recent"),
                recent_uri,
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
            device_listbox.add_bookmark (
                _("FileSystem"),
                root_uri,
                new ThemedIcon.with_default_fallbacks (Marlin.ICON_FILESYSTEM)
            );
        }

        device_listbox.add_all_local_volumes_and_mounts (volume_monitor);
    }

    private void refresh_network_listbox () {
        foreach (Gtk.Widget child in network_listbox.get_children ()) {
            network_listbox.remove (child);
           ((BookmarkRow)child).destroy_bookmark ();
        }

        var network_uri = _(Marlin.NETWORK_URI);
        if (network_uri != "") {
            network_listbox.add_bookmark (
                _("Entire Network"),
                Marlin.NETWORK_URI,
                new ThemedIcon (Marlin.ICON_NETWORK)
            );
        }

    }

    /* SidebarInterface */
    public int32 add_plugin_item (Marlin.SidebarPluginItem item, PlaceType category) {
        switch (category) {
            case PlaceType.BOOKMARKS_CATEGORY:
                return bookmark_listbox.add_bookmark (item.name, item.uri, item.icon).id;
            case PlaceType.STORAGE_CATEGORY:
                return device_listbox.add_bookmark (item.name, item.uri, item.icon).id;
            case PlaceType.NETWORK_CATEGORY:
                return network_listbox.add_bookmark (item.name, item.uri, item.icon).id;
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
        var bm = bookmark_list.insert_uri_at_end (uri, label);
        bookmark_listbox.add_bookmark (bm.label, bm.uri, bm.get_icon ());
    }

    public bool has_favorite_uri (string uri) {
        return false;
    }


    /* PRIVATE CLASSES */
    private class BookmarkListBox : Gtk.ListBox {
        public Marlin.SidebarListBox sidebar { get; construct; }
        public BookmarkListBox (Marlin.SidebarListBox sidebar) {
            Object (
                sidebar: sidebar
            );
        }

        construct {
            selection_mode = Gtk.SelectionMode.SINGLE;
        }

        public virtual BookmarkRow add_bookmark (string label, string uri, Icon gicon) {
            var row = new BookmarkRow (label, uri, gicon, sidebar);
            add (row);
            return row;
        }

        public void clear () {
            foreach (Gtk.Widget child in get_children ()) {
                remove (child);
                ((BookmarkRow)child).destroy_bookmark ();
            }
        }
    }
    private class DeviceListBox : BookmarkListBox {
        public DeviceListBox (Marlin.SidebarListBox sidebar) {
            Object (
                sidebar: sidebar
            );
        }

        public override BookmarkRow add_bookmark (string label, string uri, Icon gicon) {
            var row = new DeviceRow (label, uri, gicon, sidebar);
            add (row);
            return row;
        }

        public void add_volume (Volume vol) {
            if (sidebar.ejecting_or_unmounting) {
                return;
            }
        }
        public void add_mount (Mount mount)  {
            if (sidebar.ejecting_or_unmounting) {
                return;
            }

            /* show mounted volume in sidebar */
            var root = mount.get_root ();
            var device_label = root.get_basename ();
            if (device_label != mount.get_name ()) {
                ///TRANSLATORS: The first string placeholder '%s' represents a device label, the second '%s' represents a mount name.
                device_label = _("%s on %s").printf (device_label, mount.get_name ());
            }

            var row = add_bookmark (device_label, mount.get_default_location ().get_uri (), mount.get_icon ());
            ((DeviceRow)row).add_device_tooltip.begin ();
        }
        public void add_drive (Drive drive)  {
            if (sidebar.ejecting_or_unmounting) {
                return;
            }
        }
        public void remove_volume (Volume vol)  {
            if (sidebar.ejecting_or_unmounting) {
                return;
            }
        }
        public void remove_mount (Mount mount)  {
            if (sidebar.ejecting_or_unmounting) {
                return;
            }
        }
        public void remove_drive (Drive drive)  {
            if (sidebar.ejecting_or_unmounting) {
                return;
            }
        }
        public void update_volume (Volume vol)  {
            if (sidebar.ejecting_or_unmounting) {
                return;
            }
        }
        public void update_mount (Mount mount)  {
            if (sidebar.ejecting_or_unmounting) {
                return;
            }
        }
        public void update_drive (Drive drive)  {
            if (sidebar.ejecting_or_unmounting) {
                return;
            }
        }

        public void add_all_local_volumes_and_mounts (VolumeMonitor vm) {
            add_connected_drives (vm); // Add drives and their associated volumes
            add_volumes (null, vm.get_volumes ()); // Add volumes not associated with a drive
            add_mounts_without_volume (vm.get_mounts ());
        }

        private void add_connected_drives (VolumeMonitor vm) {
            foreach (GLib.Drive drive in vm.get_connected_drives ()) {
                var volumes = drive.get_volumes ();
                if (volumes != null) {
                    add_volumes (drive, volumes);
                } else if (drive.is_media_removable () && !drive.is_media_check_automatic ()) {
                /* If the drive has no mountable volumes and we cannot detect media change.. we
                 * display the drive in the sidebar so the user can manually poll the drive by
                 * right clicking and selecting "Rescan..."
                 *
                 * This is mainly for drives like floppies where media detection doesn't
                 * work.. but it's also for human beings who like to turn off media detection
                 * in the OS to save battery juice.
                 */
                    add_bookmark (drive.get_name (), "", drive.get_icon ());
                }
            }
        }

        private void add_volumes (Drive? drive, List<Volume> volumes) {
            foreach (Volume volume in volumes) {
                if (volume.get_drive () != drive) {
                    continue;
                }

                var mount = volume.get_mount ();
                if (mount != null) {
                    add_mount (mount);
                } else {
                    /* Do show the unmounted volumes in the sidebar;
                    * this is so the user can mount it (in case automounting
                    * is off).
                    *
                    * Also, even if automounting is enabled, this gives a visual
                    * cue that the user should remember to yank out the media if
                    * he just unmounted it.
                    */

                    add_bookmark (volume.get_name (), "", volume.get_icon ());
                }
            }
        }

        private void add_mounts_without_volume (List<Mount> mounts) {
            foreach (Mount mount in mounts) {
                if (mount.is_shadowed ()) {
                    continue;
                }

                var volume = mount.get_volume ();
                if (volume != null) {
                    continue;
                }

                var root = mount.get_root ();
                if (root.is_native () && root.get_uri_scheme () != "archive") {
                    add_mount (mount);
                }

            }
        }
    }

    private class NetworkListBox : BookmarkListBox {
        public NetworkListBox (Marlin.SidebarListBox sidebar) {
            Object (
                sidebar: sidebar
            );
        }
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
        public Marlin.SidebarListBox sidebar { get; construct; }

        public BookmarkRow (string name,
                            string uri,
                            Icon gicon,
                            Marlin.SidebarListBox sidebar) {
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
        public DeviceRow (string name, string uri, Icon gicon, Marlin.SidebarListBox sidebar) {
            Object (
                custom_name: name,
                uri: uri,
                gicon: gicon,
                sidebar: sidebar
            );
        }

        public async void add_device_tooltip () {

        }
    }

    private class NetworkRow : BookmarkRow {
        public NetworkRow (string name, string uri, Icon gicon, Marlin.SidebarListBox sidebar) {
            Object (
                custom_name: name,
                uri: uri,
                gicon: gicon,
                sidebar: sidebar
            );
        }
    }
}
