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
using Varka.Widgets;
using EelGtk.Window;

namespace Marlin.View {
    public class Window : Gtk.Window
    {
        public UIManager ui;
        public Widget menu_bar;
        public Chrome.TopMenu top_menu;
        public Notebook tabs;
        public Marlin.Places.Sidebar sidebar;

        public ViewContainer? current_tab;
        public CollapsiblePaned main_box;
        public ContextView contextview;

        public Gtk.ActionGroup main_actions;
        public Gtk.AccelGroup accel_group;

        public Varka.Widgets.ToolButtonWithMenu button_forward;
        public Varka.Widgets.ToolButtonWithMenu button_back;

        private const int horizontal_contextplane_max_width = 910;
        private const int horizontal_contextplane_max_height = 380; // after which we will go vertical

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
        
        public signal void selection_changed(GLib.List<GOF.File> gof_file);

        public signal void loading_uri (string location, Widget sidebar);

        public signal void reload_tabs();

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
                ui.add_ui_from_file(Config.UI_DIR + "marlin-ui.xml");
            } catch (Error e) {
                stderr.printf ("Error loading UI: %s", e.message);
            }

            main_actions = new Gtk.ActionGroup("MainActionGroup");
            main_actions.set_translation_domain("marlin");
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

            /* Menubar */
            menu_bar = ui.get_widget("/MenuBar");
            menu_bar.hide ();

            /* Topmenu */
            top_menu = new Chrome.TopMenu(this);

            menu_bar.button_press_event.connect(top_menu.right_click);


            /* Contents */
            tabs = new Notebook();
            tabs.show_border = false;
            tabs.show_tabs = false;
            tabs.set_scrollable(true);
            tabs.show();

            /* Sidebar */
            sidebar = new Marlin.Places.Sidebar ((Gtk.Widget) this);
            Preferences.settings.bind("sidebar-icon-size", sidebar, "icon-size", SettingsBindFlags.DEFAULT);

            /* Devide main views into sidebars */
            main_box = new CollapsiblePaned(Orientation.VERTICAL);
            main_box.show();

            var lside_pane = new HCollapsiblePaned();
            lside_pane.show();

            lside_pane.pack1(sidebar, false, false);
            lside_pane.pack2(main_box, true, true);
            lside_pane.collapse_mode = CollapseMode.LEFT;

            main_box.pack1(tabs, true, true);

            ((Gtk.ToggleAction) main_actions.get_action("Show Hide Context Pane")).set_active(Preferences.settings.get_boolean("start-with-contextview"));

            main_box.collapse_mode = CollapseMode.RIGHT;

            /*/
            /* Pack up all the view
            /*/

            VBox window_box = new VBox(false, 0);
            window_box.show();
            window_box.pack_start(menu_bar, false, false, 0);
            window_box.pack_start(top_menu, false, false, 0);
            window_box.pack_start(lside_pane, true, true, 0);

            add(window_box);

            lside_pane.set_position (Preferences.settings.get_int("sidebar-width"));

            /*set_default_size(760, 450);
            set_position(WindowPosition.CENTER);*/
            var geometry = Preferences.settings.get_string("geometry");
            set_initial_geometry_from_string (this, geometry, 700, 450, false);
            if (Preferences.settings.get_boolean("maximized")) {
                maximize();
            }
            title = Marlin.APP_TITLE;
            //this.icon = DrawingService.GetIcon("system-file-manager", 32);
            //this.icon = IconTheme.get_default ().load_icon ("system-file-manager", 32, 0);
            try {
                this.icon = IconTheme.get_default ().load_icon ("marlin", 32, 0);
            } catch (Error err) {
                stderr.printf ("Unable to load marlin icon: %s", err.message);
            }
            show();

            Preferences.settings.bind("show-menubar", menu_bar, "visible", 0);
            Preferences.settings.bind("show-menubar", main_actions.get_action("Show Hide Menubar"), "active", 0);
            //Preferences.settings.bind("show-menubar", top_menu.compact_menu_button, "visible", SettingsBindFlags.INVERT_BOOLEAN);
            Preferences.settings.bind("show-hiddenfiles", main_actions.get_action("Show Hidden Files"), "active", 0);
            Preferences.settings.bind("show-sidebar", sidebar, "visible", 0);
            Preferences.settings.bind("show-sidebar", main_actions.get_action("Show Hide Sidebar"), "active", 0);

            /*/
            /* Connect and abstract signals to local ones
            /*/

