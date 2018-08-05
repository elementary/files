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

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

/* Implementations of AbstractDirectoryView are
     * IconView
     * ListView
     * ColumnView
*/

namespace FM {
    public abstract class AbstractDirectoryView : Gtk.ScrolledWindow {

        protected enum ClickZone {
            EXPANDER,
            HELPER,
            ICON,
            NAME,
            BLANK_PATH,
            BLANK_NO_PATH,
            INVALID
        }

        const int MAX_TEMPLATES = 32;

        const Gtk.TargetEntry [] drag_targets = {
            {"text/plain", Gtk.TargetFlags.SAME_APP, Marlin.TargetType.STRING},
            {"text/uri-list", Gtk.TargetFlags.SAME_APP, Marlin.TargetType.TEXT_URI_LIST}
        };

        const Gtk.TargetEntry [] drop_targets = {
            {"text/uri-list", Gtk.TargetFlags.SAME_APP, Marlin.TargetType.TEXT_URI_LIST},
            {"text/uri-list", Gtk.TargetFlags.OTHER_APP, Marlin.TargetType.TEXT_URI_LIST},
            {"XdndDirectSave0", Gtk.TargetFlags.OTHER_APP, Marlin.TargetType.XDND_DIRECT_SAVE0},
            {"_NETSCAPE_URL", Gtk.TargetFlags.OTHER_APP, Marlin.TargetType.NETSCAPE_URL}
        };

        const Gdk.DragAction file_drag_actions = (Gdk.DragAction.COPY | Gdk.DragAction.MOVE | Gdk.DragAction.LINK);

        /* Menu Handling */
        const GLib.ActionEntry [] selection_entries = {
            {"open", on_selection_action_open_executable},
            {"open_with_app", on_selection_action_open_with_app, "s"},
            {"open_with_default", on_selection_action_open_with_default},
            {"open_with_other_app", on_selection_action_open_with_other_app},
            {"rename", on_selection_action_rename},
            {"view_in_location", on_selection_action_view_in_location},
            {"forget", on_selection_action_forget},
            {"cut", on_selection_action_cut},
            {"trash", on_selection_action_trash},
            {"delete", on_selection_action_delete},
            {"restore", on_selection_action_restore}
        };

        const GLib.ActionEntry [] background_entries = {
            {"new", on_background_action_new, "s"},
            {"create_from", on_background_action_create_from, "s"},
            {"sort_by", on_background_action_sort_by_changed, "s", "'name'"},
            {"reverse", on_background_action_reverse_changed, null, "false"},
            {"folders_first", on_background_action_folders_first_changed, null, "true"},
            {"show_hidden", null, null, "false", change_state_show_hidden},
            {"show_remote_thumbnails", null, null, "false", change_state_show_remote_thumbnails}
        };

        const GLib.ActionEntry [] common_entries = {
            {"copy", on_common_action_copy},
            {"paste_into", on_common_action_paste_into},
            {"open_in", on_common_action_open_in, "s"},
            {"bookmark", on_common_action_bookmark},
            {"properties", on_common_action_properties},
            {"copy_link", on_common_action_copy_link}
        };

        GLib.SimpleActionGroup common_actions;
        GLib.SimpleActionGroup selection_actions;
        GLib.SimpleActionGroup background_actions;

        private Marlin.ZoomLevel _zoom_level = Marlin.ZoomLevel.NORMAL;
        public Marlin.ZoomLevel zoom_level {
            get {
                return _zoom_level;
            }

            set {
                if (value > maximum_zoom) {
                    _zoom_level = maximum_zoom;
                } else if (value < minimum_zoom) {
                    _zoom_level = minimum_zoom;
                } else {
                    _zoom_level = value;
                }

                on_zoom_level_changed (value);
            }
        }

        public int icon_size {
            get {
                return Marlin.zoom_level_to_icon_size (_zoom_level);
            }
        }

        protected Marlin.ZoomLevel minimum_zoom = Marlin.ZoomLevel.SMALLEST;
        protected Marlin.ZoomLevel maximum_zoom = Marlin.ZoomLevel.LARGEST;
        protected bool large_thumbnails = false;

        /* drag support */
        uint drag_scroll_timer_id = 0;
        uint drag_timer_id = 0;
        uint drag_enter_timer_id = 0;
        int drag_x = 0;
        int drag_y = 0;
        int drag_button;
        protected int drag_delay = 300;
        protected int drag_enter_delay = 1000;

        Gdk.DragAction current_suggested_action = Gdk.DragAction.DEFAULT;
        Gdk.DragAction current_actions = Gdk.DragAction.DEFAULT;

        unowned GLib.List<GOF.File> drag_file_list = null;
        GOF.File? drop_target_file = null;
        Gdk.Atom current_target_type = Gdk.Atom.NONE;

        /* drop site support */
        bool _drop_highlight;
        bool drop_highlight {
            get {
                return _drop_highlight;
            }

            set {
                if (value != _drop_highlight) {
                    if (value) {
                        Gtk.drag_highlight (this);
                    } else {
                        Gtk.drag_unhighlight (this);
                    }
                }

                _drop_highlight = value;
            }
        }

        private bool drop_data_ready = false; /* whether the drop data was received already */
        private bool drop_occurred = false; /* whether the data was dropped */
        private bool drag_has_begun = false;
        protected bool dnd_disabled = false;
        private void* drag_data;
        private GLib.List<GLib.File> drop_file_list = null; /* the list of URIs that are contained in the drop data */

        /* support for generating thumbnails */
        int thumbnail_request = -1;
        uint thumbnail_source_id = 0;
        uint freeze_source_id = 0;
        Marlin.Thumbnailer thumbnailer = null;

        /* Free space signal support */
        uint add_remove_file_timeout_id = 0;
        bool signal_free_space_change = false;

        /* Rename support */
        protected Marlin.TextRenderer? name_renderer = null;
        public string original_name = "";
        public string proposed_name = "";

        /* Support for zoom by smooth scrolling */
        private double total_delta_y = 0.0;

        /* Support for keeping cursor position after delete */
        private Gtk.TreePath deleted_path;

        /* UI options for button press handling */
        protected bool activate_on_blank = true;
        protected bool right_margin_unselects_all = false;
        public bool single_click_mode { get; set; }
        protected bool should_activate = false;
        protected bool should_scroll = true;
        protected bool should_deselect = false;
        protected Gtk.TreePath? click_path = null;
        protected uint click_zone = ClickZone.ICON;
        protected uint previous_click_zone = ClickZone.ICON;

        /* Cursors for different areas */
        private Gdk.Cursor editable_cursor;
        private Gdk.Cursor activatable_cursor;
        private Gdk.Cursor selectable_cursor;

        private GLib.List<GLib.AppInfo> open_with_apps;

        /*  Selected files are originally obtained with
            gtk_tree_model_get(): this function increases the reference
            count of the file object.*/
        protected GLib.List<unowned GOF.File> selected_files = null;
        private bool selected_files_invalid = true;

        private GLib.List<GLib.File> templates = null;

        private GLib.AppInfo default_app;
        private Gtk.TreePath? hover_path = null;

        /* Rapid keyboard paste support */
        protected bool select_added_files = false;

        public bool renaming {get; protected set; default = false;}

        private bool _is_frozen = false;
        public bool is_frozen {
            set {
                if (value && !_is_frozen) {
                    action_set_enabled (selection_actions, "cut", false);
                    action_set_enabled (common_actions, "copy", false);
                    action_set_enabled (common_actions, "paste_into", false);

                    /* Fix problems when navigating away from directory with large number
                     * of selected files (e.g. OverlayBar critical errors)
                     */
                    disconnect_tree_signals ();
                    size_allocate.disconnect (on_size_allocate);
                    clipboard.changed.disconnect (on_clipboard_changed);
                    view.key_press_event.disconnect (on_view_key_press_event);
                } else if (!value && _is_frozen) {
                    /* Ensure selected files and menu actions will be updated */
                    connect_tree_signals ();
                    on_view_selection_changed ();

                    size_allocate.connect (on_size_allocate);
                    clipboard.changed.connect (on_clipboard_changed);
                    view.key_press_event.connect (on_view_key_press_event);
                }

                _is_frozen = value;
            }

            get {
                return _is_frozen;
            }
        }

        protected bool tree_frozen = false;
        private bool in_trash = false;
        private bool in_recent = false;
        private bool in_network_root = false;
        protected bool is_writable = false;
        protected bool is_loading;
        protected bool helpers_shown;
        protected bool show_remote_thumbnails {get; set; default = false;}
        protected bool is_admin {
            get {
                return (uint)Posix.getuid () == 0;
            }
        }

        private bool all_selected = false;

        private Gtk.Widget view;
        private unowned Marlin.ClipboardManager clipboard;
        protected FM.ListModel model;
        protected Marlin.IconRenderer icon_renderer;
        protected unowned Marlin.View.Slot slot;
        protected unowned Marlin.View.Window window; /*For convenience - this can be derived from slot */
        protected static Marlin.DndHandler dnd_handler = new Marlin.DndHandler ();

        protected unowned Gtk.RecentManager recent;

        public signal void path_change_request (GLib.File location, Marlin.OpenFlag flag, bool new_root);
        public signal void item_hovered (GOF.File? file);
        public signal void selection_changed (GLib.List<unowned GOF.File> gof_file);

        public AbstractDirectoryView (Marlin.View.Slot _slot) {
            slot = _slot;
            window = _slot.window;
            editable_cursor = new Gdk.Cursor.from_name (Gdk.Display.get_default (), "text");
            activatable_cursor = new Gdk.Cursor.from_name (Gdk.Display.get_default (), "pointer");
            selectable_cursor = new Gdk.Cursor.from_name (Gdk.Display.get_default (), "default");

            var app = (Marlin.Application)(GLib.Application.get_default ());
            clipboard = app.get_clipboard_manager ();
            recent = app.get_recent_manager ();

            icon_renderer = new Marlin.IconRenderer ();
            thumbnailer = Marlin.Thumbnailer.get ();
            thumbnailer.finished.connect ((req) => {
                if (req == thumbnail_request) {
                    thumbnail_request = -1;
                }

                draw_when_idle ();
            });
            model = GLib.Object.@new (FM.ListModel.get_type (), null) as FM.ListModel;
            Preferences.settings.bind ("single-click", this, "single_click_mode", SettingsBindFlags.GET);
            Preferences.settings.bind ("show-remote-thumbnails", this, "show_remote_thumbnails", SettingsBindFlags.GET);

             /* Currently, "single-click rename" is disabled, matching existing UI
              * Currently, "activate on blank" is enabled, matching existing UI
              * Currently, "right margin unselects all" is disabled, matching existing UI
              */

            set_up__menu_actions ();
            set_up_directory_view ();
            view = create_view ();

            if (view != null) {
                add (view);
                show_all ();
                connect_drag_drop_signals (view);
                view.add_events (Gdk.EventMask.POINTER_MOTION_MASK |
                                 Gdk.EventMask.ENTER_NOTIFY_MASK |
                                 Gdk.EventMask.LEAVE_NOTIFY_MASK);

                view.motion_notify_event.connect (on_motion_notify_event);
                view.leave_notify_event.connect (on_leave_notify_event);
                view.key_press_event.connect (on_view_key_press_event);
                view.button_press_event.connect (on_view_button_press_event);
                view.button_release_event.connect (on_view_button_release_event);
                view.draw.connect (on_view_draw);
            }

            freeze_tree (); /* speed up loading of icon view. Thawed when directory loaded */
            set_up_zoom_level ();

            connect_directory_handlers (slot.directory);
        }

        ~AbstractDirectoryView () {
            debug ("ADV destruct");
        }

        public bool is_in_recent () {
            return in_recent;
        }

        protected virtual void set_up_name_renderer () {
            name_renderer.editable = false;
            name_renderer.edited.connect (on_name_edited);
            name_renderer.editing_canceled.connect (on_name_editing_canceled);
            name_renderer.editing_started.connect (on_name_editing_started);
        }

        private void set_up_directory_view () {
            set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);
            set_shadow_type (Gtk.ShadowType.NONE);

            size_allocate.connect_after (on_size_allocate);

            popup_menu.connect (on_popup_menu);

            unrealize.connect (() => {
                clipboard.changed.disconnect (on_clipboard_changed);
            });

            realize.connect (() => {
                clipboard.changed.connect (on_clipboard_changed);
                on_clipboard_changed ();
            });

            scroll_event.connect (on_scroll_event);

            get_vadjustment ().value_changed.connect_after (schedule_thumbnail_timeout);

            (GOF.Preferences.get_default ()).notify["show-hidden-files"].connect (on_show_hidden_files_changed);
            (GOF.Preferences.get_default ()).notify["show-remote-thumbnails"].connect (on_show_remote_thumbnails_changed);
            (GOF.Preferences.get_default ()).notify["sort-directories-first"].connect (on_sort_directories_first_changed);

            model.set_should_sort_directories_first (GOF.Preferences.get_default ().sort_directories_first);
            model.row_deleted.connect (on_row_deleted);
            /* Sort order of model is set after loading */
            model.sort_column_changed.connect (on_sort_column_changed);
        }

        private void set_up__menu_actions () {
            selection_actions = new GLib.SimpleActionGroup ();
            selection_actions.add_action_entries (selection_entries, this);
            insert_action_group ("selection", selection_actions);

            background_actions = new GLib.SimpleActionGroup ();
            background_actions.add_action_entries (background_entries, this);
            insert_action_group ("background", background_actions);

            common_actions = new GLib.SimpleActionGroup ();
            common_actions.add_action_entries (common_entries, this);
            insert_action_group ("common", common_actions);

            action_set_state (background_actions, "show_hidden", Preferences.settings.get_boolean ("show-hiddenfiles"));
            action_set_state (background_actions, "show_remote_thumbnails", Preferences.settings.get_boolean ("show-remote-thumbnails"));
        }

        public void zoom_in () {
            zoom_level = zoom_level + 1;
        }

        public void zoom_out () {
            if (zoom_level > 0) {
                zoom_level = zoom_level - 1;
            }
        }

        private void set_up_zoom_level () {
            zoom_level = get_set_up_zoom_level ();
        }

        public void zoom_normal () {
            zoom_level = get_normal_zoom_level ();
        }

        public void focus_first_for_empty_selection (bool select) {
            if (selected_files == null) {
                Idle.add_full (GLib.Priority.LOW, () => {
                    if (!tree_frozen) {
                        set_cursor (new Gtk.TreePath.from_indices (0), false, select, true);
                        return false;
                    } else {
                        return true;
                    }
                });
            }
        }

