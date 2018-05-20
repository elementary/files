/*
* Copyright (c) 2010 Mathijs Henquet <mathijs.henquet@gmail.com>
*               2017 elementary LLC. (https://elementary.io)
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
* Authored by: Mathijs Henquet <mathijs.henquet@gmail.com>
*              ammonkey <am.monkeyd@gmail.com>
*/

namespace Marlin.View {

    public class Window : Gtk.ApplicationWindow {
        const GLib.ActionEntry [] win_entries = {
            {"new_window", action_new_window},
            {"quit", action_quit},
            {"refresh", action_reload},
            {"undo", action_undo},
            {"redo", action_redo},
            {"bookmark", action_bookmark},
            {"find", action_find},
            {"edit_path", action_edit_path},
            {"tab", action_tab, "s"},
            {"go_to", action_go_to, "s"},
            {"zoom", action_zoom, "s"},
            {"info", action_info, "s"},
            {"view_mode", action_view_mode, "s", "'MILLER'"},
            {"show_hidden", null, null, "false", change_state_show_hidden},
            {"show_remote_thumbnails", null, null, "false", change_state_show_remote_thumbnails}
        };

        public GLib.SimpleActionGroup win_actions;

        const string [] mode_strings = {
            "ICON",
            "LIST",
            "MILLER"
        };

        public uint window_number { get; construct; }

        public bool is_first_window {
            get {
                return (window_number == 0);
            }
        }

        public Gtk.Builder ui;
        private unowned UndoManager undo_manager;
        public Chrome.TopMenu top_menu;
        public Chrome.ViewSwitcher view_switcher;
        public Granite.Widgets.DynamicNotebook tabs;
        private Gtk.Paned lside_pane;
        public Marlin.Places.Sidebar sidebar;
        public ViewContainer? current_tab = null; /* Used by connect server dialog only - to be refactored */

        private bool tabs_restored = false;
        private bool restoring_tabs = false;
        private bool doing_undo_redo = false;

        public signal void loading_uri (string location);
        public signal void folder_deleted (GLib.File location);
        public signal void free_space_change ();

        public Window (Marlin.Application application, Gdk.Screen myscreen = Gdk.Screen.get_default ()) {
            Object (
                application: application,
                height_request: 300,
                icon_name: "system-file-manager",
                screen: myscreen,
                title: _(Marlin.APP_TITLE),
                width_request: 500,
                window_number: application.window_count
            );

            if (is_first_window) {
                set_accelerators ();
            }
        }

        construct {
            win_actions = new GLib.SimpleActionGroup ();
            win_actions.add_action_entries (win_entries, this);
            insert_action_group ("win", win_actions);

            undo_actions_set_insensitive ();

            undo_manager = Marlin.UndoManager.instance ();

            build_window ();

            connect_signals ();

            default_width = Preferences.settings.get_int ("window-width");
            default_height = Preferences.settings.get_int ("window-height");

            if (is_first_window) {
                Preferences.settings.bind ("sidebar-width", lside_pane,
                                           "position", SettingsBindFlags.DEFAULT);

                var state = (Marlin.WindowState)(Preferences.settings.get_enum ("window-state"));

                if (state.is_maximized ()) {
                    maximize ();
                } else {
                    var default_x = Preferences.settings.get_int ("window-x");
                    var default_y = Preferences.settings.get_int ("window-y");

                    int shadow_size = 64; // An approximation. TODO retrieve from style context?

                    // Will be created as a normal window even if saved tiled so allow for added shadow
                    // and approximate a tiled window on restoration
                    if (state == Marlin.WindowState.TILED_START ||
                        state == Marlin.WindowState.TILED_END) {

                        default_x -= shadow_size;
                        default_y -= shadow_size;

                        default_width += shadow_size * 2;
                        default_height += shadow_size * 2;
                    }

                    move (default_x, default_y);
                }
            }

            present ();
        }

