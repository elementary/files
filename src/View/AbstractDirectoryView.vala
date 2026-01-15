/*
* Copyright 2015-2026 elementary, Inc. (https://elementary.io)
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
    public abstract class AbstractDirectoryView : Files.BasicAbstractDirectoryView, DirectoryViewInterface {
    //TODO Reorder property declarations
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

        const Gdk.DragAction FILE_DRAG_ACTIONS = (COPY | MOVE | LINK);

        /* Menu Handling */
        // Actions not required in FileChooserWidget
        const GLib.ActionEntry [] ADDITIONAL_SELECTION_ENTRIES = {
            {"open", on_selection_action_open_executable},
            {"open-with-app", on_selection_action_open_with_app, "u"},
            {"open-with-default", on_selection_action_open_with_default},
            {"open-with-other-app", on_selection_action_open_with_other_app},
            {"view-in-location", on_selection_action_view_in_location},
            {"forget", on_selection_action_forget},
            {"cut", on_selection_action_cut},
            {"trash", on_selection_action_trash},
            {"delete", on_selection_action_delete},
            {"restore", on_selection_action_restore},
            {"invert-selection", invert_selection}
        };

        const GLib.ActionEntry [] ADDITIONAL_BACKGROUND_ENTRIES = {
        };

        const GLib.ActionEntry [] ADDITIONAL_COMMON_ENTRIES = {
            {"paste-into", on_common_action_paste_into}, // Paste into selected folder
            {"paste", on_common_action_paste}, // Paste into background folder
            {"open-in", on_common_action_open_in, "i"},
            {"properties", on_common_action_properties},
            {"copy-link", on_common_action_copy_link},
            {"select-all", toggle_select_all},
            {"set-wallpaper", action_set_wallpaper}
        };

        /* Drag and drop support */
        const Gtk.TargetEntry [] DRAG_TARGETS = {
            {"text/plain", Gtk.TargetFlags.SAME_APP, Files.TargetType.STRING},
            {"text/plain", Gtk.TargetFlags.OTHER_APP, Files.TargetType.STRING},
            {"text/uri-list", Gtk.TargetFlags.SAME_APP, Files.TargetType.TEXT_URI_LIST},
            {"text/uri-list", Gtk.TargetFlags.OTHER_APP, Files.TargetType.TEXT_URI_LIST}
        };

        const Gtk.TargetEntry [] DROP_TARGETS = {
            {"text/uri-list", Gtk.TargetFlags.SAME_APP, Files.TargetType.TEXT_URI_LIST},
            {"text/uri-list", Gtk.TargetFlags.OTHER_APP, Files.TargetType.TEXT_URI_LIST},
            {"XdndDirectSave0", Gtk.TargetFlags.OTHER_APP, Files.TargetType.XDND_DIRECT_SAVE0},
            {"_NETSCAPE_URL", Gtk.TargetFlags.OTHER_APP, Files.TargetType.NETSCAPE_URL}
        };
        protected GLib.List<Files.File> source_drag_file_list = null;
        protected Gdk.Atom current_target_type = Gdk.Atom.NONE;

        /* Used only when acting as drag destination */
        uint drag_scroll_timer_id = 0;
        uint drag_enter_timer_id = 0;
        private bool destination_data_ready = false; /* whether the drop data was received already */
        private bool drop_occurred = false; /* whether the data was dropped */
        Files.File? drop_target_file = null;
        private GLib.List<GLib.File> destination_drop_file_list = null; /* the list of URIs that are contained in the drop data */
        Gdk.DragAction current_suggested_action = DEFAULT;
        Gdk.DragAction current_actions = DEFAULT;
        private DndHandler dnd_handler = new DndHandler ();

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
        private void* drag_data;

        /* Launching files in other apps */
        private GLib.List<GLib.AppInfo> open_with_apps;
        private GLib.AppInfo default_app;

        /* Prevent certain behaviours while something else is happening */
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

                    if (value) {
                        key_controller.propagation_phase = Gtk.PropagationPhase.NONE;
                    } else {
                        key_controller.propagation_phase = Gtk.PropagationPhase.BUBBLE;
                    }
                }
            }

            get {
                return _is_frozen;
            }
        }

        protected unowned Gtk.RecentManager recent;

        protected AbstractDirectoryView (View.Slot _slot) {
            base (_slot);
        }

        construct {
            set_up_additional_menu_actions ();
            var app = (Files.Application)(GLib.Application.get_default ());
            recent = app.get_recent_manager ();
            app.set_accels_for_action ("common.select-all", {"<Ctrl>A"});
            app.set_accels_for_action ("selection.invert-selection", {"<Shift><Ctrl>A"});

            connect_drag_drop_signals (view);
        }

        ~AbstractDirectoryView () {
            debug ("ADV destruct"); // Cannot reference slot here as it is already invalid
        }

        private void set_up_additional_menu_actions () {
            selection_actions.add_action_entries (ADDITIONAL_SELECTION_ENTRIES, this);
            background_actions.add_action_entries (ADDITIONAL_BACKGROUND_ENTRIES, this);
            common_actions.add_action_entries (ADDITIONAL_COMMON_ENTRIES, this);
        }

        public unowned GLib.List<GLib.AppInfo> get_open_with_apps () {
            return open_with_apps;
        }

        public GLib.AppInfo get_default_app () {
            return default_app;
        }

        public unowned GLib.List<Files.File> get_selected_files () {
            update_selected_files_and_menu ();
            return selected_files;
        }

