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

using Gtk;
using Gdk;
using Cairo;
using Marlin.View.Chrome;
using EelGtk.Window;

namespace Marlin.View {
    public class Window : Gtk.Window
    {
        public UIManager ui;
        private UndoManager undo_manager;
        public Widget menu_bar;
        public Chrome.TopMenu top_menu;
        public Gtk.InfoBar info_bar;
        public Granite.Widgets.DynamicNotebook tabs;
        public Marlin.Places.Sidebar sidebar;

        public ViewContainer? current_tab;

        public Gtk.ActionGroup main_actions;
        public Gtk.AccelGroup accel_group;

        public Granite.Widgets.ToolButtonWithMenu button_forward;
        public Granite.Widgets.ToolButtonWithMenu button_back;

        public bool can_go_up{
            set{
                main_actions.get_action("Up").set_sensitive(value);
            }
        }

        public bool can_go_forward{
            set{
                main_actions.get_action("Forward").set_sensitive(value);
            }
        }

        public bool can_go_back{
            set{
                main_actions.get_action("Back").set_sensitive(value);
            }
        }

        public signal void item_hovered (GOF.File gof_file);
        public signal void selection_changed (GLib.List<GOF.File> gof_file);

        public signal void loading_uri (string location, Widget sidebar);


        public void update_action_radio_view(int n) {
            Gtk.RadioAction action = (Gtk.RadioAction) main_actions.get_action("view-as-icons");
            assert(action != null);
            action.set_current_value(n);
        }

        protected virtual void action_radio_change_view(){
            Gtk.RadioAction action = (Gtk.RadioAction) main_actions.get_action("view-as-icons");
            assert(action != null);
            int n = action.get_current_value();
            /* change the view only for view_mode real change */
            if (n != current_tab.view_mode)
                current_tab.change_view(n, null);
        }