        private void build_window () {
            view_switcher = new Chrome.ViewSwitcher (win_actions.lookup_action ("view_mode") as SimpleAction);
            view_switcher.mode = Preferences.settings.get_enum ("default-viewmode");

            top_menu = new Chrome.TopMenu (view_switcher);
            top_menu.show_close_button = true;
            top_menu.custom_title = new Gtk.Label (null);

            set_titlebar (top_menu);

            tabs = new Granite.Widgets.DynamicNotebook ();
            tabs.show_tabs = true;
            tabs.allow_restoring = true;
            tabs.allow_duplication = true;
            tabs.allow_new_window = true;
            tabs.group_name = APP_NAME;

            this.configure_event.connect_after ((e) => {
                tabs.set_size_request (e.width / 2, -1);
                return false;
            });

            tabs.show ();

            /* Show only local places in sidebar when running as root */
            sidebar = new Marlin.Places.Sidebar (this, Posix.getuid () == 0);

            lside_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            lside_pane.position = Preferences.settings.get_int ("sidebar-width");
            lside_pane.show ();
            lside_pane.pack1 (sidebar, false, false);
            lside_pane.pack2 (tabs, true, false);
            add (lside_pane);

            /** Apply preferences */
            get_action ("show_hidden").set_state (Preferences.settings.get_boolean ("show-hiddenfiles"));
            get_action ("show_remote_thumbnails").set_state (Preferences.settings.get_boolean ("show-remote-thumbnails"));
        }

        private void connect_signals () {
            /*/
            /* Connect and abstract signals to local ones
            /*/

            top_menu.forward.connect (() => {current_tab.go_forward ();});
            top_menu.back.connect (() => {current_tab.go_back ();});
            top_menu.escape.connect (grab_focus);
            top_menu.path_change_request.connect ((loc, flag) => {
                current_tab.is_frozen = false;
                uri_path_change_request (loc, flag);
            });
            top_menu.reload_request.connect (action_reload);
            top_menu.focus_location_request.connect ((loc) => {
                current_tab.focus_location_if_in_current_directory (loc, true);
            });
            top_menu.focus_in_event.connect (() => {
                current_tab.is_frozen = true;
                return true;
            });
            top_menu.focus_out_event.connect (() => {
                current_tab.is_frozen = false;
                return true;
            });

            undo_manager.request_menu_update.connect (undo_redo_menu_update_callback);

            /* Toggle focus between sidebar and view using unmodified Tab key, unless location
             * bar in focus. */
            key_press_event.connect_after ((event) => {
                switch (event.keyval) {
                    case Gdk.Key.Left:
                    case Gdk.Key.Right:
                        /* Arrow events only reach here if ignored by views etc because of unhandled mods e.g. Ctrl+Alt.
                         * Use these events to toggle focus between view and sidebar using keyboard only */
                        if (top_menu.locked_focus) {
                            return false;
                        }

                        if (event.keyval == Gdk.Key.Left) {
                        /* This works better than trying to use a focus chain */
                            sidebar.grab_focus ();
                        } else {
                            current_tab.grab_focus ();
                            sidebar.sync_needed ();
                        }
                        return true;

                    default:
                        /* Use find function instead of view interactive search */
                        if (event.state == 0 || event.state == Gdk.ModifierType.SHIFT_MASK) {
                            /* Use printable characters to initiate search */
                            if (((unichar)(Gdk.keyval_to_unicode (event.keyval))).isprint ()) {
                                win_actions.activate_action ("find", null);
                                key_press_event (event);
                                return true;
                            }
                        }

                        break;
                }

                return false;
            });


            window_state_event.connect ((event) => {
                if (Gdk.WindowState.ICONIFIED in event.changed_mask) {
                    top_menu.cancel (); /* Cancel any ongoing search query else interface may freeze on uniconifying */
                }

                return false;
            });

            delete_event.connect (() => {
                quit ();
                return false;
            });

            tabs.new_tab_requested.connect (() => {
                add_tab ();
            });

            tabs.close_tab_requested.connect ((tab) => {
                var view_container = (tab.page as ViewContainer);
                tab.restore_data = view_container.location.get_uri ();

                /* If closing tab is current, set current_tab to null to ensure
                 * closed ViewContainer is destroyed. It will be reassigned in tab_changed
                 */
                if (view_container == current_tab) {
                    current_tab = null;
                }

                if (tabs.n_tabs == 1) {
                    add_tab ();
                }

                return true;
            });

            tabs.tab_switched.connect ((old_tab, new_tab) => {
                change_tab (tabs.get_tab_position (new_tab));
            });

            tabs.tab_restored.connect ((label, restore_data, icon) => {
                add_tab_by_uri (restore_data);
            });

            tabs.tab_duplicated.connect ((tab) => {
                add_tab_by_uri (((ViewContainer)(tab.page)).uri);
            });

            tabs.tab_moved.connect ((tab, x, y) => {
                var vc = tab.page as ViewContainer;
                ((Marlin.Application) application).create_window (vc.location, real_mode (vc.view_mode), x, y);
                /* A crash occurs if the original tab is removed while processing the signal */
                GLib.Idle.add (() => {
                    remove_tab (vc);
                    return false;
                });
            });


            tabs.tab_added.connect ((tab) => {
                var vc = tab.page as ViewContainer;
                vc.window = this;
            });

            tabs.tab_removed.connect (on_tab_removed);

            sidebar.request_focus.connect (() => {
                return !current_tab.locked_focus && !top_menu.locked_focus;
            });

            sidebar.sync_needed.connect (() => {
                loading_uri (current_tab.uri);
            });

            sidebar.path_change_request.connect (uri_path_change_request);
        }

