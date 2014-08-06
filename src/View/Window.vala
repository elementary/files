//
//  Window.vala
//
//  Authors:
//       Mathijs Henquet <mathijs.henquet@gmail.com>
//       ammonkey <am.monkeyd@gmail.com>
//
//  Copyright (c) 2010 Mathijs Henquet
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.

namespace Marlin.View {

    public class Window : Gtk.ApplicationWindow
    {

        static const GLib.ActionEntry [] win_entries = {
            {"refresh", action_reload},
            {"undo", action_undo},
            {"redo", action_redo},
            {"tab", action_tab, "s"},
            {"go_to", action_go_to, "s"},
            {"zoom", action_zoom, "s"},
            {"help", action_help, "s"},
            {"view_mode", action_view_mode, "s", "'MILLER'"},
            {"select_all", null, null, "false", change_state_select_all},
            {"show_hidden", null, null, "false", change_state_show_hidden},
            {"show_sidebar", null ,  null, "false", change_state_show_sidebar}
        };

        public GLib.SimpleActionGroup win_actions;

        static const string [] mode_strings = {
            "ICON",
            "LIST",
            "MILLER"
        };

        public Gtk.Builder ui;
        private UndoManager undo_manager;
        public GLib.Menu menu_bar;
        public Chrome.TopMenu top_menu;
        public Gtk.InfoBar info_bar;
        public Granite.Widgets.DynamicNotebook tabs;
        public Marlin.Places.Sidebar sidebar;

        public ViewContainer? current_tab = null;

        public Chrome.ButtonWithMenu button_forward;
        public Chrome.ButtonWithMenu button_back;

        public bool can_go_up = false;

        public bool can_go_forward{
            set{
                button_forward.set_sensitive (value);
            }
        }

        public bool can_go_back{
            set{
                button_back.set_sensitive (value);
            }
        }

        public bool is_first_window {get; private set;}
        private bool tabs_restored = false;

        public signal void item_hovered (GOF.File? gof_file);
        public signal void selection_changed (GLib.List<GOF.File> gof_file); //OverlayBar connects

        public signal void loading_uri (string location);

        public bool freeze_view_changes = false;
        private const int MARLIN_LEFT_OFFSET = 16;
        private const int MARLIN_TOP_OFFSET = 9;
        private const int MARLIN_MINIMUM_WINDOW_WIDTH = 640;
        private const int MARLIN_MINIMUM_WINDOW_HEIGHT = 480;

        [Signal (action=true)]
        public virtual signal void go_up () {
            current_tab.up ();
        }

        [Signal (action=true)]
        public virtual signal void edit_path () {
            action_edit_path ();
        }

        public Window (Marlin.Application app, Gdk.Screen myscreen) {
            /* Capture application window_count and active_window before they can change */
            var window_number = app.window_count;
            var active_window = app.get_active_window ();
//message ("New window");
            application = app;
            screen = myscreen;
            is_first_window = (window_number == 0);

            construct_menu_actions ();
            undo_manager = Marlin.UndoManager.instance ();
            undo_actions_set_insensitive ();
            construct_top_menu ();
            set_titlebar (top_menu);
            construct_info_bar ();
            show_infobar (!is_marlin_mydefault_fm ());
            construct_notebook ();
            construct_sidebar ();
            build_window ();
            connect_signals ();
            make_bindings ();
            set_geometry (window_number, active_window);
            show ();
        }

        private void set_geometry (int window_number, Gtk.Window? active_window) {
//message ("set geometry, window number is %i", window_number);

            /* Position first window according to preferences and
             * offset subsequent windows to ensure visibility */
            string geometry = "";
            int left_offset = 0, top_offset = 0;

            if (active_window == null || window_number == 0) {
//message ("first window");
                geometry = Preferences.settings.get_string("geometry");
                if (geometry == "")
                    geometry = (Preferences.settings.get_default_value("geometry")).get_string ();

            } else {
//message ("not first window");
                geometry = EelGtk.Window.get_geometry_string (active_window);
                left_offset = MARLIN_LEFT_OFFSET;
                top_offset = MARLIN_TOP_OFFSET;
            }
//message ("got geometry %s", geometry);
            EelGtk.Window.set_initial_geometry_from_string (this, geometry,
                                                            MARLIN_MINIMUM_WINDOW_WIDTH,
                                                            MARLIN_MINIMUM_WINDOW_HEIGHT,
                                                            false,
                                                            left_offset, top_offset);
        }

