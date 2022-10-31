/*
* Copyright 2022 elementary, Inc. (https://elementary.io)
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

namespace Files {
    public class DirectoryView : Gtk.Widget {
        static construct {
            set_layout_manager_type (typeof (Gtk.BinLayout));
        }

        public Files.ViewInterface view_widget { get; construct; }
        public Gtk.Stack stack { get; construct; }

        private enum ClickZone {
            EXPANDER,
            HELPER,
            ICON,
            NAME,
            BLANK_PATH,
            BLANK_NO_PATH,
            INVALID
        }

        private const int MAX_TEMPLATES = 32;
        private static GLib.List<GLib.File> templates = null;

        /* Menu Handling */
        const GLib.ActionEntry [] SELECTION_ENTRIES = {
            {"open", on_selection_action_open_executable},
            {"open-with-app", on_selection_action_open_with_app, "u"},
            {"open-with-default", on_selection_action_open_with_default},
            {"open-with-other-app", on_selection_action_open_with_other_app},
            {"view-in-location", on_selection_action_view_in_location},
            {"forget", on_selection_action_forget},
            {"cut", on_selection_action_cut},
            {"trash", on_selection_action_trash},
            {"delete", on_selection_action_delete},
            {"restore", on_selection_action_restore}
            // {"invert-selection", invert_selection}
        };

        const GLib.ActionEntry [] BACKGROUND_ENTRIES = {
            {"create-from", on_background_action_create_from, "s"},
        };

        const GLib.ActionEntry [] COMMON_ENTRIES = {
            {"open-in", on_common_action_open_in, "s"},
            {"bookmark", on_common_action_bookmark},
            {"properties", on_common_action_properties},
            {"copy-link", on_common_action_copy_link},
        };

        GLib.SimpleActionGroup common_actions;
        GLib.SimpleActionGroup selection_actions;
        GLib.SimpleActionGroup background_actions;

        public ZoomLevel zoom_level {
            get {
                return view_widget.zoom_level;
            }

            set {
                view_widget.zoom_level = value;
            }
        }

        public int icon_size {
            get {
                return view_widget.zoom_level.to_icon_size ();
            }
        }

        private ClipboardManager clipboard;
        // private ZoomLevel view_widget.minimum_zoom = ZoomLevel.SMALLEST;
        // private ZoomLevel view_widget.maximum_zoom = ZoomLevel.LARGEST;
        private bool large_thumbnails = false;

        uint drag_scroll_timer_id = 0;

        /* support for generating thumbnails */
        uint freeze_source_id = 0;

        /* Free space signal support */
        uint add_remove_file_timeout_id = 0;
        bool signal_free_space_change = false;

        /* Rename support */
        // Needed for properties dialog
        public string original_name = "";
        public string proposed_name = "";
        public bool renaming {get; private set; default = false;}

        // /* Cursors for different areas */
        private Gdk.Cursor editable_cursor;
        private Gdk.Cursor activatable_cursor;
        private Gdk.Cursor selectable_cursor;

        private GLib.List<GLib.AppInfo> open_with_apps;
        private GLib.AppInfo default_app;

        private GLib.List<Files.File> selected_files = null;
        private bool selected_files_invalid = true;

        /* Support for keeping cursor position after delete */
        private Gtk.TreePath deleted_path;

        private bool tree_frozen { get; set; default = false; }
        private bool _is_frozen = false;
        public bool is_frozen {
            set {
                if (is_frozen != value) {
                    _is_frozen = value;
                    if (value) {
                        action_set_enabled ("selection.cut", false);
                        action_set_enabled ("common.copy", false);
                        action_set_enabled ("common.paste-into", false);
                        action_set_enabled ("common.paste", false);

                        /* Fix problems when navigating away from directory with large number
                         * of selected files (e.g. OverlayBar critical errors)
                         */
                        clipboard.changed.disconnect (on_clipboard_changed);
                    } else {
                        clipboard.changed.connect (on_clipboard_changed);
                        update_menu_actions ();

                    }
                }
            }

            get {
                return _is_frozen;
            }
        }

        public bool in_recent { get; private set; default = false; }
        public bool show_remote_thumbnails {get; set; default = true;}
        public bool hide_local_thumbnails {get; set; default = false;}

        private bool in_trash = false;
        private bool in_network_root = false;
        private bool is_writable = false;
        private bool is_loading;
        private bool helpers_shown;
        private bool all_selected = false;
        private bool one_or_less = false;

        public Files.Slot slot { get; construct; }
        public ViewMode mode { get; construct; }
        public Files.Window window {
            get {
                return slot.window;
            }
        }

        private Gtk.RecentManager recent;

        public signal void path_change_request (GLib.File location, Files.OpenFlag flag, bool new_root);
        public signal void selection_changed (GLib.List<Files.File> gof_file);

        public DirectoryView (ViewMode mode, Slot slot) {
            Object (
                slot: slot,
                mode: mode
            );
        }

        construct {
            set_layout_manager (new Gtk.BinLayout ());
            vexpand = true;

            switch (mode) {
                case ViewMode.ICON:
                case ViewMode.LIST:
                case ViewMode.MILLER_COLUMNS:
                    view_widget = new Files.GridView ();
                    break;
                default:
                    view_widget = new Files.GridView ();
                    warning ("Unexpected mode %s", mode.to_string ());
                    break;
            }

            view_widget.set_up_zoom_level ();
            view_widget.path_change_request.connect ((uri) => {
                path_change_request (uri, Files.OpenFlag.DEFAULT, false);
            });

            stack = new Gtk.Stack ();
            stack.add_named (new Gtk.Label ("EMPTY"), "empty-label");
            stack.add_named (view_widget, "view-widget");
            stack.visible_child_name = "empty-label";
            stack.set_parent (this);

            editable_cursor = new Gdk.Cursor.from_name ("text", null);
            activatable_cursor = new Gdk.Cursor.from_name ("pointer", null);
            selectable_cursor = new Gdk.Cursor.from_name ("default", null);

            var app = (Files.Application)(GLib.Application.get_default ());
            recent = app.get_recent_manager ();
            clipboard = ClipboardManager.get_instance ();

            Files.app_settings.bind (
                "show-remote-thumbnails",
                this,
                "show_remote_thumbnails",
                SettingsBindFlags.GET
            );
            Files.app_settings.bind (
                "hide-local-thumbnails",
                this,
                "hide_local_thumbnails",
                SettingsBindFlags.GET
            );

            unrealize.connect (() => {
                clipboard.changed.disconnect (on_clipboard_changed);
            });

            realize.connect (() => {
                clipboard.changed.connect (on_clipboard_changed);
                on_clipboard_changed ();
            });

            // notify["renaming"].connect (() => {
            //     view_widget.set_renaming (renaming);
            // });

            connect_directory_handlers (slot.directory);
        }

        ~DirectoryView () {
            while (this.get_last_child () != null) {
                this.get_last_child ().unparent ();
            }
        }
// }}

//        private void setup_menu_actions () {
//             selection_actions = new GLib.SimpleActionGroup ();
//             selection_actions.add_action_entries (SELECTION_ENTRIES, this);
//             insert_action_group ("selection", selection_actions);

//             background_actions = new GLib.SimpleActionGroup ();
//             background_actions.add_action_entries (BACKGROUND_ENTRIES, this);
//             insert_action_group ("background", background_actions);

//             common_actions = new GLib.SimpleActionGroup ();
//             common_actions.add_action_entries (COMMON_ENTRIES, this);
//             insert_action_group ("common", common_actions);

