/*
 * Copyright (C) 2013 Marlin Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author: jeremywootten <jeremywootten@gmail.com>
 */
namespace Marlin.Places {

    //public class Sidebar : Gtk.ScrolledWindow {
    public class Sidebar : Marlin.AbstractSidebar {

        private const int MAX_BOOKMARKS_DROPPED = 100;
        private const int ROOT_INDENTATION_XPAD = 2;
        private const int EJECT_BUTTON_XPAD = 4;
        private const int TEXT_XPAD = 5;
        private const int ICON_XPAD = 6;

        private const int PROP_0 = 0;
        private const int PROP_ZOOM_LEVEL = 1;

        Gtk.TreeView tree_view;
        Gtk.CellRenderer indent_renderer;
        Gtk.CellRendererPixbuf icon_cell_renderer;
        Gtk.CellRendererPixbuf eject_icon_cell_renderer;
        Gtk.CellRendererText eject_text_cell_renderer;
        Gtk.CellRenderer expander_renderer;
        string uri;
        Marlin.View.Window window;
        Marlin.BookmarkList bookmarks;
        VolumeMonitor volume_monitor;
        uint n_builtins_before;

        /* DnD */
        List<GLib.File> drag_list;
        uint drag_scroll_timer_id;
        Gdk.DragContext drag_context;
        bool received_drag_data;
        uint drag_data_info;
        /* Identifiers for target types */
        public enum TargetType {
            GTK_TREE_MODEL_ROW,
            TEXT_URI_LIST
            }
        /* Gtk.Target types for dragging from shortcut list */
         const Gtk.TargetEntry source_targets [] = {
            {"GTK_TREE_MODEL_ROW", Gtk.TargetFlags.SAME_WIDGET, TargetType.GTK_TREE_MODEL_ROW}
        };

         const Gtk.TargetEntry drop_targets [] = {
            {"GTK_TREE_MODEL_ROW", Gtk.TargetFlags.SAME_WIDGET, TargetType.GTK_TREE_MODEL_ROW},
            {"text/uri-list", Gtk.TargetFlags.SAME_APP, TargetType.TEXT_URI_LIST}
        };

        private Marlin.ZoomLevel _zoom = Marlin.ZoomLevel.SMALLEST;
        public Marlin.ZoomLevel zoom_level {
            get {
                return _zoom;
            }
            set {
                _zoom = value;
                tree_view.columns_autosize ();
            }
        }

        bool drop_occurred;

        Gtk.Menu popupmenu;
        Gtk.MenuItem popupmenu_open_in_new_tab_item;
        Gtk.MenuItem popupmenu_remove_item;
        Gtk.MenuItem popupmenu_rename_item;
        Gtk.MenuItem popupmenu_separator_item1;
        Gtk.MenuItem popupmenu_separator_item2;
        Gtk.MenuItem popupmenu_mount_item;
        Gtk.MenuItem popupmenu_unmount_item;
        Gtk.MenuItem popupmenu_eject_item;
        Gtk.MenuItem popupmenu_rescan_item;
        Gtk.MenuItem popupmenu_format_item;
        Gtk.MenuItem popupmenu_empty_trash_item;
        Gtk.MenuItem popupmenu_connect_server_item;
        Gtk.MenuItem popupmenu_start_item;
        Gtk.MenuItem popupmenu_stop_item;

        /* volume mounting - delayed open process */
        bool mounting = false;
        GOF.Window.Slot go_to_after_mount_slot;
        ViewWindowOpenFlags go_to_after_mount_flags;

        Icon eject_icon;

        enum PlaceType {
            BUILT_IN,
            MOUNTED_VOLUME,
            BOOKMARK,
            BOOKMARKS_CATEGORY,
            PERSONAL_CATEGORY,
            STORAGE_CATEGORY
        }

        enum ViewWindowOpenFlags {
            DEFAULT,
            NEW_TAB,
            NEW_WINDOW
        }


        Marlin.TrashMonitor monitor;
        Gtk.IconTheme theme;

        public Sidebar (Marlin.View.Window window) {
            init ();  //creates the Gtk.TreeModel store.
            this.uri = null;
            this.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);

            this.window = window;
            window.loading_uri.connect (loading_uri_callback);

            var tree_view = new Gtk.TreeView ();
            tree_view.set_size_request (Preferences.settings.get_int ("minimum-sidebar-width"), -1);
            tree_view.set_headers_visible (false);

            var col = new Gtk.TreeViewColumn ();
            col.max_width = 24;
            col.expand = true;

            var crt = new Gtk.CellRendererText ();
            col.pack_start(crt, false);
            col.set_cell_data_func (crt, root_indent_cell_data_func);

            crt = new Gtk.CellRendererText ();
            this.indent_renderer = crt;
            col.pack_start(crt, false);
            col.set_cell_data_func (crt, indent_cell_data_func);

            var crpb = new Gtk.CellRendererPixbuf ();
            this.icon_cell_renderer = crpb;
            crpb.follow_state = true;
            crpb.stock_size = Gtk.IconSize.MENU;
            col.pack_start(crpb, false);
            col.set_attributes (crpb, "gicon", Column.ICON);
            col.set_cell_data_func (crpb, icon_cell_data_func);

            var crd = new Marlin.CellRendererDisk ();
            eject_text_cell_renderer = crd;
            crd.ellipsize = Pango.EllipsizeMode.END;
            crd.ellipsize_set = true;
            col.pack_start (crd, true);
            col.set_attributes (crd,
                                "text", Column.NAME,
                                "visible", Column.EJECT,
                                "free_space", Column.FREE_SPACE,
                                "disk_size", Column.DISK_SIZE);


            crpb = new Gtk.CellRendererPixbuf ();
            eject_icon_cell_renderer = crpb;
            crpb.mode = Gtk.CellRendererMode.ACTIVATABLE;
            crpb.stock_size = Gtk.IconSize.MENU;
            crpb.follow_state = true;
            crpb.xpad = EJECT_BUTTON_XPAD;
            crpb.xalign = (float)1.0;
            col.pack_start (crpb, false);
            col.set_attributes (crpb,
                                "visible", Column.EJECT,
                                "gicon", Column.EJECT_ICON);

            crt = new Gtk.CellRendererText ();
            crt.editable = false;
            crt.ellipsize = Pango.EllipsizeMode.END;
            crt.ellipsize_set = true;
            crt.edited.connect (edited);
            crt.editing_canceled.connect (editing_canceled);
            col.pack_start (crt,true);

            col.set_attributes (crt,
                                "text", Column.NAME,
                                "visible", Column.NO_EJECT,
                                "editable-set", Column.BOOKMARK);
            col.set_cell_data_func (crt, category_renderer_func);

            tree_view.show_expanders = false;
            var cre = new Granite.Widgets.CellRendererExpander ();
            expander_renderer = cre;
            cre.is_category_expander = true;

            /* this is required to align the eject buttons to the right */
            int exp_size = cre.get_arrow_size (tree_view);
            cre.xpad = (16 - exp_size).abs () + EJECT_BUTTON_XPAD - 2;
            cre.xalign = (float)1.0;

            col.pack_end (cre, false);
            col.set_cell_data_func (cre, expander_cell_data_func);

            tree_view.append_column (col);
            tree_view.tooltip_column = Column.TOOLTIP;
            tree_view.model = this.store;
            this.add (tree_view);

            var style_context = tree_view.get_style_context ();
            style_context.add_class (Gtk.STYLE_CLASS_SIDEBAR);
            style_context.add_class (Granite.StyleClass.SOURCE_LIST);

            tree_view.set_search_column (Column.NAME);
            var selection = tree_view.get_selection ();
            selection.set_mode (Gtk.SelectionMode.BROWSE);
            selection.set_select_function (tree_selection_func);
            this.tree_view = tree_view;
            tree_view.show ();
            this.show ();

            tree_view.row_activated.connect (row_activated_callback);

            this.drag_scroll_timer_id = -1;
            tree_view.enable_model_drag_source (Gdk.ModifierType.BUTTON1_MASK,
                                                source_targets,
                                                Gdk.DragAction.MOVE);
            Gtk.drag_dest_set (tree_view, Gtk.DestDefaults.MOTION, drop_targets,
                               Gdk.DragAction.MOVE | Gdk.DragAction.COPY | Gdk.DragAction.LINK);


            tree_view.drag_motion.connect (drag_motion_callback);
            tree_view.drag_leave.connect (drag_leave_callback);
            tree_view.drag_data_received.connect (drag_data_received_callback);
            tree_view.drag_drop.connect (drag_drop_callback);

            selection.changed.connect (selection_changed_cb);
            tree_view.popup_menu.connect (popup_menu_cb);
            tree_view.button_press_event.connect (button_press_event_cb);
            tree_view.button_release_event.connect (button_release_event_cb);
            tree_view.key_press_event.connect (key_press_event_cb);