        public void select_glib_files_when_thawed (GLib.List<GLib.File> location_list, GLib.File? focus_location) {
            GLib.List<GOF.File>? file_list = null;

            location_list.@foreach ((loc) => {
                file_list.prepend (GOF.File.@get (loc));
            });

            GLib.File? focus = focus_location != null ? focus_location.dup () : null;

            /* Because the Icon View disconnects the model while loading, we need to wait until
             * the tree is thawed and the model reconnected before selecting the files */
            Idle.add_full (GLib.Priority.LOW, () => {
                if (!tree_frozen) {
                    select_file_paths (file_list, focus);
                    return false;
                } else {
                    return true;
                }
            });
        }

        private void select_file_paths (GLib.List<GOF.File> files, GLib.File? focus) {
            Gtk.TreeIter iter;
            disconnect_tree_signals (); /* Avoid unnecessary signal processing */
            unselect_all ();

            uint count = 0;

            foreach (GOF.File f in files) {
                /* Not all files selected in previous view  (e.g. expanded tree view) may appear in this one. */
                if (model.get_first_iter_for_file (f, out iter)) {
                    count++;
                    var path = model.get_path (iter);
                    select_path (path, focus != null && focus.equal (f.location)); /* Cursor follows if matches focus location*/
                }
            }

            if (count == 0) {
                focus_first_for_empty_selection (false);
            }

            connect_tree_signals ();
            on_view_selection_changed (); /* Update selected files and menu actions */
        }

        public unowned GLib.List<GLib.AppInfo> get_open_with_apps () {
            return open_with_apps;
        }

        public unowned GLib.AppInfo get_default_app () {
            return default_app;
        }

        public new void grab_focus () {
            if (slot.is_active && view.get_realized ()) {
                view.grab_focus ();
            }
        }

        public unowned GLib.List<GOF.File> get_selected_files () {
            update_selected_files_and_menu ();
            return selected_files;
        }

/*** Protected Methods */
        protected void set_active_slot (bool scroll = true) {
            slot.active (scroll);
        }

        protected void load_location (GLib.File location) {
            path_change_request (location, Marlin.OpenFlag.DEFAULT, false);
        }

        protected void load_root_location (GLib.File location) {
            path_change_request (location, Marlin.OpenFlag.DEFAULT, true);
        }

    /** Operations on selections */
        protected void activate_selected_items (Marlin.OpenFlag flag = Marlin.OpenFlag.DEFAULT,
                                                GLib.List<GOF.File> selection = get_selected_files ()) {

            if (is_frozen || selection == null) {
                return;
            }

            unowned Gdk.Screen screen = get_screen ();

            if (selection.first ().next == null) { // Only one selected
                activate_file (selection.data, screen, flag, true);
                return;
            }

            if (!in_trash) {
                /* launch each selected file individually ignoring selections greater than 10
                 * Do not launch with new instances of this app - open according to flag instead
                 */
                if (selection.nth_data (11) == null && // Less than 10 items
                   (default_app == null || app_is_this_app (default_app))) {

                    foreach (GOF.File file in selection) {
                        /* Prevent too rapid activation of files - causes New Tab to crash for example */
                        if (file.is_folder ()) {
                            /* By default, multiple folders open in new tabs */
                            if (flag == Marlin.OpenFlag.DEFAULT) {
                                flag = Marlin.OpenFlag.NEW_TAB;
                            }

                            GLib.Idle.add (() => {
                                activate_file (file, screen, flag, false);
                                return false;
                            });
                        } else {
                            GLib.Idle.add (() => {
                                open_file (file, screen, null);
                                return false;
                            });
                        }
                    }
                } else if (default_app != null) {
                    GLib.Idle.add (() => {
                        open_files_with (default_app, selection);
                        return false;
                    });
                }
            } else {
                warning ("Cannot open files in trash");
            }
        }

        public void select_gof_file (GOF.File file) {
            var iter = Gtk.TreeIter ();
            if (!model.get_first_iter_for_file (file, out iter)) {
                return; /* file not in model */
            }

            var path = model.get_path (iter);
            set_cursor (path, false, true, false);
        }

        protected void select_and_scroll_to_gof_file (GOF.File file) {
            var iter = Gtk.TreeIter ();
            if (!model.get_first_iter_for_file (file, out iter)) {
                return; /* file not in model */
            }

            var path = model.get_path (iter);
            set_cursor (path, false, true, true);
        }

        protected void add_gof_file_to_selection (GOF.File file) {
            var iter = Gtk.TreeIter ();

            if (!model.get_first_iter_for_file (file, out iter)) {
                return; /* file not in model */
            }

            var path = model.get_path (iter);
            select_path (path); /* Cursor does not follow */
        }

    /** Directory signal handlers. */
        /* Signal could be from subdirectory as well as slot directory */
        protected void connect_directory_handlers (GOF.Directory.Async dir) {
            assert (dir != null);
            dir.file_added.connect (on_directory_file_added);
            dir.file_changed.connect (on_directory_file_changed);
            dir.file_deleted.connect (on_directory_file_deleted);
            dir.icon_changed.connect (on_directory_file_icon_changed);
            connect_directory_loading_handlers (dir);
        }

        protected void connect_directory_loading_handlers (GOF.Directory.Async dir) {
            dir.file_loaded.connect (on_directory_file_loaded);
            dir.done_loading.connect (on_directory_done_loading);
        }

        protected void disconnect_directory_loading_handlers (GOF.Directory.Async dir) {
            dir.file_loaded.disconnect (on_directory_file_loaded);
            dir.done_loading.disconnect (on_directory_done_loading);
        }

        protected void disconnect_directory_handlers (GOF.Directory.Async dir) {
            /* If the directory is still loading the file_loaded signal handler
            /* will not have been disconnected */

            if (dir.is_loading ()) {
                disconnect_directory_loading_handlers (dir);
            }

            dir.file_added.disconnect (on_directory_file_added);
            dir.file_changed.disconnect (on_directory_file_changed);
            dir.file_deleted.disconnect (on_directory_file_deleted);
            dir.icon_changed.disconnect (on_directory_file_icon_changed);
            dir.done_loading.disconnect (on_directory_done_loading);
        }

        public void change_directory (GOF.Directory.Async old_dir, GOF.Directory.Async new_dir) {
            var style_context = get_style_context ();
            if (style_context.has_class (Granite.STYLE_CLASS_H2_LABEL)) {
                style_context.remove_class (Granite.STYLE_CLASS_H2_LABEL);
                style_context.remove_class (Gtk.STYLE_CLASS_VIEW);
            }

            cancel ();
            clear ();
            disconnect_directory_handlers (old_dir);
            connect_directory_handlers (new_dir);
        }

        public void prepare_reload (GOF.Directory.Async dir) {
            cancel ();
            clear ();
            connect_directory_loading_handlers (dir);
        }

        private void clear () {
            /* after calling this (prior to reloading), the directory must be re-initialised so
             * we reconnect the file_loaded and done_loading signals */
            freeze_tree ();
            block_model ();
            model.clear ();
            all_selected = false;
            unblock_model ();
        }

        protected void connect_drag_drop_signals (Gtk.Widget widget) {
            /* Set up as drop site */
            Gtk.drag_dest_set (widget, Gtk.DestDefaults.MOTION, drop_targets, Gdk.DragAction.ASK | file_drag_actions);
            widget.drag_drop.connect (on_drag_drop);
            widget.drag_data_received.connect (on_drag_data_received);
            widget.drag_leave.connect (on_drag_leave);
            widget.drag_motion.connect (on_drag_motion);

            /* Set up as drag source */
            Gtk.drag_source_set (widget, Gdk.ModifierType.BUTTON1_MASK, drag_targets, file_drag_actions);
            widget.drag_begin.connect (on_drag_begin);
            widget.drag_data_get.connect (on_drag_data_get);
            widget.drag_data_delete.connect (on_drag_data_delete);
            widget.drag_end.connect (on_drag_end);
        }

        protected void cancel_drag_timer () {
            disconnect_drag_timeout_motion_and_release_events ();
            cancel_timeout (ref drag_timer_id);
        }

        protected void cancel_thumbnailing () {
            if (thumbnail_request >= 0) {
                thumbnailer.dequeue (thumbnail_request);
                thumbnail_request = -1;
            }

            cancel_timeout (ref thumbnail_source_id);
        }

        protected bool is_drag_pending () {
            return drag_has_begun;
        }

        protected bool selection_only_contains_folders (GLib.List<GOF.File> list) {
            bool only_folders = true;

            list.@foreach ((file) => {
                if (!(file.is_folder () || file.is_root_network_folder ())) {
                    only_folders = false;
                }
            });

            return only_folders;
        }

    /** Handle scroll events */
        protected bool handle_scroll_event (Gdk.EventScroll event) {
            if (is_frozen) {
                return true;
            }

            if ((event.state & Gdk.ModifierType.CONTROL_MASK) > 0) {
                switch (event.direction) {
                    case Gdk.ScrollDirection.UP:
                        zoom_in ();
                        return true;

                    case Gdk.ScrollDirection.DOWN:
                        zoom_out ();
                        return true;

                    case Gdk.ScrollDirection.SMOOTH:
                        double delta_x, delta_y;
                        event.get_scroll_deltas (out delta_x, out delta_y);
                        /* try to emulate a normal scrolling event by summing deltas.
                         * step size of 0.5 chosen to match sensitivity */
                        total_delta_y += delta_y;

                        if (total_delta_y >= 0.5) {
                            total_delta_y = 0;
                            zoom_out ();
                        } else if (total_delta_y <= -0.5) {
                            total_delta_y = 0;
                            zoom_in ();
                        }
                        return true;

                    default:
                        break;
                }
            }

            return false;
        }

        protected void show_or_queue_context_menu (Gdk.Event event) {
            if (selected_files != null) {
                queue_context_menu (event);
            } else {
                show_context_menu (event);
            }
        }

        protected unowned GLib.List<GOF.File> get_selected_files_for_transfer (GLib.List<unowned GOF.File> selection = get_selected_files ()) {
            unowned GLib.List<GOF.File> list = null;

            selection.@foreach ((file) => {
                list.prepend (file);
            });

            list.reverse ();

            return list;
        }

/*** Private methods */
    /** File operations */


        private void activate_file (GOF.File _file, Gdk.Screen? screen, Marlin.OpenFlag flag, bool only_one_file) {
            if (is_frozen) {
                return;
            }

            GOF.File file = _file;
            if (in_recent) {
                file = GOF.File.get_by_uri (file.get_display_target_uri ());
            }

            default_app = Marlin.MimeActions.get_default_application_for_file (file);
            GLib.File location = file.get_target_location ();

            if (screen == null) {
                screen = get_screen ();
            }

            if (file.is_folder () ||
                file.get_ftype () == "inode/directory" ||
                file.is_root_network_folder ()) {

                switch (flag) {
                    case Marlin.OpenFlag.NEW_TAB:
                    case Marlin.OpenFlag.NEW_WINDOW:

                        path_change_request (location, flag, true);
                        break;

                    default:
                        if (only_one_file) {
                            load_location (location);
                        }

                        break;
                }
            } else if (!in_trash) {
                if (only_one_file) {
                    if (file.is_root_network_folder ()) {
                        load_location (location);
                    } else if (file.is_executable ()) {
                        var content_type = file.get_ftype ();

                        if (GLib.ContentType.is_a (content_type, "text/plain")) {
                            open_file (file, screen, default_app);
                        } else {
                            file.execute (screen, null, null);
                        }
                    } else {
                        open_file (file, screen, default_app);
                    }
                }
            } else {
                warning ("Cannot open file in trash");
            }
        }

        /* Open all files through this */
        private void open_file (GOF.File file, Gdk.Screen? screen, GLib.AppInfo? app_info) {
            if (can_open_file (file, true)) {
                Marlin.MimeActions.open_glib_file_request (file.location, this, app_info);
            }
        }

        /* Also used by build open menu */
        private bool can_open_file (GOF.File file, bool show_error_dialog = false) {
            string err_msg1 = _("Cannot open this file");
            string err_msg2 = "";
            var content_type = file.get_ftype ();

            if (content_type == null) {
                bool result_uncertain = true;
                content_type = ContentType.guess (file.basename, null, out result_uncertain);
                debug ("Guessed content type to be %s from name - result_uncertain %s",
                          content_type,
                          result_uncertain.to_string ());
            }

            if (content_type == null) {
                err_msg2 = _("Cannot identify file type to open");
            } else if (!slot.directory.can_open_files) {
                err_msg2 = "Cannot open files with this protocol (%s)".printf (slot.directory.scheme);
            } else if (!slot.directory.can_stream_files && (content_type.contains ("video") || content_type.contains ("audio"))) {
                err_msg2 = "Cannot stream from this protocol (%s)".printf (slot.directory.scheme);
            }

            bool success = err_msg2.length < 1;
            if (!success && show_error_dialog) {
                PF.Dialogs.show_warning_dialog (err_msg1, err_msg2, window);
            }

            return success;
        }

        private void trash_or_delete_files (GLib.List<GOF.File> file_list,
                                            bool delete_if_already_in_trash,
                                            bool delete_immediately) {

            GLib.List<GLib.File> locations = null;
            if (in_recent) {
                file_list.@foreach ((file) => {
                    locations.prepend (GLib.File.new_for_uri (file.get_display_target_uri ()));
                });
            } else {
                file_list.@foreach ((file) => {
                    locations.prepend (file.location);
                });
            }

            Gtk.TreeIter? iter = null;
            model.get_first_iter_for_file (file_list.first ().data, out iter);
            deleted_path = model.get_path (iter);

            if (locations != null) {
                locations.reverse ();

                slot.directory.block_monitor ();
                if (delete_immediately) {
                    Marlin.FileOperations.@delete (locations,
                                                   window as Gtk.Window,
                                                   after_trash_or_delete,
                                                   this);
                } else {
                    Marlin.FileOperations.trash_or_delete (locations,
                                                           window as Gtk.Window,
                                                           after_trash_or_delete,
                                                           this);
                }
            }

            /* If in recent "folder" we need to refresh the view. */
            if (in_recent) {
                slot.reload ();
            }
        }

        private void add_file (GOF.File file, GOF.Directory.Async dir) {
            model.add_file (file, dir);

            if (select_added_files) {
                add_gof_file_to_selection (file);
            }
        }

        private void handle_free_space_change () {
            /* Wait at least 250 mS after last space change before signalling to avoid unnecessary updates*/
            if (add_remove_file_timeout_id == 0) {
                signal_free_space_change = false;
                add_remove_file_timeout_id = GLib.Timeout.add (250, () => {
                    if (signal_free_space_change) {
                        add_remove_file_timeout_id = 0;
                        window.free_space_change ();
                        return false;
                    } else {
                        signal_free_space_change = true;
                        return true;
                    }
                });
            } else {
                signal_free_space_change = false;
            }
        }