//             action_set_state (background_actions, "show-hidden",
//                               Files.app_settings.get_boolean ("show-hiddenfiles"));

//             action_set_state (background_actions, "show-remote-thumbnails",
//                               Files.app_settings.get_boolean ("show-remote-thumbnails"));

//             action_set_state (background_actions, "hide-local-thumbnails",
//                               Files.app_settings.get_boolean ("hide-local-thumbnails"));
//      }

        public void zoom_in () {
            view_widget.zoom_in ();
            on_zoom_level_changed (view_widget.zoom_level);
        }

        public void zoom_out () {
            view_widget.zoom_out ();
            on_zoom_level_changed (view_widget.zoom_level);
        }

        public void zoom_normal () {
            view_widget.zoom_normal ();
            on_zoom_level_changed (view_widget.zoom_level);
        }

        public void focus_first_for_empty_selection (bool select) {
            view_widget.show_and_select_file (null, false, false);
        }

//         /* This function is only called by Slot in order to select a file item after loading has completed.
//          * If called before initial loading is complete then tree_frozen is true.  Otherwise, e.g. when selecting search items
//          * tree_frozen is false.
//          */
//         private ulong select_source_handler = 0;
        public void select_glib_files_when_thawed (
            GLib.List<GLib.File> location_list,
            GLib.File? focus_location
        ) {
//             var files_to_select_list = new Gee.LinkedList<Files.File> ();
//             location_list.@foreach ((loc) => {
//                 files_to_select_list.add (Files.File.@get (loc));
//             });

//             GLib.File? focus_after_select = focus_location != null ? focus_location.dup () : null;

//             /* Because the Icon View disconnects the model while loading, we need to wait until
//              * the tree is thawed and the model reconnected before selecting the files.
//              * Using a timeout helps ensure that the files appear in the model before selecting. Using an Idle
//              * sometimes results in the pasted file not being selected because it is not found yet in the model. */
//             if (tree_frozen) {
//                 select_source_handler = notify["tree-frozen"].connect (() => {
//                     select_files_and_update_if_thawed (files_to_select_list, focus_after_select);
//                 });
//             } else {
//                 select_files_and_update_if_thawed (files_to_select_list, focus_after_select);
//             }
        }

//         private void select_files_and_update_if_thawed (
//             Gee.LinkedList<Files.File> files_to_select,
//             GLib.File? focus_file
//         ) {
//             if (tree_frozen) {
//                 return;
//             }

//             if (select_source_handler > 0) {
//                 disconnect (select_source_handler);
//                 select_source_handler = 0;
//             }

//             // disconnect_tree_signals (); /* Avoid unnecessary signal processing */
//             view_widget.unselect_all ();

//             uint count = 0;
//             foreach (Files.File file in files_to_select) {
//                 bool show = focus_file != null && focus_file.equal (f.location);
//                 view_widget.show_and_select_file (file, show, true);
//                 count++;
//             }

//             if (count == 0) {
//                 focus_first_for_empty_selection (false);
//             }

//             on_view_selection_changed (); /* Mark selected_file list as invalid */
//             /* Update menu and selected file list now in case autoselected */
//             update_selected_files_and_menu ();
//         }

        public unowned GLib.List<GLib.AppInfo>? get_open_with_apps () {
//             return open_with_apps;
return null;
        }

        public GLib.AppInfo get_default_app () {
            return default_app;
        }

        public new void grab_focus () {
//             if (view_widget.get_realized ()) {
//                 /* In Column View, maybe clicked on an inactive column */
//                 if (!slot.is_active) {
//                     set_active_slot ();
//                 }

//                 view_widget.grab_focus ();
//             }
        }

        public unowned GLib.List<Files.File>? get_selected_files () {
//             update_selected_files_and_menu ();
//             return selected_files;
return null;
        }

// /*** Protected Methods */
//         private void set_active_slot (bool scroll = true) {
//             slot.active (scroll);
//         }

//         private void load_location (GLib.File location) {
//             path_change_request (location, Files.OpenFlag.DEFAULT, false);
//         }

//         private void load_root_location (GLib.File location) {
//             path_change_request (location, Files.OpenFlag.DEFAULT, true);
//         }

//     /** Operations on selections */
//         private void activate_selected_items (Files.OpenFlag flag = Files.OpenFlag.DEFAULT,
//                                                 GLib.List<Files.File> selection = get_selected_files ()) {

//             if (is_frozen || selection == null) {
//                 return;
//             }

//             if (selection.first ().next == null) { // Only one selected
//                 activate_file (selection.data, flag, true);
//                 return;
//             }

//             if (!in_trash) {
//                 /* launch each selected file individually ignoring selections greater than 10
//                  * Do not launch with new instances of this app - open according to flag instead
//                  */
//                 if (selection.nth_data (11) == null && // Less than 10 items
//                    (default_app == null || app_is_this_app (default_app))) {

//                     foreach (Files.File file in selection) {
//                         /* Prevent too rapid activation of files - causes New Tab to crash for example */
//                         if (file.is_folder ()) {
//                             /* By default, multiple folders open in new tabs */
//                             if (flag == Files.OpenFlag.DEFAULT) {
//                                 flag = Files.OpenFlag.NEW_TAB;
//                             }

//                             GLib.Idle.add (() => {
//                                 activate_file (file, flag, false);
//                                 return GLib.Source.REMOVE;
//                             });
//                         } else {
//                             GLib.Idle.add (() => {
//                                 open_file (file, null);
//                                 return GLib.Source.REMOVE;
//                             });
//                         }
//                     }
//                 } else if (default_app != null) {
//                     /* Because this is in another thread we need to copy the selection to ensure it remains valid */
//                     var files_to_open = selection.copy_deep ((GLib.CopyFunc)(GLib.Object.ref));
//                     GLib.Idle.add (() => {
//                         open_files_with (default_app, files_to_open);
//                         return GLib.Source.REMOVE;
//                     });
//                 }
//             } else {
//                 warning ("Cannot open files in trash");
//             }
//         }

        public void select_gof_file (Files.File file) {
//             view_widget.show_and_select_file (file, false, true);
        }

        private void select_and_scroll_to_gof_file (Files.File file, bool unselect_others) {
            view_widget.show_and_select_file (file, true, unselect_others);
        }

//     /** Directory signal handlers. */
//         /* Signal could be from subdirectory as well as slot directory */
        private void connect_directory_handlers (Directory dir) {
            dir.file_added.connect (on_directory_file_added);
//             dir.file_changed.connect (on_directory_file_changed);
            dir.file_deleted.connect (on_directory_file_deleted);
//             dir.icon_changed.connect (on_directory_file_icon_changed);
            connect_directory_loading_handlers (dir);
        }

        private void connect_directory_loading_handlers (Directory dir) {
            dir.file_loaded.connect (on_directory_file_loaded);
            dir.done_loading.connect (on_directory_done_loading);
        }

        private void disconnect_directory_loading_handlers (Directory dir) {
            dir.file_loaded.disconnect (on_directory_file_loaded);
            dir.done_loading.disconnect (on_directory_done_loading);
        }

        private void disconnect_directory_handlers (Directory dir) {
//             /* If the directory is still loading the file_loaded signal handler
//             /* will not have been disconnected */
            if (dir.is_loading ()) {
                disconnect_directory_loading_handlers (dir);
            }
            dir.file_added.disconnect (on_directory_file_added);
//             dir.file_changed.disconnect (on_directory_file_changed);
            dir.file_deleted.disconnect (on_directory_file_deleted);
//             dir.icon_changed.disconnect (on_directory_file_icon_changed);
            dir.done_loading.disconnect (on_directory_done_loading);
        }

        public void change_directory (Directory old_dir, Directory new_dir) {
//             var style_context = get_style_context ();
//             if (style_context.has_class (Granite.STYLE_CLASS_H2_LABEL)) {
//                 style_context.remove_class (Granite.STYLE_CLASS_H2_LABEL);
//                 style_context.remove_class ("view");
//             }

            cancel ();
            clear ();
            disconnect_directory_handlers (old_dir);
            connect_directory_handlers (new_dir);
        }

        public void prepare_reload (Files.Directory dir) {
            cancel ();
            clear ();
            connect_directory_loading_handlers (dir);
        }

        private void clear () {
            view_widget.clear ();
            stack.visible_child_name = "empty-label";
            all_selected = false;
        }