            tree_view.row_expanded.connect (category_row_expanded_event_cb);
            tree_view.row_collapsed.connect (category_row_collapsed_event_cb);

            monitor = Marlin.TrashMonitor.get ();
            monitor.trash_state_changed.connect (trash_state_changed_cb);
            theme = Gtk.IconTheme.get_default ();
            theme.changed.connect (icon_theme_changed_callback);

            this.volume_monitor = GLib.VolumeMonitor.@get ();
            volume_monitor.volume_added.connect (volume_added_callback);
            volume_monitor.volume_removed.connect (volume_removed_callback);
            volume_monitor.volume_changed.connect (volume_changed_callback);

            volume_monitor.mount_added.connect (mount_added_callback);
            volume_monitor.mount_removed.connect (mount_removed_callback);
            volume_monitor.mount_changed.connect (mount_changed_callback);

            volume_monitor.drive_disconnected.connect (drive_disconnected_callback);
            volume_monitor.drive_changed.connect (drive_connected_callback);
            volume_monitor.drive_changed.connect (drive_changed_callback);

            this.bookmarks = Marlin.BookmarkList.get_instance ();
            bookmarks.contents_changed.connect (update_places);

            update_places ();
        }


        private Icon get_eject_icon () {
            if (eject_icon == null)
                eject_icon = new ThemedIcon.with_default_fallbacks ("media-eject-symbolic");

            return eject_icon;
        }

        private void category_renderer_func (Gtk.CellLayout layout,
                                             Gtk.CellRenderer renderer,
                                             Gtk.TreeModel model,
                                             Gtk.TreeIter iter) {


            PlaceType type;
            Gtk.CellRendererText crt = renderer as Gtk.CellRendererText;
            model.@get (iter, Column.ROW_TYPE, out type, -1);

            if (type == PlaceType.PERSONAL_CATEGORY ||
                type == PlaceType.STORAGE_CATEGORY ||
                type == PlaceType.BOOKMARKS_CATEGORY) {

                crt.weight = 900;
                crt.weight_set = true;
                crt.height = 20;
            } else {
                crt.weight_set = false;
                crt.height = -1;
            }
        }

        private Gtk.TreeIter add_place (PlaceType place_type,
                                        Gtk.TreeIter parent,
                                        string name,
                                        Icon? icon,
                                        string? uri,
                                        Drive? drive,
                                        Volume? volume,
                                        Mount? mount,
                                        uint index,
                                        string tooltip) {
            Gtk.TreeIter iter;
            Gdk.Pixbuf pixbuf = null;
            GLib.Icon eject;
            Marlin.IconInfo icon_info;
            bool show_eject, show_unmount;
            bool show_eject_button;

            Gtk.IconSize stock_size = Marlin.zoom_level_to_stock_icon_size (_zoom);
            eject_icon_cell_renderer.stock_size = stock_size;

            if (icon != null) {
                int icon_size = Marlin.zoom_level_to_icon_size (_zoom);
                icon_info = Marlin.IconInfo.lookup (icon, icon_size);
                pixbuf = icon_info.get_pixbuf_nodefault ();
            }

            check_unmount_and_eject (mount, volume, drive, out show_unmount, out show_eject);

            if (show_unmount || show_eject)
                    assert (place_type != PlaceType.BOOKMARK);

            if (mount == null)
                show_eject_button = false;
            else
                show_eject_button = (show_unmount || show_eject);

            if (show_eject_button)
                eject = get_eject_icon ();
            else
                eject = null;

            GLib.Error error = null;
            string converted_name = name.locale_to_utf8 (name.length, null, null, out error);
            if (error != null) {
                warning ("Could not convert bookmark name. %s", error.message);
                converted_name = name;
            }

            this.store.append (out iter, parent);
            this.store.@set (iter,
                            Column.ROW_TYPE, place_type,
                            Column.URI, uri,
                            Column.DRIVE, drive,
                            Column.VOLUME, volume,
                            Column.MOUNT, mount,
                            Column.NAME, converted_name,
                            Column.ICON, (GLib.Icon)pixbuf,
                            Column.INDEX, index,
                            Column.EJECT, show_eject_button,
                            Column.NO_EJECT, !show_eject_button,
                            Column.BOOKMARK, place_type == PlaceType.BOOKMARK,
                            Column.TOOLTIP, tooltip,
                            Column.EJECT_ICON, eject,
                            Column.FREE_SPACE, 0,
                            Column.DISK_SIZE, 0,
                            -1, -1);
            return iter;
        }

        private void compare_for_selection (string? location,
                                            string? added_uri,
                                            string? last_uri,
                                            Gtk.TreeIter iter,
                                            ref Gtk.TreePath? path) {

            if (added_uri != null && last_uri != null && added_uri == last_uri)
                path = store.get_path (iter);
            else if (location != null && location == added_uri && path == null)
                path = store.get_path (iter);
        }