        private void new_empty_file (string? parent_uri = null) {
            if (parent_uri == null) {
                parent_uri = slot.directory.file.uri;
            }

            /* Block the async directory file monitor to avoid generating unwanted "add-file" events */
            slot.directory.block_monitor ();
            Marlin.FileOperations.new_file (this as Gtk.Widget,
                                            null,
                                            parent_uri,
                                            null,
                                            null,
                                            0,
                                            (Marlin.CreateCallback?) create_file_done,
                                            this);
        }

        private void new_empty_folder () {
            /* Block the async directory file monitor to avoid generating unwanted "add-file" events */
            slot.directory.block_monitor ();
            Marlin.FileOperations.new_folder (null, null, slot.location, (Marlin.CreateCallback?) create_file_done, this);
        }

        private void after_new_file_added (GOF.File? file) {
            slot.directory.file_added.disconnect (after_new_file_added);
            if (file != null) {
                rename_file (file);
            }
        }

        protected void rename_file (GOF.File file_to_rename) {
            if (renaming) {
                warning ("already renaming %s", file_to_rename.basename);
                return;
            }
            /* Assume writability on remote locations */
            /**TODO** Reliably determine writability with various remote protocols.*/
            if (is_writable || !slot.directory.is_local) {
                start_renaming_file (file_to_rename);
            } else {
                warning ("You do not have permission to rename this file");
            }
        }

/** File operation callbacks */
        static void create_file_done (GLib.File? new_file, void* data) {
            var view = data as FM.AbstractDirectoryView;

            if (new_file == null) {
                return;
            }

            if (view == null) {
                warning ("View invalid after creating file");
                return;
            }
            /* Start to rename the file once we get signal that it has been added to model */
            view.slot.directory.file_added.connect_after (view.after_new_file_added);
            view.unblock_directory_monitor ();
        }

        /** Must pass a pointer to an instance of FM.AbstractDirectoryView as 3rd parameter when
          * using this callback */
        public static void after_trash_or_delete (bool user_cancel, void* data) {
            var view = data as FM.AbstractDirectoryView;
            if (view == null) {
                return;
            }

            /* Need to use Idle else cursor gets reset to null after setting to delete_path */
            Idle.add (() => {
                view.set_cursor (view.deleted_path, false, false, false);
                view.unblock_directory_monitor ();
                return false;
            });

        }

        private void unblock_directory_monitor () {
            /* Using an idle stops two file deleted/added signals being received (one via the file monitor
             * and one via marlin-file-changes. */
            GLib.Idle.add_full (GLib.Priority.LOW, () => {
                slot.directory.unblock_monitor ();
                return false;
            });
        }

        private void trash_or_delete_selected_files (bool delete_immediately = false) {
        /* This might be rapidly called multiple times for the same selection
         * when using keybindings. So we remember if the current selection
         * was already removed (but the view doesn't know about it yet).
         */
            unowned GLib.List<GOF.File> selection = get_selected_files_for_transfer ();
            if (selection != null) {
                trash_or_delete_files (selection, true, delete_immediately);
            }
        }

/** Signal Handlers */

    /** Menu actions */
        /** Selection actions */

        private void on_selection_action_view_in_location (GLib.SimpleAction action, GLib.Variant? param) {
            view_selected_file ();
        }

        private void view_selected_file () {
            if (selected_files == null) {
                return;
            }

            foreach (GOF.File file in selected_files) {
                var loc = GLib.File.new_for_uri (file.get_display_target_uri ());
                path_change_request (loc, Marlin.OpenFlag.NEW_TAB, true);
            }
        }

        private void on_selection_action_forget (GLib.SimpleAction action, GLib.Variant? param) {
            forget_selected_file ();
        }

        private void forget_selected_file () {
            if (selected_files == null) {
                return;
            }

            try {
                foreach (var file in selected_files) {
                    recent.remove_item (file.get_display_target_uri ());
                }
            } catch (Error err) {
                critical (err.message);
            }
        }

        private void on_selection_action_rename (GLib.SimpleAction action, GLib.Variant? param) {
            rename_selected_file ();
        }

        private void rename_selected_file () {
            if (selected_files == null) {
                return;
            }

            if (selected_files.next != null) {
                warning ("Cannot rename multiple files (yet) - renaming first only");
            }

            /**TODO** invoke batch renamer see bug #1014122*/

            rename_file (selected_files.first ().data);
        }

        private void on_selection_action_cut (GLib.SimpleAction action, GLib.Variant? param) {
            unowned GLib.List<GOF.File> selection = get_selected_files_for_transfer ();
            clipboard.cut_files (selection);
        }

        private void on_selection_action_trash (GLib.SimpleAction action, GLib.Variant? param) {
            trash_or_delete_selected_files (is_admin);
        }

        private void on_selection_action_delete (GLib.SimpleAction action, GLib.Variant? param) {
            trash_or_delete_selected_files (true);
        }

        private void on_selection_action_restore (GLib.SimpleAction action, GLib.Variant? param) {
            unowned GLib.List<GOF.File> selection = get_selected_files_for_transfer ();
            PF.FileUtils.restore_files_from_trash (selection, window);

        }

        private void on_selection_action_open_executable (GLib.SimpleAction action, GLib.Variant? param) {
            unowned GLib.List<GOF.File> selection = get_files_for_action ();
            GOF.File file = selection.data as GOF.File;
            unowned Gdk.Screen screen = get_screen ();
            file.execute (screen, null, null);
        }

        private void on_selection_action_open_with_default (GLib.SimpleAction action, GLib.Variant? param) {
            activate_selected_items (Marlin.OpenFlag.DEFAULT);
        }

        private void on_selection_action_open_with_app (GLib.SimpleAction action, GLib.Variant? param) {
            var index = int.parse (param.get_string ());
            open_files_with (open_with_apps.nth_data ((uint)index), get_files_for_action ());
        }

        private void on_selection_action_open_with_other_app () {
            unowned GLib.List<GOF.File> selection = get_files_for_action ();
            GOF.File file = selection.data as GOF.File;
            open_file (file, null, null);
        }

        private void on_common_action_bookmark (GLib.SimpleAction action, GLib.Variant? param) {
            GLib.File location;
            if (selected_files != null) {
                location = selected_files.data.get_target_location ();
            } else {
                location = slot.directory.file.get_target_location ();
            }

            window.bookmark_uri (location.get_uri (), null);
        }

        /** Background actions */

        private void change_state_show_hidden (GLib.SimpleAction action) {
            window.change_state_show_hidden (action);
        }
        private void change_state_show_remote_thumbnails (GLib.SimpleAction action) {
            window.change_state_show_remote_thumbnails (action);
        }

        private void on_background_action_new (GLib.SimpleAction action, GLib.Variant? param) {
            switch (param.get_string ()) {
                case "FOLDER":
                    new_empty_folder ();
                    break;

                case "FILE":
                    new_empty_file ();
                    break;

                default:
                    break;
            }
        }

        private void on_background_action_create_from (GLib.SimpleAction action, GLib.Variant? param) {
            int index = int.parse (param.get_string ());
            create_from_template (templates.nth_data ((uint)index));
        }

        private void on_background_action_sort_by_changed (GLib.SimpleAction action, GLib.Variant? val) {
            string sort = val.get_string ();
            set_sort (sort, false);
        }

        private void on_background_action_reverse_changed (GLib.SimpleAction action, GLib.Variant? val) {
            set_sort (null, true);
        }

        private void on_background_action_folders_first_changed (GLib.SimpleAction action, GLib.Variant? val) {
            var prefs = GOF.Preferences.get_default ();
            prefs.sort_directories_first = !prefs.sort_directories_first;
        }

        private void set_sort (string? col_name, bool reverse) {
            int sort_column_id;
            Gtk.SortType sort_order;

            if (model.get_sort_column_id (out sort_column_id, out sort_order)) {
                if (col_name != null) {
                    sort_column_id = get_column_id_from_string (col_name);
                }

                if (reverse) {
                    if (sort_order == Gtk.SortType.ASCENDING) {
                        sort_order = Gtk.SortType.DESCENDING;
                    } else {
                        sort_order = Gtk.SortType.ASCENDING;
                    }
                }

                model.set_sort_column_id (sort_column_id, sort_order);
            }
        }

        /** Common actions */

        private void on_common_action_open_in (GLib.SimpleAction action, GLib.Variant? param) {
            default_app = null;

            switch (param.get_string ()) {
                case "TAB":
                    activate_selected_items (Marlin.OpenFlag.NEW_TAB, get_files_for_action ());
                    break;

                case "WINDOW":
                    activate_selected_items (Marlin.OpenFlag.NEW_WINDOW, get_files_for_action ());
                    break;

                default:
                    break;
            }
        }

        private void on_common_action_properties (GLib.SimpleAction action, GLib.Variant? param) {
            new Marlin.View.PropertiesWindow (get_files_for_action (), this, window);
        }

        private void on_common_action_copy_link (GLib.SimpleAction action, GLib.Variant? param) {
            clipboard.copy_link_files (get_selected_files_for_transfer (get_files_for_action ()));
        }

        private void on_common_action_copy (GLib.SimpleAction action, GLib.Variant? param) {
            clipboard.copy_files (get_selected_files_for_transfer (get_files_for_action ()));
        }

        public static void after_pasting_files (GLib.HashTable? uris, void* pointer) {
            if (pointer == null) {
                return;
            }

            var view = pointer as FM.AbstractDirectoryView;
            if (view == null) {
                warning ("view no longer valid after pasting files");
                return;
            }

            if (uris == null || uris.size () == 0) {
                return;
            }

            Idle.add (() => {
                /* Select the most recently pasted files */
                GLib.List<GLib.File> pasted_files_list = null;
                uris.foreach ((k, v) => {
                    if (k is GLib.File) {
                        pasted_files_list.prepend (k as File);
                    }
                });

                view.select_glib_files_when_thawed (pasted_files_list, pasted_files_list.first ().data);
                return false;
            });
        }

        private void on_common_action_paste_into (GLib.SimpleAction action, GLib.Variant? param) {
            var file = get_files_for_action ().nth_data (0);

            if (file != null && clipboard.can_paste && !(clipboard.files_linked && in_trash)) {
                GLib.File target;
                GLib.Callback? call_back;

                if (file.is_folder () && !clipboard.has_file (file)) {
                    target = file.get_target_location ();
                } else {
                    target = slot.location;
                }

                if (target.has_uri_scheme ("trash")) {
                    /* Pasting files into trash is equivalent to trash or delete action */
                    call_back = (GLib.Callback)after_trash_or_delete;
                } else {
                    /* callback takes care of selecting pasted files */
                    call_back = (GLib.Callback)after_pasting_files;
                }

                clipboard.paste_files (target, this as Gtk.Widget, call_back);
            }
        }

        private void on_directory_file_added (GOF.Directory.Async dir, GOF.File? file) {
            if (file != null) {
                add_file (file, dir);
                handle_free_space_change ();
            }
        }

        private void on_directory_file_loaded (GOF.Directory.Async dir, GOF.File file) {
            select_added_files = false;
            add_file (file, dir); /* no freespace change signal required */
        }

        private void on_directory_file_changed (GOF.Directory.Async dir, GOF.File file) {
            if (file.location.equal (dir.file.location)) {
                /* The slot directory has changed - it can only be the properties */
                is_writable = slot.directory.file.is_writable ();
            } else {
                remove_marlin_icon_info_cache (file);
                model.file_changed (file, dir);
                /* 2nd parameter is for returned request id if required - we do not use it? */
                /* This is required if we need to dequeue the request */
                if (slot.directory.is_local || (show_remote_thumbnails && slot.directory.can_open_files)) {
                    thumbnailer.queue_file (file, null, large_thumbnails);
                    if (plugins != null) {
                        plugins.update_file_info (file);
                    }
                }
            }

            draw_when_idle ();
        }

        private void on_directory_file_icon_changed (GOF.Directory.Async dir, GOF.File file) {
            model.file_changed (file, dir);
            draw_when_idle ();
        }

        private void on_directory_file_deleted (GOF.Directory.Async dir, GOF.File file) {
            /* The deleted file could be the whole directory, which is not in the model but that
             * that does not matter.  */
            model.remove_file (file, dir);

            remove_marlin_icon_info_cache (file);
            if (file.get_thumbnail_path () != null) {
                PF.FileUtils.remove_thumbnail_paths_for_uri (file.uri);
            }

            if (file.is_folder ()) {
                /* Check whether the deleted file is the directory */
                var file_dir = GOF.Directory.Async.cache_lookup (file.location);
                if (file_dir != null) {
                    GOF.Directory.Async.purge_dir_from_cache (file_dir);
                    slot.folder_deleted (file, file_dir);
                }
            }
            handle_free_space_change ();
        }

        private void on_directory_done_loading (GOF.Directory.Async dir) {
            /* Should only be called on directory creation or reload */
            disconnect_directory_loading_handlers (dir);
            in_trash = slot.directory.is_trash;
            in_recent = slot.directory.is_recent;
            in_network_root = slot.directory.file.is_root_network_folder ();

            thaw_tree ();

            if (slot.directory.can_load) {
                is_writable = slot.directory.file.is_writable ();
                if (in_recent) {
                    model.set_sort_column_id (get_column_id_from_string ("modified"), Gtk.SortType.DESCENDING);
                } else if (slot.directory.file.info != null) {
                    model.set_sort_column_id (slot.directory.file.sort_column_id, slot.directory.file.sort_order);
                }
            } else {
                is_writable = false;
            }

            schedule_thumbnail_timeout ();
        }

    /** Handle zoom level change */
        private void on_zoom_level_changed (Marlin.ZoomLevel zoom) {
            var size = icon_size * get_scale_factor ();

            if (!large_thumbnails && size > 128 || large_thumbnails && size <= 128) {
                large_thumbnails = size > 128;
                slot.refresh_files (); /* Force GOF files to switch between normal and large thumbnails */
            }

            model.set_property ("size", icon_size);
            change_zoom_level ();
        }

    /** Handle Preference changes */
        private void on_show_hidden_files_changed (GLib.Object prefs, GLib.ParamSpec pspec) {
            bool show = (prefs as GOF.Preferences).show_hidden_files;
            cancel ();
            /* As directory may reload, for consistent behaviour always lose selection */
            unselect_all ();

            if (!show) {
                block_model ();
                model.clear ();
            }

            directory_hidden_changed (slot.directory, show);

            if (!show) {
                unblock_model ();
            }

            action_set_state (background_actions, "show_hidden", show);
        }