//         //TODO Reimplement DnD for Gtk4

//         private bool selection_only_contains_folders (GLib.List<Files.File> list) {
//             bool only_folders = true;

//             list.@foreach ((file) => {
//                 if (!(file.is_folder () || file.is_root_network_folder ())) {
//                     only_folders = false;
//                 }
//             });

//             return only_folders;
//         }

//     /** Handle scroll events */
//         //TODO Use EventControllers
//         private GLib.List<Files.File> get_selected_files_for_transfer (
//             GLib.List<Files.File> selection = get_selected_files ()
//         ) {
//             return selection.copy_deep ((GLib.CopyFunc) GLib.Object.ref);
//         }

// /*** Private methods */
//     /** File operations */
//         private void activate_file (Files.File _file, Files.OpenFlag flag, bool only_one_file) {
//             if (is_frozen) {
//                 return;
//             }

//             Files.File file = _file;
//             if (in_recent) {
//                 file = Files.File.get_by_uri (file.get_display_target_uri ());
//             }

//             default_app = MimeActions.get_default_application_for_file (file);
//             GLib.File location = file.get_target_location ();

//             if (flag != Files.OpenFlag.APP && (file.is_folder () ||
//                 file.get_ftype () == "inode/directory" ||
//                 file.is_root_network_folder ())) {

//                 switch (flag) {
//                     case Files.OpenFlag.NEW_TAB:
//                     case Files.OpenFlag.NEW_WINDOW:
//                         path_change_request (location, flag, true);
//                         break;

//                     default:
//                         if (only_one_file) {
//                             load_location (location);
//                         }

//                         break;
//                 }
//             } else if (!in_trash) {
//                 if (only_one_file) {
//                     if (file.is_executable ()) {
//                         var content_type = file.get_ftype ();

//                         if (GLib.ContentType.is_a (content_type, "text/plain")) {
//                             open_file (file, default_app);
//                         } else {
//                             try {
//                                 file.execute (null);
//                             } catch (Error e) {
//                                 PF.Dialogs.show_warning_dialog (_("Cannot execute this file"), e.message, window);
//                             }
//                         }
//                     } else {
//                         open_file (file, default_app);
//                     }
//                 }
//             } else {
//                 PF.Dialogs.show_error_dialog (
//                     ///TRANSLATORS: '%s' is a quoted placehorder for the name of a file. It can be moved but not omitted
//                     _("“%s” must be moved from Trash before opening").printf (file.basename),
//                     _("Files inside Trash cannot be opened. To open this file, it must be moved elsewhere."),
//                     window
//                 );
//             }
//         }

//         /* Open all files through this */
//         private void open_file (Files.File file, GLib.AppInfo? app_info) {
//             if (can_open_file (file, true)) {
//                 MimeActions.open_glib_file_request (file.location, this, app_info);
//             }
//         }

//         /* Also used by build open menu */
//         private bool can_open_file (Files.File file, bool show_error_dialog = false) {
//             string err_msg1 = _("Cannot open this file");
//             string err_msg2 = "";
//             var content_type = file.get_ftype ();

//             if (content_type == null) {
//                 bool result_uncertain = true;
//                 content_type = ContentType.guess (file.basename, null, out result_uncertain);
//                 debug ("Guessed content type to be %s from name - result_uncertain %s",
//                           content_type,
//                           result_uncertain.to_string ());
//             }

//             if (content_type == null) {
//                 err_msg2 = _("Cannot identify file type to open");
//             } else if (!slot.directory.can_open_files) {
//                 err_msg2 = "Cannot open files with this protocol (%s)".printf (slot.directory.scheme);
//             } else if (!slot.directory.can_stream_files &&
//                        (content_type.contains ("video") || content_type.contains ("audio"))) {

//                 err_msg2 = "Cannot stream from this protocol (%s)".printf (slot.directory.scheme);
//             }

//             bool success = err_msg2.length < 1;
//             if (!success && show_error_dialog) {
//                 PF.Dialogs.show_warning_dialog (err_msg1, err_msg2, window);
//             }

//             return success;
//         }

//         private void trash_or_delete_files (GLib.List<Files.File> file_list,
//                                             bool delete_if_already_in_trash,
//                                             bool delete_immediately) {

//             GLib.List<GLib.File> locations = null;
//             if (in_recent) {
//                 file_list.@foreach ((file) => {
//                     locations.prepend (GLib.File.new_for_uri (file.get_display_target_uri ()));
//                 });
//             } else {
//                 file_list.@foreach ((file) => {
//                     locations.prepend (file.location);
//                 });
//             }

//             /* If in recent "folder" we need to refresh the view. */
//             if (in_recent) {
//                 slot.reload ();
//             }
//         }

//         private void handle_free_space_change () {
//             /* Wait at least 250 mS after last space change before signalling to avoid unnecessary updates*/
//             if (add_remove_file_timeout_id == 0) {
//                 signal_free_space_change = false;
//                 add_remove_file_timeout_id = GLib.Timeout.add (250, () => {
//                     if (signal_free_space_change) {
//                         add_remove_file_timeout_id = 0;
//                         window.free_space_change ();
//                         return GLib.Source.REMOVE;
//                     } else {
//                         signal_free_space_change = true;
//                         return GLib.Source.CONTINUE;
//                     }
//                 });
//             } else {
//                 signal_free_space_change = false;
//             }
//         }

//         private void new_empty_file (string? parent_uri = null) {
//             if (parent_uri == null) {
//                 parent_uri = slot.directory.file.uri;
//             }

//             /* Block the async directory file monitor to avoid generating unwanted "add-file" events */
//             slot.directory.block_monitor ();
//             FileOperations.new_file.begin (
//                 this,
//                 parent_uri,
//                 null,
//                 null,
//                 0,
//                 null,
//                 (obj, res) => {
//                     try {
//                         var file = FileOperations.new_file.end (res);
//                         create_file_done (file);
//                     } catch (Error e) {
//                         critical (e.message);
//                     }
//                 }
//             );
//         }

// /** File operation callbacks */

        public void after_trash_or_delete () {
//             unblock_directory_monitor ();
        }

//         private void unblock_directory_monitor () {
//             /* Using an idle stops two file deleted/added signals being received (one via the file monitor
//              * and one via marlin-file-changes. */
//             GLib.Idle.add_full (GLib.Priority.LOW, () => {
//                 slot.directory.unblock_monitor ();
//                 return GLib.Source.REMOVE;
//             });
//         }

//         private void trash_or_delete_selected_files (bool delete_immediately = false) {
//         /* This might be rapidly called multiple times for the same selection
//          * when using keybindings. So we remember if the current selection
//          * was already removed (but the view doesn't know about it yet).
//          */
//             GLib.List<Files.File> selection = get_selected_files_for_transfer ();
//             if (selection != null) {
//                 trash_or_delete_files (selection, true, delete_immediately);
//             }
//         }

