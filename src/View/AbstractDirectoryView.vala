/*
* Copyright 2015-2020 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

/* Implementations of AbstractDirectoryView are
     * IconView
     * ListView
     * ColumnView
*/

namespace Files {
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

        const Gtk.TargetEntry [] DRAG_TARGETS = {
            {"text/plain", Gtk.TargetFlags.SAME_APP, Files.TargetType.STRING},
            {"text/uri-list", Gtk.TargetFlags.SAME_APP, Files.TargetType.TEXT_URI_LIST}
        };

        const Gtk.TargetEntry [] DROP_TARGETS = {
            {"text/uri-list", Gtk.TargetFlags.SAME_APP, Files.TargetType.TEXT_URI_LIST},
            {"text/uri-list", Gtk.TargetFlags.OTHER_APP, Files.TargetType.TEXT_URI_LIST},
            {"XdndDirectSave0", Gtk.TargetFlags.OTHER_APP, Files.TargetType.XDND_DIRECT_SAVE0},
            {"_NETSCAPE_URL", Gtk.TargetFlags.OTHER_APP, Files.TargetType.NETSCAPE_URL}
        };

        const Gdk.DragAction FILE_DRAG_ACTIONS = (Gdk.DragAction.COPY | Gdk.DragAction.MOVE | Gdk.DragAction.LINK);

        /* Menu Handling */
        const GLib.ActionEntry [] SELECTION_ENTRIES = {
            {"open", on_selection_action_open_executable},
            {"open-with-app", on_selection_action_open_with_app, "u"},
            {"open-with-default", on_selection_action_open_with_default},
            {"open-with-other-app", on_selection_action_open_with_other_app},
            {"rename", on_selection_action_rename},
            {"view-in-location", on_selection_action_view_in_location},
            {"forget", on_selection_action_forget},
            {"cut", on_selection_action_cut},
            {"trash", on_selection_action_trash},
            {"delete", on_selection_action_delete},
            {"restore", on_selection_action_restore}
        };

        const GLib.ActionEntry [] BACKGROUND_ENTRIES = {
            {"new", on_background_action_new, "s"},
            {"create-from", on_background_action_create_from, "s"},
            {"sort-by", on_background_action_sort_by_changed, "s", "'name'"},
            {"reverse", on_background_action_reverse_changed, null, "false"},
            {"folders-first", on_background_action_folders_first_changed, null, "true"},
            {"show-hidden", null, null, "false", change_state_show_hidden},
            {"show-remote-thumbnails", null, null, "true", change_state_show_remote_thumbnails},
            {"hide-local-thumbnails", null, null, "false", change_state_hide_local_thumbnails}
        };

        const GLib.ActionEntry [] COMMON_ENTRIES = {
            {"copy", on_common_action_copy},
            {"paste-into", on_common_action_paste_into},
            {"open-in", on_common_action_open_in, "s"},
            {"bookmark", on_common_action_bookmark},
            {"properties", on_common_action_properties},
            {"copy-link", on_common_action_copy_link}
        };

        GLib.SimpleActionGroup common_actions;
        GLib.SimpleActionGroup selection_actions;
        GLib.SimpleActionGroup background_actions;

        private ZoomLevel _zoom_level = ZoomLevel.NORMAL;
        public ZoomLevel zoom_level {
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
                return _zoom_level.to_icon_size ();
            }
        }

        protected ZoomLevel minimum_zoom = ZoomLevel.SMALLEST;
        protected ZoomLevel maximum_zoom = ZoomLevel.LARGEST;
        protected bool large_thumbnails = false;

        /* Used only when acting as drag source */
        int drag_x = 0;
        int drag_y = 0;
        int drag_button;
        uint drag_timer_id = 0;
        protected GLib.List<Files.File> source_drag_file_list = null;
        protected Gdk.Atom current_target_type = Gdk.Atom.NONE;

        /* Used only when acting as drag destination */
        uint drag_scroll_timer_id = 0;
        uint drag_enter_timer_id = 0;
        private bool destination_data_ready = false; /* whether the drop data was received already */
        private bool drop_occurred = false; /* whether the data was dropped */
        Files.File? drop_target_file = null;
        private GLib.List<GLib.File> destination_drop_file_list = null; /* the list of URIs that are contained in the drop data */
        Gdk.DragAction current_suggested_action = Gdk.DragAction.DEFAULT;
        Gdk.DragAction current_actions = Gdk.DragAction.DEFAULT;
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

        /* Used for blocking and unblocking DnD */
        protected bool dnd_disabled = false;
        private void* drag_data;

        /* support for generating thumbnails */
        int thumbnail_request = -1;
        uint thumbnail_source_id = 0;
        uint freeze_source_id = 0;
        Thumbnailer thumbnailer = null;

        /* Free space signal support */
        uint add_remove_file_timeout_id = 0;
        bool signal_free_space_change = false;

        /* Rename support */
        protected Files.TextRenderer? name_renderer = null;
        public string original_name = "";
        public string proposed_name = "";

        /* Support for zoom by smooth scrolling */
        private double total_delta_y = 0.0;

        /* Support for keeping cursor position after delete */
        private Gtk.TreePath deleted_path;

        /* UI options for button press handling */
        protected bool right_margin_unselects_all = false;
        protected bool on_directory = false;
        protected bool one_or_less = true;
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
        protected GLib.List<Files.File> selected_files = null;
        private bool selected_files_invalid = true;

        private static GLib.List<GLib.File> templates = null;

        private GLib.AppInfo default_app;
        private Gtk.TreePath? hover_path = null;

        public bool renaming {get; protected set; default = false;}

        private bool _is_frozen = false;
        public bool is_frozen {
            set {
                if (is_frozen != value) {
                    _is_frozen = value;
                    if (value) {
                        action_set_enabled (selection_actions, "cut", false);
                        action_set_enabled (common_actions, "copy", false);
                        action_set_enabled (common_actions, "paste-into", false);

                        /* Fix problems when navigating away from directory with large number
                         * of selected files (e.g. OverlayBar critical errors)
                         */
                        disconnect_tree_signals ();
                        clipboard.changed.disconnect (on_clipboard_changed);
                        view.key_press_event.disconnect (on_view_key_press_event);
                    } else {
                        view.key_press_event.connect (on_view_key_press_event);
                        clipboard.changed.connect (on_clipboard_changed);
                        connect_tree_signals ();

                        update_menu_actions ();

                    }
                }
            }

            get {
                return _is_frozen;
            }
        }

        public bool in_recent { get; private set; default = false; }

        protected bool tree_frozen { get; set; default = false; }
        private bool in_trash = false;
        private bool in_network_root = false;
        protected bool is_writable = false;
        protected bool is_loading;
        protected bool helpers_shown;
        protected bool show_remote_thumbnails {get; set; default = true;}
        protected bool hide_local_thumbnails {get; set; default = false;}

        private bool all_selected = false;

        private Gtk.Widget view;
        private unowned ClipboardManager clipboard;
        protected Files.ListModel model;
        protected Files.IconRenderer icon_renderer;
        protected unowned View.Slot slot;
        protected unowned View.Window window; /*For convenience - this can be derived from slot */
        protected static DndHandler dnd_handler = new DndHandler ();

        protected unowned Gtk.RecentManager recent;

        public signal void path_change_request (GLib.File location, Files.OpenFlag flag, bool new_root);
        public signal void item_hovered (Files.File? file);
        public signal void selection_changed (GLib.List<Files.File> gof_file);

        protected AbstractDirectoryView (View.Slot _slot) {
            slot = _slot;
            window = _slot.window;
            editable_cursor = new Gdk.Cursor.from_name (Gdk.Display.get_default (), "text");
            activatable_cursor = new Gdk.Cursor.from_name (Gdk.Display.get_default (), "pointer");
            selectable_cursor = new Gdk.Cursor.from_name (Gdk.Display.get_default (), "default");

            var app = (Files.Application)(GLib.Application.get_default ());
            clipboard = app.get_clipboard_manager ();
            recent = app.get_recent_manager ();

            thumbnailer = Thumbnailer.get ();
            thumbnailer.finished.connect ((req) => {
                if (req == thumbnail_request) {
                    thumbnail_request = -1;
                }

                draw_when_idle ();
            });

            model = new Files.ListModel ();

            Files.app_settings.bind ("show-remote-thumbnails",
                                                             this, "show_remote_thumbnails", SettingsBindFlags.GET);
            Files.app_settings.bind ("hide-local-thumbnails",
                                                             this, "hide_local_thumbnails", SettingsBindFlags.GET);

             /* Currently, "single-click rename" is disabled, matching existing UI
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

            set_up_zoom_level ();
            freeze_tree (); /* speed up loading of icon view. Thawed when directory loaded */


            connect_directory_handlers (slot.directory);
        }

        ~AbstractDirectoryView () {
            debug ("ADV destruct");
        }

        protected virtual void set_up_name_renderer () {
            name_renderer.editable = false;
            name_renderer.edited.connect (on_name_edited);
            name_renderer.editing_canceled.connect (on_name_editing_canceled);
            name_renderer.editing_started.connect (on_name_editing_started);
        }

        private void set_up_directory_view () {
            set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
            set_shadow_type (Gtk.ShadowType.NONE);

            popup_menu.connect (on_popup_menu);

            unrealize.connect (() => {
                clipboard.changed.disconnect (on_clipboard_changed);
            });

            realize.connect (() => {
                clipboard.changed.connect (on_clipboard_changed);
                on_clipboard_changed ();
            });

            scroll_event.connect (on_scroll_event);

            get_vadjustment ().value_changed.connect_after (() => {
                schedule_thumbnail_timeout ();
            });

            var prefs = (Files.Preferences.get_default ());
            prefs.notify["show-hidden-files"].connect (on_show_hidden_files_changed);
            prefs.notify["show-remote-thumbnails"].connect (on_show_remote_thumbnails_changed);
            prefs.notify["hide-local-thumbnails"].connect (on_hide_local_thumbnails_changed);
            prefs.notify["sort-directories-first"].connect (on_sort_directories_first_changed);

            model.set_should_sort_directories_first (Files.Preferences.get_default ().sort_directories_first);
            model.row_deleted.connect (on_row_deleted);
            /* Sort order of model is set after loading */
            model.sort_column_changed.connect (on_sort_column_changed);
        }

        private void set_up__menu_actions () {
            selection_actions = new GLib.SimpleActionGroup ();
            selection_actions.add_action_entries (SELECTION_ENTRIES, this);
            insert_action_group ("selection", selection_actions);

            background_actions = new GLib.SimpleActionGroup ();
            background_actions.add_action_entries (BACKGROUND_ENTRIES, this);
            insert_action_group ("background", background_actions);

            common_actions = new GLib.SimpleActionGroup ();
            common_actions.add_action_entries (COMMON_ENTRIES, this);
            insert_action_group ("common", common_actions);

            action_set_state (background_actions, "show-hidden",
                              Files.app_settings.get_boolean ("show-hiddenfiles"));

            action_set_state (background_actions, "show-remote-thumbnails",
                              Files.app_settings.get_boolean ("show-remote-thumbnails"));

            action_set_state (background_actions, "hide-local-thumbnails",
                              Files.app_settings.get_boolean ("hide-local-thumbnails"));
        }

        public void zoom_in () {
            zoom_level = zoom_level + 1;
        }

        public void zoom_out () {
            if (zoom_level > 0) {
                zoom_level = zoom_level - 1;
            }
        }

        public void zoom_normal () {
            zoom_level = get_normal_zoom_level ();
        }

        public void focus_first_for_empty_selection (bool select) {
            if (selected_files == null) {
                Idle.add_full (GLib.Priority.LOW, () => {
                    if (!tree_frozen) {
                        set_cursor (new Gtk.TreePath.from_indices (0), false, select, true);
                        return GLib.Source.REMOVE;
                    } else {
                        return GLib.Source.CONTINUE;
                    }
                });
            }
        }

        /* This function is only called by Slot in order to select a file item after loading has completed.
         * If called before initial loading is complete then tree_frozen is true.  Otherwise, e.g. when selecting search items
         * tree_frozen is false.
         */
        private ulong select_source_handler = 0;
        public void select_glib_files_when_thawed (GLib.List<GLib.File> location_list, GLib.File? focus_location) {
            var files_to_select_list = new Gee.LinkedList<Files.File> ();
            location_list.@foreach ((loc) => {
                files_to_select_list.add (Files.File.@get (loc));
            });

            GLib.File? focus_after_select = focus_location != null ? focus_location.dup () : null;

            /* Because the Icon View disconnects the model while loading, we need to wait until
             * the tree is thawed and the model reconnected before selecting the files.
             * Using a timeout helps ensure that the files appear in the model before selecting. Using an Idle
             * sometimes results in the pasted file not being selected because it is not found yet in the model. */
            if (tree_frozen) {
                select_source_handler = notify["tree-frozen"].connect (() => {
                    select_files_and_update_if_thawed (files_to_select_list, focus_after_select);
                });
            } else {
                select_files_and_update_if_thawed (files_to_select_list, focus_after_select);
            }
        }

        private void select_files_and_update_if_thawed (Gee.LinkedList<Files.File> files_to_select,
                                                        GLib.File? focus_file) {
            if (tree_frozen) {
                return;
            }

            if (select_source_handler > 0) {
                disconnect (select_source_handler);
                select_source_handler = 0;
            }

            Gtk.TreeIter iter;
            disconnect_tree_signals (); /* Avoid unnecessary signal processing */
            unselect_all ();

            uint count = 0;

            foreach (Files.File f in files_to_select) {
                /* Not all files selected in previous view  (e.g. expanded tree view) may appear in this one. */
                if (model.get_first_iter_for_file (f, out iter)) {
                    count++;
                    var path = model.get_path (iter);
                    /* Cursor follows if matches focus location*/
                    select_path (path, focus_file != null && focus_file.equal (f.location));
                }
            }

            if (count == 0) {
                focus_first_for_empty_selection (false);
            }

            connect_tree_signals ();
            on_view_selection_changed (); /* Mark selected_file list as invalid */
            /* Update menu and selected file list now in case autoselected */
            update_selected_files_and_menu ();
        }

        public unowned GLib.List<GLib.AppInfo> get_open_with_apps () {
            return open_with_apps;
        }

        public GLib.AppInfo get_default_app () {
            return default_app;
        }

        public new void grab_focus () {
            if (view.get_realized ()) {
                /* In Column View, maybe clicked on an inactive column */
                if (!slot.is_active) {
                    set_active_slot ();
                }

                view.grab_focus ();
            }
        }

        public unowned GLib.List<Files.File> get_selected_files () {
            update_selected_files_and_menu ();
            return selected_files;
        }