        private void on_tab_removed (Granite.Widgets.Tab tab) {
            (tab.page as ViewContainer).close ();

            if (tabs.n_tabs == 0) {
                add_tab ();
            }
        }

        private void open_new_container (GLib.File loc, Marlin.OpenFlag flag) {
            switch (flag) {
                case Marlin.OpenFlag.NEW_TAB:
                    add_tab (loc, current_tab.view_mode);
                    break;
                case Marlin.OpenFlag.NEW_WINDOW:
                    add_window (loc, current_tab.view_mode);
                    break;
                default:
                    break;
            }
        }

        public GOF.AbstractSlot? get_active_slot () {
            if (current_tab != null) {
                return current_tab.get_current_slot ();
            } else {
                return null;
            }
        }

        public new void set_title (string title) {
            this.title = title;
        }

        public void change_tab (int offset) {
            if (restoring_tabs) {
                return;
            }

            ViewContainer? old_tab = current_tab;
            current_tab = (tabs.get_tab_by_index (offset)).page as ViewContainer;

            if (current_tab == null || old_tab == current_tab) {
                return;
            }

            if (old_tab != null) {
                old_tab.set_active_state (false);
            }

            loading_uri (current_tab.uri);

            current_tab.set_active_state (true, false); /* changing tab should not cause animated scrolling */
            top_menu.working = current_tab.is_frozen;
        }

        /** Convenience function for opening a single tab **/
        public void open_single_tab (File? file = null, Marlin.ViewMode mode = Marlin.ViewMode.PREFERRED) {
            open_tabs ({file}, mode);
        }

        public void open_tabs (File[]? files = null, Marlin.ViewMode mode = Marlin.ViewMode.PREFERRED) {
            if (files == null || files.length == 0 || files[0] == null) {
                /* Restore session if not root and settings allow */
                if (Posix.getuid () == 0 ||
                    !Preferences.settings.get_boolean ("restore-tabs") ||
                    restore_tabs () < 1) {

                    /* Open a tab pointing at the default location if no tabs restored*/
                    var location = File.new_for_path (PF.UserUtils.get_real_user_home ());
                    add_tab (location, mode);
                }
            } else {
                /* Open tabs at each requested location */
                foreach (var file in files) {
                    add_tab (file, mode);
                }
            }
        }

        private void add_tab_by_uri (string uri, Marlin.ViewMode mode = Marlin.ViewMode.PREFERRED) {
            var file = get_file_from_uri (uri);
            if (file != null) {
                add_tab (file, mode);
            } else {
                add_tab ();
            }
        }

        private void add_tab (File location = File.new_for_commandline_arg (Environment.get_home_dir ()),
                             Marlin.ViewMode mode = Marlin.ViewMode.PREFERRED) {
            mode = real_mode (mode);
            var content = new View.ViewContainer (this);

            var tab = new Granite.Widgets.Tab ("", null, content);
            tab.ellipsize_mode = Pango.EllipsizeMode.MIDDLE;

            content.tab_name_changed.connect ((tab_name) => {
                /* Adding a reference to content in the closure
                   prevents destruction of viewcontainer when tab closed */
                Idle.add (() => {
                    tab.label = check_current_for_tab_with_same_name ();
                    return false;
                });
            });

            content.loading.connect ((is_loading) => {
                tab.working = is_loading;
                update_top_menu ();
            });

            content.active.connect (() => {
                update_top_menu ();
            });

            content.add_view (mode, location);
            change_tab ((int)tabs.insert_tab (tab, -1));
            tabs.current = tab;
        }