// /** Signal Handlers */
        private void on_selection_action_view_in_location (GLib.SimpleAction action, GLib.Variant? param) {
//             view_selected_file ();
        }

//         private void view_selected_file () {
//             if (selected_files == null) {
//                 return;
//             }

//             foreach (Files.File file in selected_files) {
//                 var loc = GLib.File.new_for_uri (file.get_display_target_uri ());
//                 path_change_request (loc, Files.OpenFlag.NEW_TAB, true);
//             }
//         }

        private void on_selection_action_forget (GLib.SimpleAction action, GLib.Variant? param) {
//             forget_selected_file ();
        }

//         private void forget_selected_file () {
//             if (selected_files == null) {
//                 return;
//             }

//             try {
//                 foreach (var file in selected_files) {
//                     recent.remove_item (file.get_display_target_uri ());
//                 }
//             } catch (Error err) {
//                 critical (err.message);
//             }
//         }


        private void on_selection_action_cut (GLib.SimpleAction action, GLib.Variant? param) {
//             GLib.List<Files.File> selection = get_selected_files_for_transfer ();
//             clipboard.cut_files (selection);
        }

        private void on_selection_action_trash (GLib.SimpleAction action, GLib.Variant? param) {
//             trash_or_delete_selected_files (Files.is_admin ());
        }

        private void on_selection_action_delete (GLib.SimpleAction action, GLib.Variant? param) {
//             trash_or_delete_selected_files (true);
        }

        private void on_selection_action_restore (GLib.SimpleAction action, GLib.Variant? param) {
//             GLib.List<Files.File> selection = get_selected_files_for_transfer ();
//             FileUtils.restore_files_from_trash (selection, window);
        }

        private void on_selection_action_open_executable (GLib.SimpleAction action, GLib.Variant? param) {
//             GLib.List<Files.File> selection = get_files_for_action ();
//             Files.File file = selection.data as Files.File;
//             try {
//                 file.execute (null);
//             } catch (Error e) {
//                 PF.Dialogs.show_warning_dialog (_("Cannot execute this file"), e.message, window);
//             }
        }

        private void on_selection_action_open_with_default (GLib.SimpleAction action, GLib.Variant? param) {
//             activate_selected_items (Files.OpenFlag.APP, get_files_for_action ());
        }

        private void on_selection_action_open_with_app (GLib.SimpleAction action, GLib.Variant? param) {
//             open_files_with (open_with_apps.nth_data (param.get_uint32 ()), get_files_for_action ());
        }

        private void on_selection_action_open_with_other_app () {
//             GLib.List<Files.File> selection = get_files_for_action ();
//             Files.File file = selection.data as Files.File;
//             open_file (file, null);
        }

        private void on_common_action_bookmark (GLib.SimpleAction action, GLib.Variant? param) {
//             GLib.File location;
//             if (selected_files != null) {
//                 location = selected_files.data.get_target_location ();
//             } else {
//                 location = slot.directory.file.get_target_location ();
//             }

//             window.bookmark_uri (location.get_uri ());
        }

// /** Background actions */

        private void on_background_action_new (GLib.SimpleAction action, GLib.Variant? param) {
//             switch (param.get_string ()) {
//                 case "FOLDER":
//                     new_empty_folder ();
//                     break;

//                 case "FILE":
//                     new_empty_file ();
//                     break;

//                 default:
//                     break;
//             }
        }

        private void on_background_action_create_from (GLib.SimpleAction action, GLib.Variant? param) {
//             int index = int.parse (param.get_string ());
//             create_from_template (templates.nth_data ((uint)index));
        }

// /** Common actions */
        private void on_common_action_open_in (GLib.SimpleAction action, GLib.Variant? param) {
//             default_app = null;

//             switch (param.get_string ()) {
//                 case "TAB":
//                     activate_selected_items (Files.OpenFlag.NEW_TAB, get_files_for_action ());
//                     break;

//                 case "WINDOW":
//                     activate_selected_items (Files.OpenFlag.NEW_WINDOW, get_files_for_action ());
//                     break;

//                 default:
//                     break;
//             }
        }

        private void on_common_action_properties (GLib.SimpleAction action, GLib.Variant? param) {
//             new PropertiesWindow (get_files_for_action (), this, window);
        }

        private void on_common_action_copy_link (GLib.SimpleAction action, GLib.Variant? param) {
//             clipboard.copy_link_files (get_selected_files_for_transfer (get_files_for_action ()));
        }

        private void on_common_action_copy (GLib.SimpleAction action, GLib.Variant? param) {
//             clipboard.copy_files (get_selected_files_for_transfer (get_files_for_action ()));
        }

        private void on_common_action_paste (GLib.SimpleAction action, GLib.Variant? param) {
//             if (clipboard.can_paste && !(clipboard.files_linked && in_trash)) {
//                 var target = slot.location;
//                 clipboard.paste_files.begin (target, this as Gtk.Widget, (obj, res) => {
//                     clipboard.paste_files.end (res);
//                     if (target.has_uri_scheme ("trash")) {
//                         /* Pasting files into trash is equivalent to trash or delete action */
//                         after_trash_or_delete ();
//                     }
//                 });
//             }
        }

        private void on_common_action_paste_into (GLib.SimpleAction action, GLib.Variant? param) {
//             var file = get_files_for_action ().nth_data (0);

//             if (file != null &&
//                 clipboard.can_paste &&
//                 !(clipboard.files_linked && in_trash)) {
//
//                 GLib.File target;
//                 if (file.is_folder () && !clipboard.has_file (file)) {
//                     target = file.get_target_location ();
//                 } else {
//                     target = slot.location;
//                 }

//                 clipboard.paste_files.begin (target, this as Gtk.Widget, (obj, res) => {
//                     clipboard.paste_files.end (res);
//                     if (target.has_uri_scheme ("trash")) {
//                         /* Pasting files into trash is equivalent to trash or delete action */
//                         after_trash_or_delete ();
//                     }
//                 });
//             }
        }

        private void on_directory_file_added (Directory dir, Files.File? file) {
            // assert (file != null);
//             if (file != null) {
            if (file != null) {
                view_widget.add_file (file);
                stack.visible_child_name = "view-widget";
            }
//                 view_widget show_and_select_file (file, false, true); /* Always select files added to view after initial load */
//                 handle_free_space_change ();
//             } else {
//                 critical ("Null file added");
//             }
        }

        private void on_directory_file_loaded (Directory dir, Files.File file) {
            view_widget.add_file (file); /* Do not select files added during initial load */
            stack.visible_child_name = "view-widget";
//             /* no freespace change signal required */
        }

        private void on_directory_file_changed (Directory dir, Files.File file) {
//             if (file.location.equal (dir.file.location)) {
//                 /* The slot directory has changed - it can only be the properties */
//                 is_writable = slot.directory.file.is_writable ();
//             } else {
//                 view_widget.file_changed (file);
//                 }
//             }

//             draw_when_idle ();
        }

        private void on_directory_file_icon_changed (Directory dir, Files.File file) {
//             view_widget.file_icon_changed (file);
        }

        private void on_directory_file_deleted (Directory dir, Files.File file) {
//             /* The deleted file could be the whole directory, which is not in the model but that
//              * that does not matter.  */

            file.exists = false;
            view_widget.file_deleted (file);

            if (file.get_thumbnail_path () != null) {
                FileUtils.remove_thumbnail_paths_for_uri (file.uri);
            }

            // if (plugins != null) {
            //     plugins.update_file_info (file);
            // }

            if (file.is_folder ()) {
                /* Check whether the deleted file is the directory */
                var file_dir = Directory.cache_lookup (file.location);
                if (file_dir != null) {
                    Directory.purge_dir_from_cache (file_dir);
                    slot.folder_deleted (file, file_dir);
                }
            }

//             handle_free_space_change ();
        }

        private void on_directory_done_loading (Directory dir) {
//             /* Should only be called on directory creation or reload */
            disconnect_directory_loading_handlers (dir);
            in_trash = slot.directory.is_trash;
            in_recent = slot.directory.is_recent;
            in_network_root = slot.directory.file.is_root_network_folder ();

            if (slot.directory.can_load) {
                is_writable = slot.directory.file.is_writable ();
                if (in_recent) {
                    view_widget.sort_type = Files.SortType.MODIFIED;
                    view_widget.sort_reversed = false;
                } else if (slot.directory.file.info != null) {
                    view_widget.sort_type = slot.directory.file.sort_type;
                    view_widget.sort_reversed = slot.directory.file.sort_reversed;
                }
            } else {
                is_writable = false;
            }
        }