        public Window (Marlin.Application app, Gdk.Screen myscreen)
        {
            application = app;
            screen = myscreen;

            ui = new UIManager();

            try {
                ui.add_ui_from_file(Config.UI_DIR + "pantheon-files-ui.xml");
            } catch (Error e) {
                stderr.printf ("Error loading UI: %s", e.message);
            }

            main_actions = new Gtk.ActionGroup("MainActionGroup");
            main_actions.set_translation_domain("pantheon-files");
            main_actions.add_actions(main_entries, this);
            main_actions.add_toggle_actions(main_toggle_entries, this);
            main_actions.add_radio_actions(view_radio_entries, -1,
                                           action_radio_change_view);
            /*main_actions.add_radio_actions(color_radio_entries, -1,
                                           action_radio_set_color_changed);*/
            accel_group = ui.get_accel_group();
            add_accel_group(accel_group);

            ui.insert_action_group(main_actions, 0);
            ui.ensure_update();

            /* Menubar. We only need a menubar for special cases like global menus or HUD.
               We don't need to show it in any other case */
            menu_bar = ui.get_widget("/MenuBar");
            menu_bar.no_show_all = true;
            menu_bar.hide ();

            /* Topmenu */
            top_menu = new Chrome.TopMenu(this);

            /* Info Bar */
            info_bar = new Gtk.InfoBar ();

            var label = new Gtk.Label (_("Files isn't your default file manager."));
            label.set_line_wrap (true);

            var expander = new Label ("");
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

            ((Box)info_bar.get_content_area ()).add (label);
            ((Box)info_bar.get_content_area ()).add (expander);
            ((Box)info_bar.get_content_area ()).add (bbox);

            show_infobar (!is_marlin_mydefault_fm ());

            /* Contents */
            tabs = new Granite.Widgets.DynamicNotebook ();
            tabs.show_tabs = true;
            tabs.allow_restoring = true;
            tabs.allow_duplication = true;
            this.configure_event.connect ((e) => {
                tabs.set_size_request (e.width / 2, -1);
                return false;
            });

            tabs.show ();

            /* Sidebar */
            sidebar = new Marlin.Places.Sidebar (this);
            Preferences.settings.bind("sidebar-zoom-level", sidebar, "zoom-level", SettingsBindFlags.DEFAULT);

            var lside_pane = new Granite.Widgets.ThinPaned ();
            lside_pane.show ();

            lside_pane.pack1 (sidebar, false, false);
            lside_pane.pack2 (tabs, true, false);

            sidebar.show ();

            /*/
            /* Pack up all the view
            /*/

            Box window_box = new Box(Gtk.Orientation.VERTICAL, 0);
            window_box.show();
            window_box.pack_start(menu_bar, false, false, 0);
            window_box.pack_start(top_menu, false, false, 0);
            window_box.pack_start(info_bar, false, false, 0);
            window_box.pack_start(lside_pane, true, true, 0);

            add(window_box);

            lside_pane.position = Preferences.settings.get_int ("sidebar-width");

            /*set_default_size(760, 450);
            set_position(WindowPosition.CENTER);*/
            var geometry = Preferences.settings.get_string("geometry");
            /* only position the first window */
            set_initial_geometry_from_string (this, geometry, 700, 450, !app.is_first_window ((Gtk.Window) this));
            if (Preferences.settings.get_boolean("maximized")) {
                maximize();
            }
            title = Marlin.APP_TITLE;
            try {
                this.icon = IconTheme.get_default ().load_icon ("system-file-manager", 32, 0);
            } catch (Error err) {
                stderr.printf ("Unable to load marlin icon: %s", err.message);
            }
            show();

            Preferences.settings.bind("show-sidebar", sidebar, "visible", 0);
            Preferences.settings.bind("show-sidebar", main_actions.get_action("Show Hide Sidebar"), "active", 0);
            Preferences.settings.bind("show-hiddenfiles", main_actions.get_action("Show Hidden Files"), "active", 0);

            /*/
            /* Connect and abstract signals to local ones
            /*/

            window_state_event.connect ((event) => {
                if ((bool) event.changed_mask & Gdk.WindowState.MAXIMIZED) {
                    Preferences.settings.set_boolean("maximized",
                                                     (bool) get_window().get_state() & Gdk.WindowState.MAXIMIZED);
                }
                return false;
            });

            delete_event.connect(() => {
                save_geometries();
                destroy();
            	return false;
            });
            
            tabs.tab_added.connect ((tab) => {
                make_new_tab (tab);
            });
            
            tabs.tab_removed.connect ((tab) => {
                if (tabs.n_tabs == 1) {
                    make_new_tab ();
                }
                
                tab.restore_data =
                    (tab.page as ViewContainer).slot.location.get_uri ();
                
                return true;
            });
            
            tabs.tab_switched.connect ((old_tab, new_tab) => {
                change_tab (tabs.get_tab_position (new_tab));
            });
            
            tabs.tab_restored.connect ((tab) => {
                make_new_tab (tab, File.new_for_uri (tab.restore_data));
            });
            
            tabs.tab_duplicated.connect ((tab) => {
                make_new_tab (null, File.new_for_uri (((tab.page as ViewContainer).get_active_slot ()).location.get_uri ()));
            });

            Gtk.Allocation win_alloc;
            get_allocation (out win_alloc);

            /* keyboard shortcuts bindings */
            if (app.is_first_window ((Gtk.Window) this)) {
                unowned Gtk.BindingSet binding_set = Gtk.BindingSet.by_class (get_class ());
                Gtk.BindingEntry.add_signal (binding_set, Gdk.keyval_from_name ("BackSpace"), 0, "go_up", 0);
                Gtk.BindingEntry.add_signal (binding_set, Gdk.keyval_from_name ("L"), Gdk.ModifierType.CONTROL_MASK, "edit_path", 0);
            }

            /* UndoRedo */
            undo_manager = Marlin.UndoManager.instance ();
            undo_manager.request_menu_update.connect (undo_redo_menu_update_callback);
            undo_actions_set_insensitive ();

        }

        private void show_infobar (bool val) {
            if (val)
                info_bar.show_all ();
            else
                info_bar.hide ();
        }