        private string check_current_for_tab_with_same_name () {
            var vc = current_tab;
            if (vc == null) {
                return "";
            }

            string name = vc.tab_name;

            if (name == Marlin.INVALID_TAB_NAME) {
                return name;
            }

            string path = Uri.unescape_string (vc.uri);
            string new_name = name;

            foreach (Granite.Widgets.Tab tab in tabs.tabs) {
                var content = (ViewContainer)(tab.page);
                if (content != vc) {
                    string content_path = Uri.unescape_string (content.uri);
                    if (content.tab_name == name && content_path != path) {
                        if (content.tab_name == tab.label) {
                            Idle.add_full (GLib.Priority.LOW, () => {
                                /* Trigger relabelling of conflicting tab (but not before this function finishes) */
                                content.tab_name_changed (content.tab_name);
                                return false;
                            });
                        }

                        new_name = disambiguate_name (name, path, content_path); /*Also relabel this tab */
                    }
                }
            }

            return new_name;
        }

        private string disambiguate_name (string name, string path, string conflict_path) {
            string prefix = "";
            string prefix_conflict = "";
            string path_temp = path;
            string conflict_path_temp = conflict_path;

            /* Add parent directories until path and conflict path differ */
            while (prefix == prefix_conflict) {
                var parent_path= PF.FileUtils.get_parent_path_from_path (path_temp);
                var parent_conflict_path = PF.FileUtils.get_parent_path_from_path (conflict_path_temp);
                prefix = Path.get_basename (parent_path) + Path.DIR_SEPARATOR_S + prefix;
                prefix_conflict = Path.get_basename (parent_conflict_path) + Path.DIR_SEPARATOR_S + prefix_conflict;
                path_temp= parent_path;
                conflict_path_temp = parent_conflict_path;
            }

            return prefix + name;
        }

        public void bookmark_uri (string uri, string? name = null) {
            sidebar.add_uri (uri, name);
        }

        public bool can_bookmark_uri (string uri) {
            return !sidebar.has_bookmark (uri);
        }

        public void remove_tab (ViewContainer view_container) {
            actual_remove_tab (tabs.get_tab_by_widget (view_container as Gtk.Widget));
        }

        private void actual_remove_tab (Granite.Widgets.Tab tab) {
            /* signal for restore_data to be set and a new tab to be created if this is last tab */
            tabs.close_tab_requested (tab);
            /* now close the tab */
            tab.close ();
        }

        public void add_window (File location = File.new_for_path (PF.UserUtils.get_real_user_home ()),
                                 Marlin.ViewMode mode = Marlin.ViewMode.PREFERRED,
                                 int x = -1, int y = -1) {

            ((Marlin.Application) application).create_window (location, real_mode (mode), x, y);
        }

        private void undo_actions_set_insensitive () {
            GLib.SimpleAction action;
            action = get_action ("undo");
            action.set_enabled (false);
            action = get_action ("redo");
            action.set_enabled (false);
        }

        private void update_undo_actions (UndoMenuData? data = null) {
            GLib.SimpleAction action;
            action = get_action ("undo");
            action.set_enabled (data != null && data.undo_label != null);
            action = get_action ("redo");
            action.set_enabled (data != null && data.redo_label != null);
        }

        private void undo_redo_menu_update_callback (UndoManager manager, UndoMenuData data) {
            update_undo_actions (data);
        }

        private void action_edit_path () {
            top_menu.enter_navigate_mode ();
        }

        private void action_bookmark (GLib.SimpleAction action, GLib.Variant? param) {
            /* Note: Duplicate bookmarks will not be created by BookmarkList */
            sidebar.add_uri (current_tab.location.get_uri ());
        }

        private void action_find (GLib.SimpleAction action, GLib.Variant? param) {
            /* Do not initiate search while slot is frozen e.g. during loading */
            if (current_tab == null || current_tab.is_frozen) {
                return;
            }

            top_menu.enter_search_mode ();
        }

        private bool adding_window = false;
        private void action_new_window (GLib.SimpleAction action, GLib.Variant? param) {
            /* Limit rate of adding new windows using the keyboard */
            if (adding_window) {
                return;
            } else {
                adding_window = true;
                add_window ();
                GLib.Timeout.add (500, () => {
                    adding_window = false;
                    return false;
                });
            }
        }