        private void update_places () {
            Gtk.TreeSelection selection;
            Gtk.TreeIter iter, last_iter;
            Gtk.TreePath select_path;
            //VolumeMonitor volume_monitor;
           // Mount mount;
            //Drive drive;
            //Volume volume;
            string location, mount_uri, last_uri;
            Icon icon;
            File root;
            GOF.Window.Slot slot;
            string tooltip;
message ("update_places");
            last_uri = null;
            select_path = null;
            location = null;

            n_builtins_before = 0;
            selection = tree_view.get_selection ();

            unowned Gtk.TreeModel model;
            if (selection.get_selected (out model, out last_iter))
                store.@get (last_iter,
                            Column.URI, &last_uri,
                            -1);

            store.clear ();

            plugins.update_sidebar ((Gtk.Widget)this);
            slot = window.get_active_slot();

            if (slot != null)
                location = slot.location.get_uri ();

            /* add bookmarks category */
            store.append (out iter, null);
            store.@set (iter,
                        Column.ICON, null,
                        Column.NAME, _("Personal"),
                        Column.ROW_TYPE, PlaceType.BOOKMARKS_CATEGORY,
                        Column.EJECT, false,
                        Column.NO_EJECT, true,
                        Column.BOOKMARK, false,
                        Column.TOOLTIP, _("Your common places and bookmarks"),
                        -1);
            /* add built-in bookmarks */
            /* home folder if different from desktop directory */
            string display_name;
            try {
                mount_uri = GLib.Filename.to_uri (GLib.Environment.get_home_dir (), null);
            }
            catch (ConvertError e) {
                mount_uri = "";
            }
            display_name = _("Home");
            icon = new ThemedIcon (Marlin.ICON_HOME);
            last_iter = add_place ( PlaceType.BUILT_IN,
                                    iter,
                                    display_name,
                                    icon,
                                    mount_uri,
                                    null,
                                    null,
                                    null,
                                    0,
                                    _("Open your personal folder"));

            compare_for_selection ( location,
                                    mount_uri,
                                    last_uri,
                                    last_iter,
                                    ref select_path);

            n_builtins_before++;

            /* add bookmarks */
            uint bookmark_count = bookmarks.length ();
            uint index;
            unowned Bookmark bm;
            for (index = 0; index < bookmark_count; index++) {
                bm = bookmarks.item_at (index);

                if (bm == null || bm.uri_known_not_to_exist ())
                    continue;

                name = bm.label.dup ();
                icon = bm.get_icon ();
                mount_uri = bm.get_uri ();
                root = bm.get_location ();
                tooltip = root.get_parse_name ();
                last_iter = add_place ( PlaceType.BOOKMARK,
                                        iter,
                                        name,
                                        icon,
                                        mount_uri,
                                        null,
                                        null,
                                        null,
                                        index + n_builtins_before,
                                        tooltip);
                 compare_for_selection (location,
                                        mount_uri,
                                        last_uri,
                                        last_iter,
                                        ref select_path);
                debug ("update places - bookmark %u %s", index, mount_uri);
            }
            /* add trash */
            mount_uri = Marlin.TRASH_URI;
            icon = Marlin.TrashMonitor.get_icon ();
            last_iter = add_place ( PlaceType.BUILT_IN,
                                    iter,
                                    _("Trash"),
                                    icon,
                                    mount_uri,
                                    null,
                                    null,
                                    null,
                                    index + n_builtins_before,
                                    _("Open the Trash"));
             compare_for_selection (location,
                                    mount_uri,
                                    last_uri,
                                    last_iter,
                                    ref select_path);
            /* add storage category*/
            store.append (out iter, null);
            store.@set (iter,
                        Column.ICON, null,
                        Column.NAME, _("Devices"),
                        Column.ROW_TYPE, PlaceType.STORAGE_CATEGORY,
                        Column.EJECT, false,
                        Column.NO_EJECT, true,
                        Column.BOOKMARK, false,
                        Column.TOOLTIP, _("Your local partitions and devices"),
                        -1);
            mount_uri = "file:///";
            icon = new ThemedIcon.with_default_fallbacks (Marlin.ICON_FILESYSTEM);
            last_iter = add_place (PlaceType.BUILT_IN,
                                   iter,
                                   _("File System"),
                                   icon,
                                   mount_uri,
                                   null,
                                   null,
                                   null,
                                   0,
                                   _("Open the contents of the FileSystem"));
             compare_for_selection (location,
                                    mount_uri,
                                    last_uri,
                                    last_iter,
                                    ref select_path);

            //volume_monitor = this.volume_monitor;
            /* First go through all connected drives */
            var drives = volume_monitor.get_connected_drives ();
            List<Volume> volumes;
            foreach (Drive drive in drives) {
                volumes = drive.get_volumes ();
                if (volumes != null) {
                    foreach (Volume volume in volumes) {
                        var mount = volume.get_mount ();
                        if (mount != null) {
                            /* show mounted volume in sidebar */
                            icon = mount.get_icon ();
                            root = mount.get_default_location ();
                            mount_uri = root.get_uri ();
                            name = mount.get_name ();
                            tooltip = root.get_parse_name ();
                            last_iter = add_place (PlaceType.MOUNTED_VOLUME,
                                                   iter,
                                                   name,
                                                   icon,
                                                   mount_uri,
                                                   drive,
                                                   volume,
                                                   mount,
                                                   0,
                                                   tooltip);
                            GLib.FileInfo info;
                            try {
                                info = root.query_filesystem_info ("filesystem::*", null);
                            }
                            catch (GLib.Error error) {
                                //message ("Error querying root filesystem info: %s", error.message);
                                info = null;
                            }
                            uint64 fs_capacity = 0;
                            uint64 fs_free = 0;
                            if (info != null) {
                                fs_capacity = info.get_attribute_uint64 (FileAttribute.FILESYSTEM_SIZE);
                                fs_free = info.get_attribute_uint64 (FileAttribute.FILESYSTEM_FREE);
                            }
                            store.@set (last_iter,
                                        Column.FREE_SPACE, fs_free,
                                        Column.DISK_SIZE, fs_capacity,
                                        -1);
                            compare_for_selection (location,
                                                   mount_uri,
                                                   last_uri,
                                                   last_iter,
                                                   ref select_path);
                        } else {
                            /* Do show the unmounted volumes in the sidebar;
                            * this is so the user can mount it (in case automounting
                            * is off).
                            *
                            * Also, even if automounting is enabled, this gives a visual
                            * cue that the user should remember to yank out the media if
                            * he just unmounted it.
                            */
                            icon = volume.get_icon ();
                            name = volume.get_name ();
                            tooltip = (_("Mount and open %s")).printf (name);
                            last_iter = add_place (PlaceType.MOUNTED_VOLUME,
                                                   iter,
                                                   name,
                                                   icon,
                                                   null,
                                                   drive,
                                                   volume,
                                                   null,
                                                   0,
                                                   tooltip);
                        }
                    }
                } else {
                    if (drive.is_media_removable () && !drive.is_media_check_automatic ()) {
                        /* If the drive has no mountable volumes and we cannot detect media change.. we
                         * display the drive in the sidebar so the user can manually poll the drive by
                         * right clicking and selecting "Rescan..."
                         *
                         * This is mainly for drives like floppies where media detection doesn't
                         * work.. but it's also for human beings who like to turn off media detection
                         * in the OS to save battery juice.
                         */
                        icon = drive.get_icon ();
                        name = drive.get_name ();
                        tooltip = (_("Mount and open %s")).printf  (name);
                        last_iter = add_place (PlaceType.BUILT_IN,
                                               iter,
                                               name,
                                               icon,
                                               null,
                                               drive,
                                               null,
                                               null,
                                               0,
                                               tooltip);
                    }
                }
            }
            /* add all volumes that is not associated with a drive */
            volumes = volume_monitor.get_volumes ();
            foreach (Volume volume in volumes) {
                var drive = volume.get_drive ();
                if (drive != null)
                    continue;

                var mount = volume.get_mount ();
                if (mount != null) {
                    icon = mount.get_icon ();
                    root = mount.get_default_location ();
                    mount_uri = root.get_uri ();
                    tooltip = root.get_parse_name ();
                    name = mount.get_name ();
                    last_iter = add_place (PlaceType.MOUNTED_VOLUME,
                                           iter,
                                           name,
                                           icon,
                                           mount_uri,
                                           null,
                                           volume,
                                           mount,
                                           0,
                                           tooltip);

                    compare_for_selection (location,
                                           mount_uri,
                                           last_uri,
                                           last_iter,
                                           ref select_path);
                } else {
                /* see comment above in why we add an icon for an unmounted mountable volume */
                    icon = volume.get_icon ();
                    name = volume.get_name ();
                    last_iter = add_place (PlaceType.MOUNTED_VOLUME,
                                           iter,
                                           name,
                                           icon,
                                           null,
                                           null,
                                           volume,
                                           null,
                                           0,
                                           name);
                }
            }
            /* add mounts that have no volume (/etc/mtab mounts, ftp, sftp,...) */
            List<Mount> network_mounts = null;
            var mounts = volume_monitor.get_mounts ();
            foreach (Mount mount in mounts) {
                if (mount.is_shadowed ())
                    continue;

                var volume = mount.get_volume ();
                if (volume != null)
                    continue;

                root = mount.get_default_location ();

                if (root.is_native ()) {
                    string scheme = root.get_uri_scheme ();
                    if (scheme == "archive") {
                        network_mounts.prepend (mount);
                        continue;
                    }
                }

                icon = mount.get_icon ();
                mount_uri = root.get_uri ();
                tooltip = root.get_parse_name ();
                name = mount.get_name ();
                last_iter = add_place (PlaceType.MOUNTED_VOLUME,
                                       iter,
                                       name,
                                       icon,
                                       mount_uri,
                                       null,
                                       null,
                                       mount,
                                       0,
                                       tooltip);

                compare_for_selection (location,
                                       mount_uri,
                                       last_uri,
                                       last_iter,
                                       ref select_path);
            }
            /* add network category */

            store.append (out iter, null);
            store.@set (iter,
                        Column.ICON, null,
                        Column.NAME, _("Network"),
                        Column.ROW_TYPE, PlaceType.STORAGE_CATEGORY,
                        Column.EJECT, false,
                        Column.NO_EJECT, true,
                        Column.BOOKMARK, false,
                        Column.TOOLTIP, _("Your network places"),
                        -1);

            network_mounts.reverse ();
            foreach (Mount mount in network_mounts) {
                root = mount.get_default_location ();
                icon = mount.get_icon ();
                mount_uri = root.get_uri ();
                tooltip = root.get_parse_name ();
                name = mount.get_name ();
                last_iter = add_place (PlaceType.BUILT_IN,
                                       iter,
                                       name,
                                       icon,
                                       mount_uri,
                                       null,
                                       null,
                                       mount,
                                       0,
                                       tooltip);

                compare_for_selection (location,
                                       mount_uri,
                                       last_uri,
                                       last_iter,
                                       ref select_path);
            }

            mount_uri = "network:///";
            icon = new GLib.ThemedIcon (Marlin.ICON_NETWORK);
            last_iter = add_place (PlaceType.BUILT_IN,
                                   iter,
                                   _("Entire Network"),
                                   icon,
                                   mount_uri,
                                   null,
                                   null,
                                   null,
                                   0,
                                   _("Browse the contents of the network"));

            expander_init_pref_state (tree_view);

            if (location != null && mount_uri != null && location == mount_uri)
                selection.select_iter (last_iter);

            if (select_path != null)
                selection.select_path (select_path);
        }

        private void mount_added_callback (VolumeMonitor volume_monitor, Mount mount) {
            update_places ();
        }
        private void mount_removed_callback (VolumeMonitor volume_monitor, Mount mount) {
            update_places ();
        }
        private void mount_changed_callback (VolumeMonitor volume_monitor, Mount mount) {
            update_places ();
        }

        private void volume_added_callback (VolumeMonitor volume_monitor, Volume volume) {
            update_places ();
        }
        private void volume_removed_callback (VolumeMonitor volume_monitor, Volume volume) {
            update_places ();
        }
        private void volume_changed_callback (VolumeMonitor volume_monitor, Volume volume) {
            update_places ();
        }

        private void drive_connected_callback (VolumeMonitor volume_monitor, Drive drive) {
            update_places ();
        }
        private void drive_disconnected_callback (VolumeMonitor volume_monitor, Drive drive) {
            update_places ();
        }
        private void drive_changed_callback (VolumeMonitor volume_monitor, Drive drive) {
            update_places ();
        }