        [Signal (action=true)]
        public virtual signal void go_up () {
            action_go_up ();
        }

        [Signal (action=true)]
        public virtual signal void edit_path () {
            action_edit_path ();
        }

        public void colorize_current_tab_selection (int n) {
            if (!current_tab.content_shown)
                ((FM.Directory.View) current_tab.slot.view_box).colorize_selection(n);
        }


        public GOF.Window.Slot? get_active_slot() {
            if (current_tab != null)
                return current_tab.get_active_slot ();
            return null;
        }

        public new void set_title(string title){
            this.title = title;
        }

        public void change_tab (int offset) {
            ViewContainer old_tab = current_tab;
            current_tab = (tabs.get_tab_by_index (offset)).page as ViewContainer;
            if (old_tab == current_tab) {
                return;
            }
            if (old_tab != null) {
                var old_slot = old_tab.get_active_slot ();
                if (old_slot != null)
                    old_slot.inactive ();
            }

            if (current_tab != null) {
                var cur_slot = current_tab.get_active_slot ();
                if (cur_slot != null) {
                    cur_slot.active();
                    current_tab.update_location_state(false);
                    /* update radio action view state */
                    update_action_radio_view(current_tab.view_mode);
                    /* sync selection */
                    if (cur_slot.view_box != null && !current_tab.content_shown)
                        ((FM.Directory.View) cur_slot.view_box).sync_selection();
                    /* sync sidebar selection */
                    loading_uri (current_tab.slot.directory.file.uri, sidebar);
                }
            }
        }

        private void make_new_tab (Granite.Widgets.Tab? tab = null,
                                   File location = File.new_for_commandline_arg (Environment.get_home_dir ())) {
            if (tab == null) {
                var new_tab = new Granite.Widgets.Tab ();
                tabs.insert_tab (new_tab, -1);
                make_new_tab (new_tab, location);
                return;
            }

            var content = new View.ViewContainer (this, location,
                                    current_tab != null ? current_tab.view_mode : Preferences.settings.get_enum("default-viewmode"));

            tab.label = "";
            tab.page = content;

            content.tab_name_changed.connect ((tab_name) => {
                tab.label = tab_name;
            });

            tabs.current = tab;
            change_tab (tabs.get_tab_position (tab));
        }

        public void add_tab (File location) {
            make_new_tab (null, location);
            
            /* The following fixes a bug where upon first opening
               Files, the overlay status bar is shown empty. */
            if (tabs.n_tabs == 1) {
                var tab = tabs.get_tab_by_index (0);
                if (tab != null)
                    (tab.page as ViewContainer).overlay_statusbar.update ();
            }
        }

        public void remove_tab (ViewContainer view_container) {
            var tab = tabs.get_tab_by_widget (view_container as Gtk.Widget);
            if (tab != null)
                tabs.remove_tab (tab);
        }

        public void add_window(File location){
            ((Marlin.Application) application).create_window (location, screen);
        }

        private void undo_actions_set_insensitive () {
            Gtk.Action action;

            action = main_actions.get_action ("Undo");
            action.set_sensitive (false);
            action = main_actions.get_action ("Redo");
            action.set_sensitive (false);
        }

        private void update_undo_actions (UndoMenuData? data = null) {
            Gtk.Action action;

            action = main_actions.get_action ("Undo");
            if (data != null && data.undo_label != null && sensitive) {
                action.set_label (data.undo_label);
                action.set_tooltip (data.undo_description);
            } else {
                action.set_label (_("Undo"));
                action.set_tooltip (_("Undo the last action"));
            }
            action.set_sensitive (data != null && data.undo_label != null);

            action = main_actions.get_action ("Redo");
            if (data != null && data.redo_label != null && sensitive) {
                action.set_label (data.redo_label);
                action.set_tooltip (data.redo_description);
            } else {
                action.set_label (_("Redo"));
                action.set_tooltip (_("Redo the last action"));
            }
            action.set_sensitive (data != null && data.redo_label != null);
        }