        private void action_quit (GLib.SimpleAction action, GLib.Variant? param) {
            (application as Marlin.Application).quit ();
        }

        private void action_reload () {
            /* avoid spawning reload when key kept pressed */
            if (tabs.current.working) {
                warning ("Too rapid reloading suppressed");
                return;
            }
            current_tab.reload ();
            sidebar.reload ();
        }

        private void action_view_mode (GLib.SimpleAction action, GLib.Variant? param) {
            string mode_string = param.get_string ();
            Marlin.ViewMode mode = Marlin.ViewMode.MILLER_COLUMNS;
            switch (mode_string) {
                case "ICON":
                    mode = Marlin.ViewMode.ICON;
                    break;

                case "LIST":
                    mode = Marlin.ViewMode.LIST;
                    break;

                case "MILLER":
                    mode = Marlin.ViewMode.MILLER_COLUMNS;
                    break;

                default:
                    break;
            }
            current_tab.change_view_mode (mode);
            /* ViewContainer takes care of changing appearance */
        }

        private void action_go_to (GLib.SimpleAction action, GLib.Variant? param) {
            switch (param.get_string ()) {
                case "RECENT":
                    uri_path_change_request (Marlin.RECENT_URI);
                    break;

                case "HOME":
                    uri_path_change_request ("file://" + PF.UserUtils.get_real_user_home ());
                    break;

                case "TRASH":
                    uri_path_change_request (Marlin.TRASH_URI);
                    break;

                case "NETWORK":
                    uri_path_change_request (Marlin.NETWORK_URI);
                    break;

                case "SERVER":
                    connect_to_server ();
                    break;

                case "UP":
                    current_tab.go_up ();
                    break;

                case "FORWARD":
                    current_tab.go_forward ();
                    break;

                case "BACK":
                    current_tab.go_back ();
                    break;

                default:
                    break;
            }
        }

        private void action_zoom (GLib.SimpleAction action, GLib.Variant? param) {
            if (current_tab != null) {
                assert (current_tab.view != null);
                switch (param.get_string ()) {
                    case "ZOOM_IN":
                        current_tab.view.zoom_in ();
                        break;

                    case "ZOOM_OUT":
                        current_tab.view.zoom_out ();
                        break;

                    case "ZOOM_NORMAL":
                        current_tab.view.zoom_normal ();
                        break;

                    default:
                        break;
                }
            }
        }

        private void action_tab (GLib.SimpleAction action, GLib.Variant? param) {
            switch (param.get_string ()) {
                case "NEW":
                    add_tab ();
                    break;

                case "CLOSE":
                    actual_remove_tab (tabs.current);
                    break;

                case "NEXT":
                    tabs.next_page ();
                    break;

                case "PREVIOUS":
                    tabs.previous_page ();
                    break;

                default:
                    break;
            }
        }

        private void action_info (GLib.SimpleAction action, GLib.Variant? param) {
            switch (param.get_string ()) {
                case "HELP":
                    show_app_help ();
                    break;

                default:
                    break;
            }
        }

        private void action_undo (GLib.SimpleAction action, GLib.Variant? param) {
            if (doing_undo_redo) { /* Guard against rapid pressing of Ctrl-Z */
                return;
            }
            before_undo_redo ();
            undo_manager.undo (this, after_undo_redo);
        }

        private void action_redo (GLib.SimpleAction action, GLib.Variant? param) {
            if (doing_undo_redo) { /* Guard against rapid pressing of Ctrl-Shift-Z */
                return;
            }
            before_undo_redo ();
            undo_manager.redo (this, after_undo_redo);
        }

        private void before_undo_redo () {
            doing_undo_redo = true;
            update_undo_actions ();
        }

        public static void after_undo_redo (void  *data) {
            var window = data as Marlin.View.Window;
            if (window.current_tab.slot.directory.is_recent) {
                window.current_tab.reload ();
            }

            window.doing_undo_redo = false;
        }

        public void change_state_show_hidden (GLib.SimpleAction action) {
            bool state = !action.state.get_boolean ();
            action.set_state (new GLib.Variant.boolean (state));
            Preferences.settings.set_boolean ("show-hiddenfiles", state);
        }

