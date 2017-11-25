/***
    Copyright (c) 2015-2017 elementary LLC (http://launchpad.net/elementary)

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Mr Jamie McCracken (jamiemcc at blueyonder dot co dot uk)
              Roth Robert <evfool@gmail.com>
              ammonkey <am.monkeyd@gmail.com>
              Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace Marlin.Places {
    public class Sidebar : Marlin.AbstractSidebar {

        enum PlaceType {
            BUILT_IN,
            MOUNTED_VOLUME,
            BOOKMARK,
            BOOKMARKS_CATEGORY,
            PERSONAL_CATEGORY,
            STORAGE_CATEGORY
        }

        private const int MAX_BOOKMARKS_DROPPED = 100;
        /* Indents */
        private const int ROOT_INDENTATION_XPAD = 4; /* Left Indent for all rows*/
        private const int ICON_XPAD = 4; /* Extra indent for sub-category rows */
        private const int BOOKMARK_YPAD = 1; /* Affects vertical spacing of bookmarks */
        private const int CATEGORY_YPAD = 3; /* Affects height of category headers */

        private static Marlin.DndHandler dnd_handler = new Marlin.DndHandler ();

        Gtk.TreeView tree_view;
        Gtk.CellRendererText name_renderer;
        Gtk.CellRenderer eject_spinner_cell_renderer;
        Gtk.CellRenderer expander_renderer;
        Marlin.View.Window window;
        Marlin.BookmarkList bookmarks;
        VolumeMonitor volume_monitor;
        Marlin.TrashMonitor monitor;
        Gtk.IconTheme theme;
        GLib.Icon eject_icon;

        int eject_button_size = 20;
        uint n_builtins_before; /* Number of builtin (immovable) bookmarks before the personal bookmarks */
        string last_selected_uri;
        string slot_location;

        /* DnD */
        List<GLib.File> drag_list;
        Gtk.TreeRowReference? drag_row_ref;
        bool dnd_disabled = false;
        uint drag_data_info;
        uint drag_scroll_timer_id;
        Gdk.DragContext drag_context;
        bool received_drag_data;
        bool drop_occurred;
        bool internal_drag_started;
        bool dragged_out_of_window;
        bool renaming = false;
        bool local_only;

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

        Gtk.Menu popupmenu;
        Gtk.MenuItem popupmenu_open_in_new_tab_item;
        Gtk.MenuItem popupmenu_open_in_new_window_item;
        Gtk.MenuItem popupmenu_remove_item;
        Gtk.MenuItem popupmenu_rename_item;
        Gtk.MenuItem popupmenu_separator_item1;
        Gtk.MenuItem popupmenu_separator_item2;
        Gtk.MenuItem popupmenu_mount_item;
        Gtk.MenuItem popupmenu_unmount_item;
        Gtk.MenuItem popupmenu_eject_item;
        Gtk.MenuItem popupmenu_empty_trash_item;
        Gtk.MenuItem popupmenu_drive_property_item;

        /* volume mounting - delayed open process */
        bool mounting = false;

        /* prevent multiple unmount processes */
        bool ejecting_or_unmounting = false;

        /* TODO Make it an option in Settings whether or not to show
         * bookmarks pointing to non-existent (or unmounted) files. */
        bool display_all_bookmarks = true;

        /* Remember vertical adjustment value when lose focus */
        double adjustment_val = 0.0;
        /* Remember path at button press */
        Gtk.TreePath? click_path = null;

        bool is_admin {
            get {
                return (uint)Posix.getuid () == 0;
            }
        }

        /* For cancelling async tooltip updates when update_places re-entered */
        Cancellable? update_cancellable = null;

        public signal bool request_focus ();
        public signal void sync_needed ();
        public signal void path_change_request (string uri, Marlin.OpenFlag flag);

        public new void grab_focus () {
            tree_view.grab_focus ();
        }

        public new bool has_focus {
            get {
                return tree_view.has_focus;
            }
        }

        public Sidebar (Marlin.View.Window window, bool local_only = false) {
            init ();  /* creates the Gtk.TreeModel store. */
            this.last_selected_uri = null;
            this.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            this.window = window;
            this.local_only = local_only;

            window.loading_uri.connect (loading_uri_callback);
            window.free_space_change.connect (reload);

            construct_tree_view ();
            configure_tree_view ();
            connect_tree_view_signals ();
            this.scroll_event.connect (update_adjustment_val);
            this.content_box.pack_start (this.tree_view, true);

            this.bookmarks = Marlin.BookmarkList.get_instance ();
            bookmarks.contents_changed.connect (update_places);

            set_up_trash_monitor ();
            this.volume_monitor = GLib.VolumeMonitor.@get ();
            connect_volume_monitor_signals ();

            set_up_theme ();
            this.show_all ();

            update_places ();
        }

        private void construct_tree_view () {
            tree_view = new Gtk.TreeView ();
            tree_view.set_size_request (Preferences.settings.get_int ("minimum-sidebar-width"), -1);
            tree_view.set_headers_visible (false);
            tree_view.show_expanders = false;

            var col = new Gtk.TreeViewColumn ();
            col.max_width = -1;
            col.expand = true;
            col.spacing = 3;

            var crt = new Gtk.CellRendererText (); /* Extra indent for start margin */
            crt.xpad = ROOT_INDENTATION_XPAD;
            crt.ypad = BOOKMARK_YPAD;
            col.pack_start (crt, false);

            crt = new Gtk.CellRendererText (); /* Extra indent for sub-category rows (bookmarks)*/
            crt.xpad = ICON_XPAD;
            crt.ypad = BOOKMARK_YPAD;
            col.pack_start (crt, false);
            col.set_attributes (crt, "visible", Column.NOT_CATEGORY);

            var crpb = new Gtk.CellRendererPixbuf (); /* Icon for bookmark or device */
            crpb.follow_state = true;
            crpb.stock_size = Gtk.IconSize.MENU;
            crpb.ypad = BOOKMARK_YPAD;
            col.pack_start (crpb, false);
            col.set_attributes (crpb,
                                "gicon", Column.ICON,
                                "visible", Column.NOT_CATEGORY);

            var crd = new Marlin.CellRendererDisk (); /* Renders category & bookmark text and diskspace graphic */
            name_renderer = crd as Gtk.CellRendererText;
            name_renderer.ellipsize = Pango.EllipsizeMode.END;
            name_renderer.ellipsize_set = true;
            name_renderer.edited.connect (edited);
            name_renderer.editing_canceled.connect (editing_canceled);

            col.pack_start (crd, true);
            col.set_attributes (crd,
                                "text", Column.NAME,
                                "free_space", Column.FREE_SPACE,
                                "disk_size", Column.DISK_SIZE,
                                "editable-set", Column.BOOKMARK);

            /* renderer function sets font weight and ypadding depending on whether bookmark or category */
            col.set_cell_data_func (name_renderer, category_renderer_func);

            var crsp = new Gtk.CellRendererSpinner (); /* Spinner shown while ejecting */
            crsp.ypad = BOOKMARK_YPAD;
            col.pack_end (crsp, false);
            col.set_attributes (crsp,
                                "visible", Column.SHOW_SPINNER,
                                "active", Column.SHOW_SPINNER,
                                "pulse", Column.SPINNER_PULSE);

            crpb = new Gtk.CellRendererPixbuf (); /* Icon for eject button (hidden while ejecting or unmounted) */
            this.eject_spinner_cell_renderer = crpb;
            crpb.follow_state = true;
            crpb.stock_size = Gtk.IconSize.MENU;
            crpb.gicon = new ThemedIcon.with_default_fallbacks ("media-eject-symbolic");
            crpb.xpad = ICON_XPAD;
            crpb.ypad = BOOKMARK_YPAD;

            col.pack_start (crpb, false);
            col.set_attributes (crpb, "visible", Column.SHOW_EJECT);

            var cre = new Granite.Widgets.CellRendererExpander (); /* Expander button for categories */
            expander_renderer = cre;
            cre.is_category_expander = true;
            cre.is_expander = true;
            cre.xpad = ICON_XPAD;
            cre.ypad = BOOKMARK_YPAD;

            col.pack_end (cre, false);
            col.set_attributes (cre, "visible", Column.IS_CATEGORY);

            tree_view.append_column (col);
            tree_view.tooltip_column = Column.TOOLTIP;
            tree_view.model = this.store;


        }

        private void configure_tree_view () {
            var style_context = tree_view.get_style_context ();
            style_context.add_class (Gtk.STYLE_CLASS_SIDEBAR);
            style_context.add_class (Granite.STYLE_CLASS_SOURCE_LIST);

            tree_view.set_search_column (Column.NAME);
            var selection = tree_view.get_selection ();
            selection.set_mode (Gtk.SelectionMode.BROWSE);

            this.drag_scroll_timer_id = 0;
            tree_view.enable_model_drag_source (Gdk.ModifierType.BUTTON1_MASK,
                                                source_targets,
                                                Gdk.DragAction.MOVE);
            Gtk.drag_dest_set (tree_view,
                               Gtk.DestDefaults.MOTION,
                               drop_targets,
                               Gdk.DragAction.MOVE | Gdk.DragAction.COPY | Gdk.DragAction.LINK);
        }

        private void connect_tree_view_signals () {
            tree_view.row_activated.connect (row_activated_callback);

            tree_view.drag_motion.connect (drag_motion_callback);
            tree_view.drag_leave.connect (drag_leave_callback);
            tree_view.drag_data_received.connect (drag_data_received_callback);
            tree_view.drag_drop.connect (drag_drop_callback);
            tree_view.drag_failed.connect (drag_failed_callback);
            tree_view.drag_end.connect (drag_end_callback);

            (tree_view.get_selection ()).changed.connect (selection_changed_cb);
            tree_view.popup_menu.connect (popup_menu_cb);
            tree_view.button_press_event.connect (button_press_event_cb);
            tree_view.button_release_event.connect (button_release_event_cb);
            tree_view.key_press_event.connect (key_press_event_cb);

            tree_view.row_expanded.connect (category_row_expanded_event_cb);
            tree_view.row_collapsed.connect (category_row_collapsed_event_cb);

            tree_view.add_events (Gdk.EventMask.FOCUS_CHANGE_MASK | Gdk.EventMask.ENTER_NOTIFY_MASK);
            tree_view.focus_in_event.connect (focus_in_event_cb);
            tree_view.leave_notify_event.connect (on_leave_notify_event);
        }

        private bool on_leave_notify_event () {
            if (renaming) {
                return true;
            }

            /* Signal Marlin.View.Window to synchronise sidebar with current tab */
            sync_needed ();
            return false;
        }

        private bool focus_in_event_cb (Gdk.EventFocus event) {
            /* Restore saved adjustment value to prevent unexpected scrolling */
            ((this as Gtk.ScrolledWindow).get_vadjustment ()).set_value (adjustment_val);
            return false;
        }

        private bool update_adjustment_val () {
            adjustment_val = ((this as Gtk.ScrolledWindow).get_vadjustment ()).value;
            return false;
        }

        private void set_up_trash_monitor () {
            monitor = Marlin.TrashMonitor.get ();
            monitor.trash_state_changed.connect (trash_state_changed_cb);
        }

        private void connect_volume_monitor_signals () {
            volume_monitor.volume_added.connect (volume_added_callback);
            volume_monitor.volume_removed.connect (volume_removed_callback);
            volume_monitor.volume_changed.connect (volume_changed_callback);

            volume_monitor.mount_added.connect (mount_added_callback);
            volume_monitor.mount_removed.connect (mount_removed_callback);
            volume_monitor.mount_changed.connect (mount_changed_callback);

            volume_monitor.drive_disconnected.connect (drive_disconnected_callback);
            volume_monitor.drive_changed.connect (drive_connected_callback);
            volume_monitor.drive_changed.connect (drive_changed_callback);
        }
        private void disconnect_volume_monitor_signals () {
            volume_monitor = GLib.VolumeMonitor.@get ();
            volume_monitor.volume_added.disconnect (volume_added_callback);
            volume_monitor.volume_removed.disconnect (volume_removed_callback);
            volume_monitor.volume_changed.disconnect (volume_changed_callback);

            volume_monitor.mount_added.disconnect (mount_added_callback);
            volume_monitor.mount_removed.disconnect (mount_removed_callback);
            volume_monitor.mount_changed.disconnect (mount_changed_callback);

            volume_monitor.drive_disconnected.disconnect (drive_disconnected_callback);
            volume_monitor.drive_changed.disconnect (drive_connected_callback);
            volume_monitor.drive_changed.disconnect (drive_changed_callback);
        }

        private void set_up_theme () {
            theme = Gtk.IconTheme.get_default ();
            theme.changed.connect (icon_theme_changed_callback);
            get_eject_icon ();
        }

        private void get_eject_icon () {
            if (eject_icon == null)
                eject_icon = new ThemedIcon.with_default_fallbacks ("media-eject-symbolic");
        }

        protected Gtk.TreeIter? add_category (Marlin.PlaceType place_type, string name, string tooltip) {
            return add_place (place_type, null,
                              name, null, null, null, null, null,
                              0, tooltip);
        }

        protected override Gtk.TreeIter add_place (Marlin.PlaceType place_type,
                                                   Gtk.TreeIter? parent,
                                                   string name,
                                                   Icon? icon,
                                                   string? uri,
                                                   Drive? drive,
                                                   Volume? volume,
                                                   Mount? mount,
                                                   uint index,
                                                   string? tooltip = null) {

            bool show_eject, show_unmount;
            check_unmount_and_eject (mount, volume, drive, out show_unmount, out show_eject);
            if (show_unmount || show_eject)
                    assert (place_type != Marlin.PlaceType.BOOKMARK);

            bool show_eject_button = false;
            if (mount != null)
                show_eject_button = (show_unmount || show_eject);

            GLib.Icon eject;
            if (show_eject_button)
                eject = this.eject_icon;
            else
                eject = null;

            GLib.Error error = null;
            string converted_name = name.locale_to_utf8 (name.length, null, null, out error);
            if (error != null) {
                warning ("Could not convert bookmark name. %s", error.message);
                converted_name = name;
            }

            bool is_category = (place_type == Marlin.PlaceType.BOOKMARKS_CATEGORY) ||
                               (place_type == Marlin.PlaceType.PERSONAL_CATEGORY) ||
                               (place_type == Marlin.PlaceType.STORAGE_CATEGORY) ||
                               (place_type == Marlin.PlaceType.NETWORK_CATEGORY);

            Gtk.TreeIter iter;
            this.store.append (out iter, parent);

            this.store.@set (iter,
                            Column.ROW_TYPE, place_type,
                            Column.URI, uri,
                            Column.DRIVE, drive,
                            Column.VOLUME, volume,
                            Column.MOUNT, mount,
                            Column.NAME, converted_name,
                            Column.ICON, icon,
                            Column.INDEX, index,
                            Column.CAN_EJECT, show_eject_button,
                            Column.NO_EJECT, !show_eject_button,
                            Column.BOOKMARK, place_type == Marlin.PlaceType.BOOKMARK,
                            Column.IS_CATEGORY, is_category,
                            Column.NOT_CATEGORY, !is_category,
                            Column.TOOLTIP, tooltip,
                            Column.EJECT_ICON, eject,
                            Column.SHOW_SPINNER, false,
                            Column.SHOW_EJECT, show_eject_button,
                            Column.SPINNER_PULSE, 0,
                            Column.FREE_SPACE, (uint64)0,
                            Column.DISK_SIZE, (uint64)0);

            return iter;
        }

        public bool has_bookmark (string uri) {
            bool found = false;

            store.@foreach ((model, path, iter) => {
                string u;
                bool is_bookmark;

                model.@get (iter, Column.URI, out u, Column.BOOKMARK, out is_bookmark);
                if (is_bookmark && u == uri) {
                    found = true;
                    return true;
                } else {
                    return false;
                }
            });

            return found;
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

        private void update_places () {
            Gtk.TreeIter iter, last_iter;
            string mount_uri;
            GLib.File root;

            if (update_cancellable != null) {
                update_cancellable.cancel ();
            }

            update_cancellable = new Cancellable ();

            this.last_selected_uri = null;
            this.n_builtins_before = 0;

            if ((tree_view.get_selection ()).get_selected (null, out iter))
                store.@get (iter, Column.URI, &last_selected_uri);
            else
                last_selected_uri = null;

            store.clear ();

            iter = add_category (Marlin.PlaceType.BOOKMARKS_CATEGORY,
                                 _("Personal"),
                                 _("Your common places and bookmarks"));

            /* Add Home BUILTIN */
            try {
                mount_uri = GLib.Filename.to_uri (Eel.get_real_user_home (), null);
            }
            catch (ConvertError e) {
                mount_uri = "";
            }

            add_place (Marlin.PlaceType.BUILT_IN,
                       iter,
                       _("Home"),
                       new ThemedIcon (Marlin.ICON_HOME),
                       mount_uri,
                       null,
                       null,
                       null,
                       0,
                       _("Open your personal folder"));

            n_builtins_before++;

            /*  Add Recents BUILTIN */
            if (recent_is_supported ()) {
                add_place (Marlin.PlaceType.BUILT_IN,
                    iter,
                    Marlin.PROTOCOL_NAME_RECENT,
                    new ThemedIcon (Marlin.ICON_RECENT),
                    Marlin.RECENT_URI,
                    null,
                    null,
                    null,
                    0,
                    _("View the list of recently used files"));

                n_builtins_before++;
            }

            /* Add bookmarks */
            uint bookmark_count = bookmarks.length ();
            unowned Bookmark bm;
            uint index;
            for (index = 0; index < bookmark_count; index++) {
                bm = bookmarks.item_at (index);
                if (bm == null ||
                    (bm.uri_known_not_to_exist () && !display_all_bookmarks) ||
                    (local_only && GLib.Uri.parse_scheme (bm.get_uri ()) != "file")) {

                    continue;
                }

                add_bookmark (iter, bm, index);
            }

            /* Do not show Trash if running as root (cannot be loaded) */
            if (!is_admin) {
                /* Add trash */
                add_place (Marlin.PlaceType.BUILT_IN,
                           iter,
                           _("Trash"),
                           Marlin.TrashMonitor.get_icon (),
                           Marlin.TRASH_URI,
                           null,
                           null,
                           null,
                           index + n_builtins_before,
                           _("Open the Trash"));
            }

            /* ADD STORAGE CATEGORY*/
            iter = add_category (Marlin.PlaceType.STORAGE_CATEGORY,
                                 _("Devices"),
                                 _("Your local partitions and devices"));


            /* Add Filesystem BUILTIN */
            last_iter = add_place (Marlin.PlaceType.BUILT_IN,
                                       iter,
                                       _("File System"),
                                       new ThemedIcon.with_default_fallbacks (Marlin.ICON_FILESYSTEM),
                                       Marlin.ROOT_FS_URI,
                                       null,
                                       null,
                                       null,
                                       0,
                                       null);

            add_device_tooltip.begin (last_iter, PF.FileUtils.get_file_for_path (Marlin.ROOT_FS_URI), update_cancellable);

            /* Add all connected drives */
            GLib.List<GLib.Drive> drives = volume_monitor.get_connected_drives ();
            GLib.List<GLib.Volume> volumes;
            foreach (GLib.Drive drive in drives) {
                volumes = drive.get_volumes ();
                if (volumes != null) {
                    add_volumes (iter, drive, volumes);
                } else if (drive.is_media_removable () &&
                           !drive.is_media_check_automatic ()) {

                    /* If the drive has no mountable volumes and we cannot detect media change.. we
                     * display the drive in the sidebar so the user can manually poll the drive by
                     * right clicking and selecting "Rescan..."
                     *
                     * This is mainly for drives like floppies where media detection doesn't
                     * work.. but it's also for human beings who like to turn off media detection
                     * in the OS to save battery juice.
                     */
                    var name = drive.get_name ();
                    add_place (Marlin.PlaceType.BUILT_IN,
                               iter,
                               name,
                               drive.get_icon (),
                               null,
                               drive,
                               null,
                               null,
                               0,
                               null);
                }
            }
            /* add all volumes that are not associated with a drive */
            volumes = volume_monitor.get_volumes ();
            foreach (Volume volume in volumes) {
                if (volume.get_drive () != null)
                    continue;

                var mount = volume.get_mount ();
                if (mount != null) {
                    root = mount.get_root ();
                    last_iter = add_place (Marlin.PlaceType.MOUNTED_VOLUME,
                                           iter,
                                           mount.get_name (),
                                           mount.get_icon (),
                                           root.get_uri (),
                                           null,
                                           volume,
                                           mount,
                                           0,
                                           null);

                    add_device_tooltip.begin (last_iter, root, update_cancellable);
                } else {
                /* see comment above in why we add an icon for an unmounted mountable volume */
                    var name = volume.get_name ();
                    add_place (Marlin.PlaceType.MOUNTED_VOLUME,
                               iter,
                               name,
                               volume.get_icon (),
                               null,
                               null,
                               volume,
                               null,
                               0,
                               name);
                }
            }
            /* Add mounts that have no volume (/etc/mtab mounts, ftp, sftp,...) */
            GLib.List<Mount> network_mounts = null;
            var mounts = volume_monitor.get_mounts ();
            foreach (Mount mount in mounts) {
                if (mount.is_shadowed ())
                    continue;

                var volume = mount.get_volume ();
                if (volume != null)
                    continue;

                root = mount.get_root ();
                if (root.is_native ()) {
                    string scheme = root.get_uri_scheme ();
                    if (scheme == "archive" ) {
                        network_mounts.prepend (mount);
                        continue;
                    }
                } else {
                    network_mounts.prepend (mount);
                    continue;
                }

                last_iter = add_place (Marlin.PlaceType.MOUNTED_VOLUME,
                                       iter,
                                       mount.get_name (),
                                       mount.get_icon (),
                                       root.get_uri (),
                                       null,
                                       null,
                                       mount,
                                       0,
                                       null);

                add_device_tooltip.begin (last_iter, root, update_cancellable);
            }

            if (!local_only) { /* Network operations fail when root */
                /* ADD NETWORK CATEGORY */
                iter = add_category (Marlin.PlaceType.NETWORK_CATEGORY,
                                     _("Network"),
                                     _("Your network places"));

                network_category_reference = new Gtk.TreeRowReference (store, store.get_path (iter));

                /* Add network mounts */
                network_mounts.reverse ();
                foreach (Mount mount in network_mounts) {
                    root = mount.get_default_location ();
                    /* get_smb_share_from_uri will return the uri unaltered if does not have
                     * the smb scheme so we need not test.  This is required because the mount
                     * does not return the true root location of the share but the location used
                     * when creating the mount.
                     */
                    string uri = PF.FileUtils.get_smb_share_from_uri (root.get_uri ());

                    last_iter = add_place (Marlin.PlaceType.BUILT_IN,
                                           iter,
                                           mount.get_name (),
                                           mount.get_icon (),
                                           uri,
                                           null,
                                           null,
                                           mount,
                                           0,
                                           null);

                    add_device_tooltip.begin (last_iter, root, update_cancellable);
                }

                /* Add Entire Network BUILTIN */
                add_place (Marlin.PlaceType.BUILT_IN,
                           iter,
                           _("Entire Network"),
                           new GLib.ThemedIcon (Marlin.ICON_NETWORK),
                           "network:///",
                           null,
                           null,
                           null,
                           0,
                           _("Browse the contents of the network"));

                plugins.update_sidebar ((Gtk.Widget)this); /* Add "Connect Server plugin */
            }

            expander_init_pref_state (tree_view);

            /* select any previously selected place or any place matching slot location */
            if (last_selected_uri != null)
                set_matching_selection (this.last_selected_uri);
            else
                set_matching_selection  (slot_location);
        }

        private void add_bookmark (Gtk.TreeIter iter, Marlin.Bookmark bm, uint index) {
            string parsename = PF.FileUtils.sanitize_path (bm.get_parse_name ());

            /* TreeView tooltips are set as markup so escape problematic characters */
            parsename = parsename.replace ("&", "&amp;").replace (">", "&gt;").replace ("<", "&lt;");

            add_place ( Marlin.PlaceType.BOOKMARK,
                        iter,
                        bm.label.dup (),
                        bm.get_icon (),
                        bm.get_uri (),
                        null,
                        null,
                        null,
                        index + n_builtins_before,
                        parsename);
        }

        private void add_volumes (Gtk.TreeIter iter,
                                  GLib.Drive drive,
                                  GLib.List<GLib.Volume> volumes) {
            Gtk.TreeIter last_iter;
            foreach (Volume volume in volumes) {
                var mount = volume.get_mount ();
                if (mount != null) {
                    /* show mounted volume in sidebar */
                    var root = mount.get_root ();
                    last_iter = add_place (Marlin.PlaceType.MOUNTED_VOLUME,
                                           iter,
                                           mount.get_name (),
                                           mount.get_icon (),
                                           root.get_uri (),
                                           drive,
                                           volume,
                                           mount,
                                           0,
                                           null);

                    add_device_tooltip.begin (last_iter, root, update_cancellable);
                } else {
                    /* Do show the unmounted volumes in the sidebar;
                    * this is so the user can mount it (in case automounting
                    * is off).
                    *
                    * Also, even if automounting is enabled, this gives a visual
                    * cue that the user should remember to yank out the media if
                    * he just unmounted it.
                    */
                    var name = volume.get_name ();
                    add_place (Marlin.PlaceType.MOUNTED_VOLUME,
                               iter,
                               name,
                               volume.get_icon (),
                               null,
                               drive,
                               volume,
                               null,
                               0,
                               null);
                }
            }
        }

        private async bool get_filesystem_space_and_type (GLib.File root, out uint64 fs_capacity,
                                                          out uint64 fs_free, out string type,
                                                          Cancellable update_cancellable) {
            fs_capacity = 0;
            fs_free = 0;
            type = "";

            string scheme = Uri.parse_scheme (root.get_uri ());
            if ("sftp davs".contains (scheme)) {
                return false; /* Cannot get info from these protocols */
            }
            if ("smb afp".contains (scheme)) {
                /* Check network is functional */
                var net_mon = GLib.NetworkMonitor.get_default ();
                if (!net_mon.get_network_available ()) {
                    return false;
                }
            }

            GLib.FileInfo info;
            try {
                info = yield root.query_filesystem_info_async ("filesystem::*", 0, update_cancellable);
            }
            catch (GLib.Error error) {
                if (!(error is IOError.CANCELLED)) {
                    warning ("Error querying %s filesystem info: %s", root.get_uri (), error.message);
                }
                info = null;
            }

            if (update_cancellable.is_cancelled () || info == null) {
                return false;
            } else {
                if (info.has_attribute (FileAttribute.FILESYSTEM_SIZE)) {
                    fs_capacity = info.get_attribute_uint64 (FileAttribute.FILESYSTEM_SIZE);
                }
                if (info.has_attribute (FileAttribute.FILESYSTEM_FREE)) {
                    fs_free = info.get_attribute_uint64 (FileAttribute.FILESYSTEM_FREE);
                }
                if (info.has_attribute (FileAttribute.FILESYSTEM_TYPE)) {
                    type = info.get_attribute_as_string (FileAttribute.FILESYSTEM_TYPE);
                }
                return true;
            }
        }

        private string get_tooltip_for_device (GLib.File location, uint64 fs_capacity,
                                               uint64 fs_free, string type) {
            var sb = new StringBuilder ("");
            sb.append (PF.FileUtils.sanitize_path (location.get_parse_name ()));
            if (type != null && type != "") {
                sb.append (" - ");
                sb.append (type);
            }
            if (fs_capacity > 0) {
                sb.append (" ");
                sb.append (_("(%s Free of %s)").printf (format_size (fs_free), format_size (fs_capacity)));
            }

            return sb.str.replace ("&", "&amp;").replace (">", "&gt;").replace ("<", "&lt;");
        }

        private async void add_device_tooltip (Gtk.TreeIter iter, GLib.File root, Cancellable update_cancellable) {

            uint64 fs_capacity, fs_free;
            string fs_type;
            var rowref = new Gtk.TreeRowReference (store, store.get_path (iter));

            if (yield get_filesystem_space_and_type (root, out fs_capacity, out fs_free, out fs_type, update_cancellable)) {
                var tooltip = get_tooltip_for_device (root, fs_capacity, fs_free, fs_type);
                if (rowref != null && rowref.valid ()) {
                    Gtk.TreeIter? itr = null;
                    store.get_iter (out itr, rowref.get_path ());
                    store.@set (itr,
                                Column.FREE_SPACE, fs_free,
                                Column.DISK_SIZE, fs_capacity,
                                Column.TOOLTIP, tooltip);
                } else {
                    warning ("Attempt to add tooltip for %s failed - invalid rowref", root.get_uri ());
                }
            }
        }

/* DRAG N DROP FUNCTIONS START */

        private bool drag_failed_callback (Gdk.DragContext context, Gtk.DragResult result) {
            int x, y;
            Gdk.Device device;

            if (internal_drag_started && dragged_out_of_window) {
                device = context.get_device ();
                device.get_position (null, out x, out y);

#if HAVE_UNITY

#if HAVE_PLANK_0_11
                Plank.PoofWindow poof_window;
                poof_window = Plank.PoofWindow.get_default ();
#else
                Plank.Widgets.PoofWindow? poof_window = null;
                poof_window = Plank.Widgets.PoofWindow.get_default ();
#endif
                poof_window.show_at (x, y);
#endif

                if (drag_row_ref != null) {
                    Gtk.TreeIter iter;
                    store.get_iter (out iter, drag_row_ref.get_path ());
                    remove_bookmark_iter (iter);
                }
                return true;
            } else
                return false;
        }

        private void drag_end_callback (Gdk.DragContext context) {
            internal_drag_started = false;
            dragged_out_of_window = false;
        }

        private bool drag_motion_callback (Gdk.DragContext context,
                                           int x,
                                           int y,
                                           uint time) {
            if (!received_drag_data
             && !get_drag_data (tree_view, context, time))
                    return false;

            Gtk.TreeViewDropPosition pos;
            Gtk.TreePath path;
            if (!compute_drop_position (tree_view, x, y, out path, out pos))
                return false;

            Gdk.DragAction action = Gdk.DragAction.DEFAULT;
            if (pos == Gtk.TreeViewDropPosition.BEFORE
             || pos == Gtk.TreeViewDropPosition.AFTER) {
                if (received_drag_data
                 && drag_data_info == TargetType.GTK_TREE_MODEL_ROW) {
                    action = Gdk.DragAction.MOVE;
                    internal_drag_started = true;
                }
                else if (drag_list != null
                      && can_accept_files_as_bookmarks (drag_list))
                    action = Gdk.DragAction.COPY;
            }
            else if (drag_list != null && path != null) {
                Gtk.TreeIter iter;
                store.get_iter (out iter, path);
                string uri;
                this.store.@get (iter, Column.URI, out uri);
                if (uri != null) {
                    GOF.File file = GOF.File.get_by_uri (uri);
                    if (file.ensure_query_info ()) {
                        PF.FileUtils.file_accepts_drop (file, drag_list, context, out action);
                    } else {
                        warning ("Could not ensure query info for %s when dropping onto sidebar", file.location.get_uri ());
                    }
                }
            }

            tree_view.set_drag_dest_row (path, pos);
            GLib.Signal.stop_emission_by_name (tree_view, "drag-motion");

            Gdk.drag_status (context, action, time);

            /* start the drag autoscroll timer if not already running */
            if (drag_scroll_timer_id < 1) {
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
            drop_occurred = true;
            bool retval = get_drag_data (tree_view, context, time);
            GLib.Signal.stop_emission_by_name (tree_view, "drag_drop");
            return retval;
        }

        private  bool get_drag_data (Gtk.TreeView tree_view,
                                     Gdk.DragContext context,
                                     uint32 time) {
            var target_list = Gtk.drag_dest_get_target_list (tree_view);
            var target = Gtk.drag_dest_find_target (tree_view,
                                                    context,
                                                    target_list);

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
            if (!received_drag_data) {
                this.drag_list = null;
                this.drag_row_ref = null;
                if (selection_data.get_target () != Gdk.Atom.NONE
                    && info == TargetType.TEXT_URI_LIST) {

                    string s = (string)(selection_data.get_data ());
                    drag_list = EelGFile.list_new_from_string (s);
                } else {
                    if (info == TargetType.GTK_TREE_MODEL_ROW) {
                        Gtk.TreePath path;
                        Gtk.tree_get_row_drag_data (selection_data, null, out path);
                        drag_row_ref = new Gtk.TreeRowReference (store, path);
                    }
                }
                received_drag_data = true;
                drag_data_info = info;
            }

            GLib.Signal.stop_emission_by_name (widget, "drag-data-received");

            if (!drop_occurred) /* called from drag_motion_callback */
                return;

            drop_occurred = false;
            bool success = process_drop (context, x, y, info);
            Gtk.drag_finish (context, success, false, time);
            free_drag_data ();
            update_places ();
        }

        private bool process_drop (Gdk.DragContext context, int x, int y, uint info) {
            Gtk.TreePath tree_path;
            Gtk.TreeViewDropPosition drop_pos;
            if (compute_drop_position (tree_view, x, y, out tree_path, out drop_pos)) {
                Gtk.TreeIter iter;
                if (!store.get_iter (out iter, tree_path)) {
                    warning ("Could not retrieve tree path after drop onto sidebar");
                    return false;
                }

                if (drop_pos == Gtk.TreeViewDropPosition.BEFORE
                 || drop_pos == Gtk.TreeViewDropPosition.AFTER)
                    return process_drop_between (iter, drop_pos, info);
                else
                    return process_drop_onto (iter, context, info);
            } else {
                warning ("compute drop position failed after drop onto sidebar");
            }
            return false;
        }

        private bool process_drop_between (Gtk.TreeIter iter,
                                           Gtk.TreeViewDropPosition drop_pos,
                                           uint info) {
            Marlin.PlaceType type;
            uint target_position;
            store.@get (iter,
                        Column.ROW_TYPE, out type,
                        Column.INDEX, out target_position);

            if (type == Marlin.PlaceType.BOOKMARK || type == Marlin.PlaceType.BUILT_IN) {
                switch (info) {
                    case TargetType.TEXT_URI_LIST:
                        drop_drag_list (target_position, drop_pos);
                        return true;
                    case TargetType.GTK_TREE_MODEL_ROW:
                        reorder_bookmarks (target_position, drop_pos);
                        return true;
                    default:
                        assert_not_reached ();
                }
            }
            return false;
        }

        private bool process_drop_onto (Gtk.TreeIter iter, Gdk.DragContext context, uint info) {
            string drop_uri;
            store.@get (iter, Column.URI, out drop_uri);

            var real_action = context.get_selected_action ();

            if (real_action == Gdk.DragAction.ASK) {
                var actions = context.get_actions ();

                if (drop_uri.has_prefix ("trash://")) {
                    actions &= Gdk.DragAction.MOVE;
                }

                real_action = dnd_handler.drag_drop_action_ask ((Gtk.Widget)tree_view, window, actions);
            }

            if (real_action == Gdk.DragAction.DEFAULT) {
                return false;
            }

            switch (info) {
                 case TargetType.TEXT_URI_LIST:
                    dnd_handler.dnd_perform (this, GOF.File.get_by_uri (drop_uri), drag_list, real_action);
                    return true;
                default: // Cannot drop row onto row
                    return false;;
            }
        }

        private void drag_leave_callback (Gdk.DragContext context, uint time) {
            dragged_out_of_window = true;
            free_drag_data ();
            tree_view.set_drag_dest_row (null, Gtk.TreeViewDropPosition.BEFORE);
            GLib.Signal.stop_emission_by_name (tree_view, "drag-leave");
        }

        private void free_drag_data () {
            received_drag_data = false;
            /* stop any running drag autoscroll timer */
            if (drag_scroll_timer_id > 0) {
                GLib.Source.remove (drag_scroll_timer_id);
                drag_scroll_timer_id = 0;
            }
        }

        private  bool can_accept_file_as_bookmark (GLib.File file) {
            return file.query_exists (null) && window.can_bookmark_uri (file.get_uri ());
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
            return count > 0 && count <= MAX_BOOKMARKS_DROPPED;
        }

        private void drop_drag_list (uint target_position, Gtk.TreeViewDropPosition drop_pos) {
            if (drag_list == null) {
                warning ("dropped a null drag list");
                return;
            }

            GLib.List<string> uris = null;
            drag_list.@foreach ((file) => {
                if (can_accept_file_as_bookmark (file))
                    uris.prepend (file.get_uri ());
            });

            if (uris != null) {
                if (target_position > n_builtins_before) {
                    target_position-= n_builtins_before;
                } else {
                    /* The target is a builtin. Always drop at start of bookmarks */
                    target_position = 0;
                    drop_pos = Gtk.TreeViewDropPosition.BEFORE; /* We have effectively moved target down */
                }
                uint position = (drop_pos == Gtk.TreeViewDropPosition.AFTER) ? ++target_position : target_position;
                bookmarks.insert_uris (uris, position);
            }
        }

        public void add_uri (string uri, string? label = null) {
            bookmarks.insert_uri_at_end (uri, label);
        }

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

        /* Computes the appropriate row and position for dropping */
        private bool compute_drop_position (Gtk.TreeView tree_view,
                                            int x,
                                            int y,
                                            out Gtk.TreePath path,
                                            out Gtk.TreeViewDropPosition drop_position
                                            ) {
            path = null;
            drop_position = 0;
            if (!tree_view.get_dest_row_at_pos (x, y, out path, out drop_position)) {
                return false;
            }

            if (path.get_depth () == 1) { /* On category name */
                return false;
            }

            int row = (path.get_indices ()) [0];
            Gtk.TreeIter? row_iter = null;
            store.get_iter_from_string (out row_iter, row.to_string ());
            int last_row = store.iter_n_children (row_iter) - 1;

            if (row > 0) {
                /* On a Device or Network bookmark - these can only be dropped into */
                drop_position = Gtk.TreeViewDropPosition.INTO_OR_BEFORE;
            } else if (row == last_row && drop_position == Gtk.TreeViewDropPosition.AFTER) {
                /* Cannot drop after "Trash" */
                return false;
            } else if (received_drag_data && drag_data_info == TargetType.GTK_TREE_MODEL_ROW) {
                /* bookmark rows are never dragged into other bookmark rows */
                if (drop_position == Gtk.TreeViewDropPosition.INTO_OR_BEFORE) {
                    drop_position = Gtk.TreeViewDropPosition.BEFORE;
                } else if (drop_position == Gtk.TreeViewDropPosition.INTO_OR_AFTER) {
                    drop_position = Gtk.TreeViewDropPosition.AFTER;
                }
            }

            return true;
        }

/* BOOKMARK/SHORTCUT FUNCTIONS */

        private void open_selected_bookmark (Gtk.TreeModel model,
                                             Gtk.TreePath path,
                                             Marlin.OpenFlag open_flag) {
            if (path == null)
                return;

            Gtk.TreeIter iter;
            if (!store.get_iter (out iter, path))
                return;

            string? uri = null;
            Marlin.PluginCallbackFunc? f = null;
            store.@get (iter, Column.URI, out uri, Column.PLUGIN_CALLBACK, out f);

            if (uri != null) {
                path_change_request (uri, open_flag);
            } else if (f != null) {
                f (this);
            } else if (!ejecting_or_unmounting) {
                Drive drive;
                Volume volume;

                var mount_op = new Gtk.MountOperation (window);
                store.@get (iter,
                            Column.DRIVE, out drive,
                            Column.VOLUME, out volume);

                if (volume != null && !mounting)
                    mount_volume (volume, mount_op, open_flag);

                else if (drive != null && volume == null
                        && (drive.can_start () || drive.can_start_degraded ()))
                    start_drive (drive, mount_op);
            }
        }

        private void mount_volume (Volume volume, Gtk.MountOperation mount_op, Marlin.OpenFlag flags) {
            mounting = true;
            volume.mount.begin (GLib.MountMountFlags.NONE,
                                mount_op,
                                null,
                                (obj, res) => {
                try {
                    mounting = false;
                    volume.mount.end (res);
                    Mount mount = volume.get_mount ();
                    if (mount != null) {
                        var location = mount.get_root ();
                        if (flags == Marlin.OpenFlag.NEW_WINDOW) {
                            var app = Marlin.Application.get ();
                            app.create_window (location);
                        } else if (flags == Marlin.OpenFlag.NEW_TAB) {
                            window.add_tab (location, Marlin.ViewMode.CURRENT);
                        } else {
                            window.uri_path_change_request (location.get_uri ());
                        }
                    }
                }
                catch (GLib.Error error) {
                    warning ("Error mounting volume %s: %s", volume.get_name (), error.message);
                }
            });
        }

        private void start_drive (Drive drive, Gtk.MountOperation mount_op) {
            drive.start.begin (DriveStartFlags.NONE,
                               mount_op,
                               null,
                               (obj, res) => {
                    try {
                        drive.start.end (res);
                    }
                    catch (GLib.Error error) {
                            var primary = _("Unable to start %s".printf (drive.get_name ()));
                            Eel.show_error_dialog (primary, error.message, null);
                    }
                }
            );
        }

        private void rename_selected_bookmark () {
            Gtk.TreeIter iter;
            if (!get_selected_iter ( out iter))
                return;

            if (!bookmark_at_iter (iter))
                 return;

            var path = store.get_path (iter);
            var column = tree_view.get_column (0);
            name_renderer.editable = true;
            renaming = true;

            /* Restore vertical scroll adjustment to stop tree_view scrolling to top on rename
             * For some reason, scroll to cell does not always work here
             */
            ((this as Gtk.ScrolledWindow).get_vadjustment ()).set_value (adjustment_val);

            tree_view.set_cursor_on_cell (path, column, name_renderer, true);
        }

        private void remove_selected_bookmarks () {
            Gtk.TreeIter iter;
            if (!get_selected_iter (out iter))
                return;

            remove_bookmark_iter (iter);
        }

        private void remove_bookmark_iter (Gtk.TreeIter? iter) {
            if (iter == null)
                return;

            if (!bookmark_at_iter (iter))
                 return;

            uint index;
            store.@get (iter, Column.INDEX, out index);
            index = index <= n_builtins_before ? 0 : index - n_builtins_before;
            bookmarks.delete_item_at (index);
        }

        /* Reorder the selected bookmark to the specified position */
        private void reorder_bookmarks (uint target_position, Gtk.TreeViewDropPosition drop_pos) {
            if (drag_row_ref != null) {
                Gtk.TreeIter iter;
                store.get_iter (out iter, drag_row_ref.get_path ());
                drag_row_ref = null;

                if (!bookmark_at_iter (iter))
                    return;

                uint old_position;
                store.@get (iter, Column.INDEX, out old_position);

                /* Positions are currently indices into the Sidebar TreeView.  We need to take account
                 * of builtin entries like "Home" to convert these positions into indices into the personal
                 * bookmarklist.
                 * As we are using uints, take care not to assign negative numbers */
                if (old_position > n_builtins_before) {
                    old_position-= n_builtins_before;
                } else {
                    old_position = 0;
                }

                if (target_position > n_builtins_before) {
                    target_position-= n_builtins_before;
                } else {
                    /* The target is a builtin. Always drop at start of bookmarks */
                    drop_pos = Gtk.TreeViewDropPosition.BEFORE;
                    target_position = 0;
                }
                /* If the row is dropped on the opposite side of the target than it starts from,
                 * then it replaces the target position. Otherwise it takes one more or less
                 * than the target position. */
                uint new_position = 0;
                if (old_position < target_position) {
                    new_position = (drop_pos == Gtk.TreeViewDropPosition.BEFORE) ? --target_position : target_position;
                } else if (old_position > target_position) {
                    new_position = (drop_pos == Gtk.TreeViewDropPosition.AFTER) ? ++target_position : target_position;
                } else {
                    warning ("Dropping before or after self - ignore");
                    return;
                }

                bookmarks.move_item (old_position, new_position); /* Bookmarklist will validate the positions. */
            }
        }

/* POPUP MENU FUNCTIONS */

        private void build_popup_menu () {
            if (popupmenu != null)
                return;

            popupmenu = new Gtk.Menu ();

            var item = new Gtk.ImageMenuItem.with_mnemonic (_("Open"));
            var image = new Gtk.Image.from_icon_name ("document-open", Gtk.IconSize.MENU);

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
            popupmenu_open_in_new_window_item = item;
            item.activate.connect (open_shortcut_in_new_window_cb);
            item.show ();
            popupmenu.append (item);

            popupmenu_separator_item1 = new Gtk.SeparatorMenuItem ();
            popupmenu.append (popupmenu_separator_item1);

            item = new Gtk.ImageMenuItem.with_label (_("Remove"));
            popupmenu_remove_item = item;
            image = new Gtk.Image.from_icon_name ("list-remove", Gtk.IconSize.MENU);
            item.set_image (image);
            item.activate.connect (remove_shortcut_cb);
            item.show ();
            popupmenu.append (item);

            item = new Gtk.ImageMenuItem.with_label (_("Rename"));
            popupmenu_rename_item = item;
            item.activate.connect (rename_shortcut_cb);
            item.show ();
            popupmenu.append (item);

            popupmenu_separator_item2 = new Gtk.SeparatorMenuItem ();
            popupmenu.append (popupmenu_separator_item2);

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

            /* Drive property menu item */
            item = new Gtk.ImageMenuItem.with_mnemonic (_("Properties"));
            popupmenu_drive_property_item = item;
            item.activate.connect (show_drive_info_cb);
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
                                     Marlin.DEFAULT_POPUP_MENU_DISPLACEMENT,
                                     Marlin.DEFAULT_POPUP_MENU_DISPLACEMENT,
                                     event);
        }

        /* Callback used for the GtkWidget::popup-menu signal of the shortcuts list */
        private bool popup_menu_cb (Gtk.Widget widget) {
            popup_menu (null);
            return true;
        }

/* TREEVIEW FUNCTIONS */

        private  bool get_selected_iter (out Gtk.TreeIter iter) {
            return (tree_view.get_selection ()).get_selected (null, out iter);
        }

        private void set_matching_selection (string? location) {
            /* set selection if any place matches location */
            /* first matching place is selected */
            /* Matching is done by comparing GLib.Files made from uris so that */
            /* different but equivalent uris are matched */

            var selection = tree_view.get_selection ();
            selection.unselect_all ();
            if (location == null)
                return;

            var file1 = GLib.File.new_for_path (location);

            Gtk.TreeIter iter;
            bool valid = store.get_iter_first (out iter);

            while (valid) {
                Gtk.TreeIter child_iter;
                bool child_valid = store.iter_children (out child_iter, iter);
                while (child_valid) {
                    string uri;
                    store.@get (child_iter, Column.URI, out uri);
                    if (uri == null)
                        break;

                    var file2 = GLib.File.new_for_path (uri);
                    if (file1.equal (file2)) {
                        selection.select_iter (child_iter);
                        tree_view.set_cursor (store.get_path (child_iter), null, false);
                        this.last_selected_uri = location;
                        valid = false; /* escape from outer loop */
                        break;
                    }
                    child_valid = store.iter_next (ref child_iter);
                }
                valid = valid && store.iter_next (ref iter);
            }
        }

        private void edited (Gtk.CellRendererText cell, string path_string, string new_text) {
            editing_canceled (cell);

            var path = new Gtk.TreePath.from_string (path_string);

            Gtk.TreeIter iter;
            store.get_iter (out iter, path);

            uint index;
            store.@get (iter, Column.INDEX, out index);
            index-= this.n_builtins_before;

            Marlin.Bookmark? bookmark = this.bookmarks.item_at (index);
            if (bookmark != null) {
                bookmark.label = new_text;
                update_places ();
            }
        }

        private void editing_canceled (Gtk.CellRenderer cell) {
            ((Gtk.CellRendererText)cell).editable = false;
            renaming = false;
        }

        private void expander_update_pref_state (Marlin.PlaceType type, bool flag) {
            /* Do not update settings if they have not changed.  Otherwise an infinite loop occurs
             * when viewing the ~/.config/dconf/user folder.
             */
            switch (type) {
                case Marlin.PlaceType.NETWORK_CATEGORY:
                    if (flag != Preferences.settings.get_boolean ("sidebar-cat-network-expander")) {
                        Preferences.settings.set_boolean ("sidebar-cat-network-expander", flag);
                    }
                    break;
                case Marlin.PlaceType.STORAGE_CATEGORY:
                    if (flag != Preferences.settings.get_boolean ("sidebar-cat-devices-expander")) {
                        Preferences.settings.set_boolean ("sidebar-cat-devices-expander", flag);
                    }
                    break;
                case Marlin.PlaceType.BOOKMARKS_CATEGORY:
                    if (flag != Preferences.settings.get_boolean ("sidebar-cat-personal-expander")) {
                        Preferences.settings.set_boolean ("sidebar-cat-personal-expander", flag);
                    }
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

        private void category_renderer_func (Gtk.CellLayout layout,
                                             Gtk.CellRenderer renderer,
                                             Gtk.TreeModel model,
                                             Gtk.TreeIter iter) {

            var crt = renderer as Gtk.CellRendererText;
            string text;
            bool is_category, show_eject_button;
            uint64 disk_size = 0;
            model.@get (iter, Column.NAME, out text,
                              Column.IS_CATEGORY, out is_category,
                              Column.DISK_SIZE, out disk_size,
                              Column.SHOW_EJECT, out show_eject_button, -1);

            if (is_category) {
                crt.markup = "<b>" + text + "</b>";
                crt.ypad = CATEGORY_YPAD;
            } else {
                crt.markup = text;
                crt.ypad = BOOKMARK_YPAD;
                if (disk_size > 0) {
                    /* Make disk space graphic same length whether or not eject button displayed */
                    var crd = renderer as Marlin.CellRendererDisk;
                    if (!show_eject_button) {
                        crd.rpad = eject_button_size + ICON_XPAD * 2;
                    } else {
                        crd.rpad = 0;
                    }
                }
            }
        }

        private void category_row_expanded_event_cb (Gtk.TreeView tree,
                                                     Gtk.TreeIter iter,
                                                     Gtk.TreePath path) {
            Marlin.PlaceType type;
            store.@get (iter, Column.ROW_TYPE, out type);
            expander_update_pref_state (type, true);
        }

        private void category_row_collapsed_event_cb (Gtk.TreeView tree,
                                                      Gtk.TreeIter iter,
                                                      Gtk.TreePath path) {
            Marlin.PlaceType type;
            store.@get (iter, Column.ROW_TYPE, out type);
            expander_update_pref_state (type, false);
        }

        /* Callback used when the selection in the shortcuts tree changes */
        private void selection_changed_cb () {
            check_popup_sensitivity ();
        }

        private void row_activated_callback (Gtk.TreePath path,
                                             Gtk.TreeViewColumn column) {
            open_selected_bookmark ((Gtk.TreeModel)store, path, 0);
        }

/* KEY, BUTTON AND SCROLL EVENT HANDLERS */

       /* Callback used when a button is pressed on the shortcuts list.
         * We trap button 3 to bring up a popup menu, and button 2 to
         * open in a new tab.
         */
        private bool key_press_event_cb (Gtk.Widget widget, Gdk.EventKey event) {
            Gdk.ModifierType modifiers = Gtk.accelerator_get_default_mod_mask ();
            if (event.keyval == Gdk.Key.Down
             && (event.state & modifiers) == Gdk.ModifierType.MOD1_MASK)
                return eject_or_unmount_selection ();

            if (event.keyval == Gdk.Key.F2 && (event.state & modifiers) == 0) {
                rename_selected_bookmark ();
                return true;
            }

            if (event.keyval == Gdk.Key.Right && (event.state & modifiers) == 0) {
                expand_collapse_category (true);
                return true;
            }
            if (event.keyval == Gdk.Key.Left && (event.state & modifiers) == 0) {
                expand_collapse_category (false);
                return true;
            }
            return false;
        }

        private void expand_collapse_category (bool expand) {
            Gtk.TreePath? path = get_path_at_cursor ();
            if (category_at_path (path)) {
                if (expand) {
                    tree_view.expand_row (path, false);
                } else {
                    tree_view.collapse_row (path);
                }
            }
        }

        private bool button_press_event_cb (Gtk.Widget widget, Gdk.EventButton event) {
            click_path = null;
            var tree_view = widget as Gtk.TreeView;
            if (event.window != tree_view.get_bin_window ())
                return true;

            if (renaming)
                return true;

            Gtk.TreePath? path = get_path_at_click_position (event);
            if (path == null)
                return false;

            this.click_path = path.copy ();

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
                    } else if (!bookmark_at_path (path))
                        block_drag_and_drop ();

                    break;

                case Gdk.BUTTON_SECONDARY:
                    if (path != null && !category_at_path (path))
                        popup_menu (event);

                    break;

                case Gdk.BUTTON_MIDDLE:
                    if (path != null && !category_at_path (path))
                        open_selected_bookmark (store, path, Marlin.OpenFlag.NEW_TAB);

                    break;
            }

            return false;
        }

        private bool button_release_event_cb (Gtk.Widget widget, Gdk.EventButton event) {
            Gtk.TreePath? path = get_path_at_click_position (event);
            /* Do not take action if a blocked drag was attempted (mouse over different row
             * from when button pressed or not over row), or if button press was on different widget */
            if (path == null || click_path == null || path.compare (click_path) != 0) {
                return true;
            }

            this.click_path = null;

            if (dnd_disabled) {
                unblock_drag_and_drop ();
            }

            if (renaming)
                return true;

            if (over_eject_button (event)) {
                eject_or_unmount_bookmark (path);
                return false;
            }

            if (event.button ==1) {
                if (event.window != tree_view.get_bin_window ())
                    return false;

                if (path != null) {
                    if ((event.state & Gdk.ModifierType.CONTROL_MASK) != 0)
                        open_selected_bookmark (store, path, Marlin.OpenFlag.NEW_TAB);
                    else
                        open_selected_bookmark (store, path, Marlin.OpenFlag.DEFAULT);
                }
            }

            return false;
        }

        public new void style_set (Gtk.Style previous_style) {
            update_places ();
        }

        public void reload () {
            /* The free space on devices may have changed */
            update_places ();
        }

/* MOUNT UNMOUNT AND EJECT FUNCTIONS */

         private void do_unmount (Mount? mount, Gtk.TreeRowReference? row_ref = null, bool can_eject = false) {
            /* Ignore signals generated by our own eject and unmount actins */
            disconnect_volume_monitor_signals ();

            if (mount == null) {
                finish_eject_or_unmount (row_ref, false);
                return;
            }
            /* Do not offer to empty trash every time - this can be done
             * from the context menu if needed */
            ejecting_or_unmounting = true;
            var volume = mount.get_volume ();

            GLib.MountOperation mount_op = new Gtk.MountOperation (window as Gtk.Window);
            mount.unmount_with_operation.begin (GLib.MountUnmountFlags.NONE,
                                                mount_op,
                                                null,
                                                (obj, res) => {
                bool success = false;
                try {
                    success = mount.unmount_with_operation.end (res);
                    if (success && can_eject) {
                        /* Eject associated volume after unmount if appropriate.
                         * Keep volume monitor disconnected */
                        do_eject (null, volume, null, row_ref);
                    } else {
                        finish_eject_or_unmount (row_ref, success);
                    }
                }
                catch (GLib.Error error) {
                    debug ("Error while unmounting");
                    finish_eject_or_unmount (row_ref, false);
                }
            });
         }

        private void empty_trash_on_mount (Mount? mount, Gtk.TreeRowReference? row_ref = null) {
            Marlin.FileOperations.empty_trash_for_mount (this, mount);
        }

        private bool over_eject_button (Gdk.EventButton event) {
            unowned Gtk.TreeViewColumn column;
            int width, x_offset, hseparator;
            bool show_eject;
            Gtk.TreeIter iter;
            Gtk.TreePath path;

            int x, y;
            tree_view.convert_bin_window_to_tree_coords ((int)event.x, (int)event.y, out x, out y);

            int cell_x, cell_y;
            if (tree_view.get_path_at_pos (x, y, out path, out column, out cell_x, out cell_y)) {
                if (path == null)
                    return false;

                store.get_iter (out iter, path);
                store.@get (iter, Column.CAN_EJECT, out show_eject);

                if (!show_eject || ejecting_or_unmounting)
                    return false;

                tree_view.style_get ("horizontal-separator", out hseparator, null);
                /* reload the cell attributes for this particular row */
                column.cell_set_cell_data (store, iter, false, false);
                column.cell_get_position (eject_spinner_cell_renderer, out x_offset, out width);

                x_offset += width - hseparator - eject_button_size;
                if (cell_x - x_offset >= 0 && cell_x - x_offset <= eject_button_size)
                    return true;
            }

            return false;
        }

        private void do_eject (GLib.Mount? mount, GLib.Volume? volume, GLib.Drive? drive, Gtk.TreeRowReference? row_ref = null) {
            /* Ignore signals generated by our own eject and unmount actins */
            disconnect_volume_monitor_signals ();

            GLib.MountOperation mount_op = new GLib.MountOperation ();
            if (drive != null) {
                ejecting_or_unmounting = true;
                drive.eject_with_operation.begin (GLib.MountUnmountFlags.NONE,
                                                  mount_op,
                                                  null,
                                                  (obj, res) => {
                    bool success = false;
                    try {
                        success = drive.eject_with_operation.end (res);
                    }
                    catch (GLib.Error error) {
                        warning ("Error ejecting drive: %s", error.message);
                    }
                    finish_eject_or_unmount (row_ref, success);
                });
                return;
            }

            if (volume != null) {
                ejecting_or_unmounting = true;
                volume.eject_with_operation.begin (GLib.MountUnmountFlags.NONE,
                                                   mount_op,
                                                   null,
                                                   (obj, res) => {
                    bool success = false;
                    try {
                        success = volume.eject_with_operation.end (res);
                    }
                    catch (GLib.Error error) {
                        warning ("Error ejecting volume: %s", error.message);
                    }
                    finish_eject_or_unmount (row_ref, success);
                });
                return;
            }

            if (mount != null) {
                ejecting_or_unmounting = true;
                mount.eject_with_operation.begin (GLib.MountUnmountFlags.NONE,
                                                  mount_op,
                                                  null,
                                                  (obj, res) => {
                    bool success = false;
                    try {
                        success = mount.eject_with_operation.end (res);
                    }
                    catch (GLib.Error error) {
                        warning ("Error ejecting mount: %s", error.message);
                    }
                    finish_eject_or_unmount (row_ref, success);
                });
                return;
            }
            finish_eject_or_unmount (row_ref, false);
        }

        private void finish_eject_or_unmount (Gtk.TreeRowReference? row_ref, bool success) {
            ejecting_or_unmounting = false;
            if (row_ref != null && row_ref.valid ()) {
                Gtk.TreeIter iter;
                if (store.get_iter (out iter, row_ref.get_path ())) {
                    store.@set (iter, Column.SHOW_SPINNER, false);
                    store.@set (iter, Column.SHOW_EJECT, !success); /* continue to show eject if did not succeed */
                }
            }
            /* Delay reconnecting volume monitor - we do not need to respond to signals consequent on
             * our own actions that may still be in the pipeline */
            Timeout.add (300, () => {
                connect_volume_monitor_signals ();
                update_places ();
                return false;
            });
        }

        private bool eject_or_unmount_bookmark (Gtk.TreePath? path, bool allow_eject = true) {
            if (path == null || ejecting_or_unmounting) {
                return false;
            }

            Gtk.TreeIter iter;
            if (!store.get_iter (out iter, path)) {
                return false;
            }

            Mount mount;
            Volume volume;
            Drive drive;
            bool spinner_active;
            store.@get (iter,
                        Column.MOUNT, out mount,
                        Column.VOLUME, out volume,
                        Column.DRIVE, out drive,
                        Column.SHOW_SPINNER, out spinner_active);

            /* Return if already ejecting */
            if (spinner_active) {
                return true;
            }

            bool can_unmount, can_eject;
            check_unmount_and_eject (mount, volume, drive, out can_unmount, out can_eject);

            if (!(can_eject || can_unmount)) {
                return false;
            }

            var rowref = new Gtk.TreeRowReference (store, path);
            store.@set (iter, Column.SHOW_SPINNER, true);
            store.@set (iter, Column.SHOW_EJECT, false);
            Timeout.add (100, ()=>{
                uint val;

                if (!rowref.valid ())
                    return false;

                store.@get (iter, Column.SHOW_SPINNER, out spinner_active);
                if (!spinner_active)
                    return false;

                store.@get (iter, Column.SPINNER_PULSE, out val);
                store.@set (iter, Column.SPINNER_PULSE, ++val);
                return true;
            });

            if (can_unmount) {
                do_unmount (mount, rowref, can_eject && allow_eject);
                /* Drive changed callback will eject the drive if appropriate */
            } else if (can_eject) {
                do_eject (mount, volume, drive, rowref);
            }
            return true;
        }

        private bool eject_or_unmount_selection () {
            Gtk.TreeIter iter;
            if (!get_selected_iter (out iter))
                return false;
            else
                return eject_or_unmount_bookmark (store.get_path (iter));
        }

/* POPUP MENU CALLBACK FUNCTIONS */

        private void open_shortcut_from_menu (Marlin.OpenFlag flags) {
            Gtk.TreePath path;
            tree_view.get_cursor (out path, null);
            open_selected_bookmark (store, path, flags);
        }

        private void open_shortcut_cb (Gtk.MenuItem item) {
            open_shortcut_from_menu (Marlin.OpenFlag.DEFAULT);
        }

        private void open_shortcut_in_new_window_cb (Gtk.MenuItem item) {
            open_shortcut_from_menu (Marlin.OpenFlag.NEW_WINDOW);
        }

        private void open_shortcut_in_new_tab_cb (Gtk.MenuItem item) {
            open_shortcut_from_menu (Marlin.OpenFlag.NEW_TAB);
        }

        private void mount_shortcut_cb (Gtk.MenuItem item) {
            Gtk.TreeIter iter;
            if (!get_selected_iter (out iter))
                return;

            Volume volume;
            store.@get (iter, Column.VOLUME, out volume);
            if (volume != null)
                Marlin.FileOperations.mount_volume (null, volume, false);
         }

        private void remove_shortcut_cb (Gtk.MenuItem item) {
            remove_selected_bookmarks ();
        }

        private void rename_shortcut_cb (Gtk.MenuItem item) {
            rename_selected_bookmark ();
        }

        private void show_drive_info_cb (Gtk.MenuItem item) {
            Gtk.TreeIter iter;

            if (!get_selected_iter (out iter))
                return;

            Mount mount;
            Volume volume;
            string uri;
            store.@get (iter,
                        Column.VOLUME, out volume,
                        Column.MOUNT, out mount,
                        Column.URI, out uri);

            if (mount == null && volume != null) {
                /* Mount the device if possible, defer showing the dialog after
                 * we're done */
                Marlin.FileOperations.mount_volume_full (null, volume, false, (vol, win) => {
                    new Marlin.View.VolumePropertiesWindow (vol.get_mount (), (Gtk.Window) win);
                }, window);
            } else {
                if (mount != null || uri == "file:///") {
                    new Marlin.View.VolumePropertiesWindow (mount, window);
                }
            }
        }

        private void eject_or_unmount_shortcut_cb (bool allow_eject = true) {
            Gtk.TreeIter iter;
            if (!get_selected_iter (out iter))
                return;
            else
                eject_or_unmount_bookmark (store.get_path (iter), allow_eject);
        }

        private void unmount_shortcut_cb () {
            /* If unmount rather than eject was chosen from menu, do not eject after unmount */
            eject_or_unmount_shortcut_cb (false);
        }

        private void eject_shortcut_cb () {
            eject_or_unmount_shortcut_cb (true);
        }

        private void empty_trash_cb (Gtk.MenuItem item) {
            Gtk.TreeIter iter;
            if (!get_selected_iter (out iter))
                return;

            Mount mount;
            string uri;
            store.@get (iter,
                        Column.URI, out uri,
                        Column.MOUNT, out mount);

            if (mount != null)
                /* A particular mount was clicked - empty only the trash on the mount */
                empty_trash_on_mount (mount);
            else
                /* Trash icon was clicked - empty all trash directories, including any mounted. */
                Marlin.FileOperations.empty_trash (window);
        }

/* VOLUME MONITOR CALLBACK FUNCTIONS */

        private void mount_added_callback (Mount mount) {
            update_places ();
        }
        private void mount_removed_callback (Mount mount) {
            update_places ();
        }
        private void mount_changed_callback (Mount mount) {
            update_places ();
        }

        private void volume_added_callback (Volume volume) {
            update_places ();
        }

        private void volume_removed_callback (Volume volume) {
            update_places ();
        }

        private void volume_changed_callback (Volume volume) {
            update_places ();
        }

        private void drive_connected_callback (VolumeMonitor volume_monitor, Drive drive) {
            update_places ();
        }

        private void drive_disconnected_callback (VolumeMonitor volume_monitor, Drive drive) {
            update_places ();
        }

        private void drive_changed_callback (VolumeMonitor volume_monitor, Drive drive) {
            if (ejecting_or_unmounting)
                return;

            if (!drive.is_media_check_automatic ()) {
                drive.poll_for_media.begin (null, (obj, res) => {
                    try {
                        if (drive.poll_for_media.end (res))
                            eject_drive_if_no_media (drive);
                    }
                    catch (GLib.Error e) {
                        warning ("Could not poll for media");
                    }
                });
            } else
                 eject_drive_if_no_media (drive);
        }

        private void eject_drive_if_no_media (Drive drive) {
            /* Additional checks required because some devices give incorrect results e.g. some MP3 players
             * resulting in them being ejected as soon as plugged in */
            if (drive.is_media_removable () && drive.can_poll_for_media () && !drive.has_media () && drive.can_eject ()) {
                do_eject (null, null, drive, null);
            }
        }

/* MISCELLANEOUS CALLBACK FUNCTIONS */

        private void icon_theme_changed_callback (Gtk.IconTheme icon_theme) {
            get_eject_icon ();
            update_places ();
        }

        private void loading_uri_callback (string location) {
            set_matching_selection (location);
            slot_location = location;

        }

        private void trash_state_changed_cb (Marlin.TrashMonitor trash_monitor, bool state) {
            update_places ();
            check_popup_sensitivity ();
        }

/* CHECK FUNCTIONS */
        private void check_unmount_and_eject (Mount? mount,
                                              Volume? volume,
                                              Drive? drive,
                                              out bool show_unmount,
                                              out bool show_eject) {
            show_unmount = false;
            show_eject = false;

            if (mount != null) {
                show_unmount = mount.can_unmount ();
            }

            if (drive != null) {
                show_eject = drive.can_eject ();
            }

            if (volume != null) {
                show_eject = show_eject || volume.can_eject ();
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

                /* Show_stop option is not currently used. Moreover, this can give an incorrect
                 * indication (e.g. for NTFS partitions) */
#if 0
                if (show_stop) {
                    show_unmount = false;
                }
#endif
            }

            if (volume != null && mount == null) {
                show_mount = volume.can_mount ();
            }

            if (show_eject && show_unmount) {
                show_eject = false;
            }
        }

        private void check_popup_sensitivity () {
            if (popupmenu == null)
                return;

            Gtk.TreeIter iter;
            if (!get_selected_iter (out iter))
                return;

            Marlin.PlaceType type;
            Drive drive;
            Volume volume;
            Mount mount;
            string uri;
            bool is_bookmark;
            store.@get (iter,
                        Column.ROW_TYPE, out type,
                        Column.DRIVE, out drive,
                        Column.VOLUME, out volume,
                        Column.MOUNT, out mount,
                        Column.URI, out uri,
                        Column.BOOKMARK, out is_bookmark);

            popupmenu_remove_item.visible = is_bookmark;
            popupmenu_rename_item.visible = is_bookmark;
            popupmenu_separator_item1.visible = is_bookmark;

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

            /* Context menu shows Empty Trash for the Trash icon and for any mount with a native
             * file system whose trash contains files */
            bool show_empty_trash = (uri != null) &&
                                    ((uri == Marlin.TRASH_URI) ||
                                    Marlin.FileOperations.has_trash_files (mount));

            popupmenu_separator_item2.visible = (show_eject || show_unmount ||
                                                show_mount || show_empty_trash);

            bool show_property = show_mount || show_unmount || show_eject || uri == "file:///";

            popupmenu_mount_item.visible = show_mount;
            popupmenu_unmount_item.visible = show_unmount;
            popupmenu_eject_item.visible = show_eject;
            popupmenu_empty_trash_item.visible = show_empty_trash;
            popupmenu_drive_property_item.visible = show_property;

            popupmenu_empty_trash_item.sensitive = !Marlin.TrashMonitor.is_empty ();

            bool is_plugin = (type == Marlin.PlaceType.PLUGIN_ITEM);
            popupmenu_open_in_new_tab_item.visible = !is_plugin;
            popupmenu_open_in_new_window_item.visible = !is_plugin;
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

        private bool bookmark_at_path (Gtk.TreePath? path) {
            if (path != null) {
                Gtk.TreeIter iter;
                store.get_iter (out iter, path);
                return bookmark_at_iter (iter);
            } else
                return false;
        }

        private bool bookmark_at_iter (Gtk.TreeIter? iter) {
            if (iter == null)
                return false;

            bool is_bookmark;
            store.@get (iter, Column.BOOKMARK, out is_bookmark, -1);
            return is_bookmark;
        }

        private Gtk.TreePath? get_path_at_click_position (Gdk.EventButton event) {
            int tx, ty;
            tree_view.convert_bin_window_to_tree_coords ((int)event.x, (int)event.y, out tx, out ty);
            Gtk.TreePath? path = null;
            tree_view.get_path_at_pos (tx, ty, out path, null, null, null);
            return path;
        }
        private Gtk.TreePath? get_path_at_cursor () {
            Gtk.TreePath? path = null;
            Gtk.TreeViewColumn? focus_column = null;
            tree_view.get_cursor (out path, out focus_column);
            return path;
        }

        protected void block_drag_and_drop () {
            tree_view.unset_rows_drag_source ();
            dnd_disabled = true;
        }

        protected void unblock_drag_and_drop () {
            tree_view.enable_model_drag_source (Gdk.ModifierType.BUTTON1_MASK,
                                                source_targets,
                                                Gdk.DragAction.MOVE);
            dnd_disabled = false;
        }

    }
}