        private void undo_redo_menu_update_callback (UndoManager manager, UndoMenuData data) {
            update_undo_actions (data);
        }

        private void action_new_window (Gtk.Action action) {
            var location = File.new_for_commandline_arg(Environment.get_home_dir());
            ((Marlin.Application) application).create_window (location, screen);
        }

        private void action_new_tab (Gtk.Action action) {
            make_new_tab ();
        }

        private void action_remove_tab (Gtk.Action action) {
            tabs.remove_tab (tabs.current);
        }

    	private void save_geometries () {
            Gtk.Allocation sidebar_alloc;
            sidebar.get_allocation (out sidebar_alloc);
            if (sidebar_alloc.width > 1)
                Preferences.settings.set_int("sidebar-width", sidebar_alloc.width);

            var geometry = get_geometry_string (this);
            bool is_maximized = (bool) get_window().get_state() & Gdk.WindowState.MAXIMIZED;
            if (is_maximized == false)
                Preferences.settings.set_string("geometry", geometry);
            Preferences.settings.set_boolean("maximized", is_maximized);
        }

        public Gtk.ActionGroup get_actiongroup () {
            return this.main_actions;
        }

        public void set_toolbar_items () {
            top_menu.setup_items();
        }

        private void action_go_up () {
            current_tab.up();
        }

        private void action_edit_path () {
            top_menu.location_bar.get_child ().grab_focus ();
        }

        private void action_go_back (Gtk.Action action) {
            current_tab.back();
        }

        private void action_go_forward (Gtk.Action action) {
            current_tab.forward();
        }

        private uint t_reload_cb = 0;

        private bool real_reload_callback () {
            current_tab.reload ();
            t_reload_cb = 0;
            return false;
        }

        private bool is_close_first () {
            string path = "/apps/metacity/general/button_layout";
            GConf.Client cl = GConf.Client.get_default ();
            string key;

            try {
                if (cl.get (path) != null)
                    key = cl.get_string (path);
                else
                    return false;
            } catch (GLib.Error err) {
                warning ("Unable to read metacity settings: %s", err.message);
            }

            string[] keys = key.split (":");
            if ("close" in keys[0])
                return true;
            else
                return false;

        }

        private bool is_marlin_mydefault_fm ()
        {
            bool trash_uri_is_default = false;
            bool foldertype_is_default = "pantheon-files.desktop" == AppInfo.get_default_for_type("inode/directory", false).get_id();
            AppInfo? app_trash_handler = AppInfo.get_default_for_type("x-scheme-handler/trash", true);
            if (app_trash_handler != null)
                trash_uri_is_default = "pantheon-files.desktop" == app_trash_handler.get_id();

            return foldertype_is_default && trash_uri_is_default;
        }

        private void make_marlin_default_fm (bool active)
        {
            if (active) {
                AppInfo marlin_app = (AppInfo) new DesktopAppInfo ("pantheon-files.desktop");
                if (marlin_app != null) {
                    try {
                        marlin_app.set_as_default_for_type ("inode/directory");
                        marlin_app.set_as_default_for_type ("x-scheme-handler/trash");
                    } catch (GLib.Error e) {
                        critical ("Can't set Marlin default FM: %s", e.message);
                    }
                }
            } else {
                AppInfo.reset_type_associations ("inode/directory");
                AppInfo.reset_type_associations ("x-scheme-handler/trash");
            }
        }

        private void action_reload_callback (Gtk.Action action) {
            /* avoid spawning reload when key kept pressed */
            if (t_reload_cb == 0)
                t_reload_cb = Timeout.add (90, real_reload_callback );
        }

        private void action_undo_callback (Gtk.Action action) {
            update_undo_actions ();
            undo_manager.undo (null);
        }

        private void action_redo_callback (Gtk.Action action) {
            update_undo_actions ();
            undo_manager.redo (null);
        }

        private void action_home_callback (Gtk.Action action) {
                current_tab.path_changed(File.new_for_commandline_arg(Environment.get_home_dir()));
        }

