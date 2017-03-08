/***
    Window.vala

    Authors:
       Mathijs Henquet <mathijs.henquet@gmail.com>
       ammonkey <am.monkeyd@gmail.com>

    Copyright (c) 2010 Mathijs Henquet

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
***/

namespace Marlin.View {

    public class Window : Gtk.ApplicationWindow
    {
        const GLib.ActionEntry [] win_entries = {
            {"new_window", action_new_window},
            {"quit", action_quit},
            {"refresh", action_reload},
            {"undo", action_undo},
            {"redo", action_redo},
            {"bookmark", action_bookmark},
            {"find", action_find},
            {"tab", action_tab, "s"},
            {"go_to", action_go_to, "s"},
            {"zoom", action_zoom, "s"},
            {"info", action_info, "s"},
            {"view_mode", action_view_mode, "s", "'MILLER'"},
            {"select_all", null, null, "false", change_state_select_all},
            {"show_hidden", null, null, "false", change_state_show_hidden},
            {"show_remote_thumbnails", null, null, "false", change_state_show_remote_thumbnails},
            {"show_sidebar", null ,  null, "false", change_state_show_sidebar}
        };

        public GLib.SimpleActionGroup win_actions;

        const string [] mode_strings = {
            "ICON",
            "LIST",
            "MILLER"
        };

        public Gtk.Builder ui;
        private unowned UndoManager undo_manager;
        public Chrome.TopMenu top_menu;
        public Chrome.ViewSwitcher view_switcher;
        public Gtk.InfoBar info_bar;
        public Granite.Widgets.DynamicNotebook tabs;
        private Gtk.Paned lside_pane;
        public Marlin.Places.Sidebar sidebar;
        public ViewContainer? current_tab = null;
        public uint window_number;

        public bool is_first_window {get; private set;}
        private bool tabs_restored = false;
        private bool restoring_tabs = false;
        private bool doing_undo_redo = false;

        public signal void loading_uri (string location);
        public signal void folder_deleted (GLib.File location);
        public signal void free_space_change ();
        
        [Signal (action=true)]
        public virtual signal void go_back() {
            current_tab.go_back ();
        }

        [Signal (action=true)]
        public virtual signal void go_up () {
            current_tab.go_up ();
        }

        [Signal (action=true)]
        public virtual signal void edit_path () {
            action_edit_path ();
        }

        public Window (Marlin.Application app, Gdk.Screen myscreen, bool show_window = true) {

            /* Capture application window_count and active_window before they can change */
            window_number = app.window_count;
            application = app;
            screen = myscreen;
            is_first_window = (window_number == 0);

            construct_menu_actions ();
            undo_actions_set_insensitive ();

            undo_manager = Marlin.UndoManager.instance ();
            construct_top_menu ();
            set_titlebar (top_menu);
            construct_info_bar ();
            show_infobar (!is_marlin_mydefault_fm ());
            construct_notebook ();
            construct_sidebar ();
            build_window ();

            connect_signals ();
            make_bindings ();

            if (show_window) { /* otherwise Application will size and show window */
                if (Preferences.settings.get_boolean("maximized")) {
                    maximize();
                } else {
                    resize (Preferences.settings.get_int("window-width"),
                            Preferences.settings.get_int("window-height"));
                }
                show ();
            }
        }

        private void build_window () {
            lside_pane = new Gtk.Paned (Gtk.Orientation.HORIZONTAL);
            lside_pane.show ();
            /* Only show side bar in first window - (to be confirmed) */

            lside_pane.pack1 (sidebar, false, false);

            Gtk.Box window_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            window_box.show();
            window_box.pack_start(info_bar, false, false, 0);
            window_box.pack_start(tabs, true, true, 0);

            lside_pane.pack2 (window_box, true, false);

            add(lside_pane);

            set_size_request (500, 300);
            title = _(Marlin.APP_TITLE);
            icon_name = "system-file-manager";

        /** Apply preferences */
            get_action ("show_hidden").set_state (Preferences.settings.get_boolean ("show-hiddenfiles"));
            get_action ("show_remote_thumbnails").set_state (Preferences.settings.get_boolean ("show-remote-thumbnails"));

            var show_sidebar_pref = Preferences.settings.get_boolean ("show-sidebar");
            get_action ("show_sidebar").set_state (show_sidebar_pref);
            show_sidebar (true);

            if (is_first_window) {
                window_position = Gtk.WindowPosition.CENTER;
            } else { /* Allow new window created by tab dragging to be positioned where dropped */
                window_position = Gtk.WindowPosition.NONE;
            }
        }