        private void build_window () {
//message ("build window");
            var lside_pane = new Granite.Widgets.ThinPaned ();
            lside_pane.show ();
            lside_pane.pack1 (sidebar, false, false);
            lside_pane.pack2 (tabs, true, false);

            Gtk.Box window_box = new Gtk.Box(Gtk.Orientation.VERTICAL, 0);
            window_box.show();
            window_box.pack_start(info_bar, false, false, 0);
            window_box.pack_start(lside_pane, true, true, 0);

            add(window_box);

            title = Marlin.APP_TITLE;
            try {
                this.icon = Gtk.IconTheme.get_default ().load_icon ("system-file-manager", 32, 0);
            } catch (Error err) {
                stderr.printf ("Unable to load marlin icon: %s\n", err.message);
            }

        /** Apply preferences */
            lside_pane.position = Preferences.settings.get_int ("sidebar-width");
            get_action ("show_sidebar").set_state (Preferences.settings.get_boolean ("show-sidebar"));
            get_action ("show_hidden").set_state (Preferences.settings.get_boolean ("show-hiddenfiles"));

            if (Preferences.settings.get_boolean("maximized"))
                maximize();
        }

        private void construct_sidebar () {
//message ("construct sidebar");
            sidebar = new Marlin.Places.Sidebar (this);
            sidebar.show ();
        }

        private void construct_notebook () {
            tabs = new Granite.Widgets.DynamicNotebook ();
            tabs.show_tabs = true;
            tabs.allow_restoring = true;
            tabs.allow_duplication = true;
            this.configure_event.connect ((e) => {
                tabs.set_size_request (e.width / 2, -1);
                return false;
            });

            tabs.show ();
        }

        private void construct_menu_actions () {
//message ("construct menu actions");
            win_actions = new GLib.SimpleActionGroup ();
            win_actions.add_action_entries (win_entries, this);
            this.insert_action_group ("win", win_actions);
            if (is_first_window) {
        //message ("Menubar");
                var builder = new Gtk.Builder.from_file (Config.UI_DIR + "winmenu.ui");
        //message ("got builder");
                application.set_menubar (builder.get_object ("winmenu") as GLib.MenuModel);
        //message ("menubar set");
            }
        }

        private void construct_top_menu () {
//message ("construct top menu");
            button_back = new Marlin.View.Chrome.ButtonWithMenu.from_icon_name ("go-previous", Gtk.IconSize.LARGE_TOOLBAR);
            button_forward = new Marlin.View.Chrome.ButtonWithMenu.from_icon_name ("go-next", Gtk.IconSize.LARGE_TOOLBAR);
            top_menu = new Chrome.TopMenu(this);
            top_menu.set_show_close_button (true);
            top_menu.set_custom_title (new Gtk.Label (null));
        }