        private void action_go_to_trash_callback (Gtk.Action action) {
                current_tab.path_changed(File.new_for_commandline_arg(Marlin.TRASH_URI));
        }

        private void action_go_to_network_callback (Gtk.Action action) {
                current_tab.path_changed(File.new_for_commandline_arg(Marlin.NETWORK_URI));
        }

        private void action_zoom_in_callback (Gtk.Action action) {
            if (current_tab != null && current_tab.slot != null)
                ((FM.Directory.View) current_tab.slot.view_box).zoom_in ();
        }

        private void action_zoom_out_callback (Gtk.Action action) {
            if (current_tab != null && current_tab.slot != null)
                ((FM.Directory.View) current_tab.slot.view_box).zoom_out ();
        }

        void action_next_tab ()
        {
            tabs.next_page ();
        }
        void action_previous_tab ()
        {
            tabs.previous_page ();
        }

        private void action_zoom_normal_callback (Gtk.Action action) {
            if (current_tab != null && current_tab.slot != null)
                ((FM.Directory.View) current_tab.slot.view_box).zoom_normal ();
        }

        private void action_connect_to_server_callback (Gtk.Action action)
        {
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
                "bug", Marlin.BUG_URL);
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

        static const Gtk.ActionEntry[] main_entries = {
  /* name, stock id, label */  { "File", null, N_("_File") },
  /* name, stock id, label */  { "Edit", null, N_("_Edit") },
  /* name, stock id, label */  { "View", null, N_("_View") },
  /* name, stock id, label */  { "Go", null, N_("_Go") },
  /* name, stock id, label */  { "Help", null, N_("_Help") },
/*                               { "ColorMenu", null, N_("Set _Color") },*/
  /* name, stock id, label */  { "New Window", "window-new", N_("New _Window"),
                                 "<control>N", N_("Open another Files window for the displayed location"),
                                 action_new_window },
  /* name, stock id */         { "New Tab", "tab-new",
  /* label, accelerator */       N_("New _Tab"), "<control>T",
  /* tooltip */                  N_("Open another tab for the displayed location"),
                                 action_new_tab },

  /* name, stock id */         { "Close", Stock.CLOSE,
  /* label, accelerator */       N_("_Close"), "<control>W",
  /* tooltip */                  N_("Close this folder"),
                                 action_remove_tab },
                             /*{ Chrome.ColorAction, null, "ColorAction"),
                                 null, null,
                                 null },*/
                               { "Undo", Stock.UNDO, N_("_Undo"),
                                 "<control>Z", N_("Undo the last action"),
                                 action_undo_callback },
                               { "Redo", Stock.REDO, N_("_Redo"),
                                 "<control><shift>Z", N_("Redo the last action"),
                                 action_redo_callback },
                               { "Up", Stock.GO_UP, N_("Open _Parent"),
                                 "<alt>Up", N_("Open the parent folder"),
                                 action_go_up },
                               { "Back", Stock.GO_BACK, N_("_Back"),
                                 "<alt>Left", N_("Go to the previous visited location"),
                                 //G_CALLBACK (action_up_callback) },
                                 action_go_back },
                               { "Forward", Stock.GO_FORWARD, N_("_Forward"),
                                 "<alt>Right", N_("Go to the next visited location"),
                                 action_go_forward },
                               { "Reload", Stock.REFRESH, N_("_Reload"),
                                 "<control>R", N_("Reload the current location"),
                                 action_reload_callback },
  /* name, stock id */         { "Home", Marlin.ICON_HOME,
  /* label, accelerator */       N_("_Home Folder"), "<alt>Home",
  /* tooltip */                  N_("Open your personal folder"),
                                 action_home_callback },
  /* name, stock id */         { "Go to Trash", Marlin.ICON_TRASH,
  /* label, accelerator */       N_("_Trash"), null,
  /* tooltip */                  N_("Open your personal trash folder"),
                                 action_go_to_trash_callback },
  /* name, stock id */         { "Go to Network", Marlin.ICON_NETWORK,
  /* label, accelerator */       N_("_Network"), null,
  /* tooltip */                  N_("Browse bookmarked and local network locations"),
                                 action_go_to_network_callback },
  /* name, stock id */         { "Zoom In", Stock.ZOOM_IN,
  /* label, accelerator */       N_("Zoom _In"), "<control>plus",
  /* tooltip */                  N_("Increase the view size"),
                                 action_zoom_in_callback },
  /* name, stock id */         { "ZoomInAccel", null,
  /* label, accelerator */       "ZoomInAccel", "<control>equal",
  /* tooltip */                  null,
                                 action_zoom_in_callback },
  /* name, stock id */         { "ZoomInAccel2", null,
  /* label, accelerator */       "ZoomInAccel2", "<control>KP_Add",
  /* tooltip */                  null,
                                 action_zoom_in_callback },
  /* name, stock id */         { "Zoom Out", Stock.ZOOM_OUT,
  /* label, accelerator */       N_("Zoom _Out"), "<control>minus",
  /* tooltip */                  N_("Decrease the view size"),
                                 action_zoom_out_callback },
  /* name, stock id */         { "ZoomOutAccel", null,
  /* label, accelerator */       "ZoomOutAccel", "<control>KP_Subtract",
  /* tooltip */                  null,
                                 action_zoom_out_callback },
  /* name, stock id */         { "Zoom Normal", Stock.ZOOM_100,
  /* label, accelerator */       N_("Normal Si_ze"), "<control>0",
  /* tooltip */                  N_("Use the normal view size"),
                                 action_zoom_normal_callback },
  /* name, stock id */         { "Next Tab", "",
  /* label, accelerator */       N_("Next Tab"), "<control>Page_Down",
  /* tooltip */                  "",
                                 action_next_tab },
  /* name, stock id */         { "Previous Tab", "",
  /* label, accelerator */       N_("Previous Tab"), "<control>Page_Up",
  /* tooltip */                  "",
                                 action_previous_tab },
  /* name, stock id */         { "Connect to Server", null,
  /* label, accelerator */       N_("Connect to _Server..."), null,
  /* tooltip */                  N_("Connect to a remote computer or shared disk"),
                                 action_connect_to_server_callback },
  /* name, stock id */         { "About", Stock.ABOUT,
  /* label, accelerator */       N_("_About"), null,
  /* tooltip */                  N_("Display credits"),
                                 show_about },
  /* name, stock id */         { "ReportProblem", "",
  /* label, accelerator */       N_("Report a Problem..."), null,
  /* tooltip */                  N_("File a bug on Launchpad"),
                                 show_report },
  /* name, stock id */         { "GetHelp", "",
  /* label, accelerator */       N_("Get Help Online..."), null,
  /* tooltip */                  "",
                                 show_app_help },
  /* name, stock id */         { "Translate", "",
  /* label, accelerator */       N_("Translate This Application..."), null,
  /* tooltip */                  "",
                                 show_translate }


        };

        static const Gtk.ToggleActionEntry main_toggle_entries[] = {
  /* name, stock id */         { "Show Hidden Files", null,
  /* label, accelerator */       N_("Show _Hidden Files"), "<control>H",
  /* tooltip */                  N_("Toggle the display of hidden files in the current window"),
                                 null,
                                 true },
  /* name, stock id */         { "Show Hide Sidebar", null,
  /* label, accelerator */       N_("_Places"), "F9",
  /* tooltip */                  N_("Change the visibility of this window's side pane"),
                                 null,
  /* is_active */                true }

        };

        static const Gtk.RadioActionEntry view_radio_entries[] = {
            { "view-as-icons", null,
              N_("Icon"), "<control>1", null,
              ViewMode.ICON },
            { "view-as-detailed-list", null,
              N_("List"), "<control>2", null,
              ViewMode.LIST },
            { "view-as-columns", null,
              N_("Columns"), "<control>3", null,
              ViewMode.MILLER }
     
        };
    }
}