        private bool over_eject_button (double x, double y, out Gtk.TreePath path) {
            unowned Gtk.TreeViewColumn column;
            int width, x_offset, hseparator;
            int eject_button_size;
            bool show_eject;
            Gtk.TreeIter iter;

            int cell_x, cell_y;
            if (tree_view.get_path_at_pos ((int)x, (int)y, out path, out column, out cell_x, out cell_y)) {
                if (path == null)
                    return false;

                store.get_iter (out iter, path);
                store.@get (iter, Column.EJECT, out show_eject, -1);

                if (!show_eject)
                    return false;

                tree_view.style_get ("horizontal-separator", out hseparator, null);
                /* reload the cell attributes for this particular row */
                column.cell_set_cell_data (store, iter, false, false);
                column.cell_get_position (eject_icon_cell_renderer, out x_offset, out width);

                eject_button_size = 20;
                x_offset+= width - hseparator - EJECT_BUTTON_XPAD - eject_button_size;

                if (x - x_offset >= 0 && x - x_offset <= eject_button_size)
                    return true;
            }

            return false;
        }

        private  bool clicked_eject_button (out Gtk.TreePath path) {
            Gdk.Event event = Gtk.get_current_event ();

            if ((event.type == Gdk.EventType.BUTTON_PRESS || event.type == Gdk.EventType.BUTTON_RELEASE) &&
                over_eject_button (event.button.x, event.button.y, out path)) {
                    return true;
            }
            return false;
        }

        private void row_activated_callback (Gtk.TreePath path,
                                             Gtk.TreeViewColumn column) {
            open_selected_bookmark ((Gtk.TreeModel)store, path, 0);
        }

        private void loading_uri_callback (string location, Gtk.Widget sidebar) {
            Gtk.TreeSelection selection;
            Gtk.TreeIter iter;
            Gtk.TreeIter child_iter;
            bool valid;
            bool child_valid;

            if (!(this.uri == location)) {
                this.uri = location.dup ();

                /* set selection if any place matches location */
                selection = tree_view.get_selection ();
                valid = store.get_iter_first (out iter);

                while (valid) {
                    child_valid = store.iter_children (out child_iter, iter);

                    string uri;
                    while (child_valid) {
                        store.@get (child_iter, Column.URI, out uri, -1);
                        if (uri != null && uri == location) {
                            selection.select_iter (child_iter);
                            break;
                        }

                        child_valid = store.iter_next (ref child_iter);
                    }
                    valid = store.iter_next (ref iter);
                }
            }
        }

        /* Reorders the selected bookmark to the specified position */
        private void reorder_bookmarks (uint new_position) {

            Gtk.TreeIter iter;
message ("reorder_bookmarks - new position %u", new_position);
            /* Get the selected path */
            if (!get_selected_iter (out iter))
                return;

            bool is_bookmark;
            uint old_position;
            store.@get (iter,
                        Column.BOOKMARK, out is_bookmark,
                        Column.INDEX, out old_position,
                        -1);

            old_position = old_position <= n_builtins_before ? 0 : old_position - n_builtins_before;

message ("reorder_bookmarks - corrected old position %u", old_position);

            if (!is_bookmark || old_position >= bookmarks.length ())
                return;

            bookmarks.move_item (old_position, new_position);
        }

/* DRAG N DROP FUNCTIONS START */
/******************************/

        private bool drag_motion_callback (Gdk.DragContext context,
                                           int x,
                                           int y,
                                           uint time) {
            Gtk.TreePath path;
            Gtk.TreeViewDropPosition pos = 0;
            Gdk.DragAction action = 0;
            Gtk.TreeIter iter;
            string uri;

            if (!received_drag_data) {
                if (!get_drag_data (tree_view, context, time));
{
//message ("drag_motion_callback - failed to get drag data");
                    return false;
}
            }

//message (@"Received drag data is $received_drag_data");

            if (!compute_drop_position (tree_view, x, y, out path, out pos))
{
//message ("drag_motion_callback - Failed to compute drop position");
                return false;
}
//message ("drag_motion_callback - Computed drop position");
            if (pos == Gtk.TreeViewDropPosition.BEFORE
                || pos == Gtk.TreeViewDropPosition.AFTER) {
//message (@"Drop position $pos");
//message (@"received drag data is $received_drag_data");
//message (@"drag_data_info is $drag_data_info");
//message ("drag_list is %s", drag_list != null ? "FULL" : "EMPTY");
//message (@"path is $path");

                if (received_drag_data
                    && drag_data_info == TargetType.GTK_TREE_MODEL_ROW)
{
//message ("drag_motion_callback - Drag data info = GTK_TREE_MODEL_ROW");
                    action = Gdk.DragAction.MOVE;
}
                else if (drag_list != null && can_accept_files_as_bookmarks (drag_list))
                    action = Gdk.DragAction.COPY;
            } else if (drag_list != null && path != null) {
//message ("drag_motion_callback - Dropping onto bookmark");
                store.get_iter (out iter, path);
                this.store.@get (iter, Column.URI, out uri, -1);
                //TODO use GOFFILE instead of uri
                if (uri != null) {
                    GOF.File file = GOF.File.get_by_uri (uri);
                    if (file.ensure_query_info ())
                        file.accepts_drop (drag_list, context, out action);
                }
            }

//message ("Action is %i, pos is %i", action, pos);
            tree_view.set_drag_dest_row (path, pos);
            GLib.Signal.stop_emission_by_name (tree_view, "drag-motion");

            Gdk.drag_status (context, action, time);

            /* start the drag autoscroll timer if not already running */
            if (drag_scroll_timer_id < 0) {
                drag_context = context;
                drag_scroll_timer_id = GLib.Timeout.add_full (GLib.Priority.LOW,
                                                              50,
                                                              drag_scroll_timer);
            }
            return true;
        }

        private bool drag_drop_callback (Gdk.DragContext context,
                                         int x,
                                         int y,
                                         uint time) {
            bool retval = false;
//message ("drag_drop_callback ");
            drop_occurred = true;
            retval = get_drag_data (tree_view, context, time);
            GLib.Signal.stop_emission_by_name (tree_view, "drag_drop");
            return retval;
        }

        private  bool get_drag_data (Gtk.TreeView tree_view, Gdk.DragContext context, uint32 time) {
            Gdk.Atom target = Gtk.drag_dest_find_target (tree_view, context, Gtk.drag_dest_get_target_list (tree_view));

            if (target == Gdk.Atom.NONE)
                return false;

            Gtk.drag_get_data ((Gtk.Widget)tree_view, context, target, time);
            return true;
        }

        private void drag_data_received_callback (Gtk.Widget widget,
                                                         Gdk.DragContext context,
                                                         int x,
                                                         int y,
                                                         Gtk.SelectionData selection_data,
                                                         uint info,
                                                         uint time) {
            Gtk.TreeView tree_view;
            Gtk.TreePath tree_path;
            Gtk.TreeViewDropPosition drop_pos;
            Gtk.TreeModel model;
            string drop_uri;
            bool success;

//message ("drag_data_received_callback");
            tree_view = widget as Gtk.TreeView;

            if (!received_drag_data) {
//message ("received_drag_data_callback - received drag data is false");
                if (selection_data.get_target () != Gdk.Atom.NONE && info == TargetType.TEXT_URI_LIST) {
                    string s = (string)(selection_data.get_data ()); /* ?? */
//message ("Filling drag_list");
                    this.drag_list = EelGFile.list_new_from_string (s);
                } else
{
//message ("Nulling drag_list");
                    this.drag_list = null;
}
                received_drag_data = true;
                drag_data_info = info;
            }

            GLib.Signal.stop_emission_by_name (widget, "drag-data-received");

            if (!drop_occurred)
{
//message ("received_drag_data_callback - drop did not occur");

                return;
}

warning ("DROP OCCURRED");
            success = false;
            /* Compute position */
            if (compute_drop_position (tree_view, x, y, out tree_path, out drop_pos)) {
//message ("received_drag_data_callback done compute drop poistion");

                model = tree_view.get_model ();
//message ("received_drag_data_callback done treepath is %s", tree_path.to_string ());
//message (@"received_drag_data_callback done drop position is $drop_pos");

                Gtk.TreeIter iter;
                if (model.get_iter (out iter, tree_path)) {
//message ("received_drag_data_callback - got iter");

                    if (drop_pos == Gtk.TreeViewDropPosition.BEFORE ||
                        drop_pos == Gtk.TreeViewDropPosition.AFTER) {
//message ("received_drag_data_callback - drop position before or after");

                        PlaceType type;
                        uint position;
                        model.@get (iter,
                                    Column.ROW_TYPE, out type,
                                    Column.INDEX, out position,
                                    -1);

                        if (type >= 0 &&
                            (type == PlaceType.BOOKMARK || type == PlaceType.BUILT_IN)) {
//message ("received_drag_data_callback type is bookmark or builtin");

                            if (type == PlaceType.BOOKMARK && drop_pos == Gtk.TreeViewDropPosition.AFTER)
                                position++;

//message ("received_drag_data_callback info is %u", info);
position = position <= n_builtins_before ? 0 : position - n_builtins_before;
message (@"received_drag_data_callback position is $position");

                            switch (info) {
                                case TargetType.TEXT_URI_LIST:
//message ("received_drag_data_callback- TEXT_URI_LIST");

                                    //drop_uris (selection_data, position);
                                    drop_drag_list (position);
                                    success = true;
                                    break;
                                case TargetType.GTK_TREE_MODEL_ROW:
                                    reorder_bookmarks (position);
                                    success = true;
                                    break;
                                default:
                                    assert_not_reached ();
                            }
                        }
                    } else {
//message ("received_drag_data_callback- file copy/move requested");

                        store.@get (iter,
                                    Column.URI, out drop_uri,
                                    -1);
                        Gdk.DragAction real_action;
                        /* file transfer requested */
                        real_action = context.get_selected_action ();

                        if (real_action == Gdk.DragAction.ASK) {
                            var actions = context.get_actions ();
                            if (drop_uri.has_prefix ("trash:///"))
                                actions &= Gdk.DragAction.MOVE;

                            real_action = Marlin.drag_drop_action_ask ((Gtk.Widget)tree_view,
                                                                       actions);
                        }
//message ("received_drag_data_callback- real action is %i", (int)real_action);

                        if (real_action > 0) {
                            switch (info) {
                                 case TargetType.TEXT_URI_LIST:
                                    File drop_file = File.new_for_uri (drop_uri);
                                    Marlin.FileOperations.copy_move (drag_list,
                                                                     null,
                                                                     drop_file,
                                                                     real_action,
                                                                     null, null, null);
                                    success = true;
                                    break;
                                case TargetType.GTK_TREE_MODEL_ROW:
                                    success = false;
                                    break;
                                default:
                                    assert_not_reached ();
                            }
                        }
                    }
                }
            }
            drop_occurred = false;
//message ("received_drag_data_callback- success is %s", success ? "TRUE" : "FALSE");
            update_places ();
            Gtk.drag_finish (context, success, false, time);
        }

