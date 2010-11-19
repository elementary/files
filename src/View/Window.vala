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

namespace Marlin.View {
    public class Window : Gtk.Window
    {
        public UIManager ui;
        public Widget menu_bar;
        public Chrome.TopMenu top_menu;
        public Notebook tabs;
        private IconSize isize13;
        
        public ViewContainer current_tab;

        public Gtk.ActionGroup main_actions;
        public Gtk.AccelGroup accel_group;

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

        //public signal void refresh();

        public void update_action_radio_view(int n) {
            Gtk.RadioAction action = (Gtk.RadioAction) main_actions.get_action("view-as-detailed-list");
            assert(action != null);
            action.set_current_value(n);
        }

        protected virtual void action_radio_change_view(){
            Gtk.RadioAction action = (Gtk.RadioAction) main_actions.get_action("view-as-detailed-list");
            assert(action != null);
            int n = action.get_current_value();
            /* change the view only for view_mode real change */
            if (n != current_tab.view_mode)
                current_tab.change_view(n, null);
        }
        
        public Window (GLib.Settings settings)
        {   
            ui = new UIManager();

            try {
                ui.add_ui_from_file(Config.UI_DIR + "marlin-ui.xml");
            } catch (Error e) {
                stderr.printf ("Error loading UI: %s", e.message);
            }

            main_actions = new Gtk.ActionGroup("MainActionGroup");
            main_actions.add_actions(main_entries, this);
            main_actions.add_toggle_actions(main_toggle_entries, this);
            main_actions.add_radio_actions(view_radio_entries, -1, 
                                           action_radio_change_view);
            accel_group = ui.get_accel_group();
            add_accel_group(accel_group);
            
            ui.insert_action_group(main_actions, 0);
            ui.ensure_update();


            /* Menubar */
            menu_bar = ui.get_widget("/MenuBar");
 
            /* Topmenu */
            top_menu = new Chrome.TopMenu(this);

            if (top_menu.location_bar != null) {
                //top_menu.location_bar.path = "";

                top_menu.location_bar.activate.connect(() => {
                    current_tab.path_changed(File.new_for_commandline_arg(top_menu.location_bar.path));
                });
            }
        
        
            /* Contents */
            tabs = new Notebook();
            tabs.show_border = false;
            tabs.show_tabs = false;
            tabs.show();
            
            //view = new View();
            isize13 = icon_size_register ("15px", 15, 15);

            /* Sidebar */
            var sidebar = new Label("Sidebar");
            sidebar.set_size_request(150, -1);

            /* Devide main views into sidebars */
            var main_box = new HPaned();
            main_box.show();
            main_box.pack1(sidebar, false, true);
            main_box.pack2(tabs, true, false);

            /*/
            /* Pack up all the view
            /*/

            VBox window_box = new VBox(false, 0);
            window_box.show();
            window_box.pack_start(menu_bar, false, false, 0);
            window_box.pack_start(top_menu, false, false, 0);
            window_box.pack_start(main_box, true, true, 0);

            add(window_box);
            set_default_size(760, 450);
            set_position(WindowPosition.CENTER);    
            title = Resources.APP_TITLE;
            //this.icon = DrawingService.GetIcon("system-file-manager", 32);
            show();

            Preferences.settings.bind("show-menubar", menu_bar, "visible", 0);
            Preferences.settings.bind("show-menubar", main_actions.get_action("Show Hide Menubar"), "active", 0);
            //Preferences.settings.bind("show-menubar", top_menu.compact_menu_button, "visible", SettingsBindFlags.INVERT_BOOLEAN);
            Preferences.settings.bind("show-hiddenfiles", main_actions.get_action("Show Hidden Files"), "active", 0);
            Preferences.settings.bind("show-sidebar", sidebar, "visible", 0);
            Preferences.settings.bind("show-sidebar", main_actions.get_action("Show Hide Sidebar"), "active", 0);

            top_menu.view_switcher.view_changed.connect((mode) => {
                Preferences.settings.set_enum("default-viewmode", mode);
            });

            /*/
            /* Connect and abstract signals to local ones
            /*/
       
            delete_event.connect(() => { main_quit(); });
            
            tabs.switch_page.connect((page, offset) => {
                change_tab(offset);
            });

            tabs.scroll_event.connect((scroll) => {
                uint offset = tabs.get_current_page();

                if(scroll.direction == ScrollDirection.UP)
                    offset++;
                else if(scroll.direction == ScrollDirection.DOWN)
                    offset--;

                if(offset<1)
                    offset = 0;
                else if(offset>=tabs.get_children().length())
                    offset = tabs.get_children().length();

                change_tab(offset);                
                tabs.set_current_page((int) offset);
            });
            
            top_menu.view_switcher.view_changed.connect((mode) => {
                Gtk.Action action;

                //You cannot do a switch here, only for int and string
                if (mode == ViewMode.LIST){
                    action = main_actions.get_action("view-as-detailed-list");
                    action.activate();
                } else if (mode == ViewMode.MILLER){
                    action = main_actions.get_action("view-as-columns");
                    action.activate();
                }
            });

            /* Binding Backspace keyboard shortcut */
            unowned Gtk.BindingSet binding_set;

            binding_set = Gtk.BindingSet.by_class (typeof (Marlin.View.Window).class_ref ());
            action_new (typeof (Marlin.View.Window), "go_up");
            Gtk.BindingEntry.add_signal (binding_set, Gdk.keyval_from_name ("BackSpace"), 0, "go_up", 0);
            Signal.connect (this, "go_up",
                    (GLib.Callback)action_go_up, null);
        }