/*** Protected Methods */
        protected void set_active_slot (bool scroll = true) {
            slot.active (scroll);
        }

        protected void load_location (GLib.File location) {
            path_change_request (location, Files.OpenFlag.DEFAULT, false);
        }

        protected void load_root_location (GLib.File location) {
            path_change_request (location, Files.OpenFlag.DEFAULT, true);
        }

    /** Operations on selections */
        protected void activate_selected_items (Files.OpenFlag flag = Files.OpenFlag.DEFAULT,
                                                GLib.List<Files.File> selection = get_selected_files ()) {

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

                    foreach (Files.File file in selection) {
                        /* Prevent too rapid activation of files - causes New Tab to crash for example */
                        if (file.is_folder ()) {
                            /* By default, multiple folders open in new tabs */
                            if (flag == Files.OpenFlag.DEFAULT) {
                                flag = Files.OpenFlag.NEW_TAB;
                            }

                            GLib.Idle.add (() => {
                                activate_file (file, screen, flag, false);
                                return GLib.Source.REMOVE;
                            });
                        } else {
                            GLib.Idle.add (() => {
                                open_file (file, screen, null);
                                return GLib.Source.REMOVE;
                            });
                        }
                    }
                } else if (default_app != null) {
                    /* Because this is in another thread we need to copy the selection to ensure it remains valid */
                    var files_to_open = selection.copy_deep ((GLib.CopyFunc)(GLib.Object.ref));
                    GLib.Idle.add (() => {
                        open_files_with (default_app, files_to_open);
                        return GLib.Source.REMOVE;
                    });
                }
            } else {
                warning ("Cannot open files in trash");
            }
        }

        public void select_gof_file (Files.File file) {
            Gtk.TreeIter iter;
            if (!model.get_first_iter_for_file (file, out iter)) {
                return; /* file not in model */
            }

            var path = model.get_path (iter);
            set_cursor (path, false, true, false);
        }

        protected void select_and_scroll_to_gof_file (Files.File file) {
            Gtk.TreeIter iter;
            if (!model.get_first_iter_for_file (file, out iter)) {
                return; /* file not in model */
            }

            var path = model.get_path (iter);
            set_cursor (path, false, true, true);
        }

        protected void add_gof_file_to_selection (Files.File file) {
            Gtk.TreeIter iter;
            if (!model.get_first_iter_for_file (file, out iter)) {
                return; /* file not in model */
            }

            var path = model.get_path (iter);
            select_path (path); /* Cursor does not follow */
        }

    /** Directory signal handlers. */
        /* Signal could be from subdirectory as well as slot directory */
        protected void connect_directory_handlers (Directory dir) {
            dir.file_added.connect (on_directory_file_added);
            dir.file_changed.connect (on_directory_file_changed);
            dir.file_deleted.connect (on_directory_file_deleted);
            dir.icon_changed.connect (on_directory_file_icon_changed);
            connect_directory_loading_handlers (dir);
        }

        protected void connect_directory_loading_handlers (Directory dir) {
            dir.file_loaded.connect (on_directory_file_loaded);
            dir.done_loading.connect (on_directory_done_loading);
        }

        protected void disconnect_directory_loading_handlers (Directory dir) {
            dir.file_loaded.disconnect (on_directory_file_loaded);
            dir.done_loading.disconnect (on_directory_done_loading);
        }

        protected void disconnect_directory_handlers (Directory dir) {
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

        public void change_directory (Directory old_dir, Directory new_dir) {
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

        public void prepare_reload (Directory dir) {
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
            Gtk.drag_dest_set (widget, Gtk.DestDefaults.MOTION, DROP_TARGETS, Gdk.DragAction.ASK | FILE_DRAG_ACTIONS);
            widget.drag_drop.connect (on_drag_drop);
            widget.drag_data_received.connect (on_drag_data_received);
            widget.drag_leave.connect (on_drag_leave);
            widget.drag_motion.connect (on_drag_motion);

            /* Set up as drag source */
            Gtk.drag_source_set (
                widget,
                Gdk.ModifierType.BUTTON1_MASK | Gdk.ModifierType.BUTTON3_MASK | Gdk.ModifierType.CONTROL_MASK,
                DRAG_TARGETS,
                FILE_DRAG_ACTIONS
            );
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

        protected bool selection_only_contains_folders (GLib.List<Files.File> list) {
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

        protected GLib.List<Files.File>
        get_selected_files_for_transfer (GLib.List<Files.File> selection = get_selected_files ()) {
            return selection.copy_deep ((GLib.CopyFunc) GLib.Object.ref);
        }

/*** Private methods */
    /** File operations */

        private void activate_file (Files.File _file, Gdk.Screen? screen, Files.OpenFlag flag, bool only_one_file) {
            if (is_frozen) {
                return;
            }

            Files.File file = _file;
            if (in_recent) {
                file = Files.File.get_by_uri (file.get_display_target_uri ());
            }

            default_app = MimeActions.get_default_application_for_file (file);
            GLib.File location = file.get_target_location ();

            if (screen == null) {
                screen = get_screen ();
            }

            if (flag != Files.OpenFlag.APP && (file.is_folder () ||
                file.get_ftype () == "inode/directory" ||
                file.is_root_network_folder ())) {

                switch (flag) {
                    case Files.OpenFlag.NEW_TAB:
                    case Files.OpenFlag.NEW_WINDOW:
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
                    if (file.is_executable ()) {
                        var content_type = file.get_ftype ();

                        if (GLib.ContentType.is_a (content_type, "text/plain")) {
                            open_file (file, screen, default_app);
                        } else {
                            try {
                                file.execute (null);
                            } catch (Error e) {
                                PF.Dialogs.show_warning_dialog (_("Cannot execute this file"), e.message, window);
                            }
                        }
                    } else {
                        open_file (file, screen, default_app);
                    }
                }
            } else {
                PF.Dialogs.show_error_dialog (
                    ///TRANSLATORS: '%s' is a quoted placehorder for the name of a file. It can be moved but not omitted
                    _("“%s” must be moved from Trash before opening").printf (file.basename),
                    _("Files inside Trash cannot be opened. To open this file, it must be moved elsewhere."),
                    window
                );
            }
        }

        /* Open all files through this */
        private void open_file (Files.File file, Gdk.Screen? screen, GLib.AppInfo? app_info) {
            if (can_open_file (file, true)) {
                MimeActions.open_glib_file_request (file.location, this, app_info);
            }
        }

        /* Also used by build open menu */
        private bool can_open_file (Files.File file, bool show_error_dialog = false) {
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
            } else if (!slot.directory.can_stream_files &&
                       (content_type.contains ("video") || content_type.contains ("audio"))) {

                err_msg2 = "Cannot stream from this protocol (%s)".printf (slot.directory.scheme);
            }

            bool success = err_msg2.length < 1;
            if (!success && show_error_dialog) {
                PF.Dialogs.show_warning_dialog (err_msg1, err_msg2, window);
            }

            return success;
        }

        private void trash_or_delete_files (GLib.List<Files.File> file_list,
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
                FileOperations.@delete.begin (
                    locations,
                    window as Gtk.Window,
                    !delete_immediately,
                    null,
                    (obj, res) => {
                        try {
                            FileOperations.@delete.end (res);
                        } catch (Error e) {
                            debug (e.message);
                        }

                        after_trash_or_delete ();
                    }
                );
            }

            /* If in recent "folder" we need to refresh the view. */
            if (in_recent) {
                slot.reload ();
            }
        }

        private void add_file (Files.File file, Directory dir, bool select = true) {
            model.add_file (file, dir);

            if (select) { /* This true once view finished loading */
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
                        return GLib.Source.REMOVE;
                    } else {
                        signal_free_space_change = true;
                        return GLib.Source.CONTINUE;
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
            FileOperations.new_file.begin (
                this,
                parent_uri,
                null,
                null,
                0,
                null,
                (obj, res) => {
                    try {
                        var file = FileOperations.new_file.end (res);
                        create_file_done (file);
                    } catch (Error e) {
                        critical (e.message);
                    }
                }
            );
        }

        private void new_empty_folder () {
            /* Block the async directory file monitor to avoid generating unwanted "add-file" events */
            slot.directory.block_monitor ();
            FileOperations.new_folder.begin (this, slot.location, null, (obj, res) => {
                try {
                    var file = FileOperations.new_folder.end (res);
                    create_file_done (file);
                } catch (Error e) {
                    critical (e.message);
                }
            });
        }

        private void after_new_file_added (Files.File? file) {
            slot.directory.file_added.disconnect (after_new_file_added);
            if (file != null) {
                rename_file (file);
            }
        }

        protected void rename_file (Files.File file_to_rename) {
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
        [CCode (instance_pos = -1)]
        public void create_file_done (GLib.File? new_file) {
            if (new_file == null) {
                return;
            }

            /* Start to rename the file once we get signal that it has been added to model */
            slot.directory.file_added.connect_after (after_new_file_added);
            unblock_directory_monitor ();
        }

        public void after_trash_or_delete () {
            /* Need to use Idle else cursor gets reset to null after setting to delete_path */
            Idle.add (() => {
                set_cursor (deleted_path, false, false, false);
                unblock_directory_monitor ();
                return GLib.Source.REMOVE;
            });

        }

        private void unblock_directory_monitor () {
            /* Using an idle stops two file deleted/added signals being received (one via the file monitor
             * and one via marlin-file-changes. */
            GLib.Idle.add_full (GLib.Priority.LOW, () => {
                slot.directory.unblock_monitor ();
                return GLib.Source.REMOVE;
            });
        }

        private void trash_or_delete_selected_files (bool delete_immediately = false) {
        /* This might be rapidly called multiple times for the same selection
         * when using keybindings. So we remember if the current selection
         * was already removed (but the view doesn't know about it yet).
         */
            GLib.List<Files.File> selection = get_selected_files_for_transfer ();
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

            foreach (Files.File file in selected_files) {
                var loc = GLib.File.new_for_uri (file.get_display_target_uri ());
                path_change_request (loc, Files.OpenFlag.NEW_TAB, true);
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

            /* Batch renaming will be provided by a contractor */

            rename_file (selected_files.first ().data);
        }

        private void on_selection_action_cut (GLib.SimpleAction action, GLib.Variant? param) {
            GLib.List<Files.File> selection = get_selected_files_for_transfer ();
            clipboard.cut_files (selection);
        }

        private void on_selection_action_trash (GLib.SimpleAction action, GLib.Variant? param) {
            trash_or_delete_selected_files (Files.is_admin ());
        }

        private void on_selection_action_delete (GLib.SimpleAction action, GLib.Variant? param) {
            trash_or_delete_selected_files (true);
        }

        private void on_selection_action_restore (GLib.SimpleAction action, GLib.Variant? param) {
            GLib.List<Files.File> selection = get_selected_files_for_transfer ();
            PF.FileUtils.restore_files_from_trash (selection, window);

        }

        private void on_selection_action_open_executable (GLib.SimpleAction action, GLib.Variant? param) {
            GLib.List<Files.File> selection = get_files_for_action ();
            Files.File file = selection.data as Files.File;
            try {
                file.execute (null);
            } catch (Error e) {
                PF.Dialogs.show_warning_dialog (_("Cannot execute this file"), e.message, window);
            }
        }

        private void on_selection_action_open_with_default (GLib.SimpleAction action, GLib.Variant? param) {
            activate_selected_items (Files.OpenFlag.APP, get_files_for_action ());
        }

        private void on_selection_action_open_with_app (GLib.SimpleAction action, GLib.Variant? param) {
            open_files_with (open_with_apps.nth_data (param.get_uint32 ()), get_files_for_action ());
        }

        private void on_selection_action_open_with_other_app () {
            GLib.List<Files.File> selection = get_files_for_action ();
            Files.File file = selection.data as Files.File;
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

        private void change_state_hide_local_thumbnails (GLib.SimpleAction action) {
            window.change_state_hide_local_thumbnails (action);
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
            var prefs = Files.Preferences.get_default ();
            prefs.sort_directories_first = !prefs.sort_directories_first;
        }

        private void set_sort (string? col_name, bool reverse) {
            int sort_column_id;
            Gtk.SortType sort_order;

            if (model.get_sort_column_id (out sort_column_id, out sort_order)) {
                if (col_name != null) {
                    sort_column_id = Files.ListModel.ColumnID.from_string (col_name);
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
                    activate_selected_items (Files.OpenFlag.NEW_TAB, get_files_for_action ());
                    break;

                case "WINDOW":
                    activate_selected_items (Files.OpenFlag.NEW_WINDOW, get_files_for_action ());
                    break;

                default:
                    break;
            }
        }

        private void on_common_action_properties (GLib.SimpleAction action, GLib.Variant? param) {
            new View.PropertiesWindow (get_files_for_action (), this, window);
        }

        private void on_common_action_copy_link (GLib.SimpleAction action, GLib.Variant? param) {
            clipboard.copy_link_files (get_selected_files_for_transfer (get_files_for_action ()));
        }

        private void on_common_action_copy (GLib.SimpleAction action, GLib.Variant? param) {
            clipboard.copy_files (get_selected_files_for_transfer (get_files_for_action ()));
        }

        private void on_common_action_paste_into (GLib.SimpleAction action, GLib.Variant? param) {
            var file = get_files_for_action ().nth_data (0);

            if (file != null && clipboard.can_paste && !(clipboard.files_linked && in_trash)) {
                GLib.File target;

                if (file.is_folder () && !clipboard.has_file (file)) {
                    target = file.get_target_location ();
                } else {
                    target = slot.location;
                }

                clipboard.paste_files.begin (target, this as Gtk.Widget, (obj, res) => {
                    clipboard.paste_files.end (res);
                    if (target.has_uri_scheme ("trash")) {
                        /* Pasting files into trash is equivalent to trash or delete action */
                        after_trash_or_delete ();
                    }
                });
            }
        }

        private void on_directory_file_added (Directory dir, Files.File? file) {
            if (file != null) {
                add_file (file, dir, true); /* Always select files added to view after initial load */
                handle_free_space_change ();
            } else {
                critical ("Null file added");
            }
        }

        private void on_directory_file_loaded (Directory dir, Files.File file) {
            add_file (file, dir, false); /* Do not select files added during initial load */
            /* no freespace change signal required */
        }

        private void on_directory_file_changed (Directory dir, Files.File file) {
            if (file.location.equal (dir.file.location)) {
                /* The slot directory has changed - it can only be the properties */
                is_writable = slot.directory.file.is_writable ();
            } else {
                remove_marlin_icon_info_cache (file);
                model.file_changed (file, dir);
                /* 2nd parameter is for returned request id if required - we do not use it? */
                /* This is required if we need to dequeue the request */
                if ((!slot.directory.is_network && !hide_local_thumbnails) ||
                    (show_remote_thumbnails && slot.directory.can_open_files)) {

                    thumbnailer.queue_file (file, null, large_thumbnails);
                    if (plugins != null) {
                        plugins.update_file_info (file);
                    }
                }
            }

            draw_when_idle ();
        }

        private void on_directory_file_icon_changed (Directory dir, Files.File file) {
            model.file_changed (file, dir);
            draw_when_idle ();
        }

        private void on_directory_file_deleted (Directory dir, Files.File file) {
            /* The deleted file could be the whole directory, which is not in the model but that
             * that does not matter.  */
            file.exists = false;
            model.remove_file (file, dir);

            remove_marlin_icon_info_cache (file);

            if (file.get_thumbnail_path () != null) {
                PF.FileUtils.remove_thumbnail_paths_for_uri (file.uri);
            }

            if (plugins != null) {
                plugins.update_file_info (file);
            }

            if (file.is_folder ()) {
                /* Check whether the deleted file is the directory */
                var file_dir = Directory.cache_lookup (file.location);
                if (file_dir != null) {
                    Directory.purge_dir_from_cache (file_dir);
                    slot.folder_deleted (file, file_dir);
                }
            }

            handle_free_space_change ();
        }

        private void on_directory_done_loading (Directory dir) {
            /* Should only be called on directory creation or reload */
            disconnect_directory_loading_handlers (dir);
            in_trash = slot.directory.is_trash;
            in_recent = slot.directory.is_recent;
            in_network_root = slot.directory.file.is_root_network_folder ();

            if (slot.directory.can_load) {
                is_writable = slot.directory.file.is_writable ();
                if (in_recent) {
                    model.set_sort_column_id (Files.ListModel.ColumnID.MODIFIED, Gtk.SortType.DESCENDING);
                } else if (slot.directory.file.info != null) {
                    model.set_sort_column_id (slot.directory.file.sort_column_id, slot.directory.file.sort_order);
                }
            } else {
                is_writable = false;
            }

            thaw_tree ();

            schedule_thumbnail_timeout ();
        }

    /** Handle zoom level change */
        private void on_zoom_level_changed (ZoomLevel zoom) {
            var size = icon_size * get_scale_factor ();

            if (!large_thumbnails && size > 128 || large_thumbnails && size <= 128) {
                large_thumbnails = size > 128;
                slot.refresh_files (); /* Force GOF files to switch between normal and large thumbnails */
                schedule_thumbnail_timeout ();
            }

            model.size = icon_size;
            change_zoom_level ();
        }

    /** Handle Preference changes */
        private void on_show_hidden_files_changed (GLib.Object prefs, GLib.ParamSpec pspec) {
            bool show = ((Files.Preferences) prefs).show_hidden_files;
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

            action_set_state (background_actions, "show-hidden", show);
        }

        private void on_show_remote_thumbnails_changed (GLib.Object prefs, GLib.ParamSpec pspec) {
            show_remote_thumbnails = ((Files.Preferences) prefs).show_remote_thumbnails;
            action_set_state (background_actions, "show-remote-thumbnails", show_remote_thumbnails);
            slot.reload ();
        }

        private void on_hide_local_thumbnails_changed (GLib.Object prefs, GLib.ParamSpec pspec) {
            hide_local_thumbnails = ((Files.Preferences) prefs).hide_local_thumbnails;
            action_set_state (background_actions, "hide-local-thumbnails", hide_local_thumbnails);
            slot.reload ();
        }

        private void on_sort_directories_first_changed (GLib.Object prefs, GLib.ParamSpec pspec) {
            var sort_directories_first = ((Files.Preferences) prefs).sort_directories_first;
            model.set_should_sort_directories_first (sort_directories_first);
        }

        private void directory_hidden_changed (Directory dir, bool show) {
            /* May not be slot.directory - could be subdirectory */
            dir.file_loaded.connect (on_directory_file_loaded); /* disconnected by on_done_loading callback.*/
            dir.load_hiddens ();
        }

    /** Handle popup menu events */
        private bool on_popup_menu () {
            Gdk.Event event = Gtk.get_current_event ();
            show_context_menu (event);
            return true;
        }

    /** Handle Button events */
        private bool on_drag_timeout_button_release (Gdk.EventButton event) {
            /* Only active during drag timeout */
            cancel_drag_timer ();
            return true;
        }

/** Handle Motion events */
        private bool on_drag_timeout_motion_notify (Gdk.EventMotion event) {
            /* Only active during drag timeout */
            Gdk.DragContext context;
            var widget = get_child ();
            int x = (int)event.x;
            int y = (int)event.y;

            if (Gtk.drag_check_threshold (widget, drag_x, drag_y, x, y)) {
                cancel_drag_timer ();
                should_activate = false;
                var target_list = new Gtk.TargetList (DRAG_TARGETS);
                var actions = FILE_DRAG_ACTIONS;

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

/** DRAG AND DROP SOURCE */

        /* Signal emitted on source when drag begins */
        private void on_drag_begin (Gdk.DragContext context) {
            should_activate = false;
        }

        /* Signal emitted on source when destination requests data, either to inspect
         * during motion or to process on dropping by calling Gdk.drag_data_get () */
        private void on_drag_data_get (Gdk.DragContext context,
                                       Gtk.SelectionData selection_data,
                                       uint info,
                                       uint timestamp) {

            if (source_drag_file_list == null) {
                source_drag_file_list = get_selected_files_for_transfer ();
            }

            if (source_drag_file_list == null) {
                return;
            }

            Files.File file = source_drag_file_list.first ().data;

            if (file != null && file.pix != null) {
                Gtk.drag_set_icon_gicon (context, file.pix, 0, 0);
            } else {
                Gtk.drag_set_icon_name (context, "stock-file", 0, 0);
            }

            DndHandler.set_selection_data_from_file_list (selection_data, source_drag_file_list);
        }

        /* Signal emitted on source after a DND move operation */
        private void on_drag_data_delete (Gdk.DragContext context) {
            /* block real_view default handler because handled in on_drag_end */
            GLib.Signal.stop_emission_by_name (get_child (), "drag-data-delete");
        }

        /* Signal emitted on source after completion of DnD. */
        private void on_drag_end (Gdk.DragContext context) {
            source_drag_file_list = null;
        }

/** DRAG AND DROP DESTINATION */

        /* Signal emitted on destination while drag moving over it */
        private bool on_drag_motion (Gdk.DragContext context,
                                     int x,
                                     int y,
                                     uint timestamp) {

            if (destination_data_ready) {
                /* We have the drop data - check whether we can drop here*/
                check_destination_actions_and_target_file (context, x, y, timestamp);
                /* We don't have drop data already ... */
            } else {
                get_drag_data (context, x, y, timestamp);
                return false;
            }

            if (drag_scroll_timer_id == 0) {
                start_drag_scroll_timer (context);
            }

            Gdk.drag_status (context, current_suggested_action, timestamp);
            return true;
        }

        /* Signal emitted on destination when drag button released */
        private bool on_drag_drop (Gdk.DragContext context,
                                   int x,
                                   int y,
                                   uint timestamp) {

            Gtk.TargetList list = null;
            string? uri = null;
            drop_occurred = true;

            Gdk.Atom target = Gtk.drag_dest_find_target (get_child (), context, list);
            if (target == Gdk.Atom.intern_static_string ("XdndDirectSave0")) {
                Files.File? target_file = get_drop_target_file (x, y);
                /* get XdndDirectSave file name from DnD source window */
                string? filename = dnd_handler.get_source_filename (context);
                if (target_file != null && filename != null) {
                    /* Get uri of source file when dropped */
                    uri = target_file.get_target_location ().resolve_relative_path (filename).get_uri ();
                    /* Setup the XdndDirectSave property on the source window */
                    dnd_handler.set_source_uri (context, uri);
                } else {
                    PF.Dialogs.show_error_dialog (_("Cannot drop this file"),
                                                  _("Invalid file name provided"), window);

                    return false;
                }
            }

            /* request the drag data from the source (initiates
             * saving in case of XdndDirectSave).*/
            Gtk.drag_get_data (get_child (), context, target, timestamp);

            return true;
        }


        /* Signal emitted on destination when selection data received from source
         * either during drag motion or on dropping */
        private void on_drag_data_received (Gdk.DragContext context,
                                            int x,
                                            int y,
                                            Gtk.SelectionData selection_data,
                                            uint info,
                                            uint timestamp
                                            ) {
            /* Annoyingly drag-leave is emitted before "drag-drop" and this clears the destination drag data.
             * So we have to reset some it here and clear it again after processing the drop. */
            if (info == Files.TargetType.TEXT_URI_LIST && destination_drop_file_list == null) {
                string? text;
                if (DndHandler.selection_data_is_uri_list (selection_data, info, out text)) {
                    destination_drop_file_list = PF.FileUtils.files_from_uris (text);
                    destination_data_ready = true;
                }
            }

            if (drop_occurred) {
                bool success = false;
                drop_occurred = false;

                switch (info) {
                    case Files.TargetType.XDND_DIRECT_SAVE0:
                        success = dnd_handler.handle_xdnddirectsave (context,
                                                                     drop_target_file,
                                                                     selection_data);
                        break;

                    case Files.TargetType.NETSCAPE_URL:
                        success = dnd_handler.handle_netscape_url (context,
                                                                   drop_target_file,
                                                                   selection_data);
                        break;

                    case Files.TargetType.TEXT_URI_LIST:
                        if ((current_actions & FILE_DRAG_ACTIONS) == 0) {
                            break;
                        }

                        if (selected_files != null) {
                            unselect_all ();
                        }

                        success = dnd_handler.handle_file_drag_actions (
                            get_child (),
                            context,
                            drop_target_file,
                            destination_drop_file_list,
                            current_actions,
                            current_suggested_action,
                            (Gtk.ApplicationWindow)Files.get_active_window (),
                            timestamp
                        );

                        break;

                    default:
                        break;
                }

                /* Complete XDnDDirectSave0 */
                Gtk.drag_finish (context, success, false, timestamp);
                clear_destination_drag_data ();
            }
        }

        /* Signal emitted on destination when drag leaves the widget or *before* dropping */
        private void on_drag_leave (Gdk.DragContext context, uint timestamp) {
            /* reset the drop-file for the icon renderer */
            icon_renderer.drop_file = null;
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

            /* Clear data */
            clear_destination_drag_data ();
        }

/** DnD destination helpers */

        private void clear_destination_drag_data () {
            destination_data_ready = false;
            current_target_type = Gdk.Atom.NONE;
            destination_drop_file_list = null;
            cancel_timeout (ref drag_scroll_timer_id);
        }

        private Files.File? get_drop_target_file (int win_x, int win_y) {
            Gtk.TreePath? path = get_path_at_pos (win_x, win_y);
            Files.File? file = null;

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

            return file;
        }

        /* Called by destination during drag motion */
        private void get_drag_data (Gdk.DragContext context, int x, int y, uint timestamp) {
            Gtk.TargetList? list = null;
            Gdk.Atom target = Gtk.drag_dest_find_target (get_child (), context, list);
            current_target_type = target;

            /* Check if we can handle it yet */
            if (target == Gdk.Atom.intern_static_string ("XdndDirectSave0") ||
                target == Gdk.Atom.intern_static_string ("_NETSCAPE_URL")) {

                if (drop_target_file != null &&
                    drop_target_file.is_folder () &&
                    drop_target_file.is_writable ()) {

                    icon_renderer.@set ("drop-file", drop_target_file);
                    highlight_path (get_path_at_pos (x, y));
                }

                destination_data_ready = true;
            } else if (target != Gdk.Atom.NONE && destination_drop_file_list == null) {
                /* request the drag data from the source.
                 * See {Source]on_drag_data_get () and [Destination]on_drag_data_received () */
                Gtk.drag_get_data (get_child (), context, target, timestamp);
            }
        }

        /* Called by DnD destination during drag_motion */
        private void check_destination_actions_and_target_file (Gdk.DragContext context, int x, int y, uint timestamp) {
            string current_uri = drop_target_file != null ? drop_target_file.uri : "";
            drop_target_file = get_drop_target_file (x, y);
            string uri = drop_target_file != null ? drop_target_file.uri : "";

            if (uri != current_uri) {
                cancel_timeout (ref drag_enter_timer_id);
                current_actions = Gdk.DragAction.DEFAULT;
                current_suggested_action = Gdk.DragAction.DEFAULT;

                if (drop_target_file != null) {
                    if (current_target_type == Gdk.Atom.intern_static_string ("XdndDirectSave0")) {
                        current_suggested_action = Gdk.DragAction.COPY;
                        current_actions = current_suggested_action;
                    } else {

                        current_actions = PF.FileUtils.file_accepts_drop (drop_target_file,
                                                                      destination_drop_file_list, context,
                                                                      out current_suggested_action);
                    }

                    highlight_drop_file (drop_target_file, current_actions, get_path_at_pos (x, y));

                    if (drop_target_file.is_folder () && is_valid_drop_folder (drop_target_file)) {
                        /* open the target folder after a short delay */
                        drag_enter_timer_id = GLib.Timeout.add_full (GLib.Priority.LOW,
                                                                     1000,
                                                                     () => {

                            load_location (drop_target_file.get_target_location ());
                            drag_enter_timer_id = 0;
                            return GLib.Source.REMOVE;
                        });
                    }
                }
            }
        }

        private bool is_valid_drop_folder (Files.File file) {
            /* Cannot drop onto a file onto its parent or onto itself */
            if (file.uri != slot.uri &&
                source_drag_file_list != null &&
                source_drag_file_list.index (file) < 0) {

                return true;
            } else {
                return false;
            }
        }

        private void highlight_drop_file (Files.File drop_file, Gdk.DragAction action, Gtk.TreePath? path) {
            bool can_drop = (action > Gdk.DragAction.DEFAULT);

            if (drop_highlight != can_drop) {
                drop_highlight = can_drop;
                queue_draw ();
            }

            /* Set the icon_renderer drop-file if there is an action */
            icon_renderer.drop_file = can_drop ? drop_file : null;

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

        protected void start_drag_timer (Gdk.Event event) {
            connect_drag_timeout_motion_and_release_events ();
            var button_event = (Gdk.EventButton)event;
            drag_button = (int)(button_event.button);

            drag_timer_id = GLib.Timeout.add_full (GLib.Priority.LOW,
                                                   300,
                                                   () => {
                on_drag_timeout_button_release ((Gdk.EventButton)event);
                return GLib.Source.REMOVE;
            });
        }

        protected void show_context_menu (Gdk.Event event) {
            cancel_drag_timer ();
            /* select selection or background context menu */
            update_menu_actions ();

            var menu = new Gtk.Menu ();

            var selection = get_files_for_action ();
            var selected_file = selection.data;

            var open_submenu = new Gtk.Menu ();

            if (common_actions.get_action_enabled ("open-in")) {
                var new_tab_menuitem = new Gtk.MenuItem ();
                new_tab_menuitem.add (new Granite.AccelLabel (
                    _("New Tab"),
                    "<Shift>Return"
                ));
                new_tab_menuitem.action_name = "common.open-in";
                new_tab_menuitem.action_target = "TAB";

                var new_window_menuitem = new Gtk.MenuItem.with_label (_("New Window"));
                new_window_menuitem.action_name = "common.open-in";
                new_window_menuitem.action_target = "WINDOW";

                open_submenu.add (new_tab_menuitem);
                open_submenu.add (new_window_menuitem);
                open_submenu.add (new Gtk.SeparatorMenuItem ());
            }

            if (!selected_file.is_mountable () &&
                !selected_file.is_root_network_folder () &&
                can_open_file (selected_file)) {

                if (!selected_file.is_folder () && selected_file.is_executable ()) {
                    var run_menuitem = new Gtk.MenuItem.with_label (_("Run"));
                    run_menuitem.action_name = "selection.open";

                    menu.add (run_menuitem);
                } else if (default_app != null && default_app.get_id () != APP_ID + ".desktop") {
                    var open_menuitem = new Gtk.MenuItem ();
                    open_menuitem.add (new Granite.AccelLabel (
                        _("Open in %s").printf (default_app.get_display_name ()),
                        "Return"
                    ));
                    open_menuitem.action_name = "selection.open-with-default";

                    menu.add (open_menuitem);
                }

                open_with_apps = MimeActions.get_applications_for_files (selection);

                if (selected_file.is_executable () == false) {
                    filter_default_app_from_open_with_apps ();
                }

                filter_this_app_from_open_with_apps ();

                if (open_with_apps != null && open_with_apps.data != null) {
                    unowned string last_label = "";
                    unowned string last_exec = "";
                    uint count = 0;

                    foreach (unowned AppInfo app_info in open_with_apps) {
                        /* Ensure no duplicate items */
                        unowned string label = app_info.get_display_name ();
                        unowned string exec = app_info.get_executable ().split (" ")[0];
                        if (label != last_label || exec != last_exec) {
                            var app_image = new Gtk.Image.from_gicon (
                                app_info.get_icon (),
                                Gtk.IconSize.MENU
                            );
                            app_image.pixel_size = 16;

                            var label_grid = new Gtk.Grid ();
                            label_grid.add (app_image);
                            label_grid.add (new Gtk.Label (label));

                            var menuitem = new Gtk.MenuItem ();
                            menuitem.add (label_grid);
                            menuitem.set_detailed_action_name (GLib.Action.print_detailed_name (
                                "selection.open-with-app",
                                new GLib.Variant.uint32 (count)
                            ));

                            open_submenu.add (menuitem);
                        }

                        last_label = label;
                        last_exec = exec;
                        count++;
                    };

                    if (count > 0) {
                        open_submenu.add (new Gtk.SeparatorMenuItem ());
                    }
                }

                if (selection != null && selection.first ().next == null) { // Only one selected
                    var other_apps_menuitem = new Gtk.MenuItem.with_label (_("Other Application…"));
                    other_apps_menuitem.action_name = "selection.open-with-other-app";

                    open_submenu.add (other_apps_menuitem);
                }
            }

            var open_submenu_item = new Gtk.MenuItem ();
            if (open_submenu.get_children ().length () > 0) { //Can be assumed to be limited length
                open_submenu_item.submenu = open_submenu;

                if (selected_file.is_folder () || selected_file.is_root_network_folder ()) {
                    open_submenu_item.label = _("Open in");
                } else {
                    open_submenu_item.label = _("Open with");
                }

                menu.add (open_submenu_item);
            }

            var paste_menuitem = new Gtk.MenuItem.with_label (_("Paste"));
            paste_menuitem.action_name = "common.paste-into";

            var bookmark_menuitem = new Gtk.MenuItem ();
            bookmark_menuitem.add (new Granite.AccelLabel (
                _("Add to Bookmarks"),
                "<Ctrl>d"
            ));
            bookmark_menuitem.action_name = "common.bookmark";

            var properties_menuitem = new Gtk.MenuItem ();
            properties_menuitem.add (new Granite.AccelLabel (
                _("Properties"),
                "<Alt>Return"
            ));
            properties_menuitem.action_name = "common.properties";

            if (get_selected_files () != null) {
                var cut_menuitem = new Gtk.MenuItem ();
                cut_menuitem.add (new Granite.AccelLabel (
                    _("Cut"),
                    "<Ctrl>x"
                ));
                cut_menuitem.action_name = "selection.cut";

                var copy_menuitem = new Gtk.MenuItem ();
                ///TRANSLATORS Verb to indicate action of menuitem will be to duplicate a file.
                copy_menuitem.add (new Granite.AccelLabel (
                    _("Copy"),
                    "<Ctrl>c"
                ));
                copy_menuitem.action_name = "common.copy";

                var trash_menuitem = new Gtk.MenuItem ();
                trash_menuitem.add (new Granite.AccelLabel (
                    _("Move to Trash"),
                    "Delete"
                ));
                trash_menuitem.action_name = "selection.trash";

                var delete_menuitem = new Gtk.MenuItem.with_label (_("Delete permanently"));
                delete_menuitem.action_name = "selection.delete";

                /* In trash, only show context menu when all selected files are in root folder */
                if (in_trash && valid_selection_for_restore ()) {
                    var restore_menuitem = new Gtk.MenuItem.with_label (_("Restore from Trash"));
                    restore_menuitem.action_name = "selection.restore";

                    menu.add (new Gtk.SeparatorMenuItem ());
                    menu.add (restore_menuitem);
                    menu.add (delete_menuitem);
                    menu.add (new Gtk.SeparatorMenuItem ());
                    menu.add (cut_menuitem);
                    menu.add (new Gtk.SeparatorMenuItem ());
                    menu.add (properties_menuitem);
                } else if (in_recent) {
                    var open_parent_menuitem = new Gtk.MenuItem.with_label (_("Open Parent Folder"));
                    open_parent_menuitem.action_name = "selection.view-in-location";

                    var forget_menuitem = new Gtk.MenuItem.with_label (_("Remove from History"));
                    forget_menuitem.action_name = "selection.forget";

                    menu.add (open_parent_menuitem);
                    menu.add (new Gtk.SeparatorMenuItem ());
                    menu.add (forget_menuitem);
                    menu.add (copy_menuitem);
                    menu.add (trash_menuitem);
                    menu.add (new Gtk.SeparatorMenuItem ());
                    menu.add (properties_menuitem);
                } else {
                    if (slot.directory.file.is_smb_server () && clipboard != null && clipboard.can_paste) {
                        menu.add (paste_menuitem);
                    } else if (valid_selection_for_edit ()) {
                        var rename_menuitem = new Gtk.MenuItem ();
                        rename_menuitem.add (new Granite.AccelLabel (
                            _("Rename…"),
                            "F2"
                        ));
                        rename_menuitem.action_name = "selection.rename";

                        var copy_link_menuitem = new Gtk.MenuItem ();
                        copy_link_menuitem.add (new Granite.AccelLabel (
                            _("Copy as Link"),
                            "<Shift><Ctrl>c"
                        ));
                        copy_link_menuitem.action_name = "common.copy-link";

                        if (menu.get_children ().find (open_submenu_item) != null) {
                            menu.add (new Gtk.SeparatorMenuItem ());
                        }

                        menu.add (cut_menuitem);
                        menu.add (copy_menuitem);
                        menu.add (copy_link_menuitem);

                        // Do not display the 'Paste into' menuitem if nothing to paste
                        if (common_actions.get_action_enabled ("paste-into") &&
                            clipboard != null && clipboard.can_paste) {

                            if (clipboard.files_linked) {
                                paste_menuitem.label = _("Paste Link into Folder");
                            } else {
                                paste_menuitem.label = _("Paste into Folder");
                            }

                            menu.add (paste_menuitem);
                        }

                        menu.add (new Gtk.SeparatorMenuItem ());

                        if (slot.directory.has_trash_dirs && !Files.is_admin ()) {
                            menu.add (trash_menuitem);
                        } else {
                            menu.add (delete_menuitem);
                        }

                        menu.add (rename_menuitem);
                    }

                    /* Do  not offer to bookmark if location is already bookmarked */
                    if (common_actions.get_action_enabled ("bookmark") &&
                        window.can_bookmark_uri (selected_files.data.uri)) {

                        menu.add (bookmark_menuitem);
                    }

                    menu.add (new Gtk.SeparatorMenuItem ());
                    menu.add (properties_menuitem);
                }
            } else {
                var show_hidden_menuitem = new Gtk.CheckMenuItem.with_label (_("Show Hidden Files"));
                show_hidden_menuitem.action_name = "background.show-hidden";

                var show_remote_thumbnails_menuitem = new Gtk.CheckMenuItem.with_label (_("Show Remote Thumbnails"));
                show_remote_thumbnails_menuitem.action_name = "background.show-remote-thumbnails";

                var hide_local_thumbnails_menuitem = new Gtk.CheckMenuItem.with_label (_("Hide Thumbnails"));
                hide_local_thumbnails_menuitem.action_name = "background.hide-local-thumbnails";

                if (in_trash) {
                    if (clipboard != null && clipboard.has_cutted_file (null)) {
                        menu.add (paste_menuitem);
                    }
                } else if (in_recent) {
                    menu.add (new Gtk.SeparatorMenuItem ());
                    menu.add (new SortSubMenuItem ());
                    menu.add (new Gtk.SeparatorMenuItem ());
                    menu.add (show_hidden_menuitem);
                    menu.add (hide_local_thumbnails_menuitem);
                } else {
                    if (!in_network_root) {
                        menu.add (new Gtk.SeparatorMenuItem ());

                        /* If something is pastable in the clipboard, show the option even if it is not enabled */
                        if (clipboard != null && clipboard.can_paste) {
                            if (clipboard.files_linked) {
                                paste_menuitem.label = _("Paste Link");
                            }

                            menu.add (paste_menuitem);
                        }

                        if (is_writable) {
                            menu.add (new NewSubMenuItem ());
                        }

                        menu.add (new SortSubMenuItem ());
                    }

                    /* Do  not offer to bookmark if location is already bookmarked */
                    if (common_actions.get_action_enabled ("bookmark") &&
                        window.can_bookmark_uri (slot.directory.file.uri)) {

                        menu.add (bookmark_menuitem);
                    }

                    menu.add (new Gtk.SeparatorMenuItem ());
                    menu.add (show_hidden_menuitem);

                    if (!slot.directory.is_network) {
                        menu.add (hide_local_thumbnails_menuitem);
                    } else if (slot.directory.can_open_files) {
                        menu.add (show_remote_thumbnails_menuitem);
                    }

                    if (!in_network_root) {
                        menu.add (new Gtk.SeparatorMenuItem ());
                        menu.add (properties_menuitem);
                    }
                }
            }

            if (!in_trash) {
                plugins.hook_context_menu (menu as Gtk.Widget, get_files_for_action ());
            }

            menu.set_screen (null);
            menu.attach_to_widget (this, null);

            /* Override style Granite.STYLE_CLASS_H2_LABEL of view when it is empty */
            if (slot.directory.is_empty ()) {
                menu.get_style_context ().add_class (Gtk.STYLE_CLASS_CONTEXT_MENU);
            }

            menu.show_all ();
            menu.popup_at_pointer (event);
        }

        private class SortSubMenuItem : Gtk.MenuItem {
            construct {
                var name_radioitem = new Gtk.CheckMenuItem.with_label (_("Name"));
                name_radioitem.action_name = "background.sort-by";
                name_radioitem.action_target = "name";
                name_radioitem.draw_as_radio = true;

                var size_radioitem = new Gtk.CheckMenuItem.with_label (_("Size"));
                size_radioitem.action_name = "background.sort-by";
                size_radioitem.action_target = "size";
                size_radioitem.draw_as_radio = true;

                var type_radioitem = new Gtk.CheckMenuItem.with_label (_("Type"));
                type_radioitem.action_name = "background.sort-by";
                type_radioitem.action_target = "type";
                type_radioitem.draw_as_radio = true;

                var date_radioitem = new Gtk.CheckMenuItem.with_label (_("Date"));
                date_radioitem.action_name = "background.sort-by";
                date_radioitem.action_target = "modified";
                date_radioitem.draw_as_radio = true;

                var reversed_checkitem = new Gtk.CheckMenuItem.with_label (_("Reversed Order"));
                reversed_checkitem.action_name = "background.reverse";

                var folders_first_checkitem = new Gtk.CheckMenuItem.with_label (_("Folders Before Files"));
                folders_first_checkitem.action_name = "background.folders-first";

                submenu = new Gtk.Menu ();
                submenu.add (name_radioitem);
                submenu.add (size_radioitem);
                submenu.add (type_radioitem);
                submenu.add (date_radioitem);
                submenu.add (new Gtk.SeparatorMenuItem ());
                submenu.add (reversed_checkitem);
                submenu.add (folders_first_checkitem);

                label = _("Sort by");
            }
        }

        private class NewSubMenuItem : Gtk.MenuItem {
            construct {
                var folder_menuitem = new Gtk.MenuItem ();
                folder_menuitem.add (new Granite.AccelLabel (
                    _("Folder"),
                    "<Ctrl><Shift>n"
                ));
                folder_menuitem.action_name = "background.new";
                folder_menuitem.action_target = "FOLDER";

                var file_menuitem = new Gtk.MenuItem.with_label (_("Empty File"));
                file_menuitem.action_name = "background.new";
                file_menuitem.action_target = "FILE";

                submenu = new Gtk.Menu ();
                submenu.add (folder_menuitem);
                submenu.add (file_menuitem);

                /* Potential optimisation - do just once when app starts or view created */
                templates = null;
                unowned string? template_path = GLib.Environment.get_user_special_dir (GLib.UserDirectory.TEMPLATES);
                if (template_path != null) {
                    var template_folder = GLib.File.new_for_path (template_path);
                    load_templates_from_folder (template_folder);

                    if (templates.length () > 0) { //Can be assumed to be limited length
                        submenu.add (new Gtk.SeparatorMenuItem ());

                        // We need to get directories first
                        templates.reverse ();

                        var active_submenu = submenu;
                        int index = 0;
                        foreach (unowned GLib.File template in templates) {
                            var label = template.get_basename ();
                            var ftype = template.query_file_type (GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
                            if (ftype == GLib.FileType.DIRECTORY) {
                                if (template == template_folder) {
                                    active_submenu = submenu;
                                } else {
                                    active_submenu = new Gtk.Menu ();

                                    var submenu_item = new Gtk.MenuItem.with_label (label);
                                    submenu_item.submenu = active_submenu;

                                    submenu.add (submenu_item);
                                }
                            } else {
                                var template_menuitem = new Gtk.MenuItem.with_label (label);
                                template_menuitem.set_detailed_action_name ("background.create-from::" +
                                                                            index.to_string ());

                                active_submenu.add (template_menuitem);

                            }

                            index++;
                        }
                    }
                }

                label = _("New");
            }
        }

        private bool valid_selection_for_edit () {
            foreach (unowned Files.File file in get_selected_files ()) {
                if (file.is_root_network_folder ()) {
                    return false;
                }
            }

            return true;
        }

        private bool valid_selection_for_restore () {
            foreach (unowned Files.File file in get_selected_files ()) {
                if (!(file.directory.get_basename () == "/")) {
                    return false;
                }
            }

            return true;
        }

        private void update_menu_actions () {
            if (is_frozen || !slot.directory.can_load) {
                return;
            }

            GLib.List<Files.File> selection = get_files_for_action ();
            Files.File file;

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

            action_set_enabled (common_actions, "paste-into", can_paste_into);
            action_set_enabled (common_actions, "open-in", only_folders);
            action_set_enabled (selection_actions, "rename", is_selected && !more_than_one_selected && can_rename);
            action_set_enabled (selection_actions, "view-in-location", is_selected);
            action_set_enabled (selection_actions, "open", is_selected && !more_than_one_selected && can_open);
            action_set_enabled (selection_actions, "open-with-app", can_open);
            action_set_enabled (selection_actions, "open-with-default", can_open);
            action_set_enabled (selection_actions, "open-with-other-app", can_open);
            action_set_enabled (selection_actions, "cut", is_writable && is_selected);
            action_set_enabled (selection_actions, "trash", is_writable && slot.directory.has_trash_dirs);
            action_set_enabled (selection_actions, "delete", is_writable);
            action_set_enabled (common_actions, "properties", can_show_properties);
            action_set_enabled (common_actions, "bookmark", can_bookmark);
            action_set_enabled (common_actions, "copy", !in_trash && can_copy);
            action_set_enabled (common_actions, "copy-link", !in_trash && !in_recent && can_copy);
            action_set_enabled (common_actions, "bookmark", !more_than_one_selected);

            update_default_app (selection);
            update_menu_actions_sort ();
        }

        private void update_menu_actions_sort () {
            int sort_column_id;
            Gtk.SortType sort_order;

            if (model.get_sort_column_id (out sort_column_id, out sort_order)) {
                GLib.Variant val = new GLib.Variant.string (((Files.ListModel.ColumnID)sort_column_id).to_string ());
                action_set_state (background_actions, "sort-by", val);
                val = new GLib.Variant.boolean (sort_order == Gtk.SortType.DESCENDING);
                action_set_state (background_actions, "reverse", val);
                val = new GLib.Variant.boolean (Files.Preferences.get_default ().sort_directories_first);
                action_set_state (background_actions, "folders-first", val);
            }
        }

        private void update_default_app (GLib.List<Files.File> selection) {
            default_app = MimeActions.get_default_application_for_files (selection);
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

        private static void load_templates_from_folder (GLib.File template_folder) {
            GLib.List<GLib.File> file_list = null;
            GLib.List<GLib.File> folder_list = null;

            GLib.FileEnumerator enumerator;
            var flags = GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS;
            try {
                enumerator = template_folder.enumerate_children ("standard::*", flags, null);
                uint count = templates.length (); //Assume to be limited in size
                GLib.File location;
                GLib.FileInfo? info = enumerator.next_file (null);

                while (count < MAX_TEMPLATES && (info != null)) {
                    if (!info.get_is_hidden () && !info.get_is_backup ()) {
                        location = template_folder.get_child (info.get_name ());
                        if (info.get_file_type () == GLib.FileType.DIRECTORY) {
                            folder_list.prepend (location);
                        } else {
                            file_list.prepend (location);
                            count ++;
                        }
                    }

                    info = enumerator.next_file (null);
                }
            } catch (GLib.Error error) {
                return;
            }

            if (file_list.length () > 0) { // Can assumed to be limited in length
                file_list.sort ((a, b) => {
                    return strcmp (a.get_basename ().down (), b.get_basename ().down ());
                });

                foreach (var file in file_list) {
                    templates.append (file);
                }

                templates.append (template_folder);
            }

            if (folder_list.length () > 0) { //Can be assumed to be limited in length
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

            return (exec_name == Config.APP_NAME || exec_name == Config.TERMINAL_NAME);
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
            FileOperations.new_file_from_template.begin (
                this,
                slot.location,
                new_name,
                template,
                null,
                (obj, res) => {
                    try {
                        var file = FileOperations.new_file_from_template.end (res);
                        create_file_done (file);
                    } catch (Error e) {
                        critical (e.message);
                    }
                });
        }

        private void open_files_with (GLib.AppInfo app, GLib.List<Files.File> files) {
            MimeActions.open_multiple_gof_files_request (files, this, app);
        }


/** Thumbnail and color tag handling */
        private void schedule_thumbnail_timeout () {
            /* delay creating the idle until the view has finished loading.
             * this is done because we only can tell the visible range reliably after
             * all items have been added and we've perhaps scrolled to the file remembered
             * the last time */

            assert (slot is Files.AbstractSlot && slot.directory != null);

            /* Check all known conditions preventing thumbnailing at earliest possible stage */
            if (thumbnail_source_id != 0 ||
                (slot.directory.is_network && !show_remote_thumbnails) ||
                (!slot.directory.is_network && hide_local_thumbnails) ||
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
                    return GLib.Source.CONTINUE;
                }

                thaw_child_notify ();
                freeze_source_id = 0;
                return GLib.Source.REMOVE;
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
                Files.File? file;
                GLib.List<Files.File> visible_files = null;
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
                        file = model.file_for_iter (iter); // Maybe null if dummy row or file being deleted
                        path = model.get_path (iter);

                        if (file != null && !file.is_gone) {
                            file.query_thumbnail_update (); // Ensure thumbstate up to date
                            /* Ask thumbnailer only if ThumbState UNKNOWN */
                            if (file.thumbstate == Files.File.ThumbState.UNKNOWN) {
                                visible_files.prepend (file);
                                if (path.compare (sp) >= 0 && path.compare (ep) <= 0) {
                                    actually_visible++;
                                }
                            }

                            /* This also ensures color-tag info is correct regardless of whether thumbnail is shown */
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
                /* Do not trigger a thumbnail request unless:
                    * there are unthumbnailed files actually visible
                    * there has not been another event (which would zero the thumbnail_source_id)
                    * thumbnails are not hidden by settings
                 */
                if (actually_visible > 0 && thumbnail_source_id > 0) {
                    thumbnailer.queue_files (visible_files, out thumbnail_request, large_thumbnails);
                } else {
                    draw_when_idle ();
                }

                thumbnail_source_id = 0;

                return GLib.Source.REMOVE;
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
                return GLib.Source.REMOVE;
            });
        }

        protected void block_model () {
            model.row_deleted.disconnect (on_row_deleted);
        }

        protected void unblock_model () {
            model.row_deleted.connect (on_row_deleted);
        }

        private void connect_drag_timeout_motion_and_release_events () {
            var real_view = get_child ();
            real_view.button_release_event.connect (on_drag_timeout_button_release);
            real_view.motion_notify_event.connect (on_drag_timeout_motion_notify);
        }

        private void disconnect_drag_timeout_motion_and_release_events () {
            if (drag_timer_id == 0) {
                return;
            }

            var real_view = get_child ();
            real_view.button_release_event.disconnect (on_drag_timeout_button_release);
            real_view.motion_notify_event.disconnect (on_drag_timeout_motion_notify);
        }

        private void start_drag_scroll_timer (Gdk.DragContext context) {
            drag_scroll_timer_id = GLib.Timeout.add_full (GLib.Priority.LOW,
                                                          50,
                                                          () => {
                Gtk.Widget? widget = get_child ();
                if (widget != null) {
                    Gdk.Device pointer = context.get_device ();
                    Gdk.Window window = widget.get_window ();
                    int x, y, w, h;

                    window.get_device_position (pointer, out x, out y, null);
                    window.get_geometry (null, null, out w, out h);

                    scroll_if_near_edge (y, h, 20, get_vadjustment ());
                    scroll_if_near_edge (x, w, 20, get_hadjustment ());
                    return GLib.Source.CONTINUE;
                } else {
                    return GLib.Source.REMOVE;
                }
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

        private void remove_marlin_icon_info_cache (Files.File file) {
            string? path = file.get_thumbnail_path ();

            if (path != null) {
                Files.IconSize s;

                for (int z = ZoomLevel.SMALLEST;
                     z <= ZoomLevel.LARGEST;
                     z++) {

                    s = ((ZoomLevel) z).to_icon_size ();
                    Files.IconInfo.remove_cache (path, s, get_scale_factor ());
                }
            }
        }

        /* For actions on the background we need to return the current slot directory, but this
         * should not be added to the list of selected files
         */
        private GLib.List<Files.File> get_files_for_action () {
            GLib.List<Files.File> action_files = null;
            update_selected_files_and_menu ();

            if (selected_files == null) {
                action_files.prepend (slot.directory.file);
            } else if (in_recent) {
                selected_files.@foreach ((file) => {
                    var goffile = Files.File.get_by_uri (file.get_display_target_uri ());
                    goffile.query_update ();
                    action_files.append (goffile);
                });
            } else {
                action_files = selected_files.copy_deep ((GLib.CopyFunc) GLib.Object.ref);
            }

            return (owned)action_files;
        }

        protected void on_view_items_activated () {
            activate_selected_items (Files.OpenFlag.DEFAULT);
        }

        protected void on_view_selection_changed () {
            selected_files_invalid = true;
            one_or_less = (selected_files == null || selected_files.next == null);
        }

/** Keyboard event handling **/

        /** Returns true if the code parameter matches the keycode of the keyval parameter for
          * any keyboard group or level (in order to allow for non-QWERTY keyboards) **/
        protected bool match_keycode (uint keyval, uint code, int level) {
            Gdk.KeymapKey [] keys;
            Gdk.Keymap keymap = Gdk.Keymap.get_for_display (get_display ());
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

            uint keyval = event.keyval;
            Gdk.ModifierType consumed_mods = 0;

            /* Leave standard ASCII alone, else try to get Latin hotkey from keyboard state */
            /* This means that Latin hot keys for Latin Dvorak keyboards (e.g. Spanish Dvorak)
             * will be in their Dvorak position, not their QWERTY position.
             * For non-Latin (e.g. Cyrillic) keyboards however, the Latin hotkeys are mapped
             * to the same position as on a Latin QWERTY keyboard. If the conversion fails, the unprocessed
             * event.keyval is used. */
            if (keyval > 127) {
                int eff_grp, level;

                if (!Gdk.Keymap.get_for_display (get_display ()).translate_keyboard_state (
                        event.hardware_keycode,
                        event.state, event.group,
                        out keyval, out eff_grp,
                        out level, out consumed_mods)) {

                    warning ("translate keyboard state failed");
                    keyval = event.keyval;
                    consumed_mods = 0;
                } else {
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
                }
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
                        show_context_menu (event);
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
                        trash_or_delete_selected_files (in_trash || Files.is_admin () || only_shift_pressed);
                        res = true;
                    }

                    break;

                case Gdk.Key.space:
                    if (view_has_focus () && !in_trash) {
                        activate_selected_items (Files.OpenFlag.NEW_TAB);
                        res = true;
                    }

                    break;

                case Gdk.Key.Return:
                case Gdk.Key.KP_Enter:
                    if (in_trash) {
                        break;
                    } else if (in_recent) {
                        activate_selected_items (Files.OpenFlag.DEFAULT);
                    } else if (only_shift_pressed) {
                        activate_selected_items (Files.OpenFlag.NEW_TAB);
                    } else if (only_alt_pressed) {
                        common_actions.activate_action ("properties", null);
                    } else if (no_mods) {
                         activate_selected_items (Files.OpenFlag.DEFAULT);
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
                    unowned GLib.List<Files.File> selection = get_selected_files ();
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

                    res = move_cursor (keyval, only_shift_pressed, control_pressed);
                    break;

                case Gdk.Key.Home:
                    res = only_shift_pressed &&
                          handle_multi_select (new Gtk.TreePath.from_indices (0));

                    break;

                case Gdk.Key.End:
                    res = only_shift_pressed &&
                          handle_multi_select (new Gtk.TreePath.from_indices (model.get_length ()));

                    break;

                case Gdk.Key.c:
                case Gdk.Key.C:
                    if (only_control_pressed) {
                        /* Caps Lock interferes with `shift_pressed` boolean so use another way */
                        var caps_on = Gdk.Keymap.get_for_display (get_display ()).get_caps_lock_state ();
                        var cap_c = keyval == Gdk.Key.C;

                        if (caps_on != cap_c) { /* Shift key pressed */
                            common_actions.activate_action ("copy-link", null);
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
                        update_selected_files_and_menu ();
                        if (!in_recent && is_writable) {
                            if (selected_files.first () != null && selected_files.first ().next != null) {
                                //Ignore if multiple files selected
                                Gdk.beep ();
                                warning ("Cannot paste into a multiple selection");
                            } else {
                                //None or one file selected. Paste into selected file else base directory
                                action_set_enabled (common_actions, "paste-into", true);
                                common_actions.activate_action ("paste-into", null);
                            }
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
                return GLib.Source.REMOVE;
            });

            return res;
        }

        protected bool on_motion_notify_event (Gdk.EventMotion event) {
            Gtk.TreePath? path = null;
            Files.File? file = null;

            if (renaming || is_frozen) {
                return true;
            }

            click_zone = get_event_position_info ((Gdk.EventButton)event, out path, false);

            if ((path != null && hover_path == null) ||
                (path == null && hover_path != null) ||
                (path != null && hover_path != null && path.compare (hover_path) != 0)) {

                on_directory = false;
                /* cannot get file info while network disconnected */
                if (slot.directory.is_local || NetworkMonitor.get_default ().get_network_available ()) {
                    /* cannot get file info while network disconnected. */
                    Files.File? target_file;
                    file = path != null ? model.file_for_path (path) : null;


                    if (file != null && slot.directory.is_recent) {
                        target_file = Files.File.get_by_uri (file.get_display_target_uri ());
                        target_file.ensure_query_info ();
                    } else {
                        target_file = file;
                    }

                    if (target_file != null) {
                        on_directory = target_file.is_directory;
                    }

                    item_hovered (target_file);
                    hover_path = path;
                }
            }

            if (click_zone != previous_click_zone) {
                var win = view.get_window ();
                win.set_cursor (selectable_cursor);

                switch (click_zone) {
                    case ClickZone.ICON:
                    case ClickZone.NAME:
                        if (on_directory && one_or_less) {
                            win.set_cursor (activatable_cursor);
                        }

                        break;

                    default:
                        break;
                }

                previous_click_zone = click_zone;
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
            }
            return handle_scroll_event (event);
        }

    /** name renderer signals */
        protected void on_name_editing_started (Gtk.CellEditable? editable, string path_string) {
            if (renaming) { /* Ignore duplicate editing-started signal*/
                return;
            }

            renaming = true;

            var editable_widget = editable as AbstractEditableLabel?;
            if (editable_widget != null) {
                original_name = editable_widget.get_chars (0, -1);
                var path = new Gtk.TreePath.from_string (path_string);
                Gtk.TreeIter? iter = null;
                model.get_iter (out iter, path);
                Files.File? file = null;
                model.@get (iter, Files.ListModel.ColumnID.FILE_COLUMN, out file);
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

        protected void on_name_edited (string path_string, string? _new_name) {
            /* Must not re-enter */
            if (!renaming || _new_name == null) {
                on_name_editing_canceled (); // no problem rentering this function
                return;
            }

            var new_name = _new_name.strip (); // Disallow leading and trailing space
            if (new_name == "" || proposed_name == new_name) {
                warning ("Blank name or name unchanged");
                on_name_editing_canceled ();
                return;
            }

            proposed_name = "";
            if (new_name != "") {
                var path = new Gtk.TreePath.from_string (path_string);
                Gtk.TreeIter? iter = null;
                model.get_iter (out iter, path);

                Files.File? file = null;
                model.@get (iter, Files.ListModel.ColumnID.FILE_COLUMN, out file);

                /* Only rename if name actually changed */
                /* Because Files.File.rename does not work correctly for remote files we handle ourselves */

                if (new_name != original_name) {
                    proposed_name = new_name;
                    set_file_display_name.begin (file.location, new_name, null, (obj, res) => {
                        try {
                            set_file_display_name.end (res);
                        } catch (Error e) {} // Warning dialog already shown

                        on_name_editing_canceled ();
                    });
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

        public async GLib.File? set_file_display_name (GLib.File old_location, string new_name,
                                                       GLib.Cancellable? cancellable = null) throws GLib.Error {

            /* Wait for the file to be added to the model before trying to select and scroll to it */
            slot.directory.file_added.connect_after (after_renamed_file_added);
            try {
                return yield PF.FileUtils.set_file_display_name (old_location, new_name, cancellable);
            } catch (GLib.Error e) {
                throw e;
            }
        }

        private void after_renamed_file_added (Files.File? new_file) {
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
            return true;
        }

        protected void block_drag_and_drop () {
            if (!dnd_disabled) {
                drag_data = view.get_data ("gtk-site-data");
                GLib.SignalHandler.block_matched (view, GLib.SignalMatchType.DATA, 0, 0, null, null, drag_data);
                dnd_disabled = true;
            }
        }

        protected void unblock_drag_and_drop () {
            if (dnd_disabled) {
                GLib.SignalHandler.unblock_matched (view, GLib.SignalMatchType.DATA, 0, 0, null, null, drag_data);
                dnd_disabled = false;
            }
        }

        protected virtual bool on_view_button_press_event (Gdk.EventButton event) {
            if (renaming) {
                /* Commit any change if renaming (https://github.com/elementary/files/issues/641) */
                name_renderer.end_editing (false);
            }

            cancel_hover (); /* cancel overlay statusbar cancellables */

            /* Ignore if second button pressed before first released - not permitted during rubberbanding.
             * Multiple click produces an event without corresponding release event so do not block that.
             */
            if (dnd_disabled && event.type == Gdk.EventType.BUTTON_PRESS) {
                return true;
            }

            grab_focus ();

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

            /* Native Gtk behaviour for all clicks on empty space */
            if (click_zone == ClickZone.BLANK_NO_PATH) {
                return false;
            }

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
                            update_selected_files_and_menu ();
                            should_activate = false;

                            if (no_mods && one_or_less) { /* Only activate single files with unmodified button press */
                                should_activate = on_directory || double_click_event;
                            }
                            /* We need to decide whether to rubberband or drag&drop.
                             * Rubberband if modifer pressed or if not on the icon and either
                             * the item is unselected.
                             */

                            if (!no_mods || (on_blank && !path_selected)) {
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
                                result = only_shift_pressed && handle_multi_select (path);
                            } else {
                                if (path_selected) {
                                    /* Don't deselect yet, may drag */
                                    should_deselect = true;
                                } else {
                                    should_deselect = false;
                                    select_path (path, true); /* Cursor follow and selection preserved */
                                }

                                unblock_drag_and_drop ();
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
                        click_zone == ClickZone.ICON ||
                        click_zone == ClickZone.HELPER) {

                        select_path (path); /* Note: secondary click does not toggle selection */
                    } else if (click_zone == ClickZone.INVALID) {
                        unselect_all ();
                    }

                    /* Ensure selected files list and menu actions are updated before context menu shown */
                    update_selected_files_and_menu ();
                    unblock_drag_and_drop ();
                    start_drag_timer (event);

                    result = handle_secondary_button_click (event);
                    break;

                default:
                    result = handle_default_button_click (event);
                    break;
            }

            return result;
        }

        protected virtual bool on_view_button_release_event (Gdk.EventButton event) {
            unblock_drag_and_drop ();

            /* Ignore button release from click that started renaming.
             * View may lose focus during a drag if another tab is hovered, in which case
             * we do not want to refocus this view.
             * Under both these circumstances, 'should_activate' will be false */
            if (renaming || !view_has_focus ()) {
                return true;
            }

            slot.active (should_scroll);

            Gtk.Widget widget = get_child ();
            int x = (int)event.x;
            int y = (int)event.y;
            update_selected_files_and_menu ();
            /* Only take action if pointer has not moved */
            if (!Gtk.drag_check_threshold (widget, drag_x, drag_y, x, y)) {
                if (should_activate) {
                    /* Need Idle else can crash with rapid clicking (avoid nested signals) */
                    Idle.add (() => {
                        var flag = event.button == Gdk.BUTTON_MIDDLE ? Files.OpenFlag.NEW_TAB :
                                                                       Files.OpenFlag.DEFAULT;

                        activate_selected_items (flag);
                        return GLib.Source.REMOVE;
                    });
                } else if (should_deselect && click_path != null) {
                    unselect_path (click_path);
                    /* Only need to update selected files if changed by this handler */
                    Idle.add (() => {
                        update_selected_files_and_menu ();
                        return GLib.Source.REMOVE;
                    });
                } else if (event.button == Gdk.BUTTON_SECONDARY) {
                    show_context_menu (event);
                }
            }

            should_activate = false;
            should_deselect = false;
            click_path = null;
            return false;
        }

        public virtual void change_zoom_level () {
            view.style_updated ();
        }

        private void start_renaming_file (Files.File file) {
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
                    return GLib.Source.CONTINUE;
                } else if (!ok_next_time) {
                    ok_next_time = true;
                    return GLib.Source.CONTINUE;
                }

                /* set cursor_on_cell also triggers editing-started */
                name_renderer.editable = true;
                set_cursor_on_cell (path, name_renderer as Gtk.CellRenderer, true, false);
                return GLib.Source.REMOVE;
            });

        }

        protected void on_sort_column_changed () {
            int sort_column_id = 0;
            Gtk.SortType sort_order = 0;

            /* Setting file attributes fails when root */
            if (Files.is_admin ()) {
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
            unowned string sort_col_s = ((Files.ListModel.ColumnID) sort_column_id).to_string ();
            unowned string sort_order_s = (sort_order == Gtk.SortType.DESCENDING ? "true" : "false");
            info.set_attribute_string ("metadata::marlin-sort-column-id", sort_col_s);
            info.set_attribute_string ("metadata::marlin-sort-reversed", sort_order_s);

            /* Make sure directory file info matches metadata (bug 1511307).*/
            dir.file.info.set_attribute_string ("metadata::marlin-sort-column-id", sort_col_s);
            dir.file.info.set_attribute_string ("metadata::marlin-sort-reversed", sort_order_s);
            dir.file.sort_column_id = sort_column_id;
            dir.file.sort_order = sort_order;

            if (!Files.is_admin ()) {
                dir.location.set_attributes_async.begin (info,
                                                   GLib.FileQueryInfoFlags.NONE,
                                                   GLib.Priority.DEFAULT,
                                                   null,
                                                   (obj, res) => {
                    try {
                        GLib.FileInfo inf;
                        dir.location.set_attributes_async.end (res, out inf);
                    } catch (GLib.Error e) {
                        warning ("Could not set file attributes: %s", e.message);
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

            one_or_less = (selected_files == null || selected_files.next == null);
        }

        protected virtual bool expand_collapse (Gtk.TreePath? path) {
            item_hovered (null);
            return true;
        }

        protected virtual bool handle_default_button_click (Gdk.EventButton event) {
            /* pass unhandled events to the View.Window */
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
        protected virtual bool move_cursor (uint keyval, bool only_shift_pressed, bool control_pressed) {
            return false;
        }

        protected virtual bool will_handle_button_press (bool no_mods, bool only_control_pressed,
                                                         bool only_shift_pressed) {
            if (!no_mods && !only_control_pressed) {
                return false;
            } else {
                return true;
            }
        }

        protected bool is_on_icon (int x, int y, ref bool on_helper) {
            /* x and y must be in same coordinate system as used by the IconRenderer */
            Gdk.Rectangle pointer_rect = {x - 2, y - 2, 4, 4}; /* Allow slight inaccuracy */
            bool on_icon = pointer_rect.intersect (icon_renderer.hover_rect, null);
            on_helper = pointer_rect.intersect (icon_renderer.hover_helper_rect, null);
            return on_icon;
        }

        /* Multi-select could be by rubberbanding or modified clicking. Returning false
         * invokes the default widget handler.  IconView requires special handler */
        protected virtual bool handle_multi_select (Gtk.TreePath path) {return false;}

        protected abstract Gtk.Widget? create_view ();
        protected abstract void set_up_zoom_level ();
        protected abstract ZoomLevel get_normal_zoom_level ();
        protected abstract bool view_has_focus ();
        protected abstract uint get_selected_files_from_model (out GLib.List<Files.File> selected_files);
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

/** Unimplemented methods
 *  fm_directory_view_parent_set ()  - purpose unclear
*/
    }
}