        private void on_show_remote_thumbnails_changed (GLib.Object prefs, GLib.ParamSpec pspec) {
            show_remote_thumbnails = (prefs as GOF.Preferences).show_remote_thumbnails;
            action_set_state (background_actions, "show_remote_thumbnails", show_remote_thumbnails);
            if (show_remote_thumbnails) {
                slot.reload ();
            }
        }

        private void on_sort_directories_first_changed (GLib.Object prefs, GLib.ParamSpec pspec) {
            var sort_directories_first = (prefs as GOF.Preferences).sort_directories_first;
            model.set_should_sort_directories_first (sort_directories_first);
        }

        private void directory_hidden_changed (GOF.Directory.Async dir, bool show) {
            /* May not be slot.directory - could be subdirectory */
            dir.file_loaded.connect (on_directory_file_loaded); /* disconnected by on_done_loading callback.*/
            dir.load_hiddens ();
        }

    /** Handle popup menu events */
        private bool on_popup_menu () {
            Gdk.Event event = Gtk.get_current_event ();
            show_or_queue_context_menu (event);
            return true;
        }

    /** Handle Button events */
        private bool on_drag_timeout_button_release (Gdk.EventButton event) {
            /* Only active during drag timeout */
            cancel_drag_timer ();

            if (drag_button == Gdk.BUTTON_SECONDARY) {
                show_context_menu (event);
            }

            return true;
        }

/** Handle Motion events */
        private bool on_drag_timeout_motion_notify (Gdk.EventMotion event) {
            /* Only active during drag timeout */
            Gdk.DragContext context;
            var widget = get_real_view ();
            int x = (int)event.x;
            int y = (int)event.y;

            if (Gtk.drag_check_threshold (widget, drag_x, drag_y, x, y)) {
                cancel_drag_timer ();
                should_activate = false;
                var target_list = new Gtk.TargetList (drag_targets);
                var actions = file_drag_actions;

                if (drag_button == Gdk.BUTTON_SECONDARY) {
                    actions |= Gdk.DragAction.ASK;
                }

                context = Gtk.drag_begin_with_coordinates (widget,
                                target_list,
                                actions,
                                drag_button,
                                (Gdk.Event) event,
                                 x, y);
                return true;
            } else {
                return false;
            }
        }

/** Handle TreeModel events */
        protected virtual void on_row_deleted (Gtk.TreePath path) {
            unselect_all ();
        }

/** Handle clipboard signal */
        private void on_clipboard_changed () {
            /* show possible change in appearance of cut items */
            queue_draw ();
        }

    /** Handle size allocation event */
        private void on_size_allocate (Gtk.Allocation allocation) {
            schedule_thumbnail_timeout ();
        }

/** DRAG AND DROP */

    /** Handle Drag source signals*/

        private void on_drag_begin (Gdk.DragContext context) {
            drag_has_begun = true;
            should_activate = false;
        }

        private void on_drag_data_get (Gdk.DragContext context,
                                       Gtk.SelectionData selection_data,
                                       uint info,
                                       uint timestamp) {

            /* get file list only once in case view changes location automatically
             * while dragging (which loses file selection.
             */

            if (drag_file_list == null) {
                drag_file_list = get_selected_files_for_transfer ();
            }

            if (drag_file_list == null) {
                return;
            }

            GOF.File file = drag_file_list.first ().data;

            if (file != null && file.pix != null) {
                Gtk.drag_set_icon_gicon (context, file.pix, 0, 0);
            } else {
                Gtk.drag_set_icon_name (context, "stock-file", 0, 0);
            }

            Marlin.DndHandler.set_selection_data_from_file_list (selection_data, drag_file_list);
        }

        private void on_drag_data_delete (Gdk.DragContext context) {
            /* block real_view default handler because handled in on_drag_end */
            GLib.Signal.stop_emission_by_name (get_real_view (), "drag-data-delete");
        }

        private void on_drag_end (Gdk.DragContext context) {
            cancel_timeout (ref drag_scroll_timer_id);
            drag_file_list = null;
            drop_target_file = null;
            drop_file_list = null;
            drop_data_ready = false;

            current_suggested_action = Gdk.DragAction.DEFAULT;
            current_actions = Gdk.DragAction.DEFAULT;
            drag_has_begun = false;
            drop_occurred = false;
        }


/** Handle Drop target signals*/
        private bool on_drag_motion (Gdk.DragContext context,
                                     int x,
                                     int y,
                                     uint timestamp) {

            if (!drop_data_ready && !get_drop_data (context, x, y, timestamp)) {
                /* We don't have drop data already ... */
                return false;
            } else {
                /* We have the drop data - check whether we can drop here*/
                check_destination_actions_and_target_file (context, x, y, timestamp);
            }

            if (drag_scroll_timer_id == 0) {
                start_drag_scroll_timer (context);
            }

            Gdk.drag_status (context, current_suggested_action, timestamp);
            return true;
        }

        private bool on_drag_drop (Gdk.DragContext context,
                                   int x,
                                   int y,
                                   uint timestamp) {

            Gtk.TargetList list = null;
            string? uri = null;
            bool ok_to_drop = false;

            Gdk.Atom target = Gtk.drag_dest_find_target (get_real_view (), context, list);

            if (target == Gdk.Atom.intern_static_string ("XdndDirectSave0")) {
                GOF.File? target_file = get_drop_target_file (x, y, null);
                if (target_file != null) {
                    /* get XdndDirectSave file name from DnD source window */
                    string? filename = dnd_handler.get_source_filename (context);
                    if (filename != null) {
                        /* Get uri of source file when dropped */
                        uri = target_file.get_target_location ().resolve_relative_path (filename).get_uri ();
                        /* Setup the XdndDirectSave property on the source window */
                        dnd_handler.set_source_uri (context, uri);
                        ok_to_drop = true;
                    } else {
                        PF.Dialogs.show_error_dialog (_("Cannot drop this file"), _("Invalid file name provided"), window);
                    }
                }
            } else {
                ok_to_drop = (target != Gdk.Atom.NONE);
            }

            if (ok_to_drop) {
                drop_occurred = true;
                /* request the drag data from the source (initiates
                 * saving in case of XdndDirectSave).*/
                Gtk.drag_get_data (get_real_view (), context, target, timestamp);
            }

            return ok_to_drop;
        }


        private void on_drag_data_received (Gdk.DragContext context,
                                            int x,
                                            int y,
                                            Gtk.SelectionData selection_data,
                                            uint info,
                                            uint timestamp
                                            ) {
            bool success = false;

            if (!drop_data_ready) {
                /* We don't have the drop data - extract uri list from selection data */
                string? text;
                if (Marlin.DndHandler.selection_data_is_uri_list (selection_data, info, out text)) {
                    drop_file_list = PF.FileUtils.files_from_uris (text);
                    drop_data_ready = true;
                }
            }

            if (drop_occurred && drop_data_ready) {
                drop_occurred = false;
                if (current_actions != Gdk.DragAction.DEFAULT) {
                    switch (info) {
                        case Marlin.TargetType.XDND_DIRECT_SAVE0:
                            success = dnd_handler.handle_xdnddirectsave (context,
                                                                         drop_target_file,
                                                                         selection_data);
                            break;

                        case Marlin.TargetType.NETSCAPE_URL:
                            success = dnd_handler.handle_netscape_url (context,
                                                                       drop_target_file,
                                                                       selection_data);
                            break;

                        case Marlin.TargetType.TEXT_URI_LIST:
                            if ((current_actions & file_drag_actions) != 0) {
                                if (selected_files != null) {
                                    unselect_all ();
                                }

                                select_added_files = true;
                                success = dnd_handler.handle_file_drag_actions (get_real_view (),
                                                                                window,
                                                                                context,
                                                                                drop_target_file,
                                                                                drop_file_list,
                                                                                current_actions,
                                                                                current_suggested_action,
                                                                                timestamp);
                            }

                            break;

                        default:
                            break;
                    }
                }
                Gtk.drag_finish (context, success, false, timestamp);
                on_drag_leave (context, timestamp);
            }
        }

        private void on_drag_leave (Gdk.DragContext context, uint timestamp) {
            /* reset the drop-file for the icon renderer */
            icon_renderer.set_property ("drop-file", GLib.Value (typeof (Object)));
            /* stop any running drag autoscroll timer */
            cancel_timeout (ref drag_scroll_timer_id);
            cancel_timeout (ref drag_enter_timer_id);

            /* disable the drop highlighting around the view */
            if (drop_highlight) {
                drop_highlight = false;
                queue_draw ();
            }

            /* disable the highlighting of the items in the view */
            highlight_path (null);

            /* Prepare to receive another drop */
            drop_data_ready = false;
        }

/** DnD helpers */

        private GOF.File? get_drop_target_file (int win_x, int win_y, out Gtk.TreePath? path_return) {
            Gtk.TreePath? path = get_path_at_pos (win_x, win_y);
            GOF.File? file = null;

            if (path != null) {
                file = model.file_for_path (path);
                if (file == null) {
                    /* must be on expanded empty folder, use the folder path instead */
                    Gtk.TreePath folder_path = path.copy ();
                    folder_path.up ();
                    file = model.file_for_path (folder_path);
                } else {
                    /* can only drop onto folders and executables */
                    if (!file.is_folder () && !file.is_executable ()) {
                        file = null;
                        path = null;
                    }
                }
            }

            if (path == null) {
                /* drop to current folder instead */
                file = slot.directory.file;
            }

            path_return = path;
            return file;
        }

        private bool get_drop_data (Gdk.DragContext context, int x, int y, uint timestamp) {
            Gtk.TargetList? list = null;
            Gdk.Atom target = Gtk.drag_dest_find_target (get_real_view (), context, list);
            bool result = false;
            current_target_type = target;
            /* Check if we can handle it yet */
            if (target == Gdk.Atom.intern_static_string ("XdndDirectSave0") ||
                target == Gdk.Atom.intern_static_string ("_NETSCAPE_URL")) {

                /* Determine file at current position (if any) */
                Gtk.TreePath? path = null;
                GOF.File? file = get_drop_target_file (x, y, out path);


                if (file != null &&
                    file.is_folder () &&
                    file.is_writable ()) {

                    icon_renderer.@set ("drop-file", file);
                    highlight_path (path);
                    drop_data_ready = true;
                    result = true;
                }
            } else if (target != Gdk.Atom.NONE) {
                /* request the drag data from the source */
                Gtk.drag_get_data (get_real_view (), context, target, timestamp); /* emits "drag_data_received" */
            }

            return result;
        }

        private void check_destination_actions_and_target_file (Gdk.DragContext context, int x, int y, uint timestamp) {
            Gtk.TreePath? path;
            GOF.File? file = get_drop_target_file (x, y, out path);
            string uri = file != null ? file.uri : "";
            string current_uri = drop_target_file != null ? drop_target_file.uri : "";

            Gdk.drag_status (context, Gdk.DragAction.MOVE, timestamp);
            if (uri != current_uri) {
                cancel_timeout (ref drag_enter_timer_id);
                drop_target_file = file;
                current_actions = Gdk.DragAction.DEFAULT;
                current_suggested_action = Gdk.DragAction.DEFAULT;

                if (file != null) {
                    if (current_target_type == Gdk.Atom.intern_static_string ("XdndDirectSave0")) {
                        current_suggested_action = Gdk.DragAction.COPY;
                        current_actions = current_suggested_action;
                    } else {
                        current_actions = PF.FileUtils.file_accepts_drop (file,
                                                                      drop_file_list, context,
                                                                      out current_suggested_action);
                    }

                    highlight_drop_file (drop_target_file, current_actions, path);

                    if (file.is_folder () && is_valid_drop_folder (file)) {
                        /* open the target folder after a short delay */
                        drag_enter_timer_id = GLib.Timeout.add_full (GLib.Priority.LOW,
                                                                     drag_enter_delay,
                                                                     () => {

                            load_location (file.get_target_location ());
                            drag_enter_timer_id = 0;
                            return false;
                        });
                    }
                }
            }
        }

        private bool is_valid_drop_folder (GOF.File file) {
            /* Cannot drop onto a file onto its parent or onto itself */
            if (file.uri != slot.uri &&
                drag_file_list != null &&
                drag_file_list.index (file) < 0) {

                return true;
            } else {
                return false;
            }
        }

        private void highlight_drop_file (GOF.File drop_file, Gdk.DragAction action, Gtk.TreePath? path) {
            bool can_drop = (action > Gdk.DragAction.DEFAULT);

            if (drop_highlight != can_drop) {
                drop_highlight = can_drop;
                queue_draw ();
            }

            /* Set the icon_renderer drop-file if there is an action */
            drop_file = can_drop ? drop_file : null;
            icon_renderer.set_property ("drop-file", drop_file);

            highlight_path (can_drop ? path : null);
        }

/** MENU FUNCTIONS */

        /*
         * (derived from thunar: thunar_standard_view_queue_popup)
         *
         * Schedules a context menu popup in response to
         * a right-click button event. Right-click events
         * need to be handled in a special way, as the
         * user may also start a drag using the right
         * mouse button and therefore this function
         * schedules a timer, which - once expired -
         * opens the context menu. If the user moves
         * the mouse prior to expiration, a right-click
         * drag (with #GDK_ACTION_ASK) will be started
         * instead.
        **/

        private void queue_context_menu (Gdk.Event event) {
            if (drag_timer_id > 0) { /* already queued */
                return;
            }

            start_drag_timer (event);
        }

        protected void start_drag_timer (Gdk.Event event) {
            connect_drag_timeout_motion_and_release_events ();
            var button_event = (Gdk.EventButton)event;
            drag_button = (int)(button_event.button);

            drag_timer_id = GLib.Timeout.add_full (GLib.Priority.LOW,
                                                   drag_delay,
                                                   () => {
                on_drag_timeout_button_release ((Gdk.EventButton)event);
                return false;
            });
        }

        protected void show_context_menu (Gdk.Event event) {
            /* select selection or background context menu */
            update_menu_actions ();
            var builder = new Gtk.Builder.from_file (Config.UI_DIR + "directory_view_popup.ui");
            GLib.MenuModel? model = null;

            if (get_selected_files () != null) {
                model = build_menu_selection (ref builder, in_trash, in_recent);
            } else {
                model = build_menu_background (ref builder, in_trash, in_recent);
            }

            if (model != null && model is GLib.MenuModel) {
                /* add any additional entries from plugins */
                var menu = new Gtk.Menu.from_model (model);

                if (!in_trash) {
                    plugins.hook_context_menu (menu as Gtk.Widget, get_files_for_action ());
                }

                menu.set_screen (null);
                menu.attach_to_widget (this, null);
                /* Override style Granite.STYLE_CLASS_H2_LABEL of view when it is empty */
                if (slot.directory.is_empty ()) {
                    menu.get_style_context ().add_class (Gtk.STYLE_CLASS_CONTEXT_MENU);
                }

                menu.popup_at_pointer (event);
            }
        }