        private void drag_leave_callback (Gdk.DragContext context, uint time) {
            free_drag_data ();
            tree_view.set_drag_dest_row (null, Gtk.TreeViewDropPosition.BEFORE);
            GLib.Signal.stop_emission_by_name (tree_view, "drag-leave");
        }

        private void free_drag_data () {
            received_drag_data = false;
            /* stop any running drag autoscroll timer */
            if (drag_scroll_timer_id >= 0) {
                GLib.Source.remove (drag_scroll_timer_id);
                drag_scroll_timer_id = -1;
            }
        }


//        private  bool can_accept_file_as_bookmark (GOF.File file) {
//            return file.is_directory;
//        }
        private  bool can_accept_file_as_bookmark (GLib.File file) {
            GLib.FileType ftype = file.query_file_type (GLib.FileQueryInfoFlags.NONE, null);
            return ( ftype == GLib.FileType.DIRECTORY
//                  || ftype == GLib.FileType.REGULAR
//                  || ftype == GLib.FileType.MOUNTABLE
                   );
        }

        private bool can_accept_files_as_bookmarks (List<GLib.File> items) {
        /* Iterate through selection checking if item will get accepted as a bookmark.
         * Does not accept more than MAX_BOOKMARKS_DROPPED bookmarks
         */
            int count = 0;
            items.@foreach ((file) => {
                    if (can_accept_file_as_bookmark (file))
                            count++;
            });
//message ("%i files accepted for drop", count);
            return count > 0 && count <= MAX_BOOKMARKS_DROPPED;
        }

        private void drop_drag_list (uint position) {
            if (drag_list == null)
                return;

            drag_list.@foreach ((file) => {
warning ("Attempting to drop %s", file.get_uri ());
                if (can_accept_file_as_bookmark (file)) {
                    bookmarks.insert_uri (file.get_uri (), position++);
message ("DROPPED");
}
            });
        }
        /* Parses a "text/uri-list" string and inserts its URIs as bookmarks */
//        private void drop_uris (Gtk.SelectionData selection_data,
//                                          uint position) {

//            string [] uris = selection_data.get_uris ();
//            if (uris == null)
//                return;

//            GOF.File file;
//            foreach (string uri in uris) {
//                file = GOF.File.get_by_uri (uri);
//                if (can_accept_file_as_bookmark (file))
//                    bookmarks.insert_uri (uri, position++);

//            }
//        }

        private  bool drag_scroll_timer () {
            Gtk.Adjustment adjustment;
            double val;
            int offset;
            int y, x;
            int w, h;

            /* verify that we are realized */
            if (get_realized ()) {
                /* determine pointer location and window geometry */
                Gtk.Widget widget = (this as Gtk.Bin).get_child ();
                Gdk.Device pointer = drag_context.get_device ();
                Gdk.Window window = widget.get_window ();

                window.get_device_position (pointer, out x, out y, null);
                window.get_geometry (null, null, out w, out h);
                /* check if we are near the edge (vertical) */
                offset = y - (2 * 20);
                if (offset > 0)
                    offset = int.max (y - (h - 2 * 20), 0);

                /* change the vertical adjustment appropriately */
                if (offset != 0) {
                    /* determine the vertical adjustment */
                    adjustment = (this as Gtk.ScrolledWindow).get_vadjustment ();
                    /* determine the new value */
                    val = (adjustment.value + 2.0 * offset);
                    val = val.clamp (adjustment.lower,
                                     adjustment.upper - adjustment.page_size);

                    /* apply the new value */
                    adjustment.value = val;
                }
                /* check if we are near the edge (horizontal) */
                 offset = x - (2 * 20);
                 if (offset > 0)
                    offset = int.max (x - (w - 2 * 20), 0);

                /* change the horizontal adjustment appropriately */
                if (offset != 0) {
                    /* determine the horizontal adjustment */
                    adjustment = (this as Gtk.ScrolledWindow).get_hadjustment ();
                    /* determine the new value */
                    val = (adjustment.value + 2 * offset);
                    val = val.clamp (adjustment.lower,
                                     adjustment.upper - adjustment.page_size);

                    /* apply the new value */
                    adjustment.value = val;
                }
            }
            return true;
        }

    //    private void drag_scroll_timer_destroy (Object object) {
    //        this.drag_scroll_timer_id = -1;
    //    }

    /* Computes the appropriate row and position for dropping */
        private bool compute_drop_position (Gtk.TreeView tree_view,
                                                    int x,
                                                    int y,
                                                    out Gtk.TreePath path,
                                                    out Gtk.TreeViewDropPosition drop_position
                                                    ) {
            int num_rows;
            int row;
            num_rows = store.iter_n_children (null);
//message ("num rows is %i", num_rows);
//message ("X is %i,  Y is %i", x, y);

            if (!tree_view.get_dest_row_at_pos (x, y, out path, out drop_position)) {
                warning ("compute_drop position dest_row_at_pos UNKNOWN");
                return false;
            }
            else
                //message (@"get dest_row_at_pos pos is $drop_position, path is $path");


            row = (path.get_indices ()) [0];

//message ("row is %i", row);

            path = null;
            tree_view.get_path_at_pos (x, y, out path, null, null, null);

//message (@"get_path_at_pos, path is now $path");

            if (row == 1 || row == 2) {
                /* Hardcoded shortcuts can only be dragged into */
                drop_position = Gtk.TreeViewDropPosition.INTO_OR_BEFORE;
            } else if (row >= num_rows) {
                row = num_rows - 1; /* row not used after this?? */
                drop_position = Gtk.TreeViewDropPosition.AFTER;
            } else if (drop_position != Gtk.TreeViewDropPosition.BEFORE
                       && received_drag_data
                       && drag_data_info == TargetType.GTK_TREE_MODEL_ROW)
                /* bookmark rows are never dragged into other bookmark rows */
                drop_position = Gtk.TreeViewDropPosition.AFTER;

            if (path.get_depth () == 1)
                return false;

            return true;
        }

/* DRAG N DROP FUNCTIONS  END*/
/*****************************/

        private  bool get_selected_iter (out Gtk.TreeIter iter) {
                return (tree_view.get_selection ()).get_selected (null, out iter);
        }


        /* Callback used when the file list's popup menu is detached */
        public void popup_menu_detach_cb (Gtk.Widget attach_widget, Gtk.Menu menu) {
            popupmenu = null;
            popupmenu_remove_item = null;
            popupmenu_rename_item = null;
            popupmenu_separator_item1 = null;
            popupmenu_separator_item2 = null;
            popupmenu_mount_item = null;
            popupmenu_unmount_item = null;
            popupmenu_eject_item = null;
            popupmenu_rescan_item = null;
            popupmenu_format_item = null;
            popupmenu_start_item = null;
            popupmenu_stop_item = null;
            popupmenu_empty_trash_item = null;
            popupmenu_connect_server_item = null;
        }