//     /** Handle zoom level change */
        private void on_zoom_level_changed (ZoomLevel zoom) {
            var size = zoom.to_icon_size () * get_scale_factor ();

            if (!large_thumbnails && size > 128 || large_thumbnails && size <= 128) {
                large_thumbnails = size > 128;
                slot.refresh_files (); /* Force GOF files to switch between normal and large thumbnails */
            }
        }

/** Handle Preference changes */

// /** Handle popup menu events */
//         private bool on_popup_menu () {
//             show_context_menu ();
//             return true;
//         }

// /** Handle Button events */
// /** Handle Motion events */

// /** Handle clipboard signal */
        private void on_clipboard_changed () {
            /* show possible change in appearance of cut items */
            // queue_draw ();
        }

// /** MENU FUNCTIONS */
//         private void show_context_menu () {
//             /* select selection or background context menu */
//             update_menu_actions ();

//             var menu = new Menu ();
//             var open_submenu = new Menu ();
//             var selection = get_files_for_action ();
//             var selected_file = selection.data;

//             if (common_actions.get_action_enabled ("open-in")) {
//                 var new_tab_menuitem = new MenuItem (_("New Tab"), null);
//                 if (selected_files != null) {
//                     new_tab_menuitem.set_detailed_action ("common.open-in::TAB");
//                 } else {
//                     new_tab_menuitem.set_detailed_action ("win.tab::TAB");
//                 }

//                 var new_window_menuitem = new MenuItem (_("New Window"), null);
//                 if (selected_files != null) {
//                     new_window_menuitem.set_detailed_action ("common.open-in::WINDOW");
//                 } else {
//                     new_window_menuitem.set_detailed_action ("win.tab::WINDOW");
//                 }

//                 open_submenu.append_item (new_tab_menuitem);
//                 open_submenu.append_item (new_window_menuitem);
//             }

//             if (!selected_file.is_mountable () &&
//                 !selected_file.is_root_network_folder () &&
//                 can_open_file (selected_file)) {

//                 if (!selected_file.is_folder () && selected_file.is_executable ()) {
//                     var run_menuitem = new MenuItem (_("Run"), "selection.open");
//                     menu.append_item (run_menuitem);
//                 } else if (default_app != null && default_app.get_id () != APP_ID + ".desktop") {
//                     var open_menuitem = new GLib.MenuItem (
//                         _("Open in %s").printf (default_app.get_display_name ()),
//                         "selection.open-with-default"
//                     );
//                     menu.append_item (open_menuitem);
//                 }

//                 open_with_apps = MimeActions.get_applications_for_files (selection);

//                 if (selected_file.is_executable () == false) {
//                     filter_default_app_from_open_with_apps ();
//                 }

//                 filter_this_app_from_open_with_apps ();

//                 if (open_with_apps != null && open_with_apps.data != null) {
//                     unowned string last_label = "";
//                     unowned string last_exec = "";
//                     uint count = 0;

//                     foreach (unowned AppInfo app_info in open_with_apps) {
//                         /* Ensure no duplicate items */
//                         unowned string label = app_info.get_display_name ();
//                         unowned string exec = app_info.get_executable ().split (" ")[0];
//                         if (label != last_label || exec != last_exec) {
//                             var menuitem = new GLib.MenuItem (label, null);
//                             menuitem.set_icon (app_info.get_icon ());
//                             menuitem.set_detailed_action (GLib.Action.print_detailed_name (
//                                 "selection.open-with-app",
//                                 new GLib.Variant.uint32 (count)
//                             ));

//                             open_submenu.append_item (menuitem);
//                         }

//                         last_label = label;
//                         last_exec = exec;
//                         count++;
//                     };

//                     if (count > 0) {
//                         // open_submenu.add (new Gtk.SeparatorMenuItem ());
//                     }
//                 }

//                 if (selection != null && selection.first ().next == null) { // Only one selected
//                     var other_apps_menuitem = new MenuItem (_("Other Application…"), "selection.open-with-other-app");
//                     open_submenu.append_item (other_apps_menuitem);
//                 }
//             }

//             var open_submenu_item = new GLib.MenuItem ("", null);
//             if (open_submenu.get_n_items () > 0) { //Can be assumed to be limited length
//                 open_submenu_item.set_submenu (open_submenu);

//                 if (selected_file.is_folder () || selected_file.is_root_network_folder ()) {
//                     open_submenu_item.set_label (_("Open in"));
//                 } else {
//                     open_submenu_item.set_label (_("Open with"));
//                 }

//                 menu.append_item (open_submenu_item);
//             }

//             var paste_menuitem = new MenuItem (_("Paste"), "common.paste");
//             var bookmark_menuitem = new MenuItem (_("Add to Bookmarks"), "common.bookmark");
//             var properties_menuitem = new MenuItem (_("Properties"), "common.properties");

//             MenuItem? select_all_menuitem = null;
//             MenuItem? deselect_all_menuitem = null;
//             MenuItem? invert_selection_menuitem = null;

//             if (!all_selected) {
//                 select_all_menuitem = new MenuItem (_("Select All"), "common.select-all");
//                 if (get_selected_files () != null) {
//                     invert_selection_menuitem = new MenuItem (_("Invert Selection"), "selection.invert-selection");
//                 }
//             } else {
//                 deselect_all_menuitem = new MenuItem (_("Deselect All"), "common.select-all") ;
//             }

//             if (get_selected_files () != null) { // Add selection actions
//                 var cut_menuitem = new MenuItem (_("Cut"), "selection.cut");
//                 ///TRANSLATORS Verb to indicate action of menuitem will be to duplicate a file.
//                 var copy_menuitem = new MenuItem (_("Copy"), "common.copy");
//                 var trash_menuitem = new MenuItem (_("Move to Trash"), "selection.trash");
//                 var delete_menuitem = new MenuItem (_("Delete Permanently"), "selection.delete");

//                 /* In trash, only show context menu when all selected files are in root folder */
//                 if (in_trash && valid_selection_for_restore ()) {
//                     var restore_menuitem = new MenuItem (_("Restore from Trash"), "selection.restore");
//                     menu.append_item (restore_menuitem);
//                     menu.append_item (delete_menuitem);
//                     menu.append_item (cut_menuitem);
//                     if (select_all_menuitem != null) {
//                         menu.append_item (select_all_menuitem);
//                     }