        private bool valid_selection_for_edit () {
            foreach (GOF.File file in get_selected_files ()) {
                if (file.is_root_network_folder ()) {
                    return false;
                }
            }

            return true;
        }

        private bool valid_selection_for_restore () {
            foreach (GOF.File file in get_selected_files ()) {
                if (!(file.directory.get_basename () == "/")) {
                    return false;
                }
            }

            return true;
        }

        private GLib.MenuModel? build_menu_selection (ref Gtk.Builder builder, bool in_trash, bool in_recent) {
            GLib.Menu menu = new GLib.Menu ();

            var clipboard_menu = builder.get_object ("clipboard-selection") as GLib.Menu;

            if (in_trash) {
                /* In trash, only show context menu when all selected files are in root folder */
                if (valid_selection_for_restore ()) {
                    menu.append_section (null, builder.get_object ("popup-trash-selection") as GLib.Menu);
                    clipboard_menu.remove (1); /* Copy */
                    clipboard_menu.remove (1); /* Copy Link*/
                    clipboard_menu.remove (1); /* Paste (index updated by previous line) */
                    clipboard_menu.remove (1); /* Paste Link (index updated by previous line) */
                    menu.append_section (null, clipboard_menu);

                    menu.append_section (null, builder.get_object ("properties") as GLib.Menu);
                }
            } else if (in_recent) {
                var open_menu = build_menu_open (ref builder);
                if (open_menu != null) {
                    menu.append_section (null, open_menu);
                }

                menu.append_section (null, builder.get_object ("view-in-location") as GLib.Menu);
                menu.append_section (null, builder.get_object ("forget") as GLib.Menu);

                clipboard_menu.remove (0); /* Cut */
                clipboard_menu.remove (1); /* Copy as Link */
                clipboard_menu.remove (1); /* Paste */
                clipboard_menu.remove (1); /* Paste Link */

                menu.append_section (null, clipboard_menu);

                menu.append_section (null, builder.get_object ("trash") as GLib.MenuModel);
                menu.append_section (null, builder.get_object ("properties") as GLib.Menu);
            } else {
                var open_menu = build_menu_open (ref builder);
                if (open_menu != null) {
                    menu.append_section (null, open_menu);
                }

                if (slot.directory.file.is_smb_server ()) {
                    if (clipboard != null && clipboard.can_paste) {
                        menu.append_section (null, builder.get_object ("paste") as GLib.MenuModel);
                    }
                } else if (valid_selection_for_edit ()) {
                    /* Do not display the 'Paste into' menuitem nothing to paste.
                     * We have to hard-code the menuitem index so any change to the clipboard-
                     * selection menu definition in directory_view_popup.ui may necessitate changing
                     * the index below.
                     */
                    if (!action_get_enabled (common_actions, "paste_into") ||
                        clipboard == null || !clipboard.can_paste) {
                        clipboard_menu.remove (3); /* Paste into*/
                        clipboard_menu.remove (3); /* Past Link into*/
                    } else {
                        if (clipboard.files_linked) {
                            clipboard_menu.remove (3); /* Paste into*/
                        } else {
                            clipboard_menu.remove (4); /* Paste Link into*/
                        }
                    }

                    menu.append_section (null, clipboard_menu);

                    if (slot.directory.has_trash_dirs && !is_admin) {
                        menu.append_section (null, builder.get_object ("trash") as GLib.MenuModel);
                    } else {
                        menu.append_section (null, builder.get_object ("delete") as GLib.MenuModel);
                    }

                    menu.append_section (null, builder.get_object ("rename") as GLib.MenuModel);
                }

                if (common_actions.get_action_enabled ("bookmark")) {
                    /* Do  not offer to bookmark if location is already bookmarked */
                    if (window.can_bookmark_uri (selected_files.data.uri)) {
                        menu.append_section (null, builder.get_object ("bookmark") as GLib.MenuModel);
                    }
                }
                menu.append_section (null, builder.get_object ("properties") as GLib.MenuModel);
            }

            if (menu.get_n_items () > 0) {
                return menu as MenuModel;
            } else {
                return null;
            }
        }

        private GLib.MenuModel? build_menu_background (ref Gtk.Builder builder, bool in_trash, bool in_recent) {
            var menu = new GLib.Menu ();

            if (in_trash) {
                if (clipboard != null && clipboard.has_cutted_file (null) ) {
                    menu.append_section (null, builder.get_object ("paste") as GLib.MenuModel);
                    return menu as MenuModel;
                } else {
                    return null;
                }
            }

            if (in_recent) {
                menu.append_section (null, builder.get_object ("sort-by") as GLib.MenuModel);
                menu.append_section (null, build_show_menu (builder));
                return menu as MenuModel;
            }

            var open_menu = build_menu_open (ref builder);
            if (open_menu != null) {
                menu.append_section (null, open_menu);
            }

            if (!in_network_root) {
                /* If something is pastable in the clipboard, show the option even if it is not enabled */
                if (clipboard != null && clipboard.can_paste) {
                    if (clipboard.files_linked) {
                        menu.append_section (null, builder.get_object ("paste-link") as GLib.MenuModel);
                    } else {
                        menu.append_section (null, builder.get_object ("paste") as GLib.MenuModel);
                    }
                }

                GLib.MenuModel? template_menu = build_menu_templates ();
                var new_menu = builder.get_object ("new") as GLib.Menu;

                if (is_writable) {
                    if (template_menu != null) {
                        var new_submenu = builder.get_object ("new-submenu") as GLib.Menu;
                        new_submenu.append_section (null, template_menu);
                    }

                    menu.append_section (null, new_menu as GLib.MenuModel);
                }

                menu.append_section (null, builder.get_object ("sort-by") as GLib.MenuModel);
            }

            if (common_actions.get_action_enabled ("bookmark")) {
                /* Do  not offer to bookmark if location is already bookmarked */
                if (window.can_bookmark_uri (slot.directory.file.uri)) {
                    menu.append_section (null, builder.get_object ("bookmark") as GLib.MenuModel);
                }
            }

            menu.append_section (null, build_show_menu (builder));

            if (!in_network_root) {
                menu.append_section (null, builder.get_object ("properties") as GLib.MenuModel);
            }

            return menu as MenuModel;
        }

        private GLib.MenuModel build_show_menu (Gtk.Builder builder) {
            var show_menu = builder.get_object ("show") as GLib.Menu;
            if (slot.directory.is_local || !slot.directory.can_open_files) {
                show_menu.remove (1); /* Do not show "Show Remote Thumbnails" option when in local folder or when not supported */
            }
            return show_menu;
        }

        private GLib.MenuModel? build_menu_open (ref Gtk.Builder builder) {

            var menu = new GLib.Menu ();
            GLib.MenuModel? app_submenu;

            string label = _("Invalid");
            unowned GLib.List<unowned GOF.File> selection = get_files_for_action ();
            unowned GOF.File selected_file = selection.data;

            if (can_open_file (selected_file)) {
                if (!selected_file.is_folder () && selected_file.is_executable ()) {
                    label = _("Run");
                    menu.append (label, "selection.open");
                } else if (default_app != null) {
                    if (default_app.get_id () != Marlin.APP_ID + ".desktop") {
                        label = (_("Open in %s")).printf (default_app.get_display_name ());
                        menu.append (label, "selection.open_with_default");
                    }
                }
            }

            app_submenu = build_submenu_open_with_applications (ref builder, selection);

            if (app_submenu != null && app_submenu.get_n_items () > 0) {
                if (selected_file.is_folder () || selected_file.is_root_network_folder ()) {
                    label = _("Open in");
                } else {
                    label = _("Open with");
                }

                menu.append_submenu (label, app_submenu);
            }

            return menu as MenuModel;
        }

        private GLib.MenuModel? build_submenu_open_with_applications (ref Gtk.Builder builder,
                                                                      GLib.List<GOF.File> selection) {

            var open_with_submenu = new GLib.Menu ();
            open_with_apps = null;

            if (common_actions.get_action_enabled ("open_in")) {
                open_with_submenu.append_section (null, builder.get_object ("open-in") as GLib.MenuModel);
                if (selection.data.is_mountable () || selection.data.is_root_network_folder ()) {
                    return open_with_submenu;
                }
            }

            if (can_open_file (selection.data)) {
                open_with_apps = Marlin.MimeActions.get_applications_for_files (selection);
                if (selection.data.is_executable () == false) {
                    filter_default_app_from_open_with_apps ();
                }

                filter_this_app_from_open_with_apps ();

                if (open_with_apps != null) {
                    var apps_section = new GLib.Menu ();
                    int index = -1;
                    int count = 0;
                    string last_label = "";
                    string last_exec = "";

                    foreach (var app in open_with_apps) {
                        index++;
                        if (app != null && app is AppInfo) {
                            var label = app.get_display_name ();
                            var exec = app.get_executable ().split (" ")[0];
                            if (label != last_label || exec != last_exec) {
                                apps_section.append (label, "selection.open_with_app::" + index.to_string ());
                                count++;
                            }

                            last_label = label.dup ();
                            last_exec = exec.dup ();
                        }
                    };

                    if (count >= 0) {
                        open_with_submenu.append_section (null, apps_section);
                    }
                }

                if (selection != null && selection.first ().next == null) { // Only one selected
                    var other_app_menu = new GLib.Menu ();
                    other_app_menu.append ( _("Other Application…"), "selection.open_with_other_app");
                    open_with_submenu.append_section (null, other_app_menu);
                }
            }

            return open_with_submenu as GLib.MenuModel;
        }

