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
* Authored by: Jeremy Wootten <jeremywootten@gmail.com>
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

        const int MAX_TEMPLATES = 2048;

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
            {"restore", on_selection_action_restore},
            {"invert-selection", invert_selection}
        };

        const GLib.ActionEntry [] BACKGROUND_ENTRIES = {
            {"new", on_background_action_new, "s"},
            {"create-from", on_background_action_create_from, "s"},
            {"sort-by", on_background_action_sort_by_changed, "s", "'name'"},
            {"reverse", on_background_action_reverse_changed, null, "false"},
            {"folders-first", on_background_action_folders_first_changed, null, "true"},
            {"show-hidden", null, null, "false", change_state_show_hidden}
        };

        const GLib.ActionEntry [] COMMON_ENTRIES = {
            {"copy", on_common_action_copy},
            {"paste-into", on_common_action_paste_into}, // Paste into selected folder
            {"paste", on_common_action_paste}, // Paste into background folder
            {"open-in", on_common_action_open_in, "s"},
            {"bookmark", on_common_action_bookmark},
            {"properties", on_common_action_properties},
            {"copy-link", on_common_action_copy_link},
            {"select-all", toggle_select_all},
            {"set-wallpaper", action_set_wallpaper}
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

                on_zoom_level_changed (_zoom_level);
            }
        }

        public int icon_size {
            get {
                return _zoom_level.to_icon_size ();
            }
        }

        protected ZoomLevel minimum_zoom = ZoomLevel.SMALLEST;
        protected ZoomLevel maximum_zoom = ZoomLevel.LARGEST;

        /* Used only when acting as drag source */
        double drag_x = 0;
        double drag_y = 0;
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
        /* Suppress native behavior when required */
        private bool button_press_disabled = false;
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
        protected bool should_deselect = false;
        protected bool should_thumbnail = true;

        public bool singleclick_select { get; set; }

        protected bool should_select = false;
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
                        action_set_enabled (common_actions, "paste", false);

                        /* Fix problems when navigating away from directory with large number
                         * of selected files (e.g. OverlayBar critical errors)
                         */
                        disconnect_tree_signals ();
                        clipboard.changed.disconnect (on_clipboard_changed);
                    } else {
                        clipboard.changed.connect (on_clipboard_changed);
                        connect_tree_signals ();

                        update_menu_actions ();
                    }

                    key_controller.propagation_phase = value ? Gtk.PropagationPhase.NONE : Gtk.PropagationPhase.BUBBLE;
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

        private bool all_selected = false;

        private Gtk.Widget view;
        private unowned ClipboardManager clipboard;
        protected Files.ListModel model;
        protected Files.IconRenderer icon_renderer;
        protected unowned View.Slot slot; // Must be unowned else cyclic reference stops destruction
        protected unowned View.Window? window {
            get {
                return slot.ctab.window;
            }
        }
        protected static DndHandler dnd_handler = new DndHandler ();

        protected unowned Gtk.RecentManager recent;

        protected Gtk.EventControllerKey key_controller;
        protected Gtk.GestureMultiPress button_controller;
        protected Gtk.EventControllerScroll scroll_controller;
        protected Gtk.EventControllerMotion motion_controller;

        public signal void path_change_request (GLib.File location, Files.OpenFlag flag, bool new_root);
        public signal void selection_changed (GLib.List<Files.File> gof_file);

        protected AbstractDirectoryView (View.Slot _slot) {
            slot = _slot;
            editable_cursor = new Gdk.Cursor.from_name (Gdk.Display.get_default (), "text");
            activatable_cursor = new Gdk.Cursor.from_name (Gdk.Display.get_default (), "pointer");
            selectable_cursor = new Gdk.Cursor.from_name (Gdk.Display.get_default (), "default");

            var app = (Files.Application)(GLib.Application.get_default ());
            clipboard = app.get_clipboard_manager ();
            recent = app.get_recent_manager ();
            app.set_accels_for_action ("common.select-all", {"<Ctrl>A"});
            app.set_accels_for_action ("selection.invert-selection", {"<Shift><Ctrl>A"});

            thumbnailer = Thumbnailer.get ();
            thumbnailer.finished.connect ((req) => {
                if (req == thumbnail_request) {
                    thumbnail_request = -1;
                }

                draw_when_idle ();
            });

            set_should_thumbnail ();

            model = new Files.ListModel ();


             /* Currently, "single-click rename" is disabled, matching existing UI
              * Currently, "right margin unselects all" is disabled, matching existing UI
              */

            set_up__menu_actions ();
            set_up_directory_view ();
            view = create_view ();

            if (view != null) {
                child = view;
                show_all ();
                connect_drag_drop_signals (view);

                view.draw.connect (on_view_draw);
                view.realize.connect (() => {
                   schedule_thumbnail_color_tag_timeout ();
                });

                scroll_controller = new Gtk.EventControllerScroll (view, NONE);
                scroll_controller.scroll.connect (on_scroll_event);

                key_controller = new Gtk.EventControllerKey (view) {
                    propagation_phase = BUBBLE
                };
                key_controller.key_pressed.connect (on_view_key_press_event);
                // Workaround for scroll events getting consumed by scroll controller
                // Only handle scroll events when a key is pressed (for zooming), otherwise they will be handled
                // by the native widget
                key_controller.key_pressed.connect (() => {scroll_controller.flags = VERTICAL; return false;});
                key_controller.key_released.connect (() => scroll_controller.flags = NONE);

                // Hack required to suppress native behaviour when dragging
                // multiple selected items with GestureMultiPress event controller
                // Native behaviour deselects items except the one clicked on
                view.button_press_event.connect (() => {
                    return button_press_disabled;
                });

                button_controller = new Gtk.GestureMultiPress (view) {
                    propagation_phase = TARGET,  //Allow editable widget to receive button press event first
                    button = 0
                };
                button_controller.pressed.connect (on_view_button_press_event);
                button_controller.released.connect (on_view_button_release_event);

                motion_controller = new Gtk.EventControllerMotion (view) {
                    propagation_phase = CAPTURE
                };
                motion_controller.motion.connect (on_motion_notify_event);
                motion_controller.leave.connect (on_leave_notify_event);
            }

            freeze_tree (); /* speed up loading of icon view. Thawed when directory loaded */
            set_up_zoom_level ();

            connect_directory_handlers (slot.directory);
        }

        ~AbstractDirectoryView () {
            debug ("ADV destruct"); // Cannot reference slot here as it is already invalid
        }

        protected void set_up_name_renderer () {
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

            get_vadjustment ().value_changed.connect_after (() => {
                schedule_thumbnail_color_tag_timeout ();
            });

            notify["renaming"].connect (() => {
                // Suppress ability to scroll with the scrollbar while renaming
                // No obvious way to disable it so just hide it
                var vscroll_bar = get_vscrollbar ();
                vscroll_bar.visible = !renaming;
            });


            var prefs = (Files.Preferences.get_default ());
            prefs.notify["show-hidden-files"].connect (on_show_hidden_files_changed);
            prefs.notify["show-remote-thumbnails"].connect (on_show_thumbnails_changed);
            prefs.notify["show-local-thumbnails"].connect (on_show_thumbnails_changed);
            prefs.notify["sort-directories-first"].connect (on_sort_directories_first_changed);
            prefs.bind_property (
                "singleclick-select", this, "singleclick_select", BindingFlags.DEFAULT | BindingFlags.SYNC_CREATE
            );

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
            var view_settings = get_view_settings ();
            if (view_settings == null) {
                zoom_level = ZoomLevel.NORMAL;
            } else {
                zoom_level = (ZoomLevel)view_settings.get_enum ("default-zoom-level"); // syncs to settings
            }


        }

        private uint set_cursor_timeout_id = 0;
        public void focus_first_for_empty_selection (bool select) {
            if (selected_files == null) {
                set_cursor_timeout_id = Idle.add_full (GLib.Priority.LOW, () => {
                    if (!tree_frozen) {
                        set_cursor_timeout_id = 0;
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

            // Ensure focus file not overridden later
            if (set_cursor_timeout_id > 0) {
                Source.remove (set_cursor_timeout_id);
                set_cursor_timeout_id = 0;
            }

            if (select_source_handler > 0) {
                disconnect (select_source_handler);
                select_source_handler = 0;
            }

            disconnect_tree_signals (); /* Avoid unnecessary signal processing */
            unselect_all ();

            uint count = 0;
            Gtk.TreeIter? iter;
            foreach (Files.File f in files_to_select) {
                /* Not all files selected in previous view  (e.g. expanded tree view) may appear in this one. */
                var path = model.get_path_for_first_file (f);
                if (path != null) {
                    count++;
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
            var path = model.get_path_for_first_file (file);
            set_cursor (path, false, true, false);
        }

        protected void select_and_scroll_to_gof_file (Files.File file) {
            var path = model.get_path_for_first_file (file);
            set_cursor (path, false, true, true);
        }

        protected void add_gof_file_to_selection (Files.File file) {
            select_path (model.get_path_for_first_file (file)); /* Cursor does not follow */
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
            model.set_sorting_off ();
            dir.file_loaded.connect (on_directory_file_loaded);
            dir.done_loading.connect (on_directory_done_loading);
        }

        protected void disconnect_directory_loading_handlers (Directory dir) {
            model.set_sorting_on ();
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
            /* Prevent unexpected file activation after navigation with double-click in mixed mode */
            on_directory = false;
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
                Gdk.ModifierType.BUTTON1_MASK | Gdk.ModifierType.CONTROL_MASK,
                DRAG_TARGETS,
                FILE_DRAG_ACTIONS
            );
            widget.drag_begin.connect (on_drag_begin);
            widget.drag_data_get.connect (on_drag_data_get);
            widget.drag_data_delete.connect (on_drag_data_delete);
            widget.drag_end.connect (on_drag_end);
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
                MimeActions.open_glib_file_request.begin (file.location, this, app_info);
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

            deleted_path = model.get_path_for_first_file (file_list.first ().data);

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

        // Only called after initial loading finished, in response to files added due to internal or external
        // file operations
        private void add_file (Files.File file, Directory dir, bool is_internal = true) {
            model.insert_sorted (file, dir);
            if (is_internal) { /* This true once view finished loading */
                // Do not select until the model has resorted else wrong file is selected
                ulong model_resorted = 0;
                model_resorted = model.rows_reordered.connect (() => {
                     model.disconnect (model_resorted);
                     add_gof_file_to_selection (file);
                });
            }
        }

        private void handle_free_space_change () requires (window != null) {
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
                // Wait for model to sort before starting to rename.
                Timeout.add (50, () => {
                    if (model.sort_pending) {
                        return Source.CONTINUE;
                    } else {
                        start_renaming_file (file_to_rename);
                        return Source.REMOVE;
                    }
                });

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
            rename_selection ();
        }

        private void rename_selection () {
            if (selected_files == null) {
                return;
            }

            if (selected_files.next != null) {
                var rename_dialog = new Files.RenamerDialog (selected_files) {
                    transient_for = slot.window
                };
                rename_dialog.present ();
            } else {
                rename_file (selected_files.data);
            }
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
            FileUtils.restore_files_from_trash.begin (selection, window);
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

        private void on_common_action_bookmark (GLib.SimpleAction action, GLib.Variant? param) requires (window != null) {
            GLib.File location;
            if (selected_files != null) {
                location = selected_files.data.get_target_location ();
            } else {
                location = slot.directory.file.get_target_location ();
            }

            window.bookmark_uri (location.get_uri ());
        }

        /** Background actions */

        private void change_state_show_hidden (GLib.SimpleAction action) requires (window != null) {
            window.change_state_show_hidden (action);
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
            var path = param.get_string ();
            create_from_template (path);
        }

        private void on_background_action_sort_by_changed (GLib.SimpleAction action, GLib.Variant? val) {
            set_sort (val != null ? val.get_string () : null, false);
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
            } else {
                warning ("Set Sort: The model is unsorted - this should not happen");
            }
        }

        /** Common actions */
        private void action_set_wallpaper (GLib.SimpleAction action, GLib.Variant? param) {
            var file = get_files_for_action ().nth_data (0);

            var active_window = (Gtk.Window) get_toplevel ();
            Xdp.Parent? parent = active_window != null ? Xdp.parent_new_gtk (active_window) : null;

            var portal = new Xdp.Portal ();
            portal.set_wallpaper.begin (parent, file.uri, NONE, null);
        }

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

        private void on_common_action_paste (GLib.SimpleAction action, GLib.Variant? param) {
            if (clipboard.can_paste && !(clipboard.files_linked && in_trash)) {
                var target = slot.location;
                clipboard.paste_files.begin (target, this as Gtk.Widget, (obj, res) => {
                    clipboard.paste_files.end (res);
                    if (target.has_uri_scheme ("trash")) {
                        /* Pasting files into trash is equivalent to trash or delete action */
                        after_trash_or_delete ();
                    }
                });
            }
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

        private void toggle_select_all () {
            update_selected_files_and_menu ();
            if (all_selected) {
                unselect_all ();
            } else {
                select_all ();
            }
        }

        private void on_directory_file_added (Directory dir, Files.File? file, bool is_internal) {
            if (file != null) {
                add_file (file, dir, is_internal); /* Only select files added to view by this app */
                handle_free_space_change ();
                Idle.add (() => {
                    update_icon_and_plugins (file);
                    return Source.REMOVE;
                });
            } else {
                critical ("Null file added");
            }
        }

        private void on_directory_file_loaded (Directory dir, Files.File file) {
            // Do not select or sort files added during initial load.
            model.add_file (file, dir);
        }

        private void on_directory_file_changed (Directory dir, Files.File file) {
            if (file.location.equal (dir.file.location)) {
                /* The slot directory has changed - it can only be the properties */
                is_writable = slot.directory.file.is_writable ();
            } else {
                on_directory_file_icon_changed (dir, file);
            }
        }

        private void on_directory_file_icon_changed (Directory dir, Files.File file) {
            if (is_frozen) {
                return;
            }

            model.file_changed (file, dir);
            Idle.add (() => {
                update_icon_and_plugins (file);
                if (should_thumbnail) {
                    thumbnailer.queue_file (file, null);
                }

                return Source.REMOVE;
            });

            draw_when_idle ();
        }

        private void on_directory_file_deleted (Directory dir, Files.File file) {
            /* The deleted file could be the whole directory, which is not in the model but that
             * that does not matter.  */
            file.exists = false;
            model.remove_file (file, dir);

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

            // Wait for view to draw so thumbnails and color tags displayed on first sight
            Idle.add (() => {
                thaw_tree ();
                schedule_thumbnail_color_tag_timeout ();
                return Source.REMOVE;
            });
        }

    /** Handle zoom level change */
        private void on_zoom_level_changed (ZoomLevel zoom) {
            model.icon_size = icon_size;
            change_zoom_level ();
        }

    /** Handle Preference changes */
        private void on_show_hidden_files_changed (GLib.Object prefs, GLib.ParamSpec pspec) {
            bool show = ((Files.Preferences) prefs).show_hidden_files;
            model.show_hidden_files = show;
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

            foreach (Files.File file in slot.directory.get_files ()) {
                if (file.is_folder ()) {
                    file.ensure_size ();
                }
            }

            action_set_state (background_actions, "show-hidden", show);
        }

        private void set_should_thumbnail () {
            var prefs = Files.Preferences.get_default ();
            if (slot.directory.is_network) {
                should_thumbnail = slot.directory.can_open_files && prefs.show_remote_thumbnails;
            } else {
                should_thumbnail = prefs.show_local_thumbnails;
            }
        }

        private void on_show_thumbnails_changed () {
            set_should_thumbnail ();
            slot.reload ();
        }

        private void on_sort_directories_first_changed (GLib.Object prefs, GLib.ParamSpec pspec) {
            var sort_directories_first = ((Files.Preferences) prefs).sort_directories_first;
            model.set_should_sort_directories_first (sort_directories_first);
        }

        private void directory_hidden_changed (Directory dir, bool show) {
            /* May not be slot.directory - could be subdirectory */
            connect_directory_loading_handlers (dir);
            dir.load_hiddens ();
        }

    /** Handle popup menu events */
        private bool on_popup_menu () {
            Gdk.Event event = Gtk.get_current_event ();
            show_context_menu (event);
            return true;
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
        private void on_drag_begin () {
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
        private void on_drag_data_delete () {
            /* block real_view default handler because handled in on_drag_end */
            GLib.Signal.stop_emission_by_name (get_child (), "drag-data-delete");
        }

        /* Signal emitted on source after completion of DnD. */
        private void on_drag_end () {
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
                start_drag_scroll_timer (Gtk.get_current_event_device ());
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
                string? filename = dnd_handler.get_source_filename (context.get_source_window ());
                if (target_file != null && filename != null) {
                    /* Get uri of source file when dropped */
                    uri = target_file.get_target_location ().resolve_relative_path (filename).get_uri ();
                    /* Setup the XdndDirectSave property on the source window */
                    dnd_handler.set_source_uri (context.get_source_window (), uri);
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
                    destination_drop_file_list = FileUtils.files_from_uris (text);
                    destination_data_ready = true;
                }
            }

            if (drop_occurred) {
                bool success = false;
                drop_occurred = false;

                switch (info) {
                    case Files.TargetType.XDND_DIRECT_SAVE0:
                        success = dnd_handler.handle_xdnddirectsave (context.get_source_window (),
                                                                     drop_target_file,
                                                                     selection_data);
                        break;

                    case Files.TargetType.NETSCAPE_URL:
                        success = dnd_handler.handle_netscape_url (context.get_source_window (),
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
                            drop_target_file,
                            destination_drop_file_list,
                            current_actions,
                            current_suggested_action,
                            (Gtk.ApplicationWindow)Files.get_active_window (),
                            timestamp
                        );

                        Idle.add (() => {
                            update_selected_files_and_menu ();
                            return Source.REMOVE;
                        });

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
        private void on_drag_leave () {
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

                        current_actions = DndHandler.file_accepts_drop (
                            drop_target_file,
                            destination_drop_file_list,
                            context.get_selected_action (),
                            context.get_actions (),
                            out current_suggested_action
                        );
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



        protected void show_context_menu (Gdk.Event event) requires (window != null) {
            /* select selection or background context menu */
            update_menu_actions ();

            var menu = new Gtk.Menu ();

            var selection = get_files_for_action ();
            var selected_file = selection.data;

            var open_submenu = new Gtk.Menu ();

            if (common_actions.get_action_enabled ("open-in")) {
                var new_tab_menuitem = new Gtk.MenuItem ();
                if (selected_files != null) {
                    new_tab_menuitem.add (new Granite.AccelLabel (
                        _("New Tab"),
                        "<Shift>Return"
                    ));
                    new_tab_menuitem.action_name = "common.open-in";
                } else {
                    new_tab_menuitem.add (new Granite.AccelLabel.from_action_name (
                        _("New Tab"),
                        "win.tab::TAB"
                    ));
                    new_tab_menuitem.action_name = "win.tab";
                }

                new_tab_menuitem.action_target = "TAB";

                var new_window_menuitem = new Gtk.MenuItem ();
                if (selected_files != null) {
                    new_window_menuitem.add (new Granite.AccelLabel (
                        _("New Window"),
                        "<Shift><Ctrl>Return"
                    ));
                    new_window_menuitem.action_name = "common.open-in";
                } else {
                    new_window_menuitem.add (new Granite.AccelLabel.from_action_name (
                        _("New Window"),
                        "win.tab::WINDOW"
                    ));
                    new_window_menuitem.action_name = "win.tab";
                }
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

            var paste_menuitem = new Gtk.MenuItem ();
            paste_menuitem.action_name = "common.paste";

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

            Gtk.MenuItem? select_all_menuitem = null;
            Gtk.MenuItem? deselect_all_menuitem = null;
            Gtk.MenuItem? invert_selection_menuitem = null;
            if (!all_selected) {
                select_all_menuitem = new Gtk.MenuItem () {
                    action_name = "common.select-all"
                };
                select_all_menuitem.add (new Granite.AccelLabel.from_action_name (
                    _("Select All"),
                    select_all_menuitem.action_name
                ));

                if (get_selected_files () != null) {
                    invert_selection_menuitem = new Gtk.MenuItem () {
                        action_name = "selection.invert-selection"
                    };
                    invert_selection_menuitem.add (new Granite.AccelLabel.from_action_name (
                        _("Invert Selection"),
                        invert_selection_menuitem.action_name
                    ));
                }
            } else {
                deselect_all_menuitem = new Gtk.MenuItem () {
                    action_name = "common.select-all"
                };
                deselect_all_menuitem.add (new Granite.AccelLabel.from_action_name (
                    _("Deselect All"),
                    deselect_all_menuitem.action_name
                ));
            }

            if (get_selected_files () != null) { // Add selection actions
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

                var delete_menuitem = new Gtk.MenuItem.with_label (_("Delete Permanently")) {
                    action_name = "selection.delete"
                };
                delete_menuitem.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);

                /* In trash, only show context menu when all selected files are in root folder */
                if (in_trash && valid_selection_for_restore ()) {
                    var restore_menuitem = new Gtk.MenuItem.with_label (_("Restore from Trash"));
                    restore_menuitem.action_name = "selection.restore";

                    menu.add (new Gtk.SeparatorMenuItem ());
                    menu.add (restore_menuitem);
                    menu.add (delete_menuitem);
                    menu.add (new Gtk.SeparatorMenuItem ());
                    menu.add (cut_menuitem);
                    if (select_all_menuitem != null) {
                        menu.add (select_all_menuitem);
                    }

                    if (deselect_all_menuitem != null) {
                        menu.add (deselect_all_menuitem);
                    }

                    if (invert_selection_menuitem != null) {
                        menu.add (invert_selection_menuitem);
                    }

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
                    if (select_all_menuitem != null) {
                        menu.add (select_all_menuitem);
                    }

                    if (deselect_all_menuitem != null) {
                        menu.add (deselect_all_menuitem);
                    }

                    if (invert_selection_menuitem != null) {
                        menu.add (invert_selection_menuitem);
                    }

                    menu.add (trash_menuitem);
                    menu.add (new Gtk.SeparatorMenuItem ());
                    menu.add (properties_menuitem);
                } else {
                    if (valid_selection_for_edit ()) {
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
                        // Do not display 'Paste' menuitem if there is a selected folder ('Paste into' enabled)
                        if (common_actions.get_action_enabled ("paste-into") &&
                            clipboard != null && clipboard.can_paste) {
                            var paste_into_menuitem = new Gtk.MenuItem () {
                                action_name = "common.paste-into"
                            };

                            if (clipboard.files_linked) {
                                paste_into_menuitem.add (new Granite.AccelLabel (
                                    _("Paste Link into Folder"),
                                    "<Shift><Ctrl>v"
                                ));
                            } else {
                                paste_into_menuitem.add (new Granite.AccelLabel (
                                    _("Paste into Folder"),
                                    "<Shift><Ctrl>v"
                                ));
                            }

                            menu.add (paste_into_menuitem);
                        } else if (common_actions.get_action_enabled ("paste") &&
                            clipboard != null && clipboard.can_paste) {

                            paste_menuitem.add (new Granite.AccelLabel (
                                _("Paste"),
                                "<Ctrl>v"
                            ));
                            menu.add (paste_menuitem);
                        }

                        if (select_all_menuitem != null) {
                            menu.add (select_all_menuitem);
                        }

                        if (deselect_all_menuitem != null) {
                            menu.add (deselect_all_menuitem);
                        }

                        if (invert_selection_menuitem != null) {
                            menu.add (invert_selection_menuitem);
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
            } else { // Add background folder actions
                if (in_trash) {
                    if (clipboard != null && clipboard.has_cutted_file (null)) {
                        paste_menuitem.add (new Granite.AccelLabel (
                            _("Paste into Folder"),
                            "<Ctrl>v"
                        ));
                        menu.add (paste_menuitem);
                        if (select_all_menuitem != null) {
                            menu.add (select_all_menuitem);
                        }
                    }
                } else if (in_recent) {
                    if (select_all_menuitem != null) {
                        menu.add (select_all_menuitem);
                    }

                    menu.add (new Gtk.SeparatorMenuItem ());
                    menu.add (new SortSubMenuItem ());
                    menu.add (new Gtk.SeparatorMenuItem ());
                } else {
                    if (!in_network_root) {
                        menu.add (new Gtk.SeparatorMenuItem ());
                        /* If something is pastable in the clipboard, show the option even if it is not enabled */
                        if (clipboard != null && clipboard.can_paste) {
                            if (clipboard.files_linked) {
                                paste_menuitem.add (new Granite.AccelLabel (
                                    _("Paste Link into Folder"),
                                    "<Ctrl>v"
                                ));
                            } else {
                                paste_menuitem.add (new Granite.AccelLabel (
                                    _("Paste"),
                                    "<Ctrl>v"
                                ));
                            }
                        }

                        menu.add (paste_menuitem);
                        if (select_all_menuitem != null) {
                            menu.add (select_all_menuitem);
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

                    if (!in_network_root) {
                        menu.add (new Gtk.SeparatorMenuItem ());
                        menu.add (properties_menuitem);
                    }
                }
            }

            if (!in_trash) {
                // We send the actual files - it is up to the plugin to extract target
                // if needed.  Color tag plugin needs actual file, others need target
                plugins.hook_context_menu (menu as Gtk.Widget, get_selected_files ());

                if (selection.length () == 1 && "image" in selection.nth_data (0).info.get_content_type ()) {
                    var wallpaper_menuitem = new Gtk.MenuItem.with_label (_("Set as Wallpaper")) {
                        action_name = "common.set-wallpaper"
                    };

                    menu.add (wallpaper_menuitem);
                }
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

                unowned string? template_path = GLib.Environment.get_user_special_dir (GLib.UserDirectory.TEMPLATES);
                if (template_path != null) {
                    load_templates_from_folder (GLib.File.new_for_path (template_path), submenu);
                }

                label = _("New");
            }

            private void load_templates_from_folder (GLib.File template_folder, Gtk.Menu submenu, uint count = 0) {
                GLib.List<GLib.File> file_list = null;
                GLib.List<GLib.File> folder_list = null;

                GLib.FileEnumerator enumerator;
                var flags = GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS;
                try {
                    enumerator = template_folder.enumerate_children ("standard::*", flags, null);
                    GLib.File location;
                    GLib.FileInfo? info = enumerator.next_file (null);

                    while (count < MAX_TEMPLATES && (info != null)) {
                        if (!info.get_attribute_boolean (GLib.FileAttribute.STANDARD_IS_BACKUP)) {
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

                if (folder_list.length () > 0) {
                    folder_list.sort ((a, b) => {
                        return strcmp (a.get_basename ().down (), b.get_basename ().down ());
                    });

                    folder_list.@foreach ((folder) => {
                        var folder_menu = new Gtk.Menu ();
                        var folder_menuitem = new Gtk.MenuItem.with_label (folder.get_basename ());
                        folder_menuitem.submenu = folder_menu;
                        submenu.add (folder_menuitem);
                        load_templates_from_folder (folder, folder_menu);
                    });
                }

                if (file_list.length () > 0) {
                    file_list.sort ((a, b) => {
                        return strcmp (a.get_basename ().down (), b.get_basename ().down ());
                    });

                    file_list.@foreach ((file) => {
                        var template_menuitem = new Gtk.MenuItem.with_label (file.get_basename ()) {
                            action_name = "background.create-from",
                            action_target = file.get_path ()
                        };

                        submenu.add (template_menuitem);
                    });
                }
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

            action_set_enabled (common_actions, "paste", !in_recent && is_writable);
            action_set_enabled (common_actions, "paste-into", !renaming & can_paste_into);
            action_set_enabled (common_actions, "open-in", !renaming & only_folders);
            action_set_enabled (selection_actions, "rename", !renaming & is_selected && can_rename);
            action_set_enabled (selection_actions, "view-in-location", !renaming & is_selected);
            action_set_enabled (selection_actions, "open", !renaming && is_selected && !more_than_one_selected && can_open);
            action_set_enabled (selection_actions, "open-with-app", !renaming && can_open);
            action_set_enabled (selection_actions, "open-with-default", !renaming && can_open);
            action_set_enabled (selection_actions, "open-with-other-app", !renaming && can_open);
            action_set_enabled (selection_actions, "cut", !renaming && is_writable && is_selected);
            action_set_enabled (selection_actions, "trash", !renaming && is_writable && slot.directory.has_trash_dirs);
            action_set_enabled (selection_actions, "delete", !renaming && is_writable);
            action_set_enabled (selection_actions, "invert-selection", !renaming && is_selected);
            action_set_enabled (common_actions, "select-all", !renaming && is_selected);
            action_set_enabled (common_actions, "properties", !renaming && can_show_properties);
            action_set_enabled (common_actions, "bookmark", !renaming && can_bookmark);
            action_set_enabled (common_actions, "copy", !renaming && !in_trash && can_copy);
            action_set_enabled (common_actions, "copy-link", !renaming && !in_trash && !in_recent && can_copy);
            action_set_enabled (common_actions, "bookmark", !renaming && !more_than_one_selected);
            action_set_enabled (common_actions, "set-wallpaper", !renaming && !more_than_one_selected);

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
            } else {
                warning ("Update menu actions sort: The model is unsorted - this should not happen");
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

            return (exec_name == Config.APP_NAME);
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

        private void create_from_template (string path) {
            /* Block the async directory file monitor to avoid generating unwanted "add-file" events */
            slot.directory.block_monitor ();
            var template = GLib.File.new_for_path (path);
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
        private void schedule_thumbnail_color_tag_timeout () {
            /* delay creating the idle until the view has finished loading.
             * this is done because we only can tell the visible range reliably after
             * all items have been added and we've perhaps scrolled to the file remembered
             * the last time */

            assert (slot is Files.AbstractSlot && slot.directory != null);

            /* Check all known conditions preventing thumbnailing at earliest possible stage */
            if (!slot.directory.can_open_files ||
                slot.directory.is_loading ()) {

                    return;
            }

            /* Restart the timeout.
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
                        if (file != null) {
                            update_icon_and_plugins (file);
                            /* Ask thumbnailer only if ThumbState UNKNOWN */
                            if (should_thumbnail) {
                                if (file.thumbstate == Files.File.ThumbState.UNKNOWN) {
                                    visible_files.prepend (file);
                                    if (path.compare (sp) >= 0 && path.compare (ep) <= 0) {
                                        actually_visible++;
                                    }
                                }
                            } else {
                                file.thumbstate = Files.File.ThumbState.NONE;
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
                    thumbnailer.queue_files (visible_files, out thumbnail_request);
                }

                //Need to redraw anyway so that standard icons are rendered.
                draw_when_idle ();

                thumbnail_source_id = 0;

                return GLib.Source.REMOVE;
            });
        }

        // Called on individual files when added or changed as well as on all visible files
        // by schedule_thumbnail_color_tag_timeout.
        private void update_icon_and_plugins (Files.File file) requires (file != null) {
            if (!file.is_gone) {
                // Only update thumbnail if it is going to be shown
                if (should_thumbnail) {
                    file.update_icon ();
                }

                /* In any case, ensure color-tag info is correct */
                if (plugins != null) {
                    plugins.update_file_info (file);
                }
            }
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

        private void start_drag_scroll_timer (Gdk.Device pointer) requires (window != null) {
            drag_scroll_timer_id = GLib.Timeout.add_full (GLib.Priority.LOW,
                                                          50,
                                                          () => {
                Gtk.Widget? widget = get_child ();
                if (widget != null) {
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
        protected virtual bool on_view_key_press_event (uint original_keyval, uint keycode, Gdk.ModifierType state) {
            if (is_frozen) {
                return true;
            }

            var event = Gtk.get_current_event ();
            cancel_hover ();

            Gdk.ModifierType consumed_mods;
            var keyval = map_key (original_keyval, keycode, out consumed_mods);

            var mods = (state & ~consumed_mods) & Gtk.accelerator_get_default_mod_mask ();
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
                        rename_selection ();
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
                    } else if (shift_pressed && control_pressed && !alt_pressed) {
                        activate_selected_items (Files.OpenFlag.NEW_WINDOW);
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

                case Gdk.Key.Up:
                case Gdk.Key.Down:
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

                case Gdk.Key.Left:
                case Gdk.Key.Right:
                case Gdk.Key.BackSpace:
                    if ((this is ColumnView) && no_mods) {
                        ((Files.View.Miller)(slot.ctab.view)).on_miller_key_pressed (keyval, keycode, state);
                        res = true;
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
                        if (shift_pressed) {  // Paste into selected folder if there is one
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
                        } else { // Paste into background folder
                            if (!in_recent && is_writable) {
                                action_set_enabled (common_actions, "paste", true);
                                common_actions.activate_action ("paste", null);
                            } else {
                                PF.Dialogs.show_warning_dialog (_("Cannot paste files here"),
                                                                _("You do not have permission to change this location"),
                                                                window as Gtk.Window);
                            }

                            res = true;
                        }
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

        protected void on_motion_notify_event (double x, double y) {
            // Determine appropriate cursor
            Gtk.TreePath? path = null;
            Files.File? file = null;

            if (renaming || is_frozen) {
                return;
            }

            click_zone = get_event_position_info (x, y, out path, false);

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

                    hover_path = path;
                }
            }

            if (click_zone != previous_click_zone) {
                var win = view.get_window ();
                win.set_cursor (selectable_cursor);

                switch (click_zone) {
                    case ClickZone.ICON:
                    case ClickZone.NAME:
                        if (on_directory && one_or_less && !singleclick_select) {
                            win.set_cursor (activatable_cursor);
                        }

                        break;

                    default:
                        break;
                }

                previous_click_zone = click_zone;
            }
        }

        protected void on_leave_notify_event () {
            hover_path = null;
        }

        protected virtual void on_scroll_event (double dx, double dy) {
            if (is_frozen) {
                return;
            }

            Gdk.ModifierType state;
            Gtk.get_current_event_state (out state);
            if ((state & Gdk.ModifierType.CONTROL_MASK) > 0) {
                /* try to emulate a normal scrolling event by summing deltas.
                 * step size of 0.5 chosen to match sensitivity */
                total_delta_y += dy;

                if (total_delta_y >= 0.5) {
                    total_delta_y = 0;
                    zoom_out ();
                } else if (total_delta_y <= -0.5) {
                    total_delta_y = 0;
                    zoom_in ();
                }
            } else {
                // In case "key-released" signal was missed
                scroll_controller.flags = NONE;
            }
        }

    /** name renderer signals */
        protected void on_name_editing_started (Gtk.CellEditable? editable, string path_string) {
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
                    FileUtils.get_rename_region (original_name, out start_offset, out end_offset, false);
                }
                editable_widget.select_region (start_offset, end_offset);
            } else {
                warning ("Editable widget is null");
                on_name_editing_canceled ();
            }
        }

        protected void on_name_editing_canceled () {
            is_frozen = false;
            renaming = false;
            name_renderer.editable = false;
            proposed_name = "";

            update_menu_actions ();
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
                return yield FileUtils.set_file_display_name (old_location, new_name, cancellable);
            } catch (GLib.Error e) {
                throw e;
            }
        }

        private void after_renamed_file_added (Files.File? new_file) {
            slot.directory.file_added.disconnect (after_renamed_file_added);
            /* new_file will be null if rename failed */
            if (new_file != null) {
                selected_files_invalid = true;
                Idle.add (() => {
                    if (model.sort_pending) {
                        return Source.CONTINUE;
                    } else {
                        select_and_scroll_to_gof_file (new_file);
                        return Source.REMOVE;
                    }
                });
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

        protected virtual bool handle_primary_button_click (uint n_press, Gdk.ModifierType mods, Gtk.TreePath? path) {
            return false; // Allow drag'n'drop
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

        protected virtual void on_view_button_press_event (int n_press, double x, double y) {
            if (renaming) {
                // Button press occurred outside editable widget - end editing.
                /* Commit any change if renaming (https://github.com/elementary/files/issues/641) */
                name_renderer.end_editing (false);
            }
            cancel_hover (); /* cancel overlay statusbar cancellables */
            grab_focus ();

            Gtk.TreePath? path = null;
            // /* Remember position of click for detecting drag motion*/
            drag_x = x;
            drag_y = y;
            var button = button_controller.get_current_button ();
            Gdk.ModifierType state;
            Gtk.get_current_event_state (out state); // In Gtk4 this can be obtained from controller

            //Only rubberband with primary button
            click_zone = get_event_position_info (x, y, out path, button == Gdk.BUTTON_PRIMARY);
            click_path = path;
            var mods = state & Gtk.accelerator_get_default_mod_mask ();
            bool no_mods = (mods == 0);
            bool control_pressed = ((mods & Gdk.ModifierType.CONTROL_MASK) != 0);
            bool shift_pressed = ((mods & Gdk.ModifierType.SHIFT_MASK) != 0);
            bool other_mod_pressed = (((mods & ~Gdk.ModifierType.SHIFT_MASK) & ~Gdk.ModifierType.CONTROL_MASK) != 0);
            bool only_control_pressed = control_pressed && !other_mod_pressed; /* Shift can be pressed */
            bool only_shift_pressed = shift_pressed && !control_pressed && !other_mod_pressed;
            bool path_selected = (path != null ? path_is_selected (path) : false);
            bool on_blank = (click_zone == ClickZone.BLANK_NO_PATH || click_zone == ClickZone.BLANK_PATH);
            bool double_click_event = (n_press == 2);
            /* Block drag and drop to allow rubberbanding and prevent unwanted effects of
             * dragging on blank areas
             */
            block_drag_and_drop ();
            /* Handle un-modified clicks or control-clicks here else pass on. */
            if (!will_handle_button_press (no_mods, only_control_pressed, only_shift_pressed)) {
                return;
            }

            should_activate = false;
            should_deselect = false;
            should_select = false;

            /* Handle all selection and deselection explicitly in the following switch statement */
            switch (button) {
                case Gdk.BUTTON_PRIMARY: // button 1
                    switch (click_zone) {
                        case ClickZone.BLANK_NO_PATH:
                        case ClickZone.INVALID:
                            // Maintain existing selection by holding down modifier so we can multi-select
                            // separate groups with rubberbanding.
                            if (no_mods) {
                                unselect_all ();
                            }

                            break;

                        case ClickZone.BLANK_PATH:
                        case ClickZone.ICON:
                        case ClickZone.NAME:
                            /* Control-click on selected item should deselect it on key release (unless
                             * pointer moves) */
                            should_deselect = only_control_pressed && path_selected;

                            /* Determine whether should activate on key release (unless pointer moved)*/
                            /* Only activate single files with unmodified button when not on blank unless double-clicked */
                            if (no_mods && one_or_less) {
                                should_activate = (on_directory && !on_blank && !singleclick_select) || double_click_event;
                            }

                            /* We need to decide whether to rubberband or drag&drop.
                             * Rubberband if modifer pressed or if not on the icon and either
                             * the item is unselected. */
                            if (!no_mods || (on_blank && !path_selected)) {
                                if (only_shift_pressed && handle_multi_select (path)) {
                                    button_controller.set_state (CLAIMED);
                                }
                                // Have to select on button release because IconView, unlike TreeView,
                                // will not both select and rubberband
                                should_select = true;
                            } else {
                                if (no_mods && !path_selected) {
                                    unselect_all ();
                                }

                                select_path (path, true);

                                if (handle_primary_button_click (n_press, mods, path)) {
                                    button_controller.set_state (CLAIMED);
                                }

                                button_press_disabled = true;
                                unblock_drag_and_drop ();
                            }

                            update_selected_files_and_menu ();
                            break;

                        case ClickZone.HELPER:
                            if (only_control_pressed || only_shift_pressed) { /* Treat like modified click on icon */
                                if (only_shift_pressed && handle_multi_select (path)) {
                                    button_controller.set_state (CLAIMED);
                                }
                            } else {
                                if (path_selected) {
                                    /* Don't deselect yet, may drag */
                                    should_deselect = true;
                                } else {
                                    select_path (path, true); /* Cursor follow and selection preserved */
                                }

                                unblock_drag_and_drop ();
                                button_controller.set_state (CLAIMED); /* Prevent rubberbanding and deselection of other paths */
                            }
                            break;

                        case ClickZone.EXPANDER:
                            /* on expanders (if any) or xpad. Handle ourselves so that clicking
                             * on xpad also expands/collapses row (accessibility). */
                            expand_collapse (path);
                            button_controller.set_state (CLAIMED);
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
                    break;

                case Gdk.BUTTON_SECONDARY: // button 3
                    // No native behaviours on secondary click that we want
                    // ListView will cause unwanted deselections otherwise.
                    button_controller.set_state (CLAIMED);

                    switch (click_zone) {
                        case ClickZone.BLANK_NO_PATH:
                        case ClickZone.INVALID:
                            unselect_all ();
                            break;

                        case ClickZone.BLANK_PATH:
                            if (!path_selected && no_mods) {
                                unselect_all (); // Show the background menu on unselected blank areas
                            }

                            break;

                        case ClickZone.NAME:
                        case ClickZone.ICON:
                        case ClickZone.HELPER:
                            if (!path_selected && no_mods) {
                                unselect_all ();
                            }

                            select_path (path); /* Note: secondary click does not toggle selection */
                            break;

                        default:
                            break;
                    }

                    /* Ensure selected files list and menu actions are updated before context menu shown */
                    update_selected_files_and_menu ();
                    break;

                default:
                    if (handle_default_button_click ()) {
                        button_controller.set_state (CLAIMED);
                    }
                    break;
            }
        }

        protected virtual void on_view_button_release_event (int n_press, double x, double y) {
            unblock_drag_and_drop ();
            button_press_disabled = false;
            /* Ignore button release from click that started renaming.
             * View may lose focus during a drag if another tab is hovered, in which case
             * we do not want to refocus this view.
             * Under both these circumstances, 'should_activate' will be false */
            if (renaming || !view_has_focus ()) {
                return;
            }

            var button = button_controller.get_current_button ();
            slot.active (button == Gdk.BUTTON_SECONDARY);

            /* Only take action if pointer has not moved */
            if (!Gtk.drag_check_threshold (get_child (), (int)drag_x, (int)drag_y, (int)x, (int)y)) {
                if (should_activate) {
                    /* Need Idle else can crash with rapid clicking (avoid nested signals) */
                    Idle.add (() => {
                        var flag = button == Gdk.BUTTON_MIDDLE ? Files.OpenFlag.NEW_TAB : Files.OpenFlag.DEFAULT;
                        activate_selected_items (flag);
                        return GLib.Source.REMOVE;
                    });
                } else if (should_deselect && click_path != null) {
                    unselect_path (click_path);
                } else if (should_select && click_path != null) {
                    select_path (click_path);
                } else if (button == Gdk.BUTTON_SECONDARY) {
                    on_popup_menu ();
                }
            }

            // Selection may have been changed *but not signalled* by rubberbanding
            // in Gtk.TreeView (IconView does signal during rubberbanding)
            Idle.add (() => {
                update_selected_files_and_menu ();
                return GLib.Source.REMOVE;
            });

            should_activate = false;
            should_deselect = false;
            should_select = false;
            click_path = null;
            return;
        }

        public virtual void change_zoom_level () {
            icon_renderer.zoom_level = zoom_level;
            name_renderer.zoom_level = zoom_level;
            view.style_updated ();
        }

        private void start_renaming_file (Files.File file) {
            if (is_frozen) {
                warning ("Trying to rename when frozen");
                return;
            }

            var path = model.get_path_for_first_file (file);
            if (path == null) {
                critical ("Failed to find rename file in model");
                return;
            }
            /* Freeze updates to the view to prevent losing rename focus when the tree view updates */
            /* The order of the next three lines must not be changed */
            renaming = true;
            update_menu_actions ();
            is_frozen = true;
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
             * the directory file metadata incorrectly (bug 1511307). Also ignore when the model may temporarily
             * become unsorted.
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
            return true;
        }

        protected virtual bool handle_default_button_click () {
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
            cancel_timeout (ref drag_scroll_timer_id);
            cancel_timeout (ref add_remove_file_timeout_id);
            cancel_timeout (ref set_cursor_timeout_id);
            cancel_timeout (ref draw_timeout_id);
            /* List View will take care of unloading subdirectories */
        }

        private void cancel_hover () {
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

        protected uint get_selected_files_from_model (out GLib.List<Files.File> selected_files) {
            List<Files.File> list = null;
            uint count = 0;
            var selected_paths = get_selected_paths ();
            foreach (var path in selected_paths) {
                var file = model.file_for_path (path);
                if (file != null) {
                    list.prepend ((owned)file);
                    count++;
                } else {
                    critical ("Null file in model");
                }
            }
            selected_files = (owned)list;
            return count;
        }

        public virtual void highlight_path (Gtk.TreePath? path) {}
        protected virtual Gtk.TreePath up (Gtk.TreePath path) {path.up (); return path;}
        protected virtual Gtk.TreePath down (Gtk.TreePath path) {path.down (); return path;}
        protected virtual Settings? get_view_settings () { return null; }
        protected virtual void set_up_zoom_level () {
            var view_settings = get_view_settings ();
            if (view_settings == null) {
                minimum_zoom = ZoomLevel.SMALLEST;
                maximum_zoom = ZoomLevel.LARGEST;
                zoom_level = ZoomLevel.NORMAL;
            } else {
                minimum_zoom = (ZoomLevel)view_settings.get_enum ("minimum-zoom-level");
                maximum_zoom = (ZoomLevel)view_settings.get_enum ("maximum-zoom-level");
                zoom_level = (ZoomLevel)view_settings.get_enum ("zoom-level");

                view_settings.bind (
                    "zoom-level",
                    this, "zoom-level",
                    GLib.SettingsBindFlags.SET
                );
            }
        }

        protected virtual bool view_has_focus () {
            return view.has_focus;
        }

        protected virtual void scroll_to_cell (Gtk.TreePath? path, bool scroll_to_top) {
            if (path == null || slot == null || slot.directory == null ||
                slot.directory.permission_denied || slot.directory.is_empty ()) {

                return;
            }

            scroll_to_path (path, scroll_to_top);
        }

    //TODO Needs complete rewrite for Gtk4 so leaving some direct access of event struct
    protected static uint map_key (uint original_keyval, uint keycode, out Gdk.ModifierType consumed_mods) {
        uint keyval = original_keyval;
        consumed_mods = 0;

        if (keyval > 127) {
            int eff_grp, level;
            var event = (Gdk.EventKey)(Gtk.get_current_event ());
            var display = Gtk.get_current_event_device ().get_display ();
            var keymap = Gdk.Keymap.get_for_display (display);
            if (!keymap.translate_keyboard_state (
                    event.hardware_keycode,
                    event.state, event.group,
                    out keyval, out eff_grp,
                    out level, out consumed_mods)) {

                warning ("translate keyboard state failed");
                keyval = original_keyval;
                consumed_mods = 0;
            } else {
                keyval = 0;
                for (uint key = 32; key < 128; key++) {
                    if (match_keycode (keymap, key, event.hardware_keycode, level)) {
                        keyval = key;
                        break;
                    }
                }

                if (keyval == 0) {
                    debug ("Could not match hardware code to ASCII hotkey");
                    keyval = original_keyval;
                    consumed_mods = 0;
                }
            }
        }

        return keyval;
    }

    /** Returns true if the code parameter matches the keycode of the keyval parameter for
      * any keyboard group or level (in order to allow for non-QWERTY keyboards) **/
    protected static bool match_keycode (Gdk.Keymap keymap, uint keyval, uint code, int level) {
        Gdk.KeymapKey [] keys;
        if (keymap.get_entries_for_keyval (keyval, out keys)) {
            foreach (var key in keys) {
                if (code == key.keycode && level == key.level) {
                    return true;
                }
            }
        }

        return false;
    }

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

        protected abstract uint get_event_position_info (double x, double y,
                                                         out Gtk.TreePath? path,
                                                         bool rubberband = false);

        protected abstract void scroll_to_path (Gtk.TreePath path, bool scroll_to_top);
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