/*** Protected Methods */
    /** Operations on selections */
        protected override void activate_selected_items (
            Files.OpenFlag flag = Files.OpenFlag.DEFAULT,
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

/*** Private methods */
    /** File operations */
        protected override void activate_file (
            Files.File _file,
            Gdk.Screen? screen,
            Files.OpenFlag flag,
            bool only_one_file
        ) {
            if (is_frozen) {
                return;
            }

            var file = _file;
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
                                PF.Dialogs.show_warning_dialog (
                                    _("Cannot execute this file"),
                                    e.message,
                                    slot.top_level
                                );
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
                    slot.top_level
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
                debug (
                    "Guessed content type to be %s from name - result_uncertain %s",
                    content_type,
                    result_uncertain.to_string ()
                );
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
                PF.Dialogs.show_warning_dialog (err_msg1, err_msg2, slot.top_level);
            }

            return success;
        }

        protected override void trash_or_delete_files (
            GLib.List<Files.File> file_list,
            bool delete_if_already_in_trash,
            bool delete_immediately
        ) {
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
                    slot.top_level,
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

        protected override void rename_selection () {
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

        private void on_selection_action_trash (GLib.SimpleAction action, GLib.Variant? param) {
            trash_or_delete_selected_files (Files.is_admin ());
        }

        private void on_selection_action_delete (GLib.SimpleAction action, GLib.Variant? param) {
            trash_or_delete_selected_files (true);
        }

        private void on_selection_action_restore (GLib.SimpleAction action, GLib.Variant? param) {
            GLib.List<Files.File> selection = get_selected_files_for_transfer ();
            FileUtils.restore_files_from_trash.begin (selection, slot.top_level);
        }

        private void on_selection_action_open_executable (GLib.SimpleAction action, GLib.Variant? param) {
            GLib.List<Files.File> selection = get_files_for_action ();
            Files.File file = selection.data as Files.File;
            try {
                file.execute (null);
            } catch (Error e) {
                PF.Dialogs.show_warning_dialog (
                    _("Cannot execute this file"),
                    e.message,
                    slot.top_level
                );
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
            activate_selected_items ((Files.OpenFlag) param, get_files_for_action ());
        }

        private void on_common_action_properties (GLib.SimpleAction action, GLib.Variant? param) {
            new View.PropertiesWindow (get_files_for_action (), this, slot.top_level);
        }

        private void on_common_action_copy_link (GLib.SimpleAction action, GLib.Variant? param) {
            clipboard.copy_link_files (get_selected_files_for_transfer (get_files_for_action ()));
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

/** DRAG AND DROP SOURCE */
        /* Signal emitted on source when drag begins */
        private void on_drag_begin () {
            should_activate = false;
        }

        /* Signal emitted on source when destination requests data, either to inspect
         * during motion or to process on dropping by calling Gdk.drag_data_get () */
        private void on_drag_data_get (
            Gdk.DragContext context,
            Gtk.SelectionData selection_data,
            uint info,
            uint timestamp
        ) {
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

            switch (info) {
                case TargetType.STRING:
                    DndHandler.set_selection_data_as_text (selection_data, source_drag_file_list);
                    break;
                case TargetType.TEXT_URI_LIST:
                    DndHandler.set_selection_data_as_file_list (selection_data, source_drag_file_list);
                    break;
                default:
                    warning ("ignored info %u", info);
                    break;
            }

        }

        /* Signal emitted on source after a DND move operation */
        private void on_drag_data_delete () {
            /* block real_view default handler because handled in on_drag_end */
            GLib.Signal.stop_emission_by_name (scrolled_window.get_child (), "drag-data-delete");
        }

        /* Signal emitted on source after completion of DnD. */
        private void on_drag_end () {
            source_drag_file_list = null;
        }

/** DRAG AND DROP DESTINATION */
        /* Signal emitted on destination while drag moving over it */
        private bool on_drag_motion (
            Gdk.DragContext context,
            int x,
            int y,
            uint timestamp
        ) {
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
        private bool on_drag_drop (
            Gdk.DragContext context,
            int x,
            int y,
            uint timestamp
        ) {
            Gtk.TargetList list = null;
            string? uri = null;
            drop_occurred = true;
            Gdk.Atom target = Gtk.drag_dest_find_target (scrolled_window.get_child (), context, list);

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
                    PF.Dialogs.show_error_dialog (
                        _("Cannot drop this file"),
                        _("Invalid file name provided"),
                        slot.top_level
                    );

                    return false;
                }
            }

            /* request the drag data from the source (initiates
             * saving in case of XdndDirectSave).*/
            Gtk.drag_get_data (scrolled_window.get_child (), context, target, timestamp);

            return true;
        }

        /* Signal emitted on destination when selection data received from source
         * either during drag motion or on dropping */
        private void on_drag_data_received (
            Gdk.DragContext context,
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
                    // We require that dropped uri lists have been escaped
                    destination_drop_file_list = FileUtils.files_from_escaped_uris (text);
                    destination_data_ready = true;
                }
            }

            if (drop_occurred) {
                bool success = false;
                drop_occurred = false;

                switch (info) {
                    case Files.TargetType.XDND_DIRECT_SAVE0:
                        success = dnd_handler.handle_xdnddirectsave (
                            context.get_source_window (),
                            drop_target_file,
                            selection_data
                        );
                        break;

                    case Files.TargetType.NETSCAPE_URL:
                        success = dnd_handler.handle_netscape_url (
                            context.get_source_window (),
                            drop_target_file,
                            selection_data
                        );
                        break;

                    case Files.TargetType.TEXT_URI_LIST:
                        if ((current_actions & FILE_DRAG_ACTIONS) == 0) {
                            break;
                        }

                        if (selected_files != null) {
                            unselect_all ();
                        }

                        success = dnd_handler.handle_file_drag_actions (
                            scrolled_window.get_child (),
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
            Gdk.Atom target = Gtk.drag_dest_find_target (scrolled_window.get_child (), context, list);
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
                Gtk.drag_get_data (scrolled_window.get_child (), context, target, timestamp);
            }
        }

        /* Called by DnD destination during drag_motion */
        private void check_destination_actions_and_target_file (
            Gdk.DragContext context,
            int x,
            int y,
            uint timestamp
        ) {
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
                        drag_enter_timer_id = GLib.Timeout.add_full (
                            GLib.Priority.LOW,
                            1000,
                            () => {
                                load_location (drop_target_file.get_target_location ());
                                drag_enter_timer_id = 0;
                                return GLib.Source.REMOVE;
                            }
                        );
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

        private void highlight_drop_file (
            Files.File drop_file,
            Gdk.DragAction action,
            Gtk.TreePath? path
        ) {
            bool can_drop = (action > Gdk.DragAction.DEFAULT);

            if (drop_highlight != can_drop) {
                drop_highlight = can_drop;
                queue_draw ();
            }

            /* Set the icon_renderer drop-file if there is an action */
            icon_renderer.drop_file = can_drop ? drop_file : null;

            highlight_path (can_drop ? path : null);
        }

        /* Drag Scroll related functions */
        private void start_drag_scroll_timer (Gdk.Device pointer) requires (slot.top_level != null) {
            drag_scroll_timer_id = GLib.Timeout.add_full (
                GLib.Priority.LOW,
                50,
                () => {
                    Gtk.Widget? widget = scrolled_window.get_child ();
                    if (widget != null) {
                        Gdk.Window window = widget.get_window ();
                        int x, y, w, h;

                        window.get_device_position (pointer, out x, out y, null);
                        window.get_geometry (null, null, out w, out h);

                        scroll_if_near_edge (y, h, 20, scrolled_window.get_vadjustment ());
                        scroll_if_near_edge (x, w, 20, scrolled_window.get_hadjustment ());
                        return GLib.Source.CONTINUE;
                    } else {
                        return GLib.Source.REMOVE;
                    }
                }
            );
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

/** Other DnD related code **/
        private void connect_drag_drop_signals (Gtk.Widget widget) {
            /* Set up as drop site */
            Gtk.drag_dest_set (
                widget,
                Gtk.DestDefaults.MOTION,
                DROP_TARGETS,
                Gdk.DragAction.ASK | FILE_DRAG_ACTIONS
            );
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

        protected override bool handle_primary_button_click (
            uint n_press,
            Gdk.ModifierType mods,
            Gtk.TreePath? path
        ) {
            return false; // Allow drag'n'drop
        }

        protected override void block_drag_and_drop () {
            if (!dnd_disabled) {
                drag_data = view.get_data ("gtk-site-data");
                GLib.SignalHandler.block_matched (
                    view,
                    GLib.SignalMatchType.DATA,
                    0, 0, null, null,
                    drag_data
                );
                dnd_disabled = true;
            }
        }

        protected override void unblock_drag_and_drop () {
            if (dnd_disabled) {
                GLib.SignalHandler.unblock_matched (
                    view,
                    GLib.SignalMatchType.DATA,
                    0, 0, null, null,
                    drag_data
                );
                dnd_disabled = false;
            }
        }

/** MENU FUNCTIONS */
        //TODO DRY
        protected override void show_context_menu (Gdk.Event event) requires (slot.top_level != null) {
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
                    new_tab_menuitem.action_target = Files.OpenFlag.NEW_TAB;
                } else {
                    new_tab_menuitem.add (new Granite.AccelLabel.from_action_name (
                        _("New Tab"),
                        "win.tab::TAB"
                    ));
                    new_tab_menuitem.action_name = "win.tab";
                    new_tab_menuitem.action_target = "TAB";
                }

                var new_window_menuitem = new Gtk.MenuItem ();
                if (selected_files != null) {
                    new_window_menuitem.add (new Granite.AccelLabel (
                        _("New Window"),
                        "<Shift><Ctrl>Return"
                    ));
                    new_window_menuitem.action_name = "common.open-in";
                    new_window_menuitem.action_target = Files.OpenFlag.NEW_WINDOW;
                } else {
                    new_window_menuitem.add (new Granite.AccelLabel.from_action_name (
                        _("New Window"),
                        "win.tab::WINDOW"
                    ));
                    new_window_menuitem.action_name = "win.tab";
                    new_window_menuitem.action_target = "WINDOW";
                }

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
                        slot.top_level.can_bookmark_uri (selected_files.data.uri)) {

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
                        slot.top_level.can_bookmark_uri (slot.directory.file.uri)) {

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

        private bool valid_selection_for_restore () {
            foreach (unowned Files.File file in get_selected_files ()) {
                if (!(file.directory.get_basename () == "/")) {
                    return false;
                }
            }

            return true;
        }

        protected override void update_menu_actions () {
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
            // bool can_show_properties = false;
            // bool can_copy = false;
            // bool can_open = false;
            bool can_paste_into = false;

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
            bool can_bookmark = (!more_than_one_selected || single_folder) &&
                                (slot.directory.is_local ||
                                (file.get_ftype () != null && file.get_ftype () == "inode/directory") ||
                                file.is_smb_server ());

            bool can_copy = file.is_readable ();
            bool can_open = !renaming && is_selected && !more_than_one_selected && can_open_file (file);
            bool can_show_properties = !(in_recent && more_than_one_selected);
            bool can_trash = !renaming && is_writable && slot.directory.has_trash_dirs;
            bool can_copy_link = !renaming && !in_trash && !in_recent && can_copy;

            action_set_enabled (common_actions, "paste", !in_recent && is_writable);
            action_set_enabled (common_actions, "paste-into", !renaming & can_paste_into);
            action_set_enabled (common_actions, "open-in", !renaming & only_folders);
            action_set_enabled (selection_actions, "rename", !renaming & is_selected && can_rename);
            action_set_enabled (selection_actions, "view-in-location", !renaming & is_selected);
            action_set_enabled (selection_actions, "open", can_open);
            action_set_enabled (selection_actions, "open-with-app", !renaming && can_open);
            action_set_enabled (selection_actions, "open-with-default", !renaming && can_open);
            action_set_enabled (selection_actions, "open-with-other-app", !renaming && can_open);
            action_set_enabled (selection_actions, "cut", !renaming && is_writable && is_selected);
            action_set_enabled (selection_actions, "trash", can_trash);
            action_set_enabled (selection_actions, "delete", !renaming && is_writable);
            action_set_enabled (selection_actions, "invert-selection", !renaming && is_selected);
            action_set_enabled (common_actions, "select-all", !renaming && is_selected);
            action_set_enabled (common_actions, "properties", !renaming && can_show_properties);
            action_set_enabled (common_actions, "bookmark", !renaming && can_bookmark);
            action_set_enabled (common_actions, "copy", !renaming && !in_trash && can_copy);
            action_set_enabled (common_actions, "copy-link", can_copy_link);
            action_set_enabled (common_actions, "bookmark", !renaming && !more_than_one_selected);
            action_set_enabled (common_actions, "set-wallpaper", !renaming && !more_than_one_selected);

            update_default_app (selection);
            update_menu_actions_sort ();
        }

        private void update_default_app (GLib.List<Files.File> selection) {
            default_app = MimeActions.get_default_application_for_files (selection);
            return;
        }

    /** Menu helpers */
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

/** Menu action functions **/
        private void open_files_with (GLib.AppInfo app, GLib.List<Files.File> files) {
            MimeActions.open_multiple_gof_files_request (files, this, app);
        }

/** Keyboard event handling **/
        protected override bool on_view_key_press_event (
            uint original_keyval,
            uint keycode,
            Gdk.ModifierType state
        ) {
            if (is_frozen) {
                return true;
            }

            if (base.on_view_key_press_event (original_keyval, keycode, state)) {
                return true;
            }

            cancel_hover ();
            bool res = false;

            switch (ki.keyval) {
                case Gdk.Key.Delete:
                case Gdk.Key.KP_Delete:
                    if (!is_writable) {
                        PF.Dialogs.show_warning_dialog (
                            _("Cannot remove files from here"),
                            _("You do not have permission to change this location"),
                            slot.top_level
                        );
                    } else if (!renaming) {
                        trash_or_delete_selected_files (in_trash || Files.is_admin () || ki.only_shift_pressed);
                        res = true;
                    }

                    break;

                case Gdk.Key.Left:
                case Gdk.Key.Right:
                case Gdk.Key.BackSpace:
                    // Should only come here if ColumnView but check anyway
                    if ((this is ColumnView) && ki.no_mods) {
                        ((Files.View.Miller)(slot.top_level.get_view ())).on_miller_key_pressed (original_keyval, keycode, state);
                        res = true;
                        break;
                    }

                    break;

                case Gdk.Key.c:
                case Gdk.Key.C:
                    if (ki.only_control_pressed) {
                        /* Caps Lock interferes with `shift_pressed` boolean so use another way */
                        var caps_on = Gdk.Keymap.get_for_display (get_display ()).get_caps_lock_state ();
                        var cap_c = ki.keyval == Gdk.Key.C;

                        if (caps_on != cap_c) { /* Shift key pressed */
                            common_actions.activate_action ("copy-link", null);
                        } else {
                        /* Should not copy files in the trash - cut instead */
                            if (in_trash) {
                                PF.Dialogs.show_warning_dialog (
                                    _("Cannot copy files that are in the trash"),
                                    _("Cutting the selection instead"),
                                    slot.top_level
                                );

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
                    if (ki.only_control_pressed) {
                        if (ki.shift_pressed) {  // Paste into selected folder if there is one
                            update_selected_files_and_menu ();
                            if (!in_recent && is_writable) {
                                if (selected_files.first () != null &&
                                    selected_files.first ().next != null) {
                                    //Ignore if multiple files selected
                                    Gdk.beep ();
                                    warning ("Cannot paste into a multiple selection");
                                } else {
                                    //None or one file selected. Paste into selected file else base directory
                                    action_set_enabled (common_actions, "paste-into", true);
                                    common_actions.activate_action ("paste-into", null);
                                }
                            } else {
                                PF.Dialogs.show_warning_dialog
                                    (_("Cannot paste files here"),
                                    _("You do not have permission to change this location"),
                                    slot.top_level);
                            }

                            res = true;
                        } else { // Paste into background folder
                            if (!in_recent && is_writable) {
                                action_set_enabled (common_actions, "paste", true);
                                common_actions.activate_action ("paste", null);
                            } else {
                                PF.Dialogs.show_warning_dialog (
                                    _("Cannot paste files here"),
                                    _("You do not have permission to change this location"),
                                    slot.top_level
                                );
                            }

                            res = true;
                        }
                    }

                    break;

                case Gdk.Key.x:
                case Gdk.Key.X:
                    if (ki.only_control_pressed) {
                        if (is_writable) {
                            selection_actions.activate_action ("cut", null);
                        } else {
                            PF.Dialogs.show_warning_dialog (
                                _("Cannot remove files from here"),
                                _("You do not have permission to change this location"),
                                slot.top_level
                            );
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

        protected override void on_sort_column_changed () {
            /* Setting file attributes fails when root */
            if (Files.is_admin ()) {
                return;
            }

            base.on_sort_column_changed ();
        }

        protected override void cancel () {
            base.cancel ();
            cancel_timeout (ref drag_scroll_timer_id);
        }
    }
}
