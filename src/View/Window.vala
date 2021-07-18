/*
* Copyright (c) 2010 Mathijs Henquet <mathijs.henquet@gmail.com>
*               2017-2020 elementary, Inc. <https://elementary.io>
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

namespace Files.View {

    public class Window : Hdy.ApplicationWindow {
        const GLib.ActionEntry [] WIN_ENTRIES = {
            {"new-window", action_new_window},
            {"quit", action_quit},
            {"refresh", action_reload},
            {"undo", action_undo},
            {"redo", action_redo},
            {"bookmark", action_bookmark},
            {"find", action_find, "s"},
            {"edit-path", action_edit_path},
            {"tab", action_tab, "s"},
            {"go-to", action_go_to, "s"},
            {"zoom", action_zoom, "s"},
            {"info", action_info, "s"},
            {"view-mode", action_view_mode, "u", "0" },
            {"show-hidden", null, null, "false", change_state_show_hidden},
            {"show-remote-thumbnails", null, null, "true", change_state_show_remote_thumbnails},
            {"hide-local-thumbnails", null, null, "false", change_state_hide_local_thumbnails}
        };

        public uint window_number { get; construct; }

        public bool is_first_window {
            get {
                return (window_number == 0);
            }
        }

        public Gtk.Builder ui;
        public Files.Application marlin_app { get; construct; }
        private unowned UndoManager undo_manager;
        public Chrome.HeaderBar top_menu;
        public Chrome.ViewSwitcher view_switcher;
        public Granite.Widgets.DynamicNotebook tabs;
        private Gtk.Paned lside_pane;
        public SidebarInterface sidebar;
        public ViewContainer? current_tab = null;

        private bool tabs_restored = false;
        private int restoring_tabs = 0;
        private bool doing_undo_redo = false;

        public signal void loading_uri (string location);
        public signal void folder_deleted (GLib.File location);
        public signal void free_space_change ();

        public Window (Files.Application application, Gdk.Screen myscreen = Gdk.Screen.get_default ()) {
            Object (
                application: application,
                marlin_app: application,
                height_request: 300,
                icon_name: "system-file-manager",
                screen: myscreen,
                title: _(APP_TITLE),
                width_request: 500,
                window_number: application.window_count
            );

            if (is_first_window) {
                set_accelerators ();
            }
        }

        static construct {
            Hdy.init ();
        }

        construct {
            add_action_entries (WIN_ENTRIES, this);

            undo_actions_set_insensitive ();

            undo_manager = UndoManager.instance ();

            build_window ();

            connect_signals ();

            int width, height;
            Files.app_settings.get ("window-size", "(ii)", out width, out height);

            default_width = width;
            default_height = height;

            if (is_first_window) {
                Files.app_settings.bind ("sidebar-width", lside_pane,
                                           "position", SettingsBindFlags.DEFAULT);

                var state = (Files.WindowState)(Files.app_settings.get_enum ("window-state"));

                switch (state) {
                    case Files.WindowState.MAXIMIZED:
                        maximize ();
                        break;
                    default:
                        int default_x, default_y;
                        Files.app_settings.get ("window-position", "(ii)", out default_x, out default_y);

                        if (default_x != -1 && default_y != -1) {
                            move (default_x, default_y);
                        }
                        break;
                }
            }

            loading_uri.connect (update_labels);
            present ();
        }

        private void build_window () {
            view_switcher = new Chrome.ViewSwitcher ((SimpleAction)lookup_action ("view-mode")) {
                selected = Files.app_settings.get_enum ("default-viewmode")
            };

            top_menu = new Chrome.HeaderBar (view_switcher) {
                show_close_button = true,
                custom_title = new Gtk.Label (null)
            };

            tabs = new Granite.Widgets.DynamicNotebook.with_accellabels (
                new Granite.AccelLabel (_("New Tab"), "<Ctrl>t"),
                new Granite.AccelLabel (_("Undo Close Tab"), "<Shift><Ctrl>t")
            ) {
                show_tabs = true,
                allow_restoring = true,
                allow_duplication = true,
                allow_new_window = true,
                group_name = Config.APP_NAME
            };

            this.configure_event.connect_after ((e) => {
                tabs.set_size_request (e.width / 2, -1);
                return false;
            });

            tabs.show ();

            sidebar = new Sidebar.SidebarWindow ();
            free_space_change.connect (sidebar.on_free_space_change);

            lside_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL) {
                expand = true,
                position = Files.app_settings.get_int ("sidebar-width")
            };
            lside_pane.pack1 (sidebar, false, false);
            lside_pane.pack2 (tabs, true, true);

            var grid = new Gtk.Grid ();
            grid.attach (top_menu, 0, 0);
            grid.attach (lside_pane, 0, 1);
            grid.show_all ();

            add (grid);

            /** Apply preferences */
            var prefs = Files.app_settings;
            get_action ("show-hidden").set_state (prefs.get_boolean ("show-hiddenfiles"));
            get_action ("show-remote-thumbnails").set_state (prefs.get_boolean ("show-remote-thumbnails"));
        }

        private void connect_signals () {
            /*/
            /* Connect and abstract signals to local ones
            /*/

            top_menu.forward.connect ((steps) => { current_tab.go_forward (steps); });
            top_menu.back.connect ((steps) => { current_tab.go_back (steps); });
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

            undo_manager.request_menu_update.connect (update_undo_actions);

            key_press_event.connect ((event) => {
                var mods = event.state & Gtk.accelerator_get_default_mod_mask ();
                bool no_mods = (mods == 0);
                bool shift_pressed = ((mods & Gdk.ModifierType.SHIFT_MASK) != 0);
                bool only_shift_pressed = shift_pressed && ((mods & ~Gdk.ModifierType.SHIFT_MASK) == 0);

                /* Use Tab to toggle View and Sidebar keyboard focus.  This works better than using a focus chain
                 * because cannot tab out of location bar and also unwanted items tend to get focused.
                 * There are other hotkeys for operating/focusing other widgets.
                 * Using modified Arrow keys no longer works due to recent changes.  */
                switch (event.keyval) {
                    case Gdk.Key.Tab:
                        if (top_menu.locked_focus) {
                            return false;
                        }

                        if (no_mods || only_shift_pressed) {
                            if (!sidebar.has_focus) {
                                sidebar.grab_focus ();
                            } else {
                                current_tab.grab_focus ();
                            }

                            return true;
                        }

                        break;
                }

                return false;
            });

            key_press_event.connect_after ((event) => {
                /* Use find function instead of view interactive search */
                if (event.state == 0 || event.state == Gdk.ModifierType.SHIFT_MASK) {
                    /* Use printable characters to initiate search */
                    var uc = ((unichar)(Gdk.keyval_to_unicode (event.keyval)));
                    if (uc.isprint ()) {
                        activate_action ("find", uc.to_string ());
                        return true;
                    }
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
                var view_container = (ViewContainer)(tab.page);
                tab.restore_data = view_container.location.get_uri ();

                /* If closing tab is current, set current_tab to null to ensure
                 * closed ViewContainer is destroyed. It will be reassigned in tab_changed
                 */
                if (view_container == current_tab) {
                    current_tab = null;
                }

                view_container.close ();

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

            tabs.tab_moved.connect ((tab) => {
                /* Called when tab dragged out of notebook */
                var vc = (ViewContainer)(tab.page) ;
                /* Close view now to disconnect signal handler closures which can trigger after slot destruction */
                vc.close ();

                marlin_app.create_window (vc.location, real_mode (vc.view_mode));

                /* remove_tab function uses Idle loop to close tab */
                remove_tab (tab);
            });


            tabs.tab_added.connect ((tab) => {
                var vc = (ViewContainer)(tab.page) ;
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
            sidebar.connect_server_request.connect (connect_to_server);
        }

        private void on_tab_removed () {
            if (tabs.n_tabs == 0) {
                add_tab ();
            }
        }

        public Files.AbstractSlot? get_active_slot () {
            if (current_tab != null) {
                return current_tab.get_current_slot ();
            } else {
                return null;
            }
        }

        public new void set_title (string title) {
            this.title = title;
        }

        private void change_tab (int offset) {
            ViewContainer? old_tab = current_tab;
            current_tab = (ViewContainer)((tabs.get_tab_by_index (offset)).page) ;
            if (current_tab == null || old_tab == current_tab) {
                return;
            }

            if (restoring_tabs > 0) {
                return;
            }

            if (old_tab != null) {
                old_tab.set_active_state (false);
                old_tab.is_frozen = false;
            }

            loading_uri (current_tab.uri);
            current_tab.set_active_state (true, false); /* changing tab should not cause animated scrolling */
            sidebar.sync_uri (current_tab.uri);
            top_menu.working = current_tab.is_frozen;
        }

        public void open_tabs (GLib.File[]? files = null,
                               ViewMode mode = ViewMode.PREFERRED,
                               bool ignore_duplicate = false) {

            if (files == null || files.length == 0 || files[0] == null) {
                /* Restore session if not root and settings allow */
                if (Files.is_admin () ||
                    !Files.app_settings.get_boolean ("restore-tabs") ||
                    restore_tabs () < 1) {

                    /* Open a tab pointing at the default location if no tabs restored*/
                    var location = GLib.File.new_for_path (PF.UserUtils.get_real_user_home ());
                    add_tab (location, mode);
                    /* Ensure default tab's slot is active so it can be focused */
                    current_tab = (ViewContainer)(tabs.current.page);
                    current_tab.set_active_state (true, false);
                }
            } else {
                /* Open tabs at each requested location */
                /* As files may be derived from commandline, we use a new sanitized one */
                foreach (var file in files) {
                    add_tab (get_file_from_uri (file.get_uri ()), mode, ignore_duplicate);
                }
            }
        }

        private void add_tab_by_uri (string uri, ViewMode mode = ViewMode.PREFERRED) {
            var file = get_file_from_uri (uri);
            if (file != null) {
                add_tab (file, mode);
            } else {
                add_tab ();
            }
        }

        private void add_tab (GLib.File _location = GLib.File.new_for_commandline_arg (Environment.get_home_dir ()),
                             ViewMode mode = ViewMode.PREFERRED,
                             bool ignore_duplicate = false) {

            GLib.File location;
            // For simplicity we do not use cancellable. If issues arise may need to do this.
            var ftype = _location.query_file_type (FileQueryInfoFlags.NONE, null);

            if (ftype == FileType.REGULAR) {
                location = _location.get_parent ();
            } else {
                location = _location.dup ();
            }

            if (ignore_duplicate) {
                bool is_child;
                var existing_tab_position = location_is_duplicate (location, out is_child);
                if (existing_tab_position >= 0) {
                    tabs.current = tabs.get_tab_by_index (existing_tab_position);
                    change_tab (existing_tab_position);

                    if (is_child) {
                        /* Select the child  */
                        ((ViewContainer)(tabs.current.page)).focus_location_if_in_current_directory (location);
                    }

                    return;
                }
            }

            mode = real_mode (mode);
            var content = new View.ViewContainer (this);
            var tab = new Granite.Widgets.Tab.with_accellabels (
                "",
                null,
                content,
                new Granite.AccelLabel (_("Close Tab"), "<Ctrl>w")
            ) {
                ellipsize_mode = Pango.EllipsizeMode.MIDDLE
            };

            change_tab ((int)tabs.insert_tab (tab, -1));
            tabs.current = tab;
            /* Capturing ViewContainer object reference in closure prevents its proper destruction
             * so capture its unique id instead */
            var id = content.id;
            content.tab_name_changed.connect ((tab_name) => {
                set_tab_label (check_for_tab_with_same_name (id, tab_name), tab, tab_name);
            });

            content.loading.connect ((is_loading) => {
                if (restoring_tabs > 0 && !is_loading) {
                    restoring_tabs--;
                    /* Each restored tab must signal with is_loading false once */
                    assert (restoring_tabs >= 0);
                    if (!content.can_show_folder) {
                        warning ("Cannot restore %s, ignoring", content.uri);
                        /* remove_tab function uses Idle loop to close tab */
                        remove_content (content);
                    }
                }

                tab.working = is_loading;
                update_top_menu ();
            });

            content.active.connect (() => {
                update_top_menu ();
            });

            if (!location.equal (_location)) {
                content.add_view (mode, location, {_location});
            } else {
                content.add_view (mode, location);
            }
        }

        private int location_is_duplicate (GLib.File location, out bool is_child) {
            is_child = false;
            string parent_path = "";
            string uri = location.get_uri ();
            bool is_folder = location.query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY;
            /* Ensures consistent format of protocol and path */
            parent_path = FileUtils.get_parent_path_from_path (location.get_path ());
            int existing_position = 0;

            foreach (Granite.Widgets.Tab tab in tabs.tabs) {
                var tab_location = ((ViewContainer)(tab.page)).location;
                string tab_uri = tab_location.get_uri ();

                if (FileUtils.same_location (uri, tab_uri)) {
                    return existing_position;
                } else if (!is_folder && FileUtils.same_location (location.get_parent ().get_uri (), tab_uri)) {
                    is_child = true;
                    return existing_position;
                }

                existing_position++;
            }

            return -1;
        }

        private string check_for_tab_with_same_name (int id, string path) {
            if (path == Files.INVALID_TAB_NAME) {
                 return path;
            }

            var new_label = Path.get_basename (path);
            foreach (Granite.Widgets.Tab tab in tabs.tabs) {
                var content = (ViewContainer)(tab.page);
                if (content.id != id) {
                    string content_path = content.tab_name;
                    string content_label = Path.get_basename (content_path);
                    if (tab.label == new_label) {
                        if (content_path != path) {
                            new_label = disambiguate_name (new_label, path, content_path); /*Relabel calling tab */
                            if (content_label == tab.label) {
                                /* Also relabel conflicting tab (but not before this function finishes) */
                                Idle.add_full (GLib.Priority.LOW, () => {
                                    var unique_name = disambiguate_name (content_label, content_path, path);
                                    set_tab_label (unique_name, tab, content_path);
                                    return GLib.Source.REMOVE;
                                });
                            }
                        }
                    } else if (content_label == new_label &&
                               content_path == path &&
                               content_label != tab.label) {

                        /* Revert to short label when possible */
                        Idle.add_full (GLib.Priority.LOW, () => {
                            set_tab_label (content_label, tab, content_path);
                            return GLib.Source.REMOVE;
                        });
                    }
                }
            }

            return new_label;
        }

        /* Just to append "as Administrator" when appropriate */
        private void set_tab_label (string label, Granite.Widgets.Tab tab, string? tooltip = null) {
            string lab = label;
            if (Files.is_admin ()) {
                lab += (" " + _("(as Administrator)"));
            }

            tab.label = lab;

            /* Needs change to Granite to allow (visible) tooltip amendment.
             * This compiles because tab is a widget but the tootip is overridden by that set internally */
            if (tooltip != null) {
                var tt = tooltip;
                if (Files.is_admin ()) {
                    tt += (" " + _("(as Administrator)"));
                }

                tab.set_tooltip_text (tt);
            }
        }

        private string disambiguate_name (string name, string path, string conflict_path) {
            string prefix = "";
            string prefix_conflict = "";
            string path_temp = path;
            string conflict_path_temp = conflict_path;

            /* Add parent directories until path and conflict path differ */
            while (prefix == prefix_conflict) {
                var parent_path= FileUtils.get_parent_path_from_path (path_temp);
                var parent_conflict_path = FileUtils.get_parent_path_from_path (conflict_path_temp);
                prefix = Path.get_basename (parent_path) + Path.DIR_SEPARATOR_S + prefix;
                prefix_conflict = Path.get_basename (parent_conflict_path) + Path.DIR_SEPARATOR_S + prefix_conflict;
                path_temp= parent_path;
                conflict_path_temp = parent_conflict_path;
            }

            return prefix + name;
        }

        public void bookmark_uri (string uri, string? name = null) {
            sidebar.add_favorite_uri (uri, name);
        }

        public bool can_bookmark_uri (string uri) {
            return !sidebar.has_favorite_uri (uri);
        }


        public void remove_content (ViewContainer view_container) {
            remove_tab (tabs.get_tab_by_widget ((Gtk.Widget)view_container));
        }

        private void remove_tab (Granite.Widgets.Tab? tab) {
            if (tab != null) {
                /* Use Idle in case of rapid closing of multiple tabs during restore */
                Idle.add_full (Priority.LOW, () => {
                    tab.close ();
                    return GLib.Source.REMOVE;
                });
            }
        }

        private void add_window (GLib.File location = GLib.File.new_for_path (PF.UserUtils.get_real_user_home ()),
                                 ViewMode mode = ViewMode.PREFERRED) {

            marlin_app.create_window (location, real_mode (mode));
        }

        private void undo_actions_set_insensitive () {
            GLib.SimpleAction action;
            action = get_action ("undo");
            action.set_enabled (false);
            action = get_action ("redo");
            action.set_enabled (false);
        }

        private void update_undo_actions () {
            GLib.SimpleAction action;
            action = get_action ("undo");
            action.set_enabled (undo_manager.can_undo ());
            action = get_action ("redo");
            action.set_enabled (undo_manager.can_redo ());
        }

        private void action_edit_path () {
            top_menu.enter_navigate_mode ();
        }

        private void action_bookmark (GLib.SimpleAction action, GLib.Variant? param) {
            /* Note: Duplicate bookmarks will not be created by BookmarkList */
            sidebar.add_favorite_uri (current_tab.location.get_uri ());
        }

        private void action_find (GLib.SimpleAction action, GLib.Variant? param) {
            /* Do not initiate search while slot is frozen e.g. during loading */
            if (current_tab == null || current_tab.is_frozen) {
                return;
            }

            if (param == null) {
                top_menu.enter_search_mode ();
            } else {
                top_menu.enter_search_mode (param.get_string ());
            }
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
                    return GLib.Source.REMOVE;
                });
            }
        }

        private void action_quit (GLib.SimpleAction action, GLib.Variant? param) {
            ((Files.Application)(application)).quit ();
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
            ViewMode mode = real_mode ((ViewMode)(param.get_uint32 ()));
            current_tab.change_view_mode (mode);
            /* ViewContainer takes care of changing appearance */
        }

        private void action_go_to (GLib.SimpleAction action, GLib.Variant? param) {
            switch (param.get_string ()) {
                case "RECENT":
                    uri_path_change_request (Files.RECENT_URI);
                    break;

                case "HOME":
                    uri_path_change_request ("file://" + PF.UserUtils.get_real_user_home ());
                    break;

                case "TRASH":
                    uri_path_change_request (Files.TRASH_URI);
                    break;

                case "ROOT":
                    uri_path_change_request (Files.ROOT_FS_URI);
                    break;

                case "NETWORK":
                    uri_path_change_request (Files.NETWORK_URI);
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
                    remove_tab (tabs.current);
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
            undo_manager.undo.begin (this, null, (obj, res) => {
                try {
                    undo_manager.undo.end (res);
                    after_undo_redo ();
                } catch (Error e) {
                    critical (e.message);
                }
            });
        }

        private void action_redo (GLib.SimpleAction action, GLib.Variant? param) {
            if (doing_undo_redo) { /* Guard against rapid pressing of Ctrl-Shift-Z */
                return;
            }
            before_undo_redo ();
            undo_manager.redo.begin (this, null, (obj, res) => {
                try {
                    undo_manager.redo.end (res);
                    after_undo_redo ();
                } catch (Error e) {
                    critical (e.message);
                }
            });
        }

        private void before_undo_redo () {
            doing_undo_redo = true;
            update_undo_actions ();
        }

        public void after_undo_redo () {
            if (current_tab.slot.directory.is_recent) {
                current_tab.reload ();
            }

            doing_undo_redo = false;
        }

        public void change_state_show_hidden (GLib.SimpleAction action) {
            bool state = !action.state.get_boolean ();
            action.set_state (new GLib.Variant.boolean (state));
            Files.app_settings.set_boolean ("show-hiddenfiles", state);
        }

        public void change_state_show_remote_thumbnails (GLib.SimpleAction action) {
            bool state = !action.state.get_boolean ();
            action.set_state (new GLib.Variant.boolean (state));
            Files.app_settings.set_boolean ("show-remote-thumbnails", state);
        }

        public void change_state_hide_local_thumbnails (GLib.SimpleAction action) {
            bool state = !action.state.get_boolean ();
            action.set_state (new GLib.Variant.boolean (state));
            Files.app_settings.set_boolean ("hide-local-thumbnails", state);
        }

        private void connect_to_server () {
            var dialog = new PF.ConnectServerDialog ((Gtk.Window) this);
            string server_uri = "";

            if (dialog.run () == Gtk.ResponseType.OK) {
                server_uri = dialog.server_uri;
            }

            dialog.destroy ();

            if (server_uri != "") {
                uri_path_change_request (dialog.server_uri, Files.OpenFlag.DEFAULT);
            }
        }

        void show_app_help () {
            AppInfo.launch_default_for_uri_async.begin (Files.HELP_URL, null, null, (obj, res) => {
                try {
                    AppInfo.launch_default_for_uri_async.end (res);
                } catch (Error e) {
                    warning ("Could not open help: %s", e.message);
                }
            });
        }

        private GLib.SimpleAction? get_action (string action_name) {
            return (GLib.SimpleAction?)(lookup_action (action_name));
        }

        private ViewMode real_mode (ViewMode mode) {
            switch (mode) {
                case ViewMode.ICON:
                case ViewMode.LIST:
                case ViewMode.MILLER_COLUMNS:
                    return mode;

                case ViewMode.CURRENT:
                    return current_tab.view_mode;

                default:
                    break;
            }

            return (ViewMode)(Files.app_settings.get_enum ("default-viewmode"));
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
                ((View.ViewContainer)(tab.page)).close ();
            }

            this.destroy ();
        }

        private void save_geometries () {
            var sidebar_width = lside_pane.get_position ();
            var min_width = Files.app_settings.get_int ("minimum-sidebar-width");

            sidebar_width = int.max (sidebar_width, min_width);
            Files.app_settings.set_int ("sidebar-width", sidebar_width);

            int width, height, x, y;

            // Includes shadow for normal windows (but not maximized or tiled)
            get_size (out width, out height);
            get_position (out x, out y);

            var gdk_state = get_window ().get_state ();
            // If window is tiled, is it on left (start = true) or right (start = false)?
            var rect = get_display ().get_monitor_at_point (x, y).get_geometry ();
            var start = x + width < rect.width;

            Files.app_settings.set_enum ("window-state",
                                           Files.WindowState.from_gdk_window_state (gdk_state, start));

            Files.app_settings.set ("window-size", "(ii)", width, height);
            Files.app_settings.set ("window-position", "(ii)", x, y);
        }

        private void save_tabs () {
            if (!Files.Preferences.get_default ().remember_history) {
                return;  /* Do not clear existing settings if history is off */
            }

            VariantBuilder vb = new VariantBuilder (new VariantType ("a(uss)"));
            foreach (var tab in tabs.tabs) {
                assert (tab != null);
                var view_container = (ViewContainer)(tab.page) ;

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

            Files.app_settings.set_value ("tab-info-list", vb.end ());
            Files.app_settings.set_int ("active-tab-position", tabs.get_tab_position (tabs.current));
        }

        public uint restore_tabs () {
            /* Do not restore tabs if history off nor more than once */
            if (!Files.Preferences.get_default ().remember_history || tabs_restored || !is_first_window) {
                return 0;
            } else {
                tabs_restored = true;
            }

            GLib.Variant tab_info_array = Files.app_settings.get_value ("tab-info-list");
            GLib.VariantIter iter = new GLib.VariantIter (tab_info_array);

            ViewMode mode = ViewMode.INVALID;
            string? root_uri = null;
            string? tip_uri = null;

            /* Changes of view and rendering of location bar are avoided while restoring tabs > 0
             * as this causes all sorts of problems */
            restoring_tabs = 0;

            while (iter.next ("(uss)", out mode, out root_uri, out tip_uri)) {

                if (mode < 0 || mode >= ViewMode.INVALID ||
                    root_uri == null || root_uri == "" || tip_uri == null) {

                    continue;
                }

                /* We do not check valid location here because it may cause the interface to hang
                 * before the window appears (e.g. if trying to connect to a server that has become unavailable)
                 * Leave it to Files.Directory.Async to deal with invalid locations asynchronously.
                 * Restored tabs with invalid locations are removed in the `loading` signal handler.
                 */

                restoring_tabs++;
                add_tab_by_uri (root_uri, mode);

                if (mode == ViewMode.MILLER_COLUMNS && tip_uri != root_uri) {
                    expand_miller_view (tip_uri, root_uri);
                }

                mode = ViewMode.INVALID;
                root_uri = null;
                tip_uri = null;

                /* As loading is now asynchronous we do not need a delay here any longer */
            }

            /* We assume that the following code is reached before restoring tabs have finished loading. Tests
             * show this to be the case. */

            /* Don't attempt to set active tab position if no tabs were restored.*/
            if (restoring_tabs < 1) {
                return 0;
            }

            int active_tab_position = Files.app_settings.get_int ("active-tab-position");
            if (active_tab_position < 0 || active_tab_position >= restoring_tabs) {
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
            return restoring_tabs;
        }

        private void expand_miller_view (string tip_uri, string unescaped_root_uri) {
            /* It might be more elegant for Miller.vala to handle this */
            var tab = tabs.current;
            var view = (ViewContainer)(tab.page) ;
            var mwcols = (Miller)(view.view) ;
            var unescaped_tip_uri = FileUtils.sanitize_path (tip_uri);

            if (unescaped_tip_uri == null) {
                warning ("Invalid tip uri for Miller View");
                return;
            }

            var tip_location = FileUtils.get_file_for_path (unescaped_tip_uri);
            var root_location = FileUtils.get_file_for_path (unescaped_root_uri);
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
            if (restoring_tabs > 0 || current_tab == null) {
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
            view_switcher.selected = mode;
            view_switcher.sensitive = current_tab.can_show_folder;
            get_action ("view-mode").change_state (new Variant.uint32 (mode));
            Files.app_settings.set_enum ("default-viewmode", mode);
        }

        private void update_labels (string uri) {
            if (current_tab != null) { /* Can happen during restore */
                set_title (current_tab.tab_name); /* Not actually visible on elementaryos */
                top_menu.update_location_bar (uri);
                sidebar.sync_uri (uri);
            }
        }

        public void mount_removed (Mount mount) {
            debug ("Mount %s removed", mount.get_name ());
            GLib.File root = mount.get_root ();

            foreach (var page in tabs.get_children ()) {
                var view_container = (View.ViewContainer)page ;
                GLib.File location = view_container.location;

                if (location == null || location.has_prefix (root) || location.equal (root)) {
                    if (view_container == current_tab) {
                        view_container.focus_location (GLib.File.new_for_path (PF.UserUtils.get_real_user_home ()));
                    } else {
                        remove_content (view_container);
                    }
                }
            }
        }

        public void uri_path_change_request (string p, Files.OpenFlag flag = Files.OpenFlag.DEFAULT) {
            /* Make a sanitized file from the uri */
            var file = get_file_from_uri (p);
            if (file != null) {
                switch (flag) {
                    case Files.OpenFlag.NEW_TAB:
                        add_tab (file, current_tab.view_mode);
                        break;
                    case Files.OpenFlag.NEW_WINDOW:
                        add_window (file, current_tab.view_mode);
                        break;
                    default:
                        grab_focus ();
                        current_tab.focus_location (file);
                        break;
                }
            } else {
                warning ("Cannot browse %s", p);
            }
        }

        /** Use this function to standardise how locations are generated from uris **/
        private GLib.File? get_file_from_uri (string uri) {
            string? current_uri = null;
            if (current_tab != null && current_tab.location != null) {
                current_uri = current_tab.location.get_uri ();
            }

            string path = FileUtils.sanitize_path (uri, current_uri);
            if (path.length > 0) {
                return GLib.File.new_for_uri (FileUtils.escape_uri (path));
            } else {
                return null;
            }
        }

        public new void grab_focus () {
            current_tab.grab_focus ();
        }

        private void set_accelerators () {
            marlin_app.set_accels_for_action ("win.quit", {"<Ctrl>Q"});
            application.set_accels_for_action ("win.new-window", {"<Ctrl>N"});
            application.set_accels_for_action ("win.undo", {"<Ctrl>Z"});
            application.set_accels_for_action ("win.redo", {"<Ctrl><Shift>Z"});
            application.set_accels_for_action ("win.bookmark", {"<Ctrl>D"});
            application.set_accels_for_action ("win.find::", {"<Ctrl>F"});
            application.set_accels_for_action ("win.edit-path", {"<Ctrl>L"});
            application.set_accels_for_action ("win.tab::NEW", {"<Ctrl>T"});
            application.set_accels_for_action ("win.tab::CLOSE", {"<Ctrl>W"});
            application.set_accels_for_action ("win.tab::NEXT", {"<Ctrl>Page_Down", "<Ctrl>Tab"});
            application.set_accels_for_action ("win.tab::PREVIOUS", {"<Ctrl>Page_Up", "<Shift><Ctrl>Tab"});
            application.set_accels_for_action (
                GLib.Action.print_detailed_name ("win.view-mode", new Variant.uint32 (0)), {"<Ctrl>1"}
            );
            application.set_accels_for_action (
                GLib.Action.print_detailed_name ("win.view-mode", new Variant.uint32 (1)), {"<Ctrl>2"}
            );
            application.set_accels_for_action (
                GLib.Action.print_detailed_name ("win.view-mode", new Variant.uint32 (2)), {"<Ctrl>3"}
            );
            application.set_accels_for_action ("win.zoom::ZOOM_IN", {"<Ctrl>plus", "<Ctrl>equal"});
            application.set_accels_for_action ("win.zoom::ZOOM_OUT", {"<Ctrl>minus"});
            application.set_accels_for_action ("win.zoom::ZOOM_NORMAL", {"<Ctrl>0"});
            application.set_accels_for_action ("win.show-hidden", {"<Ctrl>H"});
            application.set_accels_for_action ("win.refresh", {"<Ctrl>R", "F5"});
            application.set_accels_for_action ("win.go-to::HOME", {"<Alt>Home"});
            application.set_accels_for_action ("win.go-to::RECENT", {"<Alt>R"});
            application.set_accels_for_action ("win.go-to::TRASH", {"<Alt>T"});
            application.set_accels_for_action ("win.go-to::ROOT", {"<Alt>slash"});
            application.set_accels_for_action ("win.go-to::NETWORK", {"<Alt>N"});
            application.set_accels_for_action ("win.go-to::SERVER", {"<Alt>C"});
            application.set_accels_for_action ("win.go-to::UP", {"<Alt>Up"});
            application.set_accels_for_action ("win.go-to::FORWARD", {"<Alt>Right", "XF86Forward"});
            application.set_accels_for_action ("win.go-to::BACK", {"<Alt>Left", "XF86Back"});
            application.set_accels_for_action ("win.info::HELP", {"F1"});
        }
    }
}