        private void construct_sidebar () {
            sidebar = new Marlin.Places.Sidebar (this);
        }

        public void show_sidebar (bool show = true) {
            var show_sidebar = (get_action ("show_sidebar")).state.get_boolean ();
            if (show && show_sidebar) {
                lside_pane.position = Preferences.settings.get_int ("sidebar-width");
            } else {
                lside_pane.position = 0;
            }
        }

        private void construct_notebook () {
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
        }

        private void construct_menu_actions () {
            win_actions = new GLib.SimpleActionGroup ();
            win_actions.add_action_entries (win_entries, this);
            this.insert_action_group ("win", win_actions);

            if (is_first_window)
                set_accelerators ();
        }

        private void construct_top_menu () {
            view_switcher = new Chrome.ViewSwitcher (win_actions.lookup_action ("view_mode") as SimpleAction);
            view_switcher.mode = Preferences.settings.get_enum("default-viewmode");
            top_menu = new Chrome.TopMenu(view_switcher);
            top_menu.set_show_close_button (true);
            top_menu.set_custom_title (new Gtk.Label (null));
        }
                
        private void construct_info_bar () {
            info_bar = new Gtk.InfoBar ();

            var label = new Gtk.Label (_("Files isn't your default file manager."));
            label.set_line_wrap (true);

            var expander = new Gtk.Label ("");
            expander.hexpand = true;

            var make_default = new Gtk.Button.with_label (_("Set as Default"));
            make_default.clicked.connect (() => {
                make_marlin_default_fm (true);
                show_infobar (false);
            });

            var ignore = new Gtk.Button.with_label (_("Ignore"));
            ignore.clicked.connect (() => {
                make_marlin_default_fm (false);
                show_infobar (false);
            });

            var bbox = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            bbox.set_spacing (3);
            bbox.pack_start (make_default, true, true, 5);
            bbox.pack_start (ignore, true, true, 5);

            ((Gtk.Box)info_bar.get_content_area ()).add (label);
            ((Gtk.Box)info_bar.get_content_area ()).add (expander);
            ((Gtk.Box)info_bar.get_content_area ()).add (bbox);
        }