        private void construct_info_bar () {
//message ("construct info bar");
            info_bar = new Gtk.InfoBar ();

            var label = new Gtk.Label (_("Files isn't your default file manager."));
            label.set_line_wrap (true);

            var expander = new Gtk.Label ("");
            expander.hexpand = true;

            var make_default = new Gtk.Button.with_label (_("Set as default"));
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
//message ("connect signals");
            /*/
            /* Connect and abstract signals to local ones
            /*/

            button_forward.slow_press.connect (() => {
                current_tab.forward ();
            });

            button_back.slow_press.connect (() => {
                current_tab.back ();
            });

            undo_manager.request_menu_update.connect (undo_redo_menu_update_callback);

//message ("Connect key press event");
            key_press_event.connect ((event) => {
                if (top_menu.location_bar.bread.is_focus)
                    return top_menu.location_bar.bread.key_press_event (event);

                return false;
            });

//message ("Connect button press event");
            var go_to_action = get_action ("go_to");
            button_press_event.connect ((event) => {
                /* Extra mouse button action: button8 = "Back" button9 = "Forward" */
                if (event.button == 8) {
                    go_to_action.activate (new GLib.Variant.string ("BACK"));
                    return true;
                } else if (event.button == 9) {
                    go_to_action.activate (new GLib.Variant.string ("FORWARD"));
                    return true;
                } else
                    return false;
            });

//message ("Connect window state event");
            window_state_event.connect ((event) => {
                if ((bool) event.changed_mask & Gdk.WindowState.MAXIMIZED) {
                    Preferences.settings.set_boolean("maximized",
                                                     (bool) get_window().get_state() & Gdk.WindowState.MAXIMIZED);
                }
                return false;
            });

            delete_event.connect (() => {
                quit ();
                return false;
            });

            tabs.new_tab_requested.connect (() => {
                make_new_tab ();
            });

            tabs.close_tab_requested.connect ((tab) => {
                tab.restore_data =
                    (tab.page as ViewContainer).slot.location.get_uri ();

                if (tabs.n_tabs == 1)
                    make_new_tab ();

                return true;
            });

            tabs.tab_switched.connect ((old_tab, new_tab) => {
                change_tab (tabs.get_tab_position (new_tab));
            });

            tabs.tab_restored.connect ((label, restore_data, icon) => {
                make_new_tab (File.new_for_uri (restore_data));
            });

            tabs.tab_duplicated.connect ((tab) => {
                make_new_tab (File.new_for_uri (((tab.page as ViewContainer).get_current_slot ()).location.get_uri ()));
            });

        }

        private void make_bindings () {
//message ("make bindings");
            /*Preference bindings */
            Preferences.settings.bind("sidebar-zoom-level", sidebar, "zoom-level", SettingsBindFlags.SET);
            Preferences.settings.bind("show-sidebar", sidebar, "visible", SettingsBindFlags.DEFAULT);

//message ("keyboard shortcut binding");
            /* keyboard shortcuts bindings */
            if (is_first_window) {
                unowned Gtk.BindingSet binding_set = Gtk.BindingSet.by_class (get_class ());
                Gtk.BindingEntry.add_signal (binding_set, Gdk.keyval_from_name ("BackSpace"), 0, "go_up", 0);
                Gtk.BindingEntry.add_signal (binding_set, Gdk.keyval_from_name ("L"), Gdk.ModifierType.CONTROL_MASK, "edit_path", 0);
            }
        }

        private void show_infobar (bool val) {
//message ("show infobar is %s", val ? "true" : "false");
            if (val) {
//message ("show");
                info_bar.show_all ();
            } else {
//message ("hide");
                info_bar.hide ();
            }
        }

        public Slot? get_active_slot() {
            if (current_tab != null)
                return current_tab.get_current_slot ();
            return null;
        }

        public new void set_title(string title){
            this.title = title;
        }

        public void change_tab (int offset) {
            ViewContainer? old_tab = current_tab;
            current_tab = (tabs.get_tab_by_index (offset)).page as ViewContainer;
            if (current_tab == null || old_tab == current_tab)
                return;

            if (old_tab != null) {
                var old_slot = old_tab.get_current_slot ();
                if (old_slot != null) {
                    old_slot.inactive ();
//message ("Window:emitting slot inactive");
}
            }

            if (current_tab != null) {
                var cur_slot = current_tab.get_current_slot ();
                if (cur_slot != null) {
                    cur_slot.active();
                    current_tab.update_location_state(false);
                    /* update radio action view state */
                    update_view_mode (current_tab.view_mode);
                    /* sync selection */
                    if (cur_slot.view_box != null && !current_tab.content_shown)
                        ((FM.DirectoryView) cur_slot.view_box).sync_selection();
                    /* sync sidebar selection */
                    loading_uri (current_tab.slot.directory.file.uri);
                }
            }
        }