        private void check_unmount_and_eject (Mount? mount,
                                              Volume? volume,
                                              Drive? drive,
                                              out bool show_unmount,
                                              out bool show_eject) {
            show_unmount = false;
            show_eject = false;

            if (drive != null)
                show_eject = drive.can_eject ();

            if (volume != null)
                show_eject = volume.can_eject ();

            if (mount != null) {
                show_eject = mount.can_eject ();
                show_unmount = mount.can_unmount () && !show_eject;
            }
        }

        private void check_visibility (Mount? mount,
                                       Volume? volume,
                                       Drive? drive,
                                       out bool show_mount,
                                       out bool show_unmount,
                                       out bool show_eject,
                                       out bool show_rescan,
                                       out bool show_format,
                                       out bool show_start,
                                       out bool show_stop) {
            show_mount = false;
            show_format = false;
            show_rescan = false;
            show_start = false;
            show_stop = false;

            check_unmount_and_eject (mount, volume, drive, out show_unmount, out show_eject);

            if (drive != null) {
                if (drive.is_media_removable () &&
                    !drive.is_media_check_automatic () &&
                    drive.can_poll_for_media ())
                        show_rescan = true;

                show_start = drive.can_start ()|| drive.can_start_degraded ();
                show_stop = drive.can_stop ();

                if (show_stop)
                    show_unmount = false;
            }

            if (volume != null && mount == null)
                show_mount = volume.can_mount ();
        }

        /* Callback used when the selection in the shortcuts tree changes */
        private void selection_changed_cb () {
            check_popup_sensitivity ();
        }

        private void check_popup_sensitivity () {
            if (popupmenu == null)
                return;

            PlaceType type;
            Drive drive;
            Volume volume;
            Mount mount;
            string uri;
            bool is_bookmark;
            Gtk.TreeIter iter;

            if (get_selected_iter (out iter))
                store.@get (iter,
                            Column.ROW_TYPE, out type,
                            Column.DRIVE, out drive,
                            Column.VOLUME, out volume,
                            Column.MOUNT, out mount,
                            Column.URI, out uri,
                            Column.BOOKMARK, out is_bookmark,
                            -1);
            else
                return;

//message ("check_popup_sensitivity - type is %i, uri is %s", type, uri);

            popupmenu_open_in_new_tab_item.show ();
            Eel.gtk_widget_set_shown (popupmenu_remove_item, is_bookmark);
            Eel.gtk_widget_set_shown (popupmenu_rename_item, is_bookmark);
            Eel.gtk_widget_set_shown (popupmenu_separator_item1, is_bookmark);

            bool show_mount, show_unmount, show_eject, show_rescan, show_format, show_start, show_stop;

            check_visibility (mount,
                              volume,
                              drive,
                              out show_mount,
                              out show_unmount,
                              out show_eject,
                              out show_rescan,
                              out show_format,
                              out show_start,
                              out show_stop);

            bool show_empty_trash = (uri != null) && (uri == Marlin.TRASH_URI);
            bool show_connect_server = (uri != null) && (uri == Marlin.NETWORK_URI);
            Eel.gtk_widget_set_shown (popupmenu_separator_item2,
                                      show_eject || show_unmount ||
                                      show_mount || show_empty_trash ||
                                      show_connect_server);
            Eel.gtk_widget_set_shown (popupmenu_mount_item, show_mount);
            Eel.gtk_widget_set_shown (popupmenu_unmount_item, show_unmount);
            Eel.gtk_widget_set_shown (popupmenu_eject_item, show_eject);
            Eel.gtk_widget_set_shown (popupmenu_empty_trash_item, show_empty_trash);
            popupmenu_empty_trash_item.set_sensitive (!(Marlin.TrashMonitor.is_empty ()));

            Eel.gtk_widget_set_shown (popupmenu_connect_server_item, show_connect_server);
        }

    //    private void drive_start_from_bookmark_cb (GLib.Object? source_object,
    //                                               GLib.AsyncResult res) {
    //        Drive drive = source_object as Drive;
    //        if (drive != null) {
    //            try {
    //                drive.poll_for_media (null);
    //            }
    //            catch (GLib.Error error) {
    //                string name = drive.get_name ();
    //                string primary = (_("Error on starting drive %s")).printf (name);
    //                Eel.show_error_dialog (primary, error.message, null); /* ?doesnt show dialog? */
    //            }
    //        }
    //    }

        private void open_selected_bookmark (Gtk.TreeModel model,
                                             Gtk.TreePath path,
                                             ViewWindowOpenFlags flags) {
            if (path == null)
                return;
            Gtk.TreeIter iter;
            if (!store.get_iter (out iter, path))
                return;

            string uri;
            File location;

            store.@get (iter, Column.URI, out uri, -1);

            if (uri != null) {
                location = File.new_for_uri (uri);
                /* Navigate to the clicked location */
                if (flags == ViewWindowOpenFlags.NEW_WINDOW) {
                    window.add_window (location);
                } else if (flags == ViewWindowOpenFlags.NEW_TAB) {
                    window.add_tab (location);
                } else {
                    GOF.Window.Slot? slot = window.get_active_slot ();
                    if (slot != null)
                        GLib.Signal.emit_by_name (slot.ctab, "path-changed", location);
                }
            } else {
                Drive drive;
                Volume volume;
                store.@get (iter,
                             Column.DRIVE, out drive,
                             Column.VOLUME, out volume,
                             -1);
                if (volume != null && !mounting) {
                    mounting = true;
                    assert (go_to_after_mount_slot == null);
message ("Volume UUID is %s", volume.get_uuid ());
                    var slot = window.get_active_slot ();
                    go_to_after_mount_slot = slot;
                    go_to_after_mount_flags = flags;
                    Marlin.FileOperations.mount_volume_full (null, volume, false, (Marlin.MountCallback)volume_mounted_cb, this);
                    //Marlin.FileOperations.mount_volume_full (null, volume, false, null);
                    //Sidebar.mount_volume (this, volume, false);
                } else if (volume == null && drive != null &&
                   (drive.can_start () || drive.can_start_degraded ())) {
message ("Drive identifiers are:");
string[] identifiers = drive.enumerate_identifiers ();
foreach (string s in identifiers) {
    message ("%s", s);
}
                    Gtk.Window win = this.get_toplevel () as Gtk.Window;
                    var mount_op = new Gtk.MountOperation (win);
                    drive.start.begin (DriveStartFlags.NONE, mount_op, null);
                }
            }
        }

        private void open_shortcut_from_menu (ViewWindowOpenFlags flags) {
           // var model = tree_view.get_model ();
            Gtk.TreePath path;
            tree_view.get_cursor (out path, null);
            open_selected_bookmark (store, path, flags);
        }

        private void open_shortcut_cb (Gtk.MenuItem item) {
            open_shortcut_from_menu ( 0);
        }

        private void open_shortcut_in_new_window_cb (Gtk.MenuItem item) {
            open_shortcut_from_menu (ViewWindowOpenFlags.NEW_WINDOW);
        }

        private void open_shortcut_in_new_tab_cb (Gtk.MenuItem item) {
            open_shortcut_from_menu (ViewWindowOpenFlags.NEW_TAB);
        }

        private void rename_selected_bookmark () {
message ("rename_selected_bookmarks");
            Gtk.TreeIter iter;
            if (get_selected_iter ( out iter)) {
                var path = store.get_path (iter);
                var column = tree_view.get_column (0);
                GLib.List<weak Gtk.CellRenderer> renderers = column.get_cells ();
                Gtk.CellRendererText cell = (Gtk.CellRendererText)(renderers.nth_data (5));
                cell.editable = true;
                tree_view.set_cursor_on_cell (path, column, cell, true);
            }
        }

        private void rename_shortcut_cb (Gtk.MenuItem item) {
            rename_selected_bookmark ();
        }

        private void remove_selected_bookmarks () {
message ("remove_selected_bookmarks");
            Gtk.TreeIter iter;
            if (!get_selected_iter (out iter))
                return;

            bool is_bookmark;
            store.@get (iter, Column.BOOKMARK, out is_bookmark, -1);

            if (!is_bookmark)
                return;

            uint index;
            store.@get (iter, Column.INDEX, out index, -1);
            index = index <= n_builtins_before ? 0 : index - n_builtins_before;
            bookmarks.delete_item_at (index);
        }

        private void remove_shortcut_cb (Gtk.MenuItem item) {
message ("remove_shortcut_cb");
            remove_selected_bookmarks ();
        }

         private void mount_shortcut_cb (Gtk.MenuItem item) {
            Gtk.TreeIter iter;
            if (!get_selected_iter (out iter))
                return;

            Volume volume;
            store.@get (iter, Column.VOLUME, out volume, -1);

            if (volume != null)
                Marlin.FileOperations.mount_volume (null, volume, false);
         }

         private void do_unmount (Mount mount) {
            if (mount != null)
                Marlin.FileOperations.unmount_mount_full (null, mount, false, true, null, null);
         }