        public void change_state_show_remote_thumbnails (GLib.SimpleAction action) {
            bool state = !action.state.get_boolean ();
            action.set_state (new GLib.Variant.boolean (state));
            Preferences.settings.set_boolean ("show-remote-thumbnails", state);
        }

        private void connect_to_server () {
            var dialog = new Marlin.ConnectServer.Dialog ((Gtk.Window) this);
            dialog.show ();
        }

        void show_app_help() {
            try {
                Gtk.show_uri (screen, Marlin.HELP_URL, -1);
            } catch (Error e) {
                critical ("Can't open the link");
            }
        }

        private GLib.SimpleAction? get_action (string action_name) {
            return win_actions.lookup_action (action_name) as GLib.SimpleAction?;
        }

        private Marlin.ViewMode real_mode (Marlin.ViewMode mode) {
            switch (mode) {
                case Marlin.ViewMode.ICON:
                case Marlin.ViewMode.LIST:
                case Marlin.ViewMode.MILLER_COLUMNS:
                    return mode;

                case Marlin.ViewMode.CURRENT:
                    return current_tab.view_mode;

                default:
                    break;
            }
            return (Marlin.ViewMode)(Preferences.settings.get_enum ("default-viewmode"));
        }

        public new GLib.SimpleActionGroup get_action_group () {
            return this.win_actions;
        }

        public void quit () {
            if (is_first_window) {
                save_geometries ();
                save_tabs ();
            }

            top_menu.destroy (); /* stop unwanted signals if quit while pathbar in focus */

            tabs.tab_removed.disconnect (on_tab_removed); /* Avoid infinite loop */

            foreach (var tab in tabs.tabs) {
                current_tab = null;
                (tab.page as Marlin.View.ViewContainer).close ();
            }

            this.destroy ();
        }

        private void save_geometries () {
            var sidebar_width = lside_pane.get_position ();
            var min_width = Preferences.settings.get_int ("minimum-sidebar-width");

            sidebar_width = int.max (sidebar_width, min_width);
            Preferences.settings.set_int ("sidebar-width", sidebar_width);

            int width, height, x, y;

            // Includes shadow for normal windows (but not maximized or tiled)
            get_size (out width, out height);
            get_position (out x, out y);

            var gdk_state = get_window ().get_state ();
            // If window is tiled, is it on left (start = true) or right (start = false)?
            var start = x + width < screen.get_width ();

            Preferences.settings.set_enum ("window-state",
                                           Marlin.WindowState.from_gdk_window_state (gdk_state, start));

            Preferences.settings.set_int ("window-width", width);
            Preferences.settings.set_int ("window-height", height);

            Preferences.settings.set_int ("window-x", x);
            Preferences.settings.set_int ("window-y", y);
        }

        private void save_tabs () {
            VariantBuilder vb = new VariantBuilder (new VariantType ("a(uss)"));

            foreach (var tab in tabs.tabs) {
                assert (tab != null);
                var view_container = tab.page as ViewContainer;

                /* Do not save if "File does not exist" or "Does not belong to you" */
                if (!view_container.can_show_folder) {
                    continue;
                }

                /* ViewContainer is responsible for returning valid uris */
                vb.add ("(uss)",
                        view_container.view_mode,
                        view_container.get_root_uri () ?? PF.UserUtils.get_real_user_home (),
                        view_container.get_tip_uri () ?? ""
                       );
            }

            Preferences.settings.set_value ("tab-info-list", vb.end ());
            Preferences.settings.set_int ("active-tab-position", tabs.get_tab_position (tabs.current));
        }