            delete_event.connect(() => {
                save_geometries();
                destroy();
            	return false;
            });

            tabs.switch_page.connect((page, offset) => {
                change_tab(offset);
            });

            tabs.scroll_event.connect((scroll) => {
                int offset = tabs.get_current_page();

                if(scroll.direction == ScrollDirection.UP)
                    offset++;
                else if(scroll.direction == ScrollDirection.DOWN)
                    offset--;

                if(offset >= 0 && offset <= tabs.get_children().length()-1)
                    tabs.set_current_page(offset);

                return true;
            });

            size_allocate.connect(resized);

            /* Binding Backspace keyboard shortcut */
            unowned Gtk.BindingSet binding_set;

            binding_set = Gtk.BindingSet.by_class (typeof (Marlin.View.Window).class_ref ());
            action_new (typeof (Marlin.View.Window), "go_up");
            Gtk.BindingEntry.add_signal (binding_set, Gdk.keyval_from_name ("BackSpace"), 0, "go_up", 0);
            action_new (typeof (Marlin.View.Window), "edit_path");
            Gtk.BindingEntry.add_signal (binding_set, Gdk.keyval_from_name ("L"), Gdk.ModifierType.CONTROL_MASK, "edit_path", 0);
            Signal.connect (this, "go_up",
                    (GLib.Callback)cb_go_up, this);
            Signal.connect (this, "edit_path",
                    (GLib.Callback)action_edit_path, null);
        }

        static void cb_go_up(Window data)
        {
            assert(data is Window);
            data.action_go_up();
        }

        public void colorize_current_tab_selection (int n) {
            ((FM.Directory.View) current_tab.slot.view_box).colorize_selection(n);
        }


        public GOF.Window.Slot? get_active_slot() {
            if (current_tab != null && current_tab.slot != null)
                return current_tab.slot;
            return null;
        }

        public new void set_title(string title){
            this.title = title;
        }

        public void change_tab(uint offset){
            ViewContainer old_tab = current_tab;
            current_tab = (ViewContainer) tabs.get_children().nth_data(offset);
            if (old_tab == current_tab) {
                return;
            }
            if (old_tab != null) {
                old_tab.slot.inactive();
            }

            if (current_tab != null && current_tab.slot != null) {
                current_tab.slot.active();
                current_tab.update_location_state(false);
                /* update radio action view state */
                update_action_radio_view(current_tab.view_mode);
                /* sync selection */
                if (current_tab.slot.view_box != null)
                    ((FM.Directory.View) current_tab.slot.view_box).sync_selection();
                /* sync ContextView */
                current_tab.sync_contextview();
                /* set window title to current title */
                set_title(current_tab.tab_name);
                /* sync sidebar selection */
                loading_uri (current_tab.slot.directory.file.uri, sidebar);

                /* focus the main view */
                //((FM.Directory.View) current_tab.slot.view_box).grab_focus();
                current_tab.content.grab_focus();
            }
        }

        public void add_tab(File location){
            ViewContainer content = new View.ViewContainer(this, location,
                current_tab != null ? current_tab.view_mode : Preferences.settings.get_enum("default-viewmode"));

            var hbox = new HBox(false, 0);
            hbox.pack_start(content.label, true, true, 0);
            var button = new Button();
            button.set_image(new Image.from_stock(Stock.CLOSE, IconSize.MENU));
            button.set_relief(ReliefStyle.NONE);
            button.set_focus_on_click(false);
            hbox.pack_start(button, false, false, 0);

            button.clicked.connect(() => {
                remove_tab(content);
            });

            hbox.show_all();

            var eventbox = new EventBox();
            eventbox.add(hbox);
            eventbox.set_visible_window(false);
            eventbox.events |= EventMask.BUTTON_PRESS_MASK;
            eventbox.button_release_event.connect((click) => {
                if(click.button == 2){
                    remove_tab(content);
                }

                return false;
            });

            tabs.append_page(content, eventbox);
            tabs.child_set (content, "tab-expand", true, null );

            tabs.set_tab_reorderable(content, true);
            tabs.show_tabs = tabs.get_children().length() > 1;

            /* jump to that new tab */
            tabs.set_current_page(tabs.get_n_pages()-1);
            //current_tab = content;
        }

        public void remove_tab(ViewContainer view_container){
            if(tabs.get_children().length() == 2){
                tabs.show_tabs = false;
            }else if(tabs.get_children().length() == 1){
                save_geometries();
                destroy();
            }

            tabs.remove(view_container);
        }
        
        public void add_window(File location){
            ((Marlin.Application) application).create_window (location, screen);
        }