         private void do_unmount_selection () {
            Gtk.TreeIter iter;
            if (!get_selected_iter (out iter))
                return;

            Mount mount;
            store.@get (iter, Column.MOUNT, out mount, -1);

            if (mount != null)
                do_unmount (mount);
         }

        private void unmount_shortcut_cb (Gtk.MenuItem item) {
            do_unmount_selection ();
        }

        private void do_eject (Mount mount, Volume volume, Drive drive) {
            var mount_op = new Gtk.MountOperation (get_toplevel () as Gtk.Window);
            if (mount != null) {
    //            try {
                    mount.eject_with_operation.begin (GLib.MountUnmountFlags.NONE, mount_op, null); /* FORCE? */
    //            }
    //            catch (GLib.Error error) {
    //                    var name = mount.get_name ();
    //                    var primary = (_("Unable to eject %s")).printf (name);
    //                    Eel.show_error_dialog (primary, error.message, null);
    //            }
            }
            if (volume != null) {
    //            try {
                    volume.eject_with_operation.begin (GLib.MountUnmountFlags.NONE, mount_op, null); /* FORCE? */
    //            }
    //            catch (GLib.Error error) {
    //                    var name = volume.get_name ();
    //                    var primary = (_("Unable to eject %s")).printf (name);
    //                    Eel.show_error_dialog (primary, error.message, null);
    //            }
            }

            if (drive != null) {
    //            try {
                    drive.eject_with_operation.begin (GLib.MountUnmountFlags.NONE, mount_op, null); /* FORCE? */
    //            }
    //            catch (GLib.Error error) {
    //                    var name = drive.get_name ();
    //                    var primary = (_("Unable to eject %s")).printf (name);
    //                    Eel.show_error_dialog (primary, error.message, null);
    //            }
            }
        }

        private void eject_shortcut_cb (Gtk.MenuItem item) {
            Gtk.TreeIter iter;
            if (!get_selected_iter (out iter))
                return;

            Mount mount;
            Volume volume;
            Drive drive;
            store.@get (iter,
                        Column.MOUNT, out mount,
                        Column.VOLUME, out volume,
                        Column.DRIVE, out drive,
                        -1);
            do_eject (mount, volume, drive);
        }

        private  bool eject_or_unmount_bookmark (Gtk.TreePath path) {
            if (path == null)
                return false;

            //var model = (Gtk.TreeModel)(store);
            Gtk.TreeIter iter;
            if (!store.get_iter (out iter, path))
                return false;

            Mount mount;
            Volume volume;
            Drive drive;
            store.@get (iter,
                        Column.MOUNT, out mount,
                        Column.VOLUME, out volume,
                        Column.DRIVE, out drive,
                        -1);

            bool can_unmount;
            bool can_eject;
            check_unmount_and_eject (mount, volume, drive, out can_unmount, out can_eject);

            if (can_eject) {
                do_eject (mount, volume, drive);
                return true;
            } else if (can_unmount) {
                do_unmount (mount);
                return true;
            }

            return false;
        }

        private bool eject_or_unmount_selection () {
            Gtk.TreeIter iter;
            if (!get_selected_iter (out iter))
                return false;

            Gtk.TreePath path = store.get_path (iter);

            if (path == null)
                return false;

            return eject_or_unmount_bookmark (path);
        }

    //    private void drive_poll_for_media_cb (Object source_object, AsyncResult res, void* user_data) {
    //        Drive drive = source_object as Drive;
    //        if (drive == null)
    //            return;

    //        try {
    //            drive.poll_for_media ();
    //        }
    //        catch (GLib.Error error) {
    //            var name = drive.get_name ();
    //            var primary = (_("Unable to poll %s for media changes")).printf (name);
    //            Eel.show_error_dialog (primary, error.message, null);
    //        }
    //    }

        private void empty_trash_cb (Gtk.MenuItem item) {
            Marlin.FileOperations.empty_trash (window);
        }

    //    private void connect_server_cb (Gtk.MenuItem item) {
    //        Marlin.ConnectServer.dialog_show (window);
    //    }

        private  bool key_press_event_cb (Gtk.Widget widget, Gdk.EventKey event) {
            Gdk.ModifierType modifiers = Gtk.accelerator_get_default_mod_mask ();
            if (event.keyval == Gdk.Key.Down && (event.state & modifiers) == Gdk.ModifierType.MOD1_MASK)
                return eject_or_unmount_selection ();

            if ((event.keyval == Gdk.Key.Delete
                || event.keyval == Gdk.Key.KP_Delete)
                && (event.state & modifiers) == 0) {
                remove_selected_bookmarks ();
                return true;
            }

            if (event.keyval == Gdk.Key.F2 && (event.state & modifiers) == 0) {
                rename_selected_bookmark ();
                return true;
            }

            return false;
        }

        private void build_popup_menu () {
            if (popupmenu != null)
                return;

            popupmenu = new Gtk.Menu ();
            popupmenu.attach_to_widget ((Gtk.Widget)this, (Gtk.MenuDetachFunc)popup_menu_detach_cb);

            var item = new Gtk.ImageMenuItem.with_mnemonic (_("Open"));
            var image = new Gtk.Image.from_stock (Gtk.Stock.OPEN, Gtk.IconSize.MENU);

            item.set_image (image);
            item.activate.connect (open_shortcut_cb);
            item.show ();
            popupmenu.append (item);

            item = new Gtk.ImageMenuItem.with_mnemonic (_("Open in New _Tab"));
            popupmenu_open_in_new_tab_item = item;
            item.activate.connect (open_shortcut_in_new_tab_cb);
            item.show ();
            popupmenu.append (item);

            item = new Gtk.ImageMenuItem.with_mnemonic (_("Open in New _Window"));
            item.activate.connect (open_shortcut_in_new_window_cb);
            item.show ();
            popupmenu.append (item);

            popupmenu_separator_item1 = Eel.gtk_menu_append_separator (popupmenu);

            item = new Gtk.ImageMenuItem.with_label (_("Remove"));
            popupmenu_remove_item = item;
            image = new Gtk.Image.from_stock (Gtk.Stock.REMOVE, Gtk.IconSize.MENU);
            item.set_image (image);
            item.activate.connect (remove_shortcut_cb);
            item.show ();
            popupmenu.append (item);

            item = new Gtk.ImageMenuItem.with_label (_("Rename"));
            popupmenu_rename_item = item;
            item.activate.connect (rename_shortcut_cb);
            item.show ();
            popupmenu.append (item);

            /* Mount/Unmount/Eject menu items */
            popupmenu_separator_item2 = Eel.gtk_menu_append_separator (popupmenu);

            item = new Gtk.ImageMenuItem.with_mnemonic (_("_Mount"));
            popupmenu_mount_item = item;
            item.activate.connect (mount_shortcut_cb);
            item.show ();
            popupmenu.append (item);

            item = new Gtk.ImageMenuItem.with_mnemonic (_("_Unmount"));
            popupmenu_unmount_item = item;
            item.activate.connect (unmount_shortcut_cb);
            item.show ();
            popupmenu.append (item);

            item = new Gtk.ImageMenuItem.with_mnemonic (_("_Eject"));
            popupmenu_eject_item = item;
            item.activate.connect (eject_shortcut_cb);
            item.show ();
            popupmenu.append (item);

            /* Empty Trash menu item */
            item = new Gtk.ImageMenuItem.with_mnemonic (_("Empty _Trash"));
            popupmenu_empty_trash_item = item;
            item.activate.connect (empty_trash_cb);
            item.show ();
            popupmenu.append (item);

            /* Connect to server menu item */
            item = new Gtk.ImageMenuItem.with_mnemonic (_("Connect to Server..."));
            popupmenu_connect_server_item = item;
            item.activate.connect (empty_trash_cb);
            item.show ();
            popupmenu.append (item);

            check_popup_sensitivity ();
        }

        private void update_popup_menu () {
            build_popup_menu ();
        }

        private new void popup_menu (Gdk.EventButton? event) {
            update_popup_menu ();
            Eel.pop_up_context_menu (popupmenu,
                                     Eel.DEFAULT_POPUP_MENU_DISPLACEMENT,
                                     Eel.DEFAULT_POPUP_MENU_DISPLACEMENT,
                                     event);
        }

        /* Callback used for the GtkWidget::popup-menu signal of the shortcuts list */
        private bool popup_menu_cb (Gtk.Widget widget) {
            popup_menu (null);
            return true;
        }