        private void connect_signals () {
            /*/
            /* Connect and abstract signals to local ones
            /*/

            top_menu.forward.connect (on_go_forward);
            top_menu.back.connect (on_go_back);
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
            button_press_event.connect (on_button_press_event);

            window_state_event.connect ((event) => {
                if ((bool) event.changed_mask & Gdk.WindowState.MAXIMIZED) {
                    Preferences.settings.set_boolean("maximized",
                                                     (bool) get_window().get_state() & Gdk.WindowState.MAXIMIZED);
                } else if ((bool) event.changed_mask & Gdk.WindowState.ICONIFIED) {
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
                if (view_container == current_tab)
                    current_tab = null;

               view_container.close ();

                if (tabs.n_tabs == 1)
                    add_tab ();

                return true;
            });

            tabs.tab_switched.connect ((old_tab, new_tab) => {
                change_tab (tabs.get_tab_position (new_tab));
            });

            tabs.tab_restored.connect ((label, restore_data, icon) => {
                add_tab (File.new_for_uri (restore_data));
            });

            tabs.tab_duplicated.connect ((tab) => {
                add_tab (File.new_for_uri (((tab.page as ViewContainer).uri)));
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

            sidebar.request_focus.connect (() => {
                return !current_tab.locked_focus && !top_menu.locked_focus;
            });

            sidebar.sync_needed.connect (() => {
                loading_uri (current_tab.uri);
            });
        }

        private void make_bindings () {
            if (is_first_window) {
                /*Preference bindings */
                Preferences.settings.bind ("show-sidebar", sidebar, "visible", SettingsBindFlags.GET);
                Preferences.settings.bind ("sidebar-width", lside_pane, "position", SettingsBindFlags.DEFAULT);

                /* keyboard shortcuts bindings */
                unowned Gtk.BindingSet binding_set = Gtk.BindingSet.by_class (get_class ());
                Gtk.BindingEntry.add_signal (binding_set, Gdk.keyval_from_name ("BackSpace"), 0, "go_back", 0);
                Gtk.BindingEntry.add_signal (binding_set, Gdk.keyval_from_name ("XF86Back"), 0, "go_back", 0);
                Gtk.BindingEntry.add_signal (binding_set, Gdk.keyval_from_name ("XF86Forward"), 0, "go_forward", 0);
                Gtk.BindingEntry.add_signal (binding_set, Gdk.keyval_from_name ("L"), Gdk.ModifierType.CONTROL_MASK, "edit_path", 0);
            }
        }

        private bool on_button_press_event (Gdk.EventButton event) {
            Gdk.ModifierType mods = event.state & Gtk.accelerator_get_default_mod_mask ();
            bool result = false;
            switch (event.button) {
                /* Extra mouse button actions */
                case 6:
                case 8:
                    if (mods == 0) {
                        result = true;
                        on_go_back ();
                    }
                    break;

                case 7:
                case 9:
                    if (mods == 0) {
                        result = true;
                        on_go_forward ();
                    }
                    break;

                default:
                    break;
            }
            return result;
        }

        private void on_go_forward (int n = 1) {
            current_tab.go_forward (n);
        }
        private void on_go_back (int n = 1) {
            current_tab.go_back (n);
        }

        public void new_container_request (GLib.File loc, Marlin.OpenFlag flag) {
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

        private void show_infobar (bool val) {
            if (val)
                info_bar.show_all ();
            else
                info_bar.hide ();
        }

        public GOF.AbstractSlot? get_active_slot() {
            if (current_tab != null)
                return current_tab.get_current_slot ();
            else
                return null;
        }

        public new void set_title(string title){
            this.title = title;
        }

        public void change_tab (int offset) {
            if (restoring_tabs) {
                return;
            }

            ViewContainer? old_tab = current_tab;
            current_tab = (tabs.get_tab_by_index (offset)).page as ViewContainer;

            if (current_tab == null || old_tab == current_tab)
                return;

            if (old_tab != null) {
                old_tab.set_active_state (false);
            }
            /* ViewContainer will update topmenu once successfully loaded */
#if 0
            /* sync selection - to be reimplemented if needed*/
            if (cur_slot.dir_view != null && current_tab.can_show_folder);
                cur_slot.dir_view.sync_selection();
#endif
            /* sync sidebar selection */
            loading_uri (current_tab.uri);
            current_tab.set_active_state (true, false); /* changing tab should not cause animated scrolling */
            top_menu.working = current_tab.is_frozen;
        }

        public void add_tab (File location = File.new_for_commandline_arg (Environment.get_home_dir ()),
                             Marlin.ViewMode mode = Marlin.ViewMode.PREFERRED) {
            mode = real_mode (mode);

            var content = new View.ViewContainer (this);
            var tab = new Granite.Widgets.Tab ("", null, content);

            content.tab_name_changed.connect ((tab_name) => {
                tab.label = tab_name;
            });

            content.loading.connect ((is_loading) => {
                tab.working = is_loading;
                update_top_menu ();
            });

            content.active.connect (() => {
                update_top_menu ();
            });

            content.update_tab_name (location);
            content.add_view (mode, location);

            change_tab ((int)tabs.insert_tab (tab, -1));
            tabs.current = tab;
        }

        public void bookmark_uri (string uri, string? name = null) {
            sidebar.add_uri (uri, name);
        }

        public bool can_bookmark_uri (string uri) {
            return !sidebar.has_place (uri);
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

        public void add_window (File location = File.new_for_path (Environment.get_home_dir ()),
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
                    uri_path_change_request ("file://" + Environment.get_home_dir());
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

                case "ABOUT":
                    show_about ();
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
            if (window.current_tab.slot.directory.is_recent)
                window.current_tab.reload ();

            window.doing_undo_redo = false;
        }

        private void change_state_select_all (GLib.SimpleAction action) {
            var slot = get_active_slot ();
            if (slot != null) {
                bool state = !action.state.get_boolean ();

                if (slot.set_all_selected (state))
                    action.set_state (new GLib.Variant.boolean (state));
            }
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

        private void change_state_show_sidebar (GLib.SimpleAction action) {
            bool state = !action.state.get_boolean ();
            action.set_state (new GLib.Variant.boolean (state));
            if (!state) {
                Preferences.settings.set_int ("sidebar-width", lside_pane.position);
            }
            show_sidebar (state);
        }

        private void connect_to_server () {
            var dialog = new Marlin.ConnectServer.Dialog ((Gtk.Window) this);
            dialog.show ();
        }

        protected void show_about() {
            Granite.Widgets.show_about_dialog ((Gtk.Window) this,
                "program-name", _(Marlin.APP_TITLE),
                "version", Config.VERSION,
                "copyright", Marlin.COPYRIGHT,
                "license-type", Gtk.License.GPL_3_0,
                "website", Marlin.LAUNCHPAD_URL,
                "website-label",  Marlin.LAUNCHPAD_LABEL,
                "authors", Marlin.AUTHORS,
                "artists", Marlin.ARTISTS,
                "logo-icon-name", Marlin.ICON_APP_LOGO,
                "translator-credits",  Marlin.TRANSLATORS,
                "help", Marlin.HELP_URL,
                "translate", Marlin.TRANSLATE_URL,
                "bug", Marlin.BUG_URL
            );
        }

        void show_app_help() {
            try { Gtk.show_uri (screen, Marlin.HELP_URL, -1); }
            catch (Error e) { critical("Can't open the link"); }
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

        private bool is_marlin_mydefault_fm () {
            bool foldertype_is_default = (Marlin.APP_DESKTOP == AppInfo.get_default_for_type("inode/directory", false).get_id());

            bool trash_uri_is_default = false;
            AppInfo? app_trash_handler = AppInfo.get_default_for_type("x-scheme-handler/trash", true);
            if (app_trash_handler != null)
                trash_uri_is_default = (Marlin.APP_DESKTOP == app_trash_handler.get_id());

            return foldertype_is_default && trash_uri_is_default;
        }

        private void make_marlin_default_fm (bool active) {
            if (active) {
                AppInfo marlin_app = (AppInfo) new DesktopAppInfo (Marlin.APP_DESKTOP);

                if (marlin_app != null) {
                    try {
                        marlin_app.set_as_default_for_type ("inode/directory");
                        marlin_app.set_as_default_for_type ("x-scheme-handler/trash");
                    } catch (GLib.Error e) {
                        critical ("Can't set Marlin default FM: %s", e.message);
                    }
                } else
                    critical ("Failed to make Pantheon Files App Info");
            } else {
                AppInfo.reset_type_associations ("inode/directory");
                AppInfo.reset_type_associations ("x-scheme-handler/trash");
            }
        }

        public void quit () {
            top_menu.destroy (); /* stop unwanted signals if quit while pathbar in focus */

            if (is_first_window) {
                save_geometries ();
                save_tabs ();
            }

            foreach (var tab in tabs.tabs) {
                current_tab = null;
                (tab.page as Marlin.View.ViewContainer).close ();
            }

            this.destroy ();
        }

        private void save_geometries () {
            save_sidebar_width ();

            bool is_maximized = (bool) get_window().get_state() & Gdk.WindowState.MAXIMIZED;

            if (is_maximized == false) {
                int width, height;
                get_size(out width, out height);
                Preferences.settings.set_int("window-width", width);
                Preferences.settings.set_int("window-height", height);
            }

            Preferences.settings.set_boolean("maximized", is_maximized);
        }

        private void save_sidebar_width () {
            var sw = lside_pane.get_position ();
            var mw = Preferences.settings.get_int("minimum-sidebar-width");

            sw = int.max (sw, mw);
            Preferences.settings.set_int("sidebar-width", sw);
        }

        private void save_tabs () {
            VariantBuilder vb = new VariantBuilder (new VariantType ("a(uss)"));

            foreach (var tab in tabs.tabs) {
                assert (tab != null);
                var view_container = tab.page as ViewContainer;

                /* Do not save if "File does not exist" or "Does not belong to you" */
                if (!view_container.can_show_folder)
                    continue;

                /* ViewContainer is responsible for returning valid uris */
                vb.add ("(uss)",
                        view_container.view_mode,
                        view_container.get_root_uri () ?? Environment.get_home_dir (),
                        view_container.get_tip_uri () ?? ""
                       );
            }

            Preferences.settings.set_value ("tab-info-list", vb.end ());
            Preferences.settings.set_int ("active-tab-position", tabs.get_tab_position (tabs.current));
        }

        public uint restore_tabs () {
            /* Do not restore tabs more than once */
            if (tabs_restored || !is_first_window)
                return 0;
            else
                tabs_restored = true;

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
                if (mode < 0 || mode >= Marlin.ViewMode.INVALID || root_uri == null || root_uri == "" || tip_uri == null)
                    continue;

                string? unescaped_root_uri = PF.FileUtils.sanitize_path (root_uri);

                if (unescaped_root_uri == null) {
                    warning ("Invalid root location for tab");
                    continue;
                }

                GLib.File root_location = GLib.File.new_for_commandline_arg (unescaped_root_uri);

                /* We do not check valid location here because it may cause the interface to hang
                 * before the window appears (e.g. if trying to connect to a server that has become unavailable)
                 * Leave it to GOF.Directory.Async to deal with invalid locations asynchronously. 
                 */

                add_tab (root_location, mode);

                if (mode == Marlin.ViewMode.MILLER_COLUMNS && tip_uri != root_uri)
                    expand_miller_view (tip_uri, root_location);

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
            if (tabs_added < 1)
                return 0;

            int active_tab_position = Preferences.settings.get_int ("active-tab-position");

            if (active_tab_position < 0 || active_tab_position >= tabs_added)
                active_tab_position = 0;

            tabs.current = tabs.get_tab_by_index (active_tab_position);
            change_tab (active_tab_position);

            string path = "";
            if (current_tab != null) {
                path = current_tab.get_tip_uri ();

                if (path == null || path == "")
                    path = current_tab.get_root_uri ();
            }

            /* Render the final path in the location bar without animation */
            top_menu.update_location_bar (path, false);
            return tabs_added;
        }

        private void expand_miller_view (string tip_uri, GLib.File root_location) {
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
            var relative_path = root_location.get_relative_path (tip_location);
            GLib.File gfile;

            if (relative_path != null) {
                string [] dirs = relative_path.split (GLib.Path.DIR_SEPARATOR_S);
                string uri = root_location.get_uri ();

                foreach (string dir in dirs) {
                    uri += (GLib.Path.DIR_SEPARATOR_S + dir);
                    gfile = PF.FileUtils.get_file_for_path (uri);

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
                    if (view_container == current_tab)
                        view_container.focus_location (File.new_for_path (Environment.get_home_dir ()));
                    else
                        remove_tab (view_container);
                }
            }
        }

        public void file_path_change_request (GLib.File loc, Marlin.OpenFlag flag = Marlin.OpenFlag.DEFAULT) {
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
                new_container_request (loc, flag);
            }
        }

        public void uri_path_change_request (string p, Marlin.OpenFlag flag = Marlin.OpenFlag.DEFAULT) {
            string path = PF.FileUtils.sanitize_path (p, current_tab.location.get_path ());
            if (path.length > 0) {
                file_path_change_request (File.new_for_commandline_arg (path), flag);
            } else {
                warning ("Cannot browse %s", p);
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
            application.set_accels_for_action ("win.select_all", {"<Ctrl>A"});
            application.set_accels_for_action ("win.bookmark", {"<Ctrl>D"});
            application.set_accels_for_action ("win.find", {"<Ctrl>F"});
            application.set_accels_for_action ("win.tab::NEW", {"<Ctrl>T"});
            application.set_accels_for_action ("win.tab::CLOSE", {"<Ctrl>W"});
            application.set_accels_for_action ("win.tab::NEXT", {"<Ctrl>Page_Down"});
            application.set_accels_for_action ("win.tab::PREVIOUS", {"<Ctrl>Page_Up"});
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
            application.set_accels_for_action ("win.go_to::FORWARD", {"<Alt>Right"});
            application.set_accels_for_action ("win.go_to::BACK", {"<Alt>Left"});
            application.set_accels_for_action ("win.info::HELP", {"F1"});
            application.set_accels_for_action ("win.info::ABOUT", {"F3"});
        }
    }
}