        public void change_tab(uint offset){
            current_tab = (ViewContainer) tabs.get_children().nth_data(offset);
            if (current_tab != null && current_tab.slot != null) {
                current_tab.update_location_state(false);
                /* update radio action view state */
                update_action_radio_view(current_tab.view_mode);
                /* focus the main view */
                /* FIXME not a smart move it's crashing when opening / closing tabs */
                /*((Bin)current_tab.slot.get_view()).get_child().grab_focus();*/
            }
        }        
        
        public void add_tab(File location){
            ViewContainer content = new View.ViewContainer(this, location);
            var hbox = new HBox(false, 0);
            hbox.pack_start(content.label, true, true, 0);
            //var image = new Image.from_stock(Stock.CLOSE, IconSize.MENU);
            //var image = new Image.from_stock(Stock.CLOSE, IconSize.BUTTON);
            /* TODO reduce the size of the tab */
            var image = new Image.from_stock(Stock.CLOSE, isize13);
            var button = new Button();
            button.set_relief(ReliefStyle.NONE);
            button.set_focus_on_click(false);
            //button.set_name("marlin-tab-close-button");
            button.add(image);
            var style = new RcStyle();
            style.xthickness = 0;
            style.ythickness = 0;
            button.modify_style(style);
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
            });
            
            tabs.append_page(content, eventbox);
            tabs.child_set (content, "tab-expand", true, null );

            tabs.set_tab_reorderable(content, true);
            tabs.show_tabs = tabs.get_children().length() > 1;        
                                