        public uint restore_tabs () {
            /* Do not restore tabs more than once */
            if (tabs_restored || !is_first_window) {
                return 0;
            } else {
                tabs_restored = true;
            }

            GLib.Variant tab_info_array = Preferences.settings.get_value ("tab-info-list");
            GLib.VariantIter iter = new GLib.VariantIter (tab_info_array);

            Marlin.ViewMode mode = Marlin.ViewMode.INVALID;
            string? root_uri = null;
            string? tip_uri = null;
            int tabs_added = 0;

            /* inhibit unnecessary changes of view and rendering of location bar while restoring tabs
             * as this causes all sorts of problems */
            restoring_tabs = true;

            while (iter.next ("(uss)", out mode, out root_uri, out tip_uri)) {

                if (mode < 0 || mode >= Marlin.ViewMode.INVALID ||
                    root_uri == null || root_uri == "" || tip_uri == null) {

                    continue;
                }

                /* We do not check valid location here because it may cause the interface to hang
                 * before the window appears (e.g. if trying to connect to a server that has become unavailable)
                 * Leave it to GOF.Directory.Async to deal with invalid locations asynchronously.
                 */

                add_tab_by_uri (root_uri, mode);

                if (mode == Marlin.ViewMode.MILLER_COLUMNS && tip_uri != root_uri) {
                    expand_miller_view (tip_uri, root_uri);
                }

                tabs_added++;
                mode = Marlin.ViewMode.INVALID;
                root_uri = null;
                tip_uri = null;

                /* Prevent too rapid loading of tabs which can cause crashes
                 * This may not be necessary with the Vala version of the views but does no harm
                 */
                Thread.usleep (100000);
            }

            restoring_tabs = false;

            /* Don't attempt to set active tab position if no tabs were restored */
            if (tabs_added < 1) {
                return 0;
            }

            int active_tab_position = Preferences.settings.get_int ("active-tab-position");

            if (active_tab_position < 0 || active_tab_position >= tabs_added) {
                active_tab_position = 0;
            }

            tabs.current = tabs.get_tab_by_index (active_tab_position);
            change_tab (active_tab_position);

            string path = "";
            if (current_tab != null) {
                path = current_tab.get_tip_uri ();

                if (path == null || path == "") {
                    path = current_tab.get_root_uri ();
                }
            }

            /* Render the final path in the location bar without animation */
            top_menu.update_location_bar (path, false);
            return tabs_added;
        }

        private void expand_miller_view (string tip_uri, string unescaped_root_uri) {
            /* It might be more elegant for Miller.vala to handle this */
            var tab = tabs.current;
            var view = tab.page as ViewContainer;
            var mwcols = view.view as Miller;
            var unescaped_tip_uri = PF.FileUtils.sanitize_path (tip_uri);

            if (unescaped_tip_uri == null) {
                warning ("Invalid tip uri for Miller View");
                return;
            }

            var tip_location = PF.FileUtils.get_file_for_path (unescaped_tip_uri);
            var root_location = PF.FileUtils.get_file_for_path (unescaped_root_uri);
            var relative_path = root_location.get_relative_path (tip_location);
            GLib.File gfile;

            if (relative_path != null) {
                string [] dirs = relative_path.split (GLib.Path.DIR_SEPARATOR_S);
                string uri = root_location.get_uri ();

                foreach (string dir in dirs) {
                    uri += (GLib.Path.DIR_SEPARATOR_S + dir);
                    gfile = get_file_from_uri (uri);

                    mwcols.add_location (gfile, mwcols.current_slot, false); /* Do not scroll at this stage */
                }
            } else {
                warning ("Invalid tip uri for Miller View %s", unescaped_tip_uri);
            }
        }

        private void update_top_menu () {
            if (restoring_tabs || current_tab == null) {
                return;
            }

            /* Update browser buttons */
            top_menu.set_back_menu (current_tab.get_go_back_path_list ());
            top_menu.set_forward_menu (current_tab.get_go_forward_path_list ());
            top_menu.can_go_back = current_tab.can_go_back;
            top_menu.can_go_forward = (current_tab.can_show_folder && current_tab.can_go_forward);
            top_menu.working = current_tab.is_loading;

            /* Update viewmode switch, action state and settings */
            var mode = current_tab.view_mode;
            view_switcher.mode = mode;
            view_switcher.sensitive = current_tab.can_show_folder;
            get_action ("view_mode").set_state (mode_strings [(int)mode]);
            Preferences.settings.set_enum ("default-viewmode", mode);
        }

        public void update_labels (string new_path, string tab_name) {
            assert (new_path != null && new_path != "");
            set_title (tab_name);
            top_menu.update_location_bar (new_path);
        }

        public void mount_removed (Mount mount) {
            debug ("Mount %s removed", mount.get_name ());
            GLib.File root = mount.get_root ();

            foreach (var page in tabs.get_children ()) {
                var view_container = page as Marlin.View.ViewContainer;
                GLib.File location = view_container.location;

                if (location == null || location.has_prefix (root) || location.equal (root)) {
                    if (view_container == current_tab) {
                        view_container.focus_location (File.new_for_path (PF.UserUtils.get_real_user_home ()));
                    } else {
                        remove_tab (view_container);
                    }
                }
            }
        }