        private void make_new_tab (File location = File.new_for_commandline_arg (Environment.get_home_dir ()),
                                   Marlin.ViewMode mode = Marlin.ViewMode.PREFERRED) {
            mode = real_mode (mode);
            update_view_mode (mode);
            var content = new View.ViewContainer (this, mode);
            var tab = new Granite.Widgets.Tab ("", null, content);
            content.tab_name_changed.connect ((tab_name) => {
                tab.label = tab_name;
            });
            content.path_changed (location);
            change_tab ((int)tabs.insert_tab (tab, -1));
            tabs.current = tab;
        }

        public void add_tab (File location, Marlin.ViewMode mode) {
            make_new_tab (location, mode);
            /* The following fixes a bug where upon first opening
               Files, the overlay status bar is shown empty. */
            if (tabs.n_tabs == 1) {
                var tab = tabs.get_tab_by_index (0);
                if (tab != null)
                    (tab.page as ViewContainer).overlay_statusbar.update ();
            }
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

        public void add_window(File location, Marlin.ViewMode mode){
            ((Marlin.Application) application).create_window (location, screen, real_mode (mode));
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
            top_menu.location_bar.bread.grab_focus ();
        }

        private uint reload_timeout_id = 0;
        private void action_reload (GLib.SimpleAction action, GLib.Variant? param) {
            /* avoid spawning reload when key kept pressed */
            if (reload_timeout_id == 0)
                reload_timeout_id = Timeout.add (90, () => {
                    current_tab.reload ();
                    reload_timeout_id = 0;
                    return false;
                });
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
            update_view_mode (mode);
        }

        private void action_go_to (GLib.SimpleAction action, GLib.Variant? param) {
//message ("action go to");
            switch (param.get_string ()) {
                case "HOME":
                    current_tab.path_changed(File.new_for_commandline_arg(Environment.get_home_dir()));
                    break;

                case "TRASH":
                    current_tab.path_changed(File.new_for_commandline_arg(Marlin.TRASH_URI));
                    break;

                case "NETWORK":
                    current_tab.path_changed(File.new_for_commandline_arg(Marlin.NETWORK_URI));
                    break;

                case "SERVER":
                    connect_to_server ();
                    break;

                case "UP":
                    current_tab.up ();
                    break;

                case "FORWARD":
                    current_tab.forward ();
                    break;

                case "BACK":
                    current_tab.back ();
                    break;

                default:
                    break;
            }
        }

        private void action_zoom (GLib.SimpleAction action, GLib.Variant? param) {
//message ("action zoom");
            if (current_tab != null && current_tab.slot != null) {
//message ("tab and slot not null");
                switch (param.get_string ()) {
                    case "ZOOM_IN":
                        ((FM.DirectoryView) current_tab.slot.view_box).zoom_in ();
                        break;

                    case "ZOOM_OUT":
                        ((FM.DirectoryView) current_tab.slot.view_box).zoom_out ();
                        break;

                    case "ZOOM_NORMAL":
                        ((FM.DirectoryView) current_tab.slot.view_box).zoom_normal ();
                        break;

                    default:
                        break;
                }
            }
        }

        private void action_tab (GLib.SimpleAction action, GLib.Variant? param) {
//message ("action tab");
            switch (param.get_string ()) {
                case "NEW":
                    make_new_tab ();
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

        private void action_help (GLib.SimpleAction action, GLib.Variant? param) {
//message ("action tab");
            switch (param.get_string ()) {
                case "HELP":
                    show_app_help ();
                    break;

                case "TRANSLATE":
                    show_translate ();
                    break;

                case "PROBLEM":
                    show_report ();
                    break;

                case "ABOUT":
                    show_about ();
                    break;

                default:
                    break;
            }
        }

        private void action_undo (GLib.SimpleAction action, GLib.Variant? param) {
//message ("action undo");
            update_undo_actions ();
            undo_manager.undo (null);
        }

        private void action_redo (GLib.SimpleAction action, GLib.Variant? param) {
//message ("action redo");
            update_undo_actions ();
            undo_manager.redo (null);
        }

        private void change_state_select_all (GLib.SimpleAction action) {
//message ("select all state %s", action.state.get_boolean () ? "true" : "false");
            Slot? slot = get_active_slot ();
            if (slot != null) {
                bool state = !action.state.get_boolean ();
                if (slot.select_all (state))
                    action.set_state (new GLib.Variant.boolean (state));
            }
        }

        private void change_state_show_hidden (GLib.SimpleAction action) {
//message ("show hidden state %s", action.state.get_boolean () ? "true" : "false");
            bool state = !action.state.get_boolean ();
            action.set_state (new GLib.Variant.boolean (state));
            Preferences.settings.set_boolean ("show-hiddenfiles", state);
        }

        private void change_state_show_sidebar (GLib.SimpleAction action) {
//message ("show sidebar state %s", action.state.get_boolean () ? "true" : "false");
            bool state = !action.state.get_boolean ();
            action.set_state (new GLib.Variant.boolean (state));
            Preferences.settings.set_boolean ("show-sidebar", state);
        }

        private void connect_to_server () {
            var dialog = new Marlin.ConnectServer.Dialog ((Gtk.Window) this);
            dialog.show ();
        }

        protected void show_about() {
            Granite.Widgets.show_about_dialog ((Gtk.Window) this,
                "program-name", Marlin.APP_TITLE,
                "version", Config.VERSION,
                // "comments", Marlin.COMMENTS,
                "copyright", Marlin.COPYRIGHT,
                "license-type", Gtk.License.GPL_3_0,
                "website", Marlin.LAUNCHPAD_URL,
                "website-label",  Marlin.LAUNCHPAD_LABEL,
                "authors", Marlin.AUTHORS,
                "artists", Marlin.ARTISTS,
                "logo-icon-name", Marlin.ICON_ABOUT_LOGO,
                "translator-credits",  Marlin.TRANSLATORS,
                "help", Marlin.HELP_URL,
                "translate", Marlin.TRANSLATE_URL,
                "bug", Marlin.BUG_URL
            );
        }

        void show_report() {
            try { Gtk.show_uri (screen, Marlin.BUG_URL, -1); }
            catch (Error e) { critical("Can't open the link"); }
        }

        void show_translate() {
            try { Gtk.show_uri (screen, Marlin.TRANSLATE_URL, -1); }
            catch (Error e) { critical("Can't open the link"); }
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
                    return this.current_tab.view_mode;
                default:
                    break;
            }
            return (Marlin.ViewMode)(Preferences.settings.get_enum ("default-viewmode"));
        }

        public GLib.SimpleActionGroup get_action_group () {
            return this.win_actions;
        }

        private bool is_marlin_mydefault_fm () {
//message ("is default?");
            bool foldertype_is_default = ("pantheon-files.desktop" == AppInfo.get_default_for_type("inode/directory", false).get_id());

            bool trash_uri_is_default = false;
            AppInfo? app_trash_handler = AppInfo.get_default_for_type("x-scheme-handler/trash", true);
            if (app_trash_handler != null)
                trash_uri_is_default = ("pantheon-files.desktop" == app_trash_handler.get_id());

            return foldertype_is_default && trash_uri_is_default;
        }

        private void make_marlin_default_fm (bool active) {
            if (active) {
                AppInfo marlin_app = (AppInfo) new DesktopAppInfo ("pantheon-files.desktop");
                if (marlin_app != null) {
//message ("make default");
                    try {
                        marlin_app.set_as_default_for_type ("inode/directory");
                        marlin_app.set_as_default_for_type ("x-scheme-handler/trash");
                    } catch (GLib.Error e) {
                        critical ("Can't set Marlin default FM: %s", e.message);
                    }
                } else {
//message ("Failed to make AppInfo");
                }
            } else {
//message ("resetting default");
                AppInfo.reset_type_associations ("inode/directory");
                AppInfo.reset_type_associations ("x-scheme-handler/trash");
            }
        }

        public void update_view_mode (Marlin.ViewMode mode) {
            GLib.SimpleAction action = get_action ("view_mode");
            action.set_state (mode_strings [(int)mode]);
            top_menu.view_switcher.mode = mode;
        }

        public void quit () {
//message ("quitting window");
            if (is_first_window) {
                save_geometries ();
                save_tabs ();
            }
            this.destroy ();
        }

        private void save_geometries () {
            Gtk.Allocation sidebar_alloc;
            sidebar.get_allocation (out sidebar_alloc);
            if (sidebar_alloc.width > 1)
                Preferences.settings.set_int("sidebar-width", sidebar_alloc.width);

            var geometry = EelGtk.Window.get_geometry_string (this);
            bool is_maximized = (bool) get_window().get_state() & Gdk.WindowState.MAXIMIZED;
            if (is_maximized == false)
                Preferences.settings.set_string("geometry", geometry);
            Preferences.settings.set_boolean("maximized", is_maximized);
        }

        private void save_tabs () {
//message ("save tabs");
            VariantBuilder vb = new VariantBuilder (new VariantType ("a(uss)"));

            foreach (var tab in tabs.tabs) {
                assert (tab != null);
                var view = tab.page as ViewContainer;

                /* Do not save if "File does not exist" or "Does not belong to you" */
                if (!view.can_show_folder)
                    continue;

                vb.add ("(uss)",
                        view.view_mode,
                        GLib.Uri.escape_string (view.get_root_uri () ?? Environment.get_home_dir ()),
                        GLib.Uri.escape_string (view.get_tip_uri () ?? "")
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
            int tabs_added = 0;
            Marlin.ViewMode mode = Marlin.ViewMode.INVALID;
            string root_uri = null;
            string tip_uri = null;

            /* inhibit unnecessary changes of view and rendering of location bar while restoring tabs
             * as this causes all sorts of problems */
            freeze_view_changes = true;
            while (iter.next ("(uss)", out mode, out root_uri, out tip_uri)) {
                if (mode < 0 || mode >= Marlin.ViewMode.INVALID || root_uri == null || root_uri == "" || tip_uri == null)
                    continue;

                GLib.File root_location = GLib.File.new_for_uri (GLib.Uri.unescape_string (root_uri));

                add_tab (root_location, mode);

                if (mode == Marlin.ViewMode.MILLER_COLUMNS && tip_uri != root_uri)
                    expand_miller_view (tip_uri, root_location);

                tabs_added++;
                mode = Marlin.ViewMode.INVALID;
                root_uri = null;
                tip_uri = null;
            }

            freeze_view_changes = false;

            int active_tab_position = Preferences.settings.get_int ("active-tab-position");
            if (active_tab_position >=0 && active_tab_position < tabs_added) {
                tabs.current = tabs.get_tab_by_index (active_tab_position);
                change_tab (active_tab_position);
            }

            string path = current_tab.get_tip_uri ();
            if (path == "")
                path = current_tab.get_root_uri ();

            /* Render the final path in the location bar without animation */
            top_menu.location_bar.bread.animation_visible = false;
            top_menu.location_bar.path = path;
            /* restore location bar animation */
            top_menu.location_bar.bread.animation_visible = true;
            return tabs_added;
        }

        private void expand_miller_view (string tip_uri, GLib.File root_location) {
            var tab = tabs.current;
            var view = tab.page as ViewContainer;
            var mwcols = view.mwcol;
            var unescaped_tip_uri = GLib.Uri.unescape_string (tip_uri);
            var tip_location = GLib.File.new_for_uri (unescaped_tip_uri);
            var relative_path = root_location.get_relative_path (tip_location);
            GLib.File gfile;

            if (relative_path != null) {
                string [] dirs = relative_path.split (GLib.Path.DIR_SEPARATOR_S);
                string uri = root_location.get_uri ();

                foreach (string dir in dirs) {
                    uri += (GLib.Path.DIR_SEPARATOR_S + dir);
                    gfile = GLib.File.new_for_uri (uri);;
                    mwcols.add_location (gfile, mwcols.current_slot);
                }
            } else {
                warning ("Invalid tip uri for Miller View");
            }
        }
    }
}