        private GLib.MenuModel? build_menu_templates () {
            /* Potential optimisation - do just once when app starts or view created */
            templates = null;
            var template_path = GLib.Environment.get_user_special_dir (GLib.UserDirectory.TEMPLATES);
            var template_folder = GLib.File.new_for_path (template_path);
            load_templates_from_folder (template_folder);

            if (templates.length () == 0) {
                return null;
            }

            var templates_menu = new GLib.Menu ();
            var templates_submenu = new GLib.Menu ();
            int index = 0;
            int count = 0;

            templates.@foreach ((template) => {
                var label = template.get_basename ();
                var ftype = template.query_file_type (GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
                if (ftype == GLib.FileType.DIRECTORY) {
                    if (template == template_folder) {
                        label = _("Templates");
                    }

                    var submenu = new GLib.MenuItem.submenu (label, templates_submenu);
                    templates_menu.append_item (submenu);
                    templates_submenu = new GLib.Menu ();
                } else {
                    templates_submenu.append (label, "background.create_from::" + index.to_string ());
                    count ++;
                }

                index++;
            });

            templates_menu.append_section (null, templates_submenu);

            if (count < 1) {
                return null;
            } else {
                return templates_menu as MenuModel;
            }
        }

        private void update_menu_actions () {
            if (is_frozen || !slot.directory.can_load) {
                return;
            }

            unowned GLib.List<GOF.File> selection = get_files_for_action ();
            GOF.File file;

            bool is_selected = selection != null;
            bool more_than_one_selected = (is_selected && selection.first ().next != null);
            bool single_folder = false;
            bool only_folders = selection_only_contains_folders (selection);
            bool can_rename = false;
            bool can_show_properties = false;
            bool can_copy = false;
            bool can_open = false;
            bool can_paste_into = false;
            bool can_bookmark = false;

            if (is_selected) {
                file = selection.data;
                if (file != null) {
                    single_folder = (!more_than_one_selected && file.is_folder ());
                    can_rename = is_writable;
                    can_paste_into = single_folder && file.is_writable () ;
                } else {
                    critical ("File in selection is null");
                }
            } else {
                file = slot.directory.file;
                single_folder = (!more_than_one_selected && file.is_folder ());
                can_paste_into = is_writable;
            }

            /* Both folder and file can be bookmarked if local, but only remote folders can be bookmarked
             * because remote file bookmarks do not work correctly for unmounted locations */
            can_bookmark = (!more_than_one_selected || single_folder) &&
                           (slot.directory.is_local ||
                           (file.get_ftype () != null && file.get_ftype () == "inode/directory") ||
                           file.is_smb_server ());

            can_copy = file.is_readable ();
            can_open = can_open_file (file);
            can_show_properties = !(in_recent && more_than_one_selected);

            action_set_enabled (common_actions, "paste_into", can_paste_into);
            action_set_enabled (common_actions, "open_in", only_folders);
            action_set_enabled (selection_actions, "rename", is_selected && !more_than_one_selected && can_rename);
            action_set_enabled (selection_actions, "view_in_location", is_selected);
            action_set_enabled (selection_actions, "open", is_selected && !more_than_one_selected && can_open);
            action_set_enabled (selection_actions, "open_with_app", can_open);
            action_set_enabled (selection_actions, "open_with_default", can_open);
            action_set_enabled (selection_actions, "open_with_other_app", can_open);
            action_set_enabled (selection_actions, "cut", is_writable && is_selected);
            action_set_enabled (selection_actions, "trash", is_writable && slot.directory.has_trash_dirs);
            action_set_enabled (selection_actions, "delete", is_writable);
            action_set_enabled (common_actions, "properties", can_show_properties);
            action_set_enabled (common_actions, "bookmark", can_bookmark);
            action_set_enabled (common_actions, "copy", !in_trash && can_copy);
            action_set_enabled (common_actions, "copy_link", !in_trash && !in_recent && can_copy);
            action_set_enabled (common_actions, "bookmark", !more_than_one_selected);

            update_default_app (selection);
            update_menu_actions_sort ();
        }

        private void update_menu_actions_sort () {
            int sort_column_id;
            Gtk.SortType sort_order;

            if (model.get_sort_column_id (out sort_column_id, out sort_order)) {
                GLib.Variant val = new GLib.Variant.string (get_string_from_column_id (sort_column_id));
                action_set_state (background_actions, "sort_by", val);
                val = new GLib.Variant.boolean (sort_order == Gtk.SortType.DESCENDING);
                action_set_state (background_actions, "reverse", val);
                val = new GLib.Variant.boolean (GOF.Preferences.get_default ().sort_directories_first);
                action_set_state (background_actions, "folders_first", val);
            }
        }

        private void update_default_app (GLib.List<unowned GOF.File> selection) {
            default_app = Marlin.MimeActions.get_default_application_for_files (get_files_for_action ());
            return;
        }

    /** Menu helpers */

        private void action_set_enabled (GLib.SimpleActionGroup? action_group, string name, bool enabled) {
            if (action_group != null) {
                GLib.SimpleAction? action = (action_group.lookup_action (name) as GLib.SimpleAction);
                if (action != null) {
                    action.set_enabled (enabled);
                    return;
                }
            }
            critical ("Action name not found: %s - cannot enable", name);
        }

        private bool action_get_enabled (GLib.SimpleActionGroup? action_group, string name) {
            if (action_group != null) {
                GLib.SimpleAction? action = (action_group.lookup_action (name) as GLib.SimpleAction);
                if (action != null) {
                    return action.enabled;
                }
            }
            critical ("Action name not found: %s - cannot get enabled", name);
            return false;
        }

        private void action_set_state (GLib.SimpleActionGroup? action_group, string name, GLib.Variant val) {
            if (action_group != null) {
                GLib.SimpleAction? action = (action_group.lookup_action (name) as GLib.SimpleAction);
                if (action != null) {
                    action.set_state (val);
                    return;
                }
            }
            critical ("Action name not found: %s - cannot set state", name);
        }

        private void load_templates_from_folder (GLib.File template_folder) {
            GLib.List<GLib.File> file_list = null;
            GLib.List<GLib.File> folder_list = null;

            GLib.FileEnumerator enumerator;
            var f_attr = GLib.FileAttribute.STANDARD_NAME + GLib.FileAttribute.STANDARD_TYPE;
            var flags = GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS;
            try {
                enumerator = template_folder.enumerate_children (f_attr, flags, null);
                uint count = templates.length ();
                GLib.File location;
                GLib.FileInfo? info = enumerator.next_file (null);

                while (count < MAX_TEMPLATES && (info != null)) {
                    location = template_folder.get_child (info.get_name ());
                    if (info.get_file_type () == GLib.FileType.DIRECTORY) {
                        folder_list.prepend (location);
                    } else {
                        file_list.prepend (location);
                        count ++;
                    }

                    info = enumerator.next_file (null);
                }
            } catch (GLib.Error error) {
                return;
            }

            if (file_list.length () > 0) {
                file_list.sort ((a,b) => {
                    return strcmp (a.get_basename ().down (), b.get_basename ().down ());
                });

                foreach (var file in file_list) {
                    templates.append (file);
                }

                templates.append (template_folder);
            }

            if (folder_list.length () > 0) {
                /* recursively load templates from subdirectories */
                folder_list.@foreach ((folder) => {
                    load_templates_from_folder (folder);
                });
            }
        }

        private void filter_this_app_from_open_with_apps () {
            unowned GLib.List<AppInfo> l = open_with_apps;

            while (l != null) {
                if (l.data is AppInfo) {
                    if (app_is_this_app (l.data)) {
                        open_with_apps.delete_link (l);
                        break;
                    }
                } else {
                    open_with_apps.delete_link (l);
                    l = open_with_apps;
                    if (l == null) {
                        break;
                    }
                }

                l = l.next;
            }
        }

        private bool app_is_this_app (AppInfo ai) {
            string exec_name = ai.get_executable ();

            return (exec_name == APP_NAME || exec_name == TERMINAL_NAME);
        }

        private void filter_default_app_from_open_with_apps () {
            if (default_app == null) {
                return;
            }

            string? id1, id2;
            id2 = default_app.get_id ();

            if (id2 != null) {
                unowned GLib.List<AppInfo> l = open_with_apps;

                while (l != null && l.data is AppInfo) {
                    id1 = l.data.get_id ();

                    if (id1 != null && id1 == id2) {
                        open_with_apps.delete_link (l);
                        break;
                    }

                    l = l.next;
                }
            }
        }

        /** Menu action functions */

        private void create_from_template (GLib.File template) {
            /* Block the async directory file monitor to avoid generating unwanted "add-file" events */
            slot.directory.block_monitor ();
            var new_name = (_("Untitled %s")).printf (template.get_basename ());
            Marlin.FileOperations.new_file_from_template (this,
                                                          null,
                                                          slot.location,
                                                          new_name,
                                                          template,
                                                          create_file_done,
                                                          this);
        }

        private void open_files_with (GLib.AppInfo app, GLib.List<GOF.File> files) {
            Marlin.MimeActions.open_multiple_gof_files_request (files, this, app);
        }


/** Thumbnail handling */
        private void schedule_thumbnail_timeout () {
            /* delay creating the idle until the view has finished loading.
             * this is done because we only can tell the visible range reliably after
             * all items have been added and we've perhaps scrolled to the file remembered
             * the last time */

            assert (slot is GOF.AbstractSlot && slot.directory != null);

            if (thumbnail_source_id != 0 ||
                (!slot.directory.is_local && !show_remote_thumbnails) ||
                 !slot.directory.can_open_files ||
                 slot.directory.is_loading ()) {

                    return;
            }

            /* Do not cancel existing requests to avoid missing thumbnails */
            cancel_timeout (ref thumbnail_source_id);
            /* In order to improve performance of the Icon View when there are a large number of files,
             * we freeze child notifications while the view is being scrolled or resized.
             * The timeout is restarted for each scroll or size allocate event */
            cancel_timeout (ref freeze_source_id);
            freeze_child_notify ();
            freeze_source_id = Timeout.add (100, () => {
                if (thumbnail_source_id > 0) {
                    return true;
                }
                thaw_child_notify ();
                freeze_source_id = 0;
                return false;
            });

            /* Views with a large number of files take longer to redraw (especially IconView) so
             * we wait longer for scrolling to stop before updating the thumbnails */
            uint delay = uint.min (50 + slot.displayed_files_count / 10, 500);
            thumbnail_source_id = GLib.Timeout.add (delay, () => {

                /* compute visible item range */
                Gtk.TreePath start_path, end_path, path;
                Gtk.TreePath sp, ep;
                Gtk.TreeIter iter;
                bool valid_iter;
                GOF.File? file;
                GLib.List<GOF.File> visible_files = null;
                uint actually_visible = 0;

                if (get_visible_range (out start_path, out end_path)) {
                    sp = start_path;
                    ep = end_path;

                    /* To improve performance for large folders we thumbnail files on either side of visible region
                     * as well.  The delay is mainly in redrawing the view and this reduces the number of updates and
                     * redraws necessary when scrolling */
                    int count = 50;
                    while (start_path.prev () && count > 0) {
                        count--;
                    }

                    count = 50;
                    while (count > 0) {
                        end_path.next ();
                        count--;
                    }

                    /* iterate over the range to collect all files */
                    valid_iter = model.get_iter (out iter, start_path);
                    while (valid_iter && thumbnail_source_id > 0) {
                        file = model.file_for_iter (iter); // Maybe null if dummy row
                        path = model.get_path (iter);

                        if (file != null) {
                            file.query_thumbnail_update (); // Ensure thumbstate up to date
                            /* Ask thumbnailer only if ThumbState UNKNOWN */
                            if ((GOF.File.ThumbState.UNKNOWN in (GOF.File.ThumbState)(file.flags))) {
                                visible_files.prepend (file);
                                if (path.compare (sp) >= 0 && path.compare (ep) <= 0) {
                                    actually_visible++;
                                }
                            }

                            if (plugins != null) {
                                plugins.update_file_info (file);
                            }

                        }
                        /* check if we've reached the end of the visible range */
                        if (path.compare (end_path) != 0) {
                            valid_iter = get_next_visible_iter (ref iter);
                        } else {
                            valid_iter = false;
                        }
                    }
                }

                /* This is the only place that new thumbnail files are created */
                /* Do not trigger a thumbnail request unless there are unthumbnailed files actually visible
                 * and there has not been another event (which would zero the thumbnail_source_if) */
                if (actually_visible > 0 && thumbnail_source_id > 0) {
                    thumbnailer.queue_files (visible_files, out thumbnail_request, large_thumbnails);
                } else {
                    draw_when_idle ();
                }

                thumbnail_source_id = 0;

                return false;
            });
        }


/** HELPER AND CONVENIENCE FUNCTIONS */
        /** This helps ensure that file item updates are reflected on screen without too many redraws **/
        uint draw_timeout_id = 0;
        private void draw_when_idle () {
            if (draw_timeout_id > 0) {
                return;
            }

            draw_timeout_id = Timeout.add (100, () => {
                draw_timeout_id = 0;
                view.queue_draw ();
                return false;
            });
        }

        protected void block_model () {
            model.row_deleted.disconnect (on_row_deleted);
        }

        protected void unblock_model () {
            model.row_deleted.connect (on_row_deleted);
        }

        private Gtk.Widget? get_real_view () {
            return (this as Gtk.Bin).get_child ();
        }

        private void connect_drag_timeout_motion_and_release_events () {
            var real_view = get_real_view ();
            real_view.button_release_event.connect (on_drag_timeout_button_release);
            real_view.motion_notify_event.connect (on_drag_timeout_motion_notify);
        }

        private void disconnect_drag_timeout_motion_and_release_events () {
            if (drag_timer_id == 0) {
                return;
            }

            var real_view = get_real_view ();
            real_view.button_release_event.disconnect (on_drag_timeout_button_release);
            real_view.motion_notify_event.disconnect (on_drag_timeout_motion_notify);
        }

        private void start_drag_scroll_timer (Gdk.DragContext context) {
            drag_scroll_timer_id = GLib.Timeout.add_full (GLib.Priority.LOW,
                                                          50,
                                                          () => {
                Gtk.Widget widget = (this as Gtk.Bin).get_child ();
                Gdk.Device pointer = context.get_device ();
                Gdk.Window window = widget.get_window ();
                int x, y, w, h;

                window.get_device_position (pointer, out x, out y, null);
                window.get_geometry (null, null, out w, out h);

                scroll_if_near_edge (y, h, 20, get_vadjustment ());
                scroll_if_near_edge (x, w, 20, get_hadjustment ());
                return true;
            });
        }

        private void scroll_if_near_edge (int pos, int dim, int threshold, Gtk.Adjustment adj) {
                /* check if we are near the edge */
                int band = 2 * threshold;
                int offset = pos - band;
                if (offset > 0) {
                    offset = int.max (band - (dim - pos), 0);
                }

                if (offset != 0) {
                    /* change the adjustment appropriately */
                    var val = adj.get_value ();
                    var lower = adj.get_lower ();
                    var upper = adj.get_upper ();
                    var page = adj.get_page_size ();

                    val = (val + 2 * offset).clamp (lower, upper - page);
                    adj.set_value (val);
                }
        }

        private void remove_marlin_icon_info_cache (GOF.File file) {
            string? path = file.get_thumbnail_path ();

            if (path != null) {
                Marlin.IconSize s;

                for (int z = Marlin.ZoomLevel.SMALLEST;
                     z <= Marlin.ZoomLevel.LARGEST;
                     z++) {

                    s = Marlin.zoom_level_to_icon_size ((Marlin.ZoomLevel)z);
                    Marlin.IconInfo.remove_cache (path, s, get_scale_factor ());
                }
            }
        }

        /* For actions on the background we need to return the current slot directory, but this
         * should not be added to the list of selected files
         */
        private unowned GLib.List<GOF.File> get_files_for_action () {
            unowned GLib.List<GOF.File> action_files = null;
            update_selected_files_and_menu ();

            if (selected_files == null) {
                action_files.prepend (slot.directory.file);
            } else if (in_recent) {
                selected_files.@foreach ((file) => {
                    var goffile = GOF.File.get_by_uri (file.get_display_target_uri ());
                    goffile.query_update ();
                    action_files.prepend (goffile);
                });

                action_files.reverse ();
            } else {
                action_files = selected_files;
            }

            return action_files;
        }

        protected void on_view_items_activated () {
            activate_selected_items (Marlin.OpenFlag.DEFAULT);
        }

        protected void on_view_selection_changed () {
            selected_files_invalid = true;
        }

/** Keyboard event handling **/

        /** Returns true if the code parameter matches the keycode of the keyval parameter for
          * any keyboard group or level (in order to allow for non-QWERTY keyboards) **/
        protected bool match_keycode (uint keyval, uint code, int level) {
            Gdk.KeymapKey [] keys;
            Gdk.Keymap keymap = Gdk.Keymap.get_default ();
            if (keymap.get_entries_for_keyval (keyval, out keys)) {
                foreach (var key in keys) {
                    if (code == key.keycode && level == key.level) {
                        return true;
                    }
                }
            }

            return false;
        }

        protected virtual bool on_view_key_press_event (Gdk.EventKey event) {
            if (is_frozen || event.is_modifier == 1) {
                return true;
            }

            cancel_hover ();

            uint keyval;
            int eff_grp, level;
            Gdk.ModifierType consumed_mods;

            if (!Gdk.Keymap.get_default ().translate_keyboard_state (event.hardware_keycode,
                                                                     event.state, event.group,
                                                                     out keyval, out eff_grp,
                                                                     out level, out consumed_mods)) {
                warning ("translate keyboard state failed");
                return false;
            }

            keyval = 0;
            for (uint key = 32; key < 128; key++) {
                if (match_keycode (key, event.hardware_keycode, level)) {
                    keyval = key;
                    break;
                }
            }

            if (keyval == 0) {
                debug ("Could not match hardware code to ASCII hotkey");
                keyval = event.keyval;
                consumed_mods = 0;
            }

            var mods = (event.state & ~consumed_mods) & Gtk.accelerator_get_default_mod_mask ();
            bool no_mods = (mods == 0);
            bool shift_pressed = ((mods & Gdk.ModifierType.SHIFT_MASK) != 0);
            bool only_shift_pressed = shift_pressed && ((mods & ~Gdk.ModifierType.SHIFT_MASK) == 0);
            bool control_pressed = ((mods & Gdk.ModifierType.CONTROL_MASK) != 0);
            bool alt_pressed = ((mods & Gdk.ModifierType.MOD1_MASK) != 0);
            bool other_mod_pressed = (((mods & ~Gdk.ModifierType.SHIFT_MASK) & ~Gdk.ModifierType.CONTROL_MASK) != 0);
            bool only_control_pressed = control_pressed && !other_mod_pressed; /* Shift can be pressed */
            bool only_alt_pressed = alt_pressed && ((mods & ~Gdk.ModifierType.MOD1_MASK) == 0);
            bool in_trash = slot.location.has_uri_scheme ("trash");
            bool in_recent = slot.location.has_uri_scheme ("recent");
            bool res = false;

            switch (keyval) {
                case Gdk.Key.F10:
                    if (only_control_pressed) {
                        show_or_queue_context_menu (event);
                        res = true;
                    }

                    break;

                case Gdk.Key.F2:
                    if (no_mods && selection_actions.get_action_enabled ("rename")) {
                        rename_selected_file ();
                        res = true;
                    }

                    break;

                case Gdk.Key.Delete:
                case Gdk.Key.KP_Delete:
                    if (!is_writable) {
                        PF.Dialogs.show_warning_dialog (_("Cannot remove files from here"),
                                                        _("You do not have permission to change this location"),
                                                        window as Gtk.Window);
                    } else if (!renaming) {
                        trash_or_delete_selected_files (in_trash || is_admin || only_shift_pressed);
                        res = true;
                    }

                    break;

                case Gdk.Key.space:
                    if (view_has_focus () && !in_trash) {
                        activate_selected_items (Marlin.OpenFlag.NEW_TAB);
                        res = true;
                    }

                    break;

                case Gdk.Key.Return:
                case Gdk.Key.KP_Enter:
                    if (in_trash) {
                        break;
                    } else if (in_recent) {
                        activate_selected_items (Marlin.OpenFlag.DEFAULT);
                    } else if (only_shift_pressed) {
                        activate_selected_items (Marlin.OpenFlag.NEW_TAB);
                    } else if (only_alt_pressed) {
                        common_actions.activate_action ("properties", null);
                    } else if (no_mods) {
                         activate_selected_items (Marlin.OpenFlag.DEFAULT);
                    } else {
                        break;
                    }

                    res = true;
                    break;

                case Gdk.Key.minus:
                    if (alt_pressed && control_pressed) {
                        Gtk.TreePath? path = get_path_at_cursor ();
                        if (path != null && path_is_selected (path)) {
                            unselect_path (path);
                        }

                        res = true;
                    }

                    break;

                case Gdk.Key.plus:
                case Gdk.Key.equal: /* Do not require Shift as well (otherwise 4 key shortcut)  */
                    if (alt_pressed && control_pressed) {
                        Gtk.TreePath? path = get_path_at_cursor ();
                        if (path != null && !path_is_selected (path)) {
                            select_path (path);
                        }

                        res = true;
                    }

                    break;

                case Gdk.Key.Escape:
                    if (no_mods) {
                        unselect_all ();
                    }

                    break;

                case Gdk.Key.Menu:
                case Gdk.Key.MenuKB:
                    if (no_mods) {
                        show_context_menu (event);
                        res = true;
                    }

                    break;

                case Gdk.Key.N:
                    if (control_pressed) {
                        new_empty_folder ();
                        res = true;
                    }

                    break;

                case Gdk.Key.a:
                    if (control_pressed) {
                        update_selected_files_and_menu (); /* Ensure all_selected correct */

                        if (all_selected) {
                            unselect_all ();
                        } else {
                            select_all ();
                        }

                        res = true;
                    }

                    break;

                case Gdk.Key.A:
                    if (control_pressed) {
                        invert_selection ();
                        res = true;
                    }

                    break;

                case Gdk.Key.Up:
                case Gdk.Key.Down:
                case Gdk.Key.Left:
                case Gdk.Key.Right:
                    unowned GLib.List<GOF.File> selection = get_selected_files ();
                    if (only_alt_pressed && keyval == Gdk.Key.Down) {
                        /* Only open a single selected folder */

                        if (selection != null &&
                            selection.first ().next == null &&
                            selection.data.is_folder ()) {

                            load_location (selection.data.location);
                            res = true;
                        }

                        break;
                    }

                    res = move_cursor (keyval, only_shift_pressed);

                    break;

                case Gdk.Key.c:
                case Gdk.Key.C:
                    if (only_control_pressed) {
                        /* Caps Lock interferes with `shift_pressed` boolean so use another way */
                        var caps_on = Gdk.Keymap.get_default ().get_caps_lock_state ();
                        var cap_c = keyval == Gdk.Key.C;

                        if (caps_on != cap_c) { /* Shift key pressed */
                            common_actions.activate_action ("copy_link", null);
                        } else {
                        /* Should not copy files in the trash - cut instead */
                            if (in_trash) {
                                PF.Dialogs.show_warning_dialog (_("Cannot copy files that are in the trash"),
                                                                _("Cutting the selection instead"),
                                                                window as Gtk.Window);

                                selection_actions.activate_action ("cut", null);
                            } else {
                                common_actions.activate_action ("copy", null);
                            }
                        }

                        res = true;
                    }

                    break;

                case Gdk.Key.v:
                case Gdk.Key.V:
                    if (only_control_pressed) {
                        if (!in_recent && is_writable) {
                            /* Will drop any existing selection and paste into current directory */
                            action_set_enabled (common_actions, "paste_into", true);
                            unselect_all ();
                            common_actions.activate_action ("paste_into", null);
                        } else {
                            PF.Dialogs.show_warning_dialog (_("Cannot paste files here"),
                                                            _("You do not have permission to change this location"),
                                                            window as Gtk.Window);
                        }

                        res = true;
                    }

                    break;

                case Gdk.Key.x:
                case Gdk.Key.X:
                    if (only_control_pressed) {
                        if (is_writable) {
                            selection_actions.activate_action ("cut", null);
                        } else {
                            PF.Dialogs.show_warning_dialog (_("Cannot remove files from here"),
                                                            _("You do not have permission to change this location"),
                                                            window as Gtk.Window);
                        }

                        res = true;
                    }

                    break;

                default:
                    break;
            }

            Idle.add (() => {
                update_selected_files_and_menu ();
                return false;
            });

            return res;
        }

        protected bool on_motion_notify_event (Gdk.EventMotion event) {
            Gtk.TreePath? path = null;

            if (renaming) {
                return true;
            }

            click_zone = get_event_position_info ((Gdk.EventButton)event, out path, false);

            if (click_zone != previous_click_zone) {
                var win = view.get_window ();
                switch (click_zone) {
                    case ClickZone.ICON:
                    case ClickZone.NAME:
                        if (single_click_mode) {
                            win.set_cursor (activatable_cursor);
                        }
                        break;

                    default:
                        win.set_cursor (selectable_cursor);
                        break;
                }

                previous_click_zone = click_zone;
            }

            if (is_frozen) {
                return false;
            }

            if ((path != null && hover_path == null) ||
                (path == null && hover_path != null) ||
                (path != null && hover_path != null && path.compare (hover_path) != 0)) {

                /* cannot get file info while network disconnected */
                if (slot.directory.is_local || NetworkMonitor.get_default ().get_network_available ()) {
                    /* cannot get file info while network disconnected. */
                    GOF.File? target_file;
                    GOF.File? file = path != null ? model.file_for_path (path) : null;

                    if (file != null && slot.directory.is_recent) {
                        target_file = GOF.File.get_by_uri (file.get_display_target_uri ());
                        target_file.ensure_query_info ();
                    } else {
                        target_file = file;
                    }

                    item_hovered (target_file);
                    hover_path = path;
                }
            }

            return false;
        }

        protected bool on_leave_notify_event (Gdk.EventCrossing event) {
            item_hovered (null); /* Ensure overlay statusbar disappears */
            hover_path = null;
            return false;
        }

        protected virtual bool on_scroll_event (Gdk.EventScroll event) {
            if ((event.state & Gdk.ModifierType.CONTROL_MASK) == 0) {
                double increment = 0.0;

                switch (event.direction) {
                    case Gdk.ScrollDirection.LEFT:
                        increment = 5.0;
                        break;

                    case Gdk.ScrollDirection.RIGHT:
                        increment = -5.0;
                        break;

                    case Gdk.ScrollDirection.SMOOTH:
                        double delta_x;
                        event.get_scroll_deltas (out delta_x, null);
                        increment = delta_x * 10.0;
                        break;

                    default:
                        break;
                }

                if (increment != 0.0) {
                    slot.horizontal_scroll_event (increment);
                }
            }
            return handle_scroll_event (event);
        }

    /** name renderer signals */
        protected void on_name_editing_started (Gtk.CellEditable? editable, string path_string) {
            if (renaming) { /* Ignore duplicate editing-started signal*/
                return;
            }

            renaming = true;

            var editable_widget = editable as Marlin.AbstractEditableLabel?;
            if (editable_widget != null) {
                original_name = editable_widget.get_chars (0, -1);
                var path = new Gtk.TreePath.from_string (path_string);
                Gtk.TreeIter? iter = null;
                model.get_iter (out iter, path);
                GOF.File? file = null;
                model.@get (iter, FM.ListModel.ColumnID.FILE_COLUMN, out file);
                int start_offset= 0, end_offset = -1;
                /* Select whole name if the file is a folder, otherwise do not select the extension */
                if (!file.is_folder ()) {
                    PF.FileUtils.get_rename_region (original_name, out start_offset, out end_offset, false);
                }
                editable_widget.select_region (start_offset, end_offset);
            } else {
                warning ("Editable widget is null");
                on_name_editing_canceled ();
            }
        }

        protected void on_name_editing_canceled () {
            renaming = false;
            name_renderer.editable = false;
            proposed_name = "";
            is_frozen = false;
            grab_focus ();
        }

        protected void on_name_edited (string path_string, string new_name) {
            /* Must not re-enter */
            if (!renaming || proposed_name == new_name) {
                return;
            }

            proposed_name = "";
            if (new_name != "") {
                var path = new Gtk.TreePath.from_string (path_string);
                Gtk.TreeIter? iter = null;
                model.get_iter (out iter, path);

                GOF.File? file = null;
                model.@get (iter, FM.ListModel.ColumnID.FILE_COLUMN, out file);

                /* Only rename if name actually changed */
                /* Because GOF.File.rename does not work correctly for remote files we handle ourselves */

                if (new_name != original_name) {
                    proposed_name = new_name;
                    set_file_display_name (file.location, new_name, after_rename);
                } else {
                    warning ("Name unchanged");
                    on_name_editing_canceled ();
                }
            } else {
                warning ("No new name");
                on_name_editing_canceled ();
            }

            /* do not cancel editing here - will be cancelled in rename callback */
        }

        public void set_file_display_name (GLib.File old_location, string new_name, PF.FileUtils.RenameCallbackFunc? f) {
            /* Wait for the file to be added to the model before trying to select and scroll to it */
            slot.directory.file_added.connect_after (after_renamed_file_added);
            PF.FileUtils.set_file_display_name (old_location, new_name, f);
        }

        public void after_rename (GLib.File file, GLib.File? result_location, GLib.Error? e) {
            on_name_editing_canceled ();
         }

        private void after_renamed_file_added (GOF.File? new_file) {
            slot.directory.file_added.disconnect (after_renamed_file_added);
            /* new_file will be null if rename failed */
            if (new_file != null) {
                select_and_scroll_to_gof_file (new_file);
            }
        }

        public virtual bool on_view_draw (Cairo.Context cr) {
            /* If folder is empty, draw the empty message in the middle of the view
             * otherwise pass on event */
            var style_context = get_style_context ();
            if (slot.directory.is_empty ()) {
                Pango.Layout layout = create_pango_layout (null);

                if (!style_context.has_class (Granite.STYLE_CLASS_H2_LABEL)) {
                    style_context.add_class (Granite.STYLE_CLASS_H2_LABEL);
                    style_context.add_class (Gtk.STYLE_CLASS_VIEW);
                }

                layout.set_markup (slot.get_empty_message (), -1);

                Pango.Rectangle? extents = null;
                layout.get_extents (null, out extents);

                double width = Pango.units_to_double (extents.width);
                double height = Pango.units_to_double (extents.height);

                double x = (double) get_allocated_width () / 2 - width / 2;
                double y = (double) get_allocated_height () / 2 - height / 2;
                get_style_context ().render_layout (cr, x, y, layout);

                return true;
            } else if (style_context.has_class (Granite.STYLE_CLASS_H2_LABEL)) {
                style_context.remove_class (Granite.STYLE_CLASS_H2_LABEL);
                style_context.remove_class (Gtk.STYLE_CLASS_VIEW);
            }

            return false;
        }

        protected virtual bool handle_primary_button_click (Gdk.EventButton event, Gtk.TreePath? path) {
            return true;
        }

        protected virtual bool handle_secondary_button_click (Gdk.EventButton event) {
            should_scroll = false;
            show_or_queue_context_menu (event);
            return true;
        }

        protected void block_drag_and_drop () {
            drag_data = view.get_data ("gtk-site-data");
            GLib.SignalHandler.block_matched (view, GLib.SignalMatchType.DATA, 0, 0, null, null, drag_data);
            dnd_disabled = true;
        }

        protected void unblock_drag_and_drop () {
            GLib.SignalHandler.unblock_matched (view, GLib.SignalMatchType.DATA, 0, 0, null, null, drag_data);
            dnd_disabled = false;
        }

        protected virtual bool on_view_button_press_event (Gdk.EventButton event) {
            if (renaming) {
                /* Cancel renaming */
                name_renderer.end_editing (true);
            }

            cancel_hover (); /* cancel overlay statusbar cancellables */

            /* Ignore if second button pressed before first released - not permitted during rubberbanding.
             * Multiple click produces an event without corresponding release event so do not block that.
             */
            if (dnd_disabled && event.type == Gdk.EventType.BUTTON_PRESS) {
                return true;
            }

            Gtk.TreePath? path = null;
            /* Remember position of click for detecting drag motion*/
            drag_x = (int)(event.x);
            drag_y = (int)(event.y);

            click_zone = get_event_position_info (event, out path, true);

            /* certain positions fake a no path blank zone */
            if (click_zone == ClickZone.BLANK_NO_PATH && path != null) {
                unselect_path (path);
                path = null;
            }

            click_path = path;

            var mods = event.state & Gtk.accelerator_get_default_mod_mask ();
            bool no_mods = (mods == 0);
            bool control_pressed = ((mods & Gdk.ModifierType.CONTROL_MASK) != 0);
            bool shift_pressed = ((mods & Gdk.ModifierType.SHIFT_MASK) != 0);
            bool other_mod_pressed = (((mods & ~Gdk.ModifierType.SHIFT_MASK) & ~Gdk.ModifierType.CONTROL_MASK) != 0);
            bool only_control_pressed = control_pressed && !other_mod_pressed; /* Shift can be pressed */
            bool only_shift_pressed = shift_pressed && !control_pressed && !other_mod_pressed;
            bool path_selected = (path != null ? path_is_selected (path) : false);
            bool on_blank = (click_zone == ClickZone.BLANK_NO_PATH || click_zone == ClickZone.BLANK_PATH);

            /* Block drag and drop to allow rubberbanding and prevent unwanted effects of
             * dragging on blank areas
             */
            block_drag_and_drop ();

            /* Handle un-modified clicks or control-clicks here else pass on.
             */
            if (!will_handle_button_press (no_mods, only_control_pressed, only_shift_pressed)) {
                return false;
            }

            if (!path_selected && click_zone != ClickZone.HELPER) {
                if (no_mods) {
                    unselect_all ();
                }
                /* If modifier pressed then default handler determines selection */
                if (no_mods && !on_blank) {
                    select_path (path, true); /* Cursor follows */
                }
            }

            bool result = false; // default false so events get passed to Window
            should_activate = false;
            should_scroll = true;

            switch (event.button) {
                case Gdk.BUTTON_PRIMARY: // button 1
                    /* Control-click should deselect previously selected path on key release (unless
                     * pointer moves)
                     */
                    should_deselect = only_control_pressed && path_selected;

                    switch (click_zone) {
                        case ClickZone.BLANK_NO_PATH:
                            break;

                        case ClickZone.BLANK_PATH:
                        case ClickZone.ICON:
                        case ClickZone.NAME:
                            bool double_click_event = (event.type == Gdk.EventType.@2BUTTON_PRESS);
                            /* determine whether should activate on key release (unless pointer moved)*/
                            should_activate = no_mods &&
                                              (!on_blank || activate_on_blank) &&
                                              (single_click_mode || double_click_event);

                            /* We need to decide whether to rubberband or drag&drop.
                             * Rubberband if modifer pressed or if not on the icon and either
                             * the item is unselected or activate_on_blank is not enabled.
                             */

                            if (!no_mods || (on_blank && (!activate_on_blank || !path_selected))) {
                                update_selected_files_and_menu ();
                                result = only_shift_pressed && handle_multi_select (path);
                            } else {
                                unblock_drag_and_drop ();
                                result = handle_primary_button_click (event, path);
                            }

                            break;

                        case ClickZone.HELPER:
                            bool multi_select = only_control_pressed || only_shift_pressed;
                            if (multi_select) { /* Treat like modified click on icon */
                                update_selected_files_and_menu ();
                                result = only_shift_pressed && handle_multi_select (path);
                            } else {
                                if (path_selected) {
                                    unselect_path (path);
                                } else {
                                    should_deselect = false;
                                    select_path (path, true); /* Cursor follow and selection preserved */
                                }

                                result = true; /* Prevent rubberbanding and deselection of other paths */
                            }
                            break;

                        case ClickZone.EXPANDER:
                            /* on expanders (if any) or xpad. Handle ourselves so that clicking
                             * on xpad also expands/collapses row (accessibility)*/
                            result = expand_collapse (path);
                            break;

                        case ClickZone.INVALID:
                            result = false; /* Allow rubberbanding */
                            break;

                        default:
                            break;
                    }

                    break;

                case Gdk.BUTTON_MIDDLE: // button 2
                    if (!path_is_selected (path)) {
                        select_path (path, true);
                    }

                    should_activate = true;
                    unblock_drag_and_drop ();
                    result = true;

                    break;

                case Gdk.BUTTON_SECONDARY: // button 3
                    if (click_zone == ClickZone.NAME ||
                        click_zone == ClickZone.BLANK_PATH ||
                        click_zone == ClickZone.ICON) {

                        select_path (path);
                    } else if (click_zone == ClickZone.INVALID) {
                        unselect_all ();
                    }

                    unblock_drag_and_drop ();
                    /* Ensure selected files list and menu actions are updated before context menu shown */
                    result = handle_secondary_button_click (event);
                    break;

                default:
                    result = handle_default_button_click (event);
                    break;
            }

            return result;
        }

        protected virtual bool on_view_button_release_event (Gdk.EventButton event) {
            if (dnd_disabled) {
                unblock_drag_and_drop ();
            }

            /* Ignore button release from click that started renaming.
             * View may lose focus during a drag if another tab is hovered, in which case
             * we do not want to refocus this view.
             * Under both these circumstances, 'should_activate' will be false */
            if (renaming || !view_has_focus ()) {
                return true;
            }

            slot.active (should_scroll);

            Gtk.Widget widget = get_real_view ();
            int x = (int)event.x;
            int y = (int)event.y;

            /* Only take action if pointer has not moved */
            if (!Gtk.drag_check_threshold (widget, drag_x, drag_y, x, y)) {
                if (should_activate) {
                    /* Need Idle else can crash with rapid clicking (avoid nested signals) */
                    Idle.add (() => {
                        var flag = event.button == Gdk.BUTTON_MIDDLE ? Marlin.OpenFlag.NEW_TAB :
                                                                       Marlin.OpenFlag.DEFAULT;

                        activate_selected_items (flag);
                        return false;
                    });
                } else if (should_deselect && click_path != null) {
                    unselect_path (click_path);
                    /* Only need to update selected files if changed by this handler */
                    Idle.add (() => {
                        update_selected_files_and_menu ();
                        return false;
                    });
                }
            }

            should_activate = false;
            should_deselect = false;
            click_path = null;
            return false;
        }

        public virtual void change_zoom_level () {
            icon_renderer.set_property ("zoom-level", zoom_level);
            name_renderer.set_property ("zoom-level", zoom_level);
            view.style_updated ();
        }

        private void start_renaming_file (GOF.File file) {
            if (is_frozen) {
                warning ("Trying to rename when frozen");
                return;
            }
            Gtk.TreeIter? iter = null;
            if (!model.get_first_iter_for_file (file, out iter)) {
                critical ("Failed to find rename file in model");
                return;
            }

            /* Freeze updates to the view to prevent losing rename focus when the tree view updates */
            is_frozen = true;
            Gtk.TreePath path = model.get_path (iter);

            uint count = 0;
            bool ok_next_time = false;
            Gtk.TreePath? start_path = null;
            /* Scroll to row to be renamed and then start renaming after a delay
             * so that file to be renamed is on screen.  This avoids the renaming being
             * cancelled */
            set_cursor_on_cell (path, name_renderer as Gtk.CellRenderer, false, false);
            GLib.Timeout.add (50, () => {
                /* Wait until view stops scrolling before starting to rename (up to 1 second)
                 * Scrolling is deemed to have stopped when the starting visible path is stable
                 * over two cycles */
                Gtk.TreePath? start = null;
                Gtk.TreePath? end = null;
                get_visible_range (out start, out end);
                count++;

                if (start_path == null || (count < 20 && start.compare (start_path) != 0)) {
                    start_path = start;
                    ok_next_time = false;
                    return true;
                } else if (!ok_next_time) {
                    ok_next_time = true;
                    return true;
                }

                /* set cursor_on_cell also triggers editing-started */
                name_renderer.editable = true;
                set_cursor_on_cell (path, name_renderer as Gtk.CellRenderer, true, false);
                return false;
            });

        }

        protected string get_string_from_column_id (int id) {
            switch (id) {
                case FM.ListModel.ColumnID.FILENAME:
                    return "name";

                case FM.ListModel.ColumnID.SIZE:
                    return "size";

                case FM.ListModel.ColumnID.TYPE:
                    return "type";

                case FM.ListModel.ColumnID.MODIFIED:
                    return "modified";

                default:
                    warning ("column id not recognised - using 'name'");
                    return "name";
            }
        }

        protected int get_column_id_from_string (string col_name) {
            switch (col_name) {
                case "name":
                    return FM.ListModel.ColumnID.FILENAME;

                case "size":
                    return FM.ListModel.ColumnID.SIZE;

                case "type":
                    return FM.ListModel.ColumnID.TYPE;

                case "modified":
                    return FM.ListModel.ColumnID.MODIFIED;

                default:
                    warning ("column name not recognised - using FILENAME");

                return FM.ListModel.ColumnID.FILENAME;
            }
        }

        protected void on_sort_column_changed () {
            int sort_column_id = 0;
            Gtk.SortType sort_order = 0;

            /* Setting file attributes fails when root */
            if (Posix.getuid () == 0) {
                return;
            }

            /* Ignore changes in model sort order while tree frozen (i.e. while still loading) to avoid resetting the
             * the directory file metadata incorrectly (bug 1511307).
             */
            if (tree_frozen || !model.get_sort_column_id (out sort_column_id, out sort_order)) {
                return;
            }

            var info = new GLib.FileInfo ();
            var dir = slot.directory;
            string sort_col_s = get_string_from_column_id (sort_column_id);
            string sort_order_s = (sort_order == Gtk.SortType.DESCENDING ? "true" : "false");
            info.set_attribute_string ("metadata::marlin-sort-column-id", sort_col_s);
            info.set_attribute_string ("metadata::marlin-sort-reversed", sort_order_s);

            /* Make sure directory file info matches metadata (bug 1511307).*/
            dir.file.info.set_attribute_string ("metadata::marlin-sort-column-id", sort_col_s);
            dir.file.info.set_attribute_string ("metadata::marlin-sort-reversed", sort_order_s);
            dir.file.sort_column_id = sort_column_id;
            dir.file.sort_order = sort_order;

            if (!is_admin) {
                dir.location.set_attributes_async.begin (info,
                                                   GLib.FileQueryInfoFlags.NONE,
                                                   GLib.Priority.DEFAULT,
                                                   null,
                                                   (obj, res) => {
                    try {
                        GLib.FileInfo inf;
                        dir.location.set_attributes_async.end (res, out inf);
                    } catch (GLib.Error e) {
                        warning ("Could not set file attributes - %s", e.message);
                    }
                });
            }
        }

        protected void cancel_timeout (ref uint id) {
            if (id > 0) {
                GLib.Source.remove (id);
                id = 0;
            }
        }

        protected void update_selected_files_and_menu () {
            if (selected_files_invalid) {
                selected_files = null;

                var selected_count = get_selected_files_from_model (out selected_files);
                all_selected = selected_count == slot.displayed_files_count;
                selected_files.reverse ();
                selected_files_invalid = false;
                update_menu_actions ();
                selection_changed (selected_files);
            }
        }

        protected virtual bool expand_collapse (Gtk.TreePath? path) {
            item_hovered (null);
            return true;
        }

        protected virtual bool handle_default_button_click (Gdk.EventButton event) {
            /* pass unhandled events to the Marlin.View.Window */
            return false;
        }

        protected virtual bool get_next_visible_iter (ref Gtk.TreeIter iter, bool recurse = true) {
            return model.iter_next (ref iter);
        }

        protected virtual void cancel () {
            grab_focus (); /* Cancel any renaming */
            cancel_hover ();
            cancel_thumbnailing ();
            cancel_drag_timer ();
            cancel_timeout (ref drag_scroll_timer_id);
            cancel_timeout (ref add_remove_file_timeout_id);
            /* List View will take care of unloading subdirectories */
        }

        private void cancel_hover () {
            item_hovered (null);
            hover_path = null;
        }

        public void close () {
            is_frozen = true; /* stop signal handlers running during destruction */
            cancel ();
            unselect_all ();
        }

        protected void invert_selection () {
            GLib.List<Gtk.TreeRowReference> selected_row_refs = null;

            foreach (Gtk.TreePath p in get_selected_paths ()) {
                selected_row_refs.prepend (new Gtk.TreeRowReference (model, p));
            }

            select_all ();

            if (selected_row_refs != null) {
                foreach (Gtk.TreeRowReference r in selected_row_refs) {
                    var p = r.get_path ();
                    if (p != null) {
                        unselect_path (p);
                    }
                }
            }
        }

        public void select_all () {
            tree_select_all ();
            update_selected_files_and_menu ();
        }

        public void unselect_all () {
            tree_unselect_all ();
            update_selected_files_and_menu ();
        }

        public void unselect_others () {
            tree_unselect_others ();
            update_selected_files_and_menu ();
        }

        public virtual void highlight_path (Gtk.TreePath? path) {}
        protected virtual Gtk.TreePath up (Gtk.TreePath path) {path.up (); return path;}
        protected virtual Gtk.TreePath down (Gtk.TreePath path) {path.down (); return path;}

/** Abstract methods - must be overridden*/
        public abstract GLib.List<Gtk.TreePath> get_selected_paths () ;
        public abstract Gtk.TreePath? get_path_at_pos (int x, int win);
        public abstract Gtk.TreePath? get_path_at_cursor ();
        public abstract void tree_select_all ();
        public abstract void tree_unselect_all ();
        public virtual void tree_unselect_others () {}
        public abstract void select_path (Gtk.TreePath? path, bool cursor_follows = false);
        public abstract void unselect_path (Gtk.TreePath? path);
        public abstract bool path_is_selected (Gtk.TreePath? path);
        public abstract bool get_visible_range (out Gtk.TreePath? start_path, out Gtk.TreePath? end_path);
        public abstract void set_cursor (Gtk.TreePath? path,
                                         bool start_editing,
                                         bool select,
                                         bool scroll_to_top);

        /* By default use the native widget cursor handling by returning false */
        protected virtual bool move_cursor (uint keyval, bool only_shift_pressed) {
            return false;
        }

        protected virtual bool will_handle_button_press (bool no_mods, bool only_control_pressed, bool only_shift_pressed) {
            if (!no_mods && !only_control_pressed) {
                return false;
            } else {
                return true;
            }
        }

        /* Multi-select could be by rubberbanding or modified clicking. Returning false
         * invokes the default widget handler.  IconView requires special handler */
        protected virtual bool handle_multi_select (Gtk.TreePath path) {return false;}

        protected abstract Gtk.Widget? create_view ();
        protected abstract Marlin.ZoomLevel get_set_up_zoom_level ();
        protected abstract Marlin.ZoomLevel get_normal_zoom_level ();
        protected abstract bool view_has_focus ();
        protected abstract uint get_selected_files_from_model (out GLib.List<unowned GOF.File> selected_files);
        protected abstract uint get_event_position_info (Gdk.EventButton event,
                                                         out Gtk.TreePath? path,
                                                         bool rubberband = false);

        protected abstract void scroll_to_cell (Gtk.TreePath? path,
                                                bool scroll_to_top);
        protected abstract void set_cursor_on_cell (Gtk.TreePath path,
                                                    Gtk.CellRenderer renderer,
                                                    bool start_editing,
                                                    bool scroll_to_top);
        protected abstract void freeze_tree ();
        protected abstract void thaw_tree ();
        protected new abstract void freeze_child_notify ();
        protected new abstract void thaw_child_notify ();
        protected abstract void connect_tree_signals ();
        protected abstract void disconnect_tree_signals ();
        protected abstract bool is_on_icon (int x, int y, Gdk.Rectangle area, Gdk.Pixbuf pix, bool rtl, ref bool on_helper);

/** Unimplemented methods
 *  fm_directory_view_parent_set ()  - purpose unclear
*/
    }
}