            /* jump to that new tab */
            tabs.set_current_page(tabs.get_n_pages()-1); 
            current_tab = content;
        }
        
        public void remove_tab(ViewContainer view_container){            
            if(tabs.get_children().length() == 2){
                tabs.show_tabs = false;
            }else if(tabs.get_children().length() == 1){
                main_quit();
                return;
            }
            
            tabs.remove(view_container);
        }
        
        private void action_new_tab (Gtk.Action action) {
            add_tab(File.new_for_commandline_arg(Environment.get_home_dir()));
        }

        private void action_remove_tab (Gtk.Action action) {
            remove_tab(current_tab);
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

        private void action_go_back (Gtk.Action action) {
            current_tab.back();
        }

        private void action_go_forward (Gtk.Action action) {
            current_tab.forward();
        }
        
        private void action_show_hidden_files (Gtk.Action action) {
            /* simply reload the view as show-hiddenfiles is a binded settings*/
            current_tab.reload();
        }
        
        private void action_show_hide_menubar (Gtk.Action action) {
            bool vis = true;
            menu_bar.get("visible", &vis);
            if (vis)
                top_menu.compact_menu_button.hide();
            else
                top_menu.compact_menu_button.show_all();
        }

        /*private void action_show_hide_sidebar (Gtk.Action action) {
            stdout.printf ("TODO\n");
        }*/

        private void action_home_callback (Gtk.Action action) {
                current_tab.path_changed(File.new_for_commandline_arg(Environment.get_home_dir()));
        }

        private void action_go_to_trash_callback (Gtk.Action action) {
                current_tab.path_changed(File.new_for_commandline_arg(Resources.MARLIN_TRASH_URI));
        }

        private void action_go_to_network_callback (Gtk.Action action) {
                current_tab.path_changed(File.new_for_commandline_arg(Resources.MARLIN_NETWORK_URI));
        }

        protected void show_about() {
        Gtk.show_about_dialog(this,
            "program-name", Resources.APP_TITLE,
            "version", Config.VERSION,
            "comments", Resources.COMMENTS,
            "copyright", Resources.COPYRIGHT,
            "license", Resources.LICENSE,
            "website", Resources.ELEMENTARY_URL,
            "website-label",  Resources.ELEMENTARY_LABEL,
            "authors", Resources.AUTHORS,
            "artists", Resources.ARTISTS,
            "logo-icon-name", Resources.ICON_ABOUT_LOGO,
            "translator-credits", _("translator-credits"),
            null);
        }

        static const Gtk.ActionEntry[] main_entries = {
  /* name, stock id, label */  { "File", null, N_("_File") },
  /* name, stock id, label */  { "Edit", null, N_("_Edit") },
  /* name, stock id, label */  { "View", null, N_("_View") },
  /* name, stock id, label */  { "Go", null, N_("_Go") },
  /* name, stock id, label */  { "Help", null, N_("_Help") },
  /* name, stock id */         { "New Tab", "tab-new",
  /* label, accelerator */       N_("New _Tab"), "<control>T",
  /* tooltip */                  N_("Open another tab for the displayed location"),
                                 action_new_tab },
  /* name, stock id */         { "Close", Stock.CLOSE,
  /* label, accelerator */       N_("_Close"), "<control>W",
  /* tooltip */                  N_("Close this folder"),
                                 action_remove_tab },
                               { "ToolbarEditor", Stock.PREFERENCES,
                                 N_("Customize _Toolbar"),               
                                 null, N_("Easily edit the toolbar layout"),
                                 action_toolbar_editor_callback },
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
  /* name, stock id */         { "Home", Resources.MARLIN_ICON_HOME,
  /* label, accelerator */       N_("_Home Folder"), "<alt>Home",
  /* tooltip */                  N_("Open your personal folder"),
                                 action_home_callback },
  /* name, stock id */         { "Go to Trash", Resources.MARLIN_ICON_TRASH,
  /* label, accelerator */       N_("_Trash"), null,
  /* tooltip */                  N_("Open your personal trash folder"),
                                 action_go_to_trash_callback },
  /* name, stock id */         { "Go to Network", Resources.MARLIN_ICON_NETWORK,
  /* label, accelerator */       N_("_Network"), null,
  /* tooltip */                  N_("Browse bookmarked and local network locations"),
                                 action_go_to_network_callback },
  /* name, stock id */         { "About", Stock.ABOUT,
  /* label, accelerator */       N_("_About"), null,
  /* tooltip */                  N_("Display credits"),
                                 show_about }


        };

        static const Gtk.ToggleActionEntry main_toggle_entries[] = {
  /* name, stock id */         { "Show Hidden Files", null,
  /* label, accelerator */       N_("Show _Hidden Files"), "<control>H",
  /* tooltip */                  N_("Toggle the display of hidden files in the current window"),
                                 action_show_hidden_files,
                                 true },
  /* name, stock id */         { "Show Hide Menubar", null,
  /* label, accelerator */       N_("_Menubar"), "F8",
  /* tooltip */                  N_("Change the visibility of this window's menubar"),
                                 action_show_hide_menubar,
  /* is_active */                true }, 
  /* name, stock id */         { "Show Hide Sidebar", null,
  /* label, accelerator */       N_("_Side Pane"), "F9",
  /* tooltip */                  N_("Change the visibility of this window's side pane"),
                                 null,
  /* is_active */                true }

        };
        
        static const Gtk.RadioActionEntry view_radio_entries[] = {
            /*{ "view-as-icons", null,
              N_("Icon View"), null, null,
              0 },*/
            { "view-as-detailed-list", null,
              N_("List View"), "<control>1", null,
              ViewMode.LIST },
            { "view-as-columns", null,
              N_("Columns View"), "<control>2", null,
              ViewMode.MILLER }
        };
    }
}