        private void file_path_change_request (GLib.File loc, Marlin.OpenFlag flag = Marlin.OpenFlag.DEFAULT) {
            /* ViewContainer deals with non-existent or unmounted directories
             * and locations that are not directories */
            if (restoring_tabs) {
                return;
            }

            if (flag == Marlin.OpenFlag.DEFAULT) {
                grab_focus ();
                /* Focus_location will not unnecessarily load the current directory if location is
                 * normal file in the current directory, otherwise it will call user_path_change_request
                 */
                current_tab.focus_location (loc);
            } else {
                open_new_container (loc, flag);
            }
        }

        public void uri_path_change_request (string p, Marlin.OpenFlag flag = Marlin.OpenFlag.DEFAULT) {
            var file = get_file_from_uri (p);
            if (file != null) {
                /* Have to escape path and use File.new_for_uri () to correctly handle paths with certain characters such as "#" */
                file_path_change_request (file, flag);
            } else {
                warning ("Cannot browse %s", p);
            }
        }

        /** Use this function to standardise how locations are generated from uris **/
        private File? get_file_from_uri (string uri) {
            /* Sanitize path removes file:// scheme if present, but GOF.Directory.Async will replace it */
            string? current_uri = null;
            if (current_tab != null && current_tab.location != null) {
                current_uri = current_tab.location.get_uri ();
            }

            string path = PF.FileUtils.sanitize_path (uri, current_uri);
            if (path.length > 0) {
                return File.new_for_uri (PF.FileUtils.escape_uri (path));
            } else {
                return null;
            }
        }

        public new void grab_focus () {
            current_tab.grab_focus ();
        }

        private void set_accelerators () {
            application.set_accels_for_action ("win.quit", {"<Ctrl>Q"});
            application.set_accels_for_action ("win.new_window", {"<Ctrl>N"});
            application.set_accels_for_action ("win.undo", {"<Ctrl>Z"});
            application.set_accels_for_action ("win.redo", {"<Ctrl><Shift>Z"});
            application.set_accels_for_action ("win.bookmark", {"<Ctrl>D"});
            application.set_accels_for_action ("win.find", {"<Ctrl>F"});
            application.set_accels_for_action ("win.edit_path", {"<Ctrl>L"});
            application.set_accels_for_action ("win.tab::NEW", {"<Ctrl>T"});
            application.set_accels_for_action ("win.tab::CLOSE", {"<Ctrl>W"});
            application.set_accels_for_action ("win.tab::NEXT", {"<Ctrl>Page_Down", "<Ctrl>Tab"});
            application.set_accels_for_action ("win.tab::PREVIOUS", {"<Ctrl>Page_Up", "<Shift><Ctrl>Tab"});
            application.set_accels_for_action ("win.view_mode::ICON", {"<Ctrl>1"});
            application.set_accels_for_action ("win.view_mode::LIST", {"<Ctrl>2"});
            application.set_accels_for_action ("win.view_mode::MILLER", {"<Ctrl>3"});
            application.set_accels_for_action ("win.zoom::ZOOM_IN", {"<Ctrl>plus", "<Ctrl>equal"});
            application.set_accels_for_action ("win.zoom::ZOOM_OUT", {"<Ctrl>minus"});
            application.set_accels_for_action ("win.zoom::ZOOM_NORMAL", {"<Ctrl>0"});
            application.set_accels_for_action ("win.show_hidden", {"<Ctrl>H"});
            application.set_accels_for_action ("win.refresh", {"<Ctrl>R", "F5"});
            application.set_accels_for_action ("win.go_to::HOME", {"<Alt>Home"});
            application.set_accels_for_action ("win.go_to::TRASH", {"<Alt>T"});
            application.set_accels_for_action ("win.go_to::NETWORK", {"<Alt>N"});
            application.set_accels_for_action ("win.go_to::SERVER", {"<Alt>C"});
            application.set_accels_for_action ("win.go_to::UP", {"<Alt>Up"});
            application.set_accels_for_action ("win.go_to::FORWARD", {"<Alt>Right", "XF86Forward"});
            application.set_accels_for_action ("win.go_to::BACK", {"<Alt>Left", "XF86Back"});
            application.set_accels_for_action ("win.info::HELP", {"F1"});
        }
    }
}