//                     if (deselect_all_menuitem != null) {
//                         menu.append_item (deselect_all_menuitem);
//                     }

//                     if (invert_selection_menuitem != null) {
//                         menu.append_item (invert_selection_menuitem);
//                     }

//                     menu.append_item (properties_menuitem);
//                 } else if (in_recent) {
//                     var open_parent_menuitem = new MenuItem (_("Open Parent Folder"), "selection.view-in-location");
//                     var forget_menuitem = new MenuItem (_("Remove from History"), "selection.forget");
//                     menu.append_item (open_parent_menuitem);
//                     menu.append_item (forget_menuitem);
//                     menu.append_item (copy_menuitem);
//                     if (select_all_menuitem != null) {
//                         menu.append_item (select_all_menuitem);
//                     }

//                     if (deselect_all_menuitem != null) {
//                         menu.append_item (deselect_all_menuitem);
//                     }

//                     if (invert_selection_menuitem != null) {
//                         menu.append_item (invert_selection_menuitem);
//                     }

//                     menu.append_item (trash_menuitem);
//                     menu.append_item (properties_menuitem);
//                 } else {
//                     if (valid_selection_for_edit ()) {
//                         var rename_menuitem = new MenuItem (_("Rename…"), "selection.rename");
//                         var copy_link_menuitem = new MenuItem (_("Copy as Link"), "common.copy-link");

//                         menu.append_item (cut_menuitem);
//                         menu.append_item (copy_menuitem);
//                         menu.append_item (copy_link_menuitem);

//                         // Do not display the 'Paste into' menuitem if nothing to paste
//                         // Do not display 'Paste' menuitem if there is a selected folder ('Paste into' enabled)
//                         if (common_actions.get_action_enabled ("paste-into") &&
//                             clipboard != null && clipboard.can_paste) {

//                             var paste_into_menuitem = new MenuItem ("", "paste-into");
//                             if (clipboard.files_linked) {
//                                 paste_into_menuitem.set_label (_("Paste Link into Folder"));
//                             } else {
//                                 paste_into_menuitem.set_label (_("Paste into Folder"));
//                             }

//                             menu.append_item (paste_into_menuitem);
//                         } else if (common_actions.get_action_enabled ("paste") &&
//                             clipboard != null && clipboard.can_paste) {

//                             menu.append_item (paste_menuitem);
//                         }

//                         if (select_all_menuitem != null) {
//                             menu.append_item (select_all_menuitem);
//                         }

//                         if (deselect_all_menuitem != null) {
//                             menu.append_item (deselect_all_menuitem);
//                         }

//                         if (invert_selection_menuitem != null) {
//                             menu.append_item (invert_selection_menuitem);
//                         }

//                         if (slot.directory.has_trash_dirs && !Files.is_admin ()) {
//                             menu.append_item (trash_menuitem);
//                         } else {
//                             menu.append_item (delete_menuitem);
//                         }

//                         menu.append_item (rename_menuitem);
//                     }

//                     /* Do  not offer to bookmark if location is already bookmarked */
//                     if (common_actions.get_action_enabled ("bookmark") &&
//                         window.can_bookmark_uri (selected_files.data.uri)) {

//                         menu.append_item (bookmark_menuitem);
//                     }

//                     menu.append_item (properties_menuitem);
//                 }
//             } else { // Add background folder actions
//                 var show_hidden_menuitem = new MenuItem (_("Show Hidden Files"), "background.show-hidden");
//                 var show_remote_thumbnails_menuitem = new MenuItem (_("Show Remote Thumbnails"),"background.show-remote-thumbnails");
//                 var hide_local_thumbnails_menuitem = new MenuItem (_("Hide Thumbnails"),"background.hide-local-thumbnails");

//                 if (in_trash) {
//                     if (clipboard != null && clipboard.has_cutted_file (null)) {
//                         paste_menuitem.set_label (_("Paste into Folder"));
//                         menu.append_item (paste_menuitem);
//                         if (select_all_menuitem != null) {
//                             menu.append_item (select_all_menuitem);
//                         }
//                     }
//                 } else if (in_recent) {
//                     if (select_all_menuitem != null) {
//                         menu.append_item (select_all_menuitem);
//                     }

//                     menu.append_item (make_sortsubmenu_item ());
//                     menu.append_item (show_hidden_menuitem);
//                     menu.append_item (hide_local_thumbnails_menuitem);
//                 } else {
//                     if (!in_network_root) {
//                         /* If something is pastable in the clipboard, show the option even if it is not enabled */
//                         if (clipboard != null && clipboard.can_paste) {
//                             if (clipboard.files_linked) {
//                                 paste_menuitem.set_label (_("Paste Link into Folder"));
//                             } else {
//                                 paste_menuitem.set_label (_("Paste"));
//                             }
//                         }

//                         menu.append_item (paste_menuitem);
//                         if (select_all_menuitem != null) {
//                             menu.append_item (select_all_menuitem);
//                         }

//                         if (is_writable) {
//                             menu.append_item (make_newsubmenu_item ());
//                         }

//                         menu.append_item (make_newsubmenu_item ());
//                     }

//                     /* Do  not offer to bookmark if location is already bookmarked */
//                     if (common_actions.get_action_enabled ("bookmark") &&
//                         window.can_bookmark_uri (slot.directory.file.uri)) {

//                         menu.append_item (bookmark_menuitem);
//                     }

//                     menu.append_item (show_hidden_menuitem);

//                     if (!slot.directory.is_network) {
//                         menu.append_item (hide_local_thumbnails_menuitem);
//                     } else if (slot.directory.can_open_files) {
//                         menu.append_item (show_remote_thumbnails_menuitem);
//                     }

//                     if (!in_network_root) {
//                         menu.append_item (properties_menuitem);
//                     }
//                 }
//             }

//             if (!in_trash) {
//                 plugins.hook_context_menu ((Gtk.Widget)menu, get_files_for_action ());
//             }

//             // menu.set_screen (null);
//             // menu.attach_to_widget (this, null);

//             /* Override style Granite.STYLE_CLASS_H2_LABEL of view when it is empty */
//             // if (slot.directory.is_empty ()) {
//             //     menu.add_class (Gtk.STYLE_CLASS_CONTEXT_MENU);
//             // }

//             // menu.show_all ();
//             new Gtk.PopoverMenu.from_model (menu).popup ();
//         }

//         private MenuItem make_sortsubmenu_item () {
//             var sort_submenu = new GLib.Menu ();
//             var menu_item = new MenuItem.submenu (_("Sortby"), sort_submenu);
//             var name_radioitem = new MenuItem (_("Name"), "background.sort-by::name");
//             var size_radioitem = new MenuItem (_("Size"), "background.sort-by::size");
//             var type_radioitem = new MenuItem (_("Type"), "background.sort-by::type");
//             var date_radioitem = new MenuItem (_("Date"), "background.sort-by::modified");
//             var reversed_checkitem = new MenuItem (_("Reversed Order"), "background.reverse");
//             var folders_first_checkitem = new MenuItem (_("Folders Before Files"), "background.folders-first");


//             sort_submenu.append_item (name_radioitem);
//             sort_submenu.append_item (size_radioitem);
//             sort_submenu.append_item (type_radioitem);
//             sort_submenu.append_item (date_radioitem);
//             sort_submenu.append_item (reversed_checkitem);
//             sort_submenu.append_item (folders_first_checkitem);

//             return menu_item;
//         }

//         private MenuItem make_newsubmenu_item () {
//             //TODO Show accelerators
//             var folder_menuitem = new GLib.MenuItem (_("Folder"), "background.new::FOLDER");
//             var file_menuitem = new GLib.MenuItem (_("Empty File"), "background.new::FILE");