#if VALA_0_14
        private void resized(Gtk.Allocation allocation){
#else
        private void resized(Gdk.Rectangle allocation){
#endif
            Orientation current_state = main_box.orientation;

            int ctxview_orientation = Preferences.settings.get_enum("contextview-orientation");

            Orientation future_state = Orientation.VERTICAL; // Because how Paned class works, this is inverted
            switch (ctxview_orientation) {
            case 0:
                future_state = Orientation.VERTICAL;
                break;
            case 1:
                future_state = Orientation.HORIZONTAL;
                break;
            case 2:
                if(allocation.width  > horizontal_contextplane_max_width &&
                   allocation.height > horizontal_contextplane_max_height){
                    future_state = Orientation.HORIZONTAL;
                }
                break;
            }

            if(current_state != future_state){
                main_box.orientation = future_state;
            }
        }

        private void action_marlin_settings_callback (Gtk.Action action) {
            new SettingsDialog(this);
        }

        private void action_new_window (Gtk.Action action) {
            ((Marlin.Application) application).create_window (current_tab.slot.location, screen);
        }

        private void action_new_tab (Gtk.Action action) {
            add_tab (current_tab.slot.location);
        }

        private void action_remove_tab (Gtk.Action action) {
            remove_tab(current_tab);
        }

    	private void save_geometries () {
            Gtk.Allocation sidebar_alloc;
            sidebar.get_allocation (out sidebar_alloc);
            if (sidebar_alloc.width > 1)
                Preferences.settings.set_int("sidebar-width", sidebar_alloc.width);

            var geometry = get_geometry_string (this);
            bool is_maximized = get_window().get_state() == Gdk.WindowState.MAXIMIZED;
            if (is_maximized == false)
                Preferences.settings.set_string("geometry", geometry);
            Preferences.settings.set_boolean("maximized", is_maximized);

            Preferences.settings.set_boolean("start-with-contextview",
                ((Gtk.ToggleAction) main_actions.get_action("Show Hide Context Pane")).get_active());
        }

        public Gtk.ActionGroup get_actiongroup () {
            return this.main_actions;
        }

        public void set_toolbar_items () {
            top_menu.setup_items();
        }

        private void action_toolbar_editor_callback (Gtk.Action action) {
            marlin_toolbar_editor_dialog_show (this);
        }

        private void action_go_up () {
            current_tab.up();
        }

        private void action_edit_path () {
            //top_menu.location_bar.state = false;
            top_menu.location_bar.get_child ().grab_focus ();
        }

        private void action_go_back (Gtk.Action action) {
            current_tab.back();
        }

        private void action_go_forward (Gtk.Action action) {
            current_tab.forward();
        }

        private void action_show_hidden_files (Gtk.Action action) {
            /*if (current_tab != null)
                current_tab.reload();*/
            /* simply reload the views as show-hiddenfiles is a binded settings */
            this.reload_tabs();
        }

        private void action_show_hide_contextview (Gtk.Action action) {
            if (((Gtk.ToggleAction)action).get_active()) {
                current_tab.sync_contextview();
                ((FM.Directory.View) current_tab.slot.view_box).sync_selection();
            } else {
                 //main_box.remove (contextview);
                if (contextview != null) {
                    contextview.destroy();
                    contextview = null;
                }
            }
        }

        private void action_show_hide_menubar (Gtk.Action action) {
            bool vis = true;
            menu_bar.get("visible", &vis);
            if (vis)
                top_menu.app_menu.hide();
            else
                top_menu.app_menu.show_all();
        }

        /*private void action_show_hide_sidebar (Gtk.Action action) {
            stdout.printf ("TODO\n");
        }*/

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
        
        void action_next_tab()
        {
            if(tabs.page == tabs.get_n_pages() - 1)
                tabs.page = 0;
            else
                tabs.page++;
        }
        void action_previous_tab()
        {
            tabs.page --;
        }

        private void action_zoom_normal_callback (Gtk.Action action) {
            if (current_tab != null && current_tab.slot != null) 
                ((FM.Directory.View) current_tab.slot.view_box).zoom_normal ();
        }

        private void action_connect_to_server_callback (Gtk.Action action)
        {
            Widget dialog = new Marlin.ConnectServer.Dialog ((Gtk.Window) this);
            dialog.show ();
        }

        protected void show_about() {
            Varka.Widgets.show_about_dialog ((Gtk.Window) this,
                "program-name", Marlin.APP_TITLE,
                "version", Config.VERSION,
                "comments", Marlin.COMMENTS,
                "copyright", Marlin.COPYRIGHT,
                "license-type", Gtk.License.GPL_3_0,
                "website", Marlin.LAUNCHPAD_URL,
                "website-label",  Marlin.LAUNCHPAD_LABEL,
                "authors", Marlin.AUTHORS,
                "artists", Marlin.ARTISTS,
                "logo-icon-name", "marlin",
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
                                 "<control>N", N_("Open another Marlin window for the displayed location"),
                                 action_new_window },
  /* name, stock id */         { "New Tab", "tab-new",
  /* label, accelerator */       N_("New _Tab"), "<control>T",
  /* tooltip */                  N_("Open another tab for the displayed location"),
                                 action_new_tab },
  /* name, stock id */         { "Close", Stock.CLOSE,
  /* label, accelerator */       N_("_Close"), "<control>W",
  /* tooltip */                  N_("Close this folder"),
                                 action_remove_tab },
                               { "ToolbarEditor", Stock.PREFERENCES,
                                 N_("Customize _Toolbar..."),
                                 null, N_("Easily edit the toolbar layout"),
                                 action_toolbar_editor_callback },
                               { "MarlinSettings", Stock.PREFERENCES,
                                 N_("Preferences"),
                                 null, N_("Change Marlin's preferences"),
                                 action_marlin_settings_callback },
                             /*{ Chrome.ColorAction, null, "ColorAction"),
                                 null, null,
                                 null },*/
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
                                 action_show_hidden_files,
                                 true },
  /* name, stock id */         { "Show Hide Context Pane", null,
  /* label, accelerator */       N_("_Context Pane"), "F7",
  /* tooltip */                  N_("Change the visibility of the context pane"),
                                 action_show_hide_contextview,
  /* is_active */                true },
  /* name, stock id */         { "Show Hide Menubar", null,
  /* label, accelerator */       N_("_Menubar"), "F8",
  /* tooltip */                  N_("Change the visibility of this window's menubar"),
                                 action_show_hide_menubar,
  /* is_active */                true },
  /* name, stock id */         { "Show Hide Sidebar", null,
  /* label, accelerator */       N_("_Places"), "F9",
  /* tooltip */                  N_("Change the visibility of this window's side pane"),
                                 null,
  /* is_active */                true }

        };

        static const Gtk.RadioActionEntry view_radio_entries[] = {
            { "view-as-icons", null,
              N_("Icon View"), "<control>1", null,
              ViewMode.ICON },
            { "view-as-detailed-list", null,
              N_("List View"), "<control>2", null,
              ViewMode.LIST },
            { "view-as-columns", null,
              N_("Columns View"), "<control>3", null,
              ViewMode.MILLER }
        };

        /*enum RowColor {
            NONE,
            BUTTER,
            ORANGE,
            CHOCOLATE,
            CHAMELEON,
            SKYBLUE,
            PLUM,
            RED,
            LIGHTGRAY,
            DARKGRAY,
        }

        static const Gtk.RadioActionEntry color_radio_entries[] = {
            { "set-color-clear", null,
              N_("None"), null, null,
              RowColor.NONE },
            { "set-color-butter", null,
              N_("Butter"), null, null,
              RowColor.BUTTER },
            { "set-color-orange", null,
              N_("Orange"), null, null,
              RowColor.ORANGE },
            { "set-color-chocolate", null,
              N_("Chocolate"), null, null,
              RowColor.CHOCOLATE },
            { "set-color-chameleon", null,
              N_("Green"), null, null,
              RowColor.CHAMELEON },
            { "set-color-skyblue", null,
              N_("Sky Blue"), null, null,
              RowColor.SKYBLUE },
            { "set-color-plum", null,
              N_("Plum"), null, null,
              RowColor.PLUM },
            { "set-color-red", null,
              N_("Scarlet Red"), null, null,
              RowColor.RED },
            { "set-color-lightgray", null,
              N_("Light Gray"), null, null,
              RowColor.LIGHTGRAY },
            { "set-color-darkgray", null,
              N_("Dark Gray"), null, null,
              RowColor.DARKGRAY }
        };*/

    }
}