        private bool button_release_event_cb (Gtk.Widget widget, Gdk.EventButton event) {
            if (event.type != Gdk.EventType.BUTTON_RELEASE)
                return true;


            Gtk.TreePath path;
            if (clicked_eject_button (out path)) {
                eject_or_unmount_bookmark (path);
                return false;
            }

            assert (tree_view != null);
            //var model = tree_view.get_model ();

            if (event.button ==1) {
                if (event.window != tree_view.get_bin_window ())
                    return false;

                tree_view.get_path_at_pos ((int)(event.x), (int)(event.y), out path, null, null, null);
                open_selected_bookmark (store, path, 0);
            }

            return false;
        }
        /* Callback used when a button is pressed on the shortcuts list.
         * We trap button 3 to bring up a popup menu, and button 2 to
         * open in a new tab.
         */
        private bool button_press_event_cb (Gtk.Widget widget, Gdk.EventButton event) {
            if (event.type != Gdk.EventType.BUTTON_PRESS)
                return true;

            var tree_view = widget as Gtk.TreeView;
            assert (tree_view != null && tree_view == this.tree_view);

            if (event.window != tree_view.get_bin_window ())
                return true;

            //var model = tree_view.get_model ();
            Gtk.TreePath path;
            tree_view.get_path_at_pos ((int)event.x, (int)event.y, out path, null, null, null);

            switch (event.button) {
                case Gdk.BUTTON_PRIMARY:
                /* If the user clicked over a category, toggle expansion. The entire row
                 * is a valid area.
                 */
                    if (path != null && category_at_path (path)) {
                        if (tree_view.is_row_expanded (path))
                            tree_view.collapse_row (path);
                        else
                            tree_view.expand_row (path, false);

                        return true;
                    }
                    break;

                case Gdk.BUTTON_SECONDARY:
                    if (path != null && !category_at_path (path))
                        popup_menu (event);

                    break;

                case Gdk.BUTTON_MIDDLE:
                    if (path != null && !category_at_path (path))
                        open_selected_bookmark (store, path, ViewWindowOpenFlags.NEW_TAB);

                    break;
            }

            return false;
        }

        private void edited (Gtk.CellRendererText cell, string path_string, string new_text) {
            cell.editable = false;
            var path = new Gtk.TreePath.from_string (path_string);

            Gtk.TreeIter iter;
            store.get_iter (out iter, path);

            uint index;
            store.@get (iter, Column.INDEX, out index, -1);
            index-= this.n_builtins_before;

            Marlin.Bookmark? bookmark = this.bookmarks.item_at (index);
            if (bookmark != null) {
                bookmark.label = new_text;
                update_places ();
            }
        }

        private void editing_canceled (Gtk.CellRenderer cell) {
            ((Gtk.CellRendererText)cell).editable = false;
        }

        private void trash_state_changed_cb (Marlin.TrashMonitor trash_monitor, bool state) {
            update_places ();
            check_popup_sensitivity ();
        }

        private void icon_cell_data_func (Gtk.CellLayout layout,
                                          Gtk.CellRenderer cell,
                                          Gtk.TreeModel model,
                                          Gtk.TreeIter iter) {

            if (!store.iter_has_child (iter))
                cell.set_visible (true);
            else
                cell.set_visible (false);
        }

        private void root_indent_cell_data_func (Gtk.CellLayout layout,
                                                 Gtk.CellRenderer cell,
                                                 Gtk.TreeModel model,
                                                 Gtk.TreeIter iter) {
            cell.set_visible (true);
            cell.xpad = ROOT_INDENTATION_XPAD;
        }

        private void indent_cell_data_func (Gtk.CellLayout layout,
                                                 Gtk.CellRenderer cell,
                                                 Gtk.TreeModel model,
                                                 Gtk.TreeIter iter) {
            var path = store.get_path (iter);
            var depth = path.get_depth ();
            cell.set_visible (depth > 1);
            cell.xpad = ICON_XPAD;
        }

        private void expander_update_pref_state (PlaceType type, bool flag) {
            switch (type) {
                case PlaceType.PERSONAL_CATEGORY:
                    Preferences.settings.set_boolean ("sidebar-cat-network-expander", flag);
                    break;
                case PlaceType.STORAGE_CATEGORY:
                    Preferences.settings.set_boolean ("sidebar-cat-devices-expander", flag);
                    break;
                case PlaceType.BOOKMARKS_CATEGORY:
                    Preferences.settings.set_boolean ("sidebar-cat-personal-expander", flag);
                    break;
            }
        }

        private void expander_init_pref_state (Gtk.TreeView tree_view) {
            var path = new Gtk.TreePath.from_indices (0,-1);
            if (Preferences.settings.get_boolean ("sidebar-cat-personal-expander"))
                tree_view.expand_row (path, false);
            else
                tree_view.collapse_row (path);

            path = new Gtk.TreePath.from_indices (1,-1);
            if (Preferences.settings.get_boolean ("sidebar-cat-devices-expander"))
                tree_view.expand_row (path, false);
            else
                tree_view.collapse_row (path);

            path = new Gtk.TreePath.from_indices (2,-1);
            if (Preferences.settings.get_boolean ("sidebar-cat-network-expander"))
                tree_view.expand_row (path, false);
            else
                tree_view.collapse_row (path);
        }

        private void expander_cell_data_func (Gtk.CellLayout layout,
                                                 Gtk.CellRenderer cell,
                                                 Gtk.TreeModel model,
                                                 Gtk.TreeIter iter) {
            PlaceType type;
            store.@get (iter, Column.ROW_TYPE, out type, -1);

            if (type == PlaceType.PERSONAL_CATEGORY ||
                type == PlaceType.STORAGE_CATEGORY ||
                type == PlaceType.BOOKMARKS_CATEGORY)
                expander_renderer.visible = true;
            else
                expander_renderer.visible = false;
        }

        private void category_row_expanded_event_cb (Gtk.TreeView tree,
                                                     Gtk.TreeIter iter,
                                                     Gtk.TreePath path) {
            PlaceType type;
            store.@get (iter, Column.ROW_TYPE, out type, -1);
            expander_update_pref_state (type, true);
        }

        private void category_row_collapsed_event_cb (Gtk.TreeView tree,
                                                      Gtk.TreeIter iter,
                                                      Gtk.TreePath path) {
            PlaceType type;
            store.@get (iter, Column.ROW_TYPE, out type, -1);
            expander_update_pref_state (type, false);
        }
        /**
         * Checks whether a tree path points to a main category.
         */
        private bool category_at_path (Gtk.TreePath path) {
        /* We determine whether an item is a category based on its level indentation.
         * According to the current implementation, a level of 1 (i.e. root) necessarily
         * means that the item is a category.
         */
            return path.get_depth () == 1;
        }

        private bool tree_selection_func (Gtk.TreeSelection selection,
                                          Gtk.TreeModel model,
                                          Gtk.TreePath path,
                                          bool path_currently_selected) {
        /* Don't allow categories to be selected. */
            return !category_at_path (path);
        }

        private void icon_theme_changed_callback (Gtk.IconTheme icon_theme) {
            update_places ();
        }

        private void zoom_in () {
            if (_zoom == Marlin.ZoomLevel.NORMAL)
                return;

            _zoom += 1;
        }

        private void zoom_out () {
            if (_zoom == Marlin.ZoomLevel.SMALLEST)
                return;

            _zoom -= 1;
        }

        private new bool handle_scroll_event (Gdk.EventScroll event) {
            double total_delta_y = 0;

            if (event.state == Gdk.ModifierType.CONTROL_MASK) {
                switch (event.direction) {
                    case Gdk.ScrollDirection.UP:
                        zoom_in ();
                        return true;
                    case Gdk.ScrollDirection.DOWN:
                        zoom_out ();
                        return true;
                    case Gdk.ScrollDirection.SMOOTH:
                    /* try to emulate a normal scrolling event by summing deltas */
                        total_delta_y += event.delta_y;
                        if (total_delta_y >= 1) {
                            total_delta_y = 0;
                            zoom_out ();
                            return true;
                        } else if (total_delta_y <= -1) {
                            total_delta_y = 0;
                            zoom_in ();
                            return true;
                        } else
                            return true;
                }
            }
            return false;
        }

        /* handle Control+Scroll, which will cause a zoom-in/out */
        public new bool scroll_event (Gdk.EventScroll event) {
            return handle_scroll_event (event); /* ?? */
        }

        public new void style_set (Gtk.Style previous_style) {
            update_places ();
        }

        static void volume_mounted_cb (GLib.Volume volume, void* call_back_data_object) {
            assert (call_back_data_object is Sidebar);
            assert (volume != null);

            var sidebar = call_back_data_object as Sidebar;
            sidebar.mounting = false;

            var mount = volume.get_mount ();
            if (mount != null) {
                var location = mount.get_default_location ();
                if (sidebar.go_to_after_mount_slot != null &&
                    sidebar.go_to_after_mount_flags != ViewWindowOpenFlags.NEW_WINDOW) {
                        GLib.Signal.emit_by_name (sidebar.go_to_after_mount_slot.ctab,
                                                  "path-changed",
                                                  location);
                        sidebar.go_to_after_mount_slot = null;
                } else
                    sidebar.window.add_window (location);
            }
        }
    }

}