//             var new_submenu = new Menu ();
//             var menu_item = new MenuItem.submenu (_("New"), new_submenu);
//             new_submenu.append_item (folder_menuitem);
//             new_submenu.append_item (file_menuitem);
//             /* Potential optimisation - do just once when app starts or view created */
//             templates = null;
//             unowned string? template_path = GLib.Environment.get_user_special_dir (GLib.UserDirectory.TEMPLATES);
//             if (template_path != null) {
//                 var template_folder = GLib.File.new_for_path (template_path);
//                 load_templates_from_folder (template_folder);

//                 if (templates.length () > 0) { //Can be assumed to be limited length
//                     // We need to get directories first
//                     templates.reverse ();

//                     var active_submenu = new_submenu;
//                     int index = 0;
//                     foreach (unowned GLib.File template in templates) {
//                         var label = template.get_basename ();
//                         var ftype = template.query_file_type (GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
//                         if (ftype == GLib.FileType.DIRECTORY) {
//                             if (template == template_folder) {
//                                 active_submenu = new_submenu;
//                             } else {
//                                 active_submenu = new Menu ();
//                                 var submenu_item = new GLib.MenuItem (label, null);
//                                 submenu_item.set_submenu (active_submenu);
//                                 active_submenu.append_item (submenu_item);
//                             }
//                         } else {
//                             var action_name = "background.create-from::%s".printf (index.to_string ());
//                             var template_menuitem = new GLib.MenuItem (label, action_name);
//                             active_submenu.append_item (template_menuitem);
//                         }

//                         index++;
//                     }
//                 }
//             }

//             return menu_item;
//         }

//         private bool valid_selection_for_edit () {
//             foreach (unowned Files.File file in get_selected_files ()) {
//                 if (file.is_root_network_folder ()) {
//                     return false;
//                 }
//             }

//             return true;
//         }

//         private bool valid_selection_for_restore () {
//             foreach (unowned Files.File file in get_selected_files ()) {
//                 if (!(file.directory.get_basename () == "/")) {
//                     return false;
//                 }
//             }

//             return true;
//         }

        private void update_menu_actions () {
//             if (is_frozen || !slot.directory.can_load) {
//                 return;
//             }

//             GLib.List<Files.File> selection = get_files_for_action ();
//             Files.File file;

//             bool is_selected = selection != null;
//             bool more_than_one_selected = (is_selected && selection.first ().next != null);
//             bool single_folder = false;
//             bool only_folders = selection_only_contains_folders (selection);
//             bool can_rename = false;
//             bool can_show_properties = false;
//             bool can_copy = false;
//             bool can_open = false;
//             bool can_paste_into = false;
//             bool can_bookmark = false;

//             if (is_selected) {
//                 file = selection.data;
//                 if (file != null) {
//                     single_folder = (!more_than_one_selected && file.is_folder ());
//                     can_rename = is_writable;
//                     can_paste_into = single_folder && file.is_writable () ;
//                 } else {
//                     critical ("File in selection is null");
//                 }
//             } else {
//                 file = slot.directory.file;
//                 single_folder = (!more_than_one_selected && file.is_folder ());
//                 can_paste_into = is_writable;
//             }

//             /* Both folder and file can be bookmarked if local, but only remote folders can be bookmarked
//              * because remote file bookmarks do not work correctly for unmounted locations */
//             can_bookmark = (!more_than_one_selected || single_folder) &&
//                            (slot.directory.is_local ||
//                            (file.get_ftype () != null && file.get_ftype () == "inode/directory") ||
//                            file.is_smb_server ());

//             can_copy = file.is_readable ();
//             can_open = can_open_file (file);
//             can_show_properties = !(in_recent && more_than_one_selected);

//             action_set_enabled ("common.paste", !in_recent && is_writable);
//             action_set_enabled ("common.paste-into", !renaming & can_paste_into);
//             action_set_enabled ("common.open-in", !renaming & only_folders);
//             action_set_enabled ("selection.rename", !renaming & is_selected && !more_than_one_selected && can_rename);
//             action_set_enabled ("selection.view-in-location", !renaming & is_selected);
//             action_set_enabled ("selection.open", !renaming && is_selected && !more_than_one_selected && can_open);
//             action_set_enabled ("selection.open-with-app", !renaming && can_open);
//             action_set_enabled ("selection.open-with-default", !renaming && can_open);
//             action_set_enabled ("selection.open-with-other-app", !renaming && can_open);
//             action_set_enabled ("selection.cut", !renaming && is_writable && is_selected);
//             action_set_enabled ("selection.trash", !renaming && is_writable && slot.directory.has_trash_dirs);
//             action_set_enabled ("selection.delete", !renaming && is_writable);
//             action_set_enabled ("selection.invert-selection", !renaming && is_selected);
//             action_set_enabled ("common.select-all", !renaming && is_selected);
//             action_set_enabled ("common.properties", !renaming && can_show_properties);
//             action_set_enabled ("common.bookmark", !renaming && can_bookmark && !more_than_one_selected);
//             action_set_enabled ("common.copy", !renaming && !in_trash && can_copy);
//             action_set_enabled ("common.copy-link", !renaming && !in_trash && !in_recent && can_copy);

//             update_default_app (selection);
//             update_menu_actions_sort ();
        }

//         private void update_menu_actions_sort () {
//             int sort_column_id;
//             Gtk.SortType sort_order;

//             if (view_widget.get_sort (out sort_column_id, out sort_order)) {
//                 GLib.Variant val = new GLib.Variant.string (((Files.ListModel.ColumnID)sort_column_id).to_string ());
//                 action_set_state (background_actions, "sort-by", val);
//                 val = new GLib.Variant.boolean (sort_order == Gtk.SortType.DESCENDING);
//                 action_set_state (background_actions, "reverse", val);
//                 val = new GLib.Variant.boolean (Files.Preferences.get_default ().sort_directories_first);
//                 action_set_state (background_actions, "folders-first", val);
//             } else {
//                 warning ("Update menu actions sort: The model is unsorted - this should not happen");
//             }
//         }

//         private void update_default_app (GLib.List<Files.File> selection) {
//             default_app = MimeActions.get_default_application_for_files (selection);
//             return;
//         }

//     /** Menu helpers */
//         private void action_set_state (GLib.SimpleActionGroup? action_group, string name, GLib.Variant val) {
//             if (action_group != null) {
//                 GLib.SimpleAction? action = (action_group.lookup_action (name) as GLib.SimpleAction);
//                 if (action != null) {
//                     action.set_state (val);
//                     return;
//                 }
//             }
//             critical ("Action name not found: %s - cannot set state", name);
//         }

//         private static void load_templates_from_folder (GLib.File template_folder) {
//             GLib.List<GLib.File> file_list = null;
//             GLib.List<GLib.File> folder_list = null;

//             GLib.FileEnumerator enumerator;
//             var flags = GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS;
//             try {
//                 enumerator = template_folder.enumerate_children ("standard::*", flags, null);
//                 uint count = templates.length (); //Assume to be limited in size
//                 GLib.File location;
//                 GLib.FileInfo? info = enumerator.next_file (null);

//                 while (count < MAX_TEMPLATES && (info != null)) {
//                     if (!info.get_is_hidden () && !info.get_is_backup ()) {
//                         location = template_folder.get_child (info.get_name ());
//                         if (info.get_file_type () == GLib.FileType.DIRECTORY) {
//                             folder_list.prepend (location);
//                         } else {
//                             file_list.prepend (location);
//                             count ++;
//                         }
//                     }

//                     info = enumerator.next_file (null);
//                 }
//             } catch (GLib.Error error) {
//                 return;
//             }

//             if (file_list.length () > 0) { // Can assumed to be limited in length
//                 file_list.sort ((a, b) => {
//                     return strcmp (a.get_basename ().down (), b.get_basename ().down ());
//                 });

//                 foreach (var file in file_list) {
//                     templates.append (file);
//                 }

//                 templates.append (template_folder);
//             }

//             if (folder_list.length () > 0) { //Can be assumed to be limited in length
//                 /* recursively load templates from subdirectories */
//                 folder_list.@foreach ((folder) => {
//                     load_templates_from_folder (folder);
//                 });
//             }
//         }

//         private void filter_this_app_from_open_with_apps () {
//             unowned GLib.List<AppInfo> l = open_with_apps;

//             while (l != null) {
//                 if (l.data is AppInfo) {
//                     if (app_is_this_app (l.data)) {
//                         open_with_apps.delete_link (l);
//                         break;
//                     }
//                 } else {
//                     open_with_apps.delete_link (l);
//                     l = open_with_apps;
//                     if (l == null) {
//                         break;
//                     }
//                 }

//                 l = l.next;
//             }
//         }

//         private bool app_is_this_app (AppInfo ai) {
//             string exec_name = ai.get_executable ();

//             return (exec_name == Config.APP_NAME);
//         }

//         private void filter_default_app_from_open_with_apps () {
//             if (default_app == null) {
//                 return;
//             }

//             string? id1, id2;
//             id2 = default_app.get_id ();

//             if (id2 != null) {
//                 unowned GLib.List<AppInfo> l = open_with_apps;

//                 while (l != null && l.data is AppInfo) {
//                     id1 = l.data.get_id ();

//                     if (id1 != null && id1 == id2) {
//                         open_with_apps.delete_link (l);
//                         break;
//                     }

//                     l = l.next;
//                 }
//             }
//         }

//         /** Menu action functions */
//         private void create_from_template (GLib.File template) {
//             /* Block the async directory file monitor to avoid generating unwanted "add-file" events */
//             slot.directory.block_monitor ();
//             var new_name = (_("Untitled %s")).printf (template.get_basename ());
//             FileOperations.new_file_from_template.begin (
//                 this,
//                 slot.location,
//                 new_name,
//                 template,
//                 null,
//                 (obj, res) => {
//                     try {
//                         var file = FileOperations.new_file_from_template.end (res);
//                         create_file_done (file);
//                     } catch (Error e) {
//                         critical (e.message);
//                     }
//                 });
//         }

//         private void open_files_with (GLib.AppInfo app, GLib.List<Files.File> files) {
//             MimeActions.open_multiple_gof_files_request (files, this, app);
//         }


// /** HELPER AND CONVENIENCE FUNCTIONS */
//         private void start_drag_scroll_timer (Gdk.Drag context) {
//             drag_scroll_timer_id = GLib.Timeout.add_full (GLib.Priority.LOW,
//                                                           50,
//                                                           () => {
//                 Gtk.Widget? widget = scrolled_window.get_child ();
//                 if (widget != null) {
//                     Gdk.Device pointer = context.get_device ();
//                     var window = widget.get_root ().get_surface ();
//                     double x, y;
//                     int w, h;

//                     window.get_device_position (pointer, out x, out y, null);

//                     scroll_if_near_edge (y, window.height, 20, scrolled_window.get_vadjustment ());
//                     scroll_if_near_edge (x, window.width, 20, scrolled_window.get_hadjustment ());
//                     return GLib.Source.CONTINUE;
//                 } else {
//                     return GLib.Source.REMOVE;
//                 }
//             });
//         }

//         private void scroll_if_near_edge (double pos, int dim, int threshold, Gtk.Adjustment adj) {
//                 /* check if we are near the edge */
//                 int band = 2 * threshold;
//                 int offset = (int)pos - band;
//                 if (offset > 0) {
//                     offset = int.max (band - (dim - (int)pos), 0);
//                 }

//                 if (offset != 0) {
//                     /* change the adjustment appropriately */
//                     var val = adj.get_value ();
//                     var lower = adj.get_lower ();
//                     var upper = adj.get_upper ();
//                     var page = adj.get_page_size ();

//                     val = (val + 2 * offset).clamp (lower, upper - page);
//                     adj.set_value (val);
//                 }
//         }

//         private void remove_marlin_icon_info_cache (Files.File file) {
//             string? path = file.get_thumbnail_path ();

//             if (path != null) {
//                 Files.IconSize s;

//                 for (int z = ZoomLevel.SMALLEST;
//                      z <= ZoomLevel.LARGEST;
//                      z++) {

//                     s = ((ZoomLevel) z).to_icon_size ();
//                     Files.IconInfo.remove_cache (path, s, get_scale_factor ());
//                 }
//             }
//         }

//         /* For actions on the background we need to return the current slot directory, but this
//          * should not be added to the list of selected files
//          */
        private GLib.List<Files.File>? get_files_for_action () {
//             GLib.List<Files.File> action_files = null;
//             update_selected_files_and_menu ();

//             if (selected_files == null) {
//                 action_files.prepend (slot.directory.file);
//             } else if (in_recent) {
//                 selected_files.@foreach ((file) => {
//                     var goffile = Files.File.get_by_uri (file.get_display_target_uri ());
//                     goffile.query_update ();
//                     action_files.append (goffile);
//                 });
//             } else {
//                 action_files = selected_files.copy_deep ((GLib.CopyFunc) GLib.Object.ref);
//             }

//             return (owned)action_files;
                return null;
        }

        private void on_view_items_activated () {
//             activate_selected_items (Files.OpenFlag.DEFAULT);
        }

        private void on_view_selection_changed () {
//             selected_files_invalid = true;
//             one_or_less = (selected_files == null || selected_files.next == null);
        }

//         private void on_name_editing_canceled () {
//             is_frozen = false;
//             renaming = false;
//             proposed_name = "";

//             update_menu_actions ();
//             grab_focus ();
//         }

//         private void on_name_edited (Files.File file, string? _new_name) {

//         }

        private void cancel_timeout (ref uint id) {
//             if (id > 0) {
//                 GLib.Source.remove (id);
//                 id = 0;
//             }
        }

        private void update_selected_files_and_menu () {
//             if (selected_files_invalid) {
//                 selected_files = null;

//                 var selected_count = view_widget.get_selected_files (out selected_files);
//                 all_selected = selected_count == slot.displayed_files_count;
//                 selected_files.reverse ();
//                 selected_files_invalid = false;
//                 update_menu_actions ();
//                 selection_changed (selected_files);
//             }

//             one_or_less = (selected_files == null || selected_files.next == null);
        }

        public virtual void cancel () {
//             grab_focus (); /* Cancel any renaming */
//             cancel_timeout (ref add_remove_file_timeout_id);
//             cancel_timeout (ref set_cursor_timeout_id);
//             cancel_timeout (ref draw_timeout_id);
//             /* List View will take care of unloading subdirectories */
        }

        public void close () {
//             is_frozen = true; /* stop signal handlers running during destruction */
//             cancel ();
//             unselect_all ();
        }

//         public virtual void highlight_path (Gtk.TreePath? path) {}
//         public virtual Gtk.TreePath up (Gtk.TreePath path) {path.up (); return path;}
//         public virtual Gtk.TreePath down (Gtk.TreePath path) {path.down (); return path;}
    }
}
