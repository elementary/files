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
using Cairo;

namespace Marlin.View {
	public class Window : Gtk.Window
	{
		public Chrome.MenuBar menu_bar;
		public Chrome.TopMenu top_menu;
		public Notebook tabs;
                private IconSize isize13;
		
		public ViewContainer current_tab;

                public bool can_go_up{
			set{
				top_menu.go_up.sensitive = value;
				menu_bar.go_up.sensitive = value;
			}
		}
		
		public bool can_go_forward{
			set{
				top_menu.go_forward.sensitive = value;
				menu_bar.go_forward.sensitive = value;
			}
		}
		
		public bool can_go_back{
			set{
				top_menu.go_back.sensitive = value;
				menu_bar.go_back.sensitive = value;
			}
		}

		public signal void show_about();		
		public signal void refresh();
                //public signal void viewmode_changed(ViewMode mode);
        
		
//		new Settings Settings;
		
		public Window ()
		{
			/*/
                        /* Menubar
                        /*/

			menu_bar = new Chrome.MenuBar();
			
			add_accel_group(menu_bar.Accels);
			
			/*/
                        /* Topmenu
                        /*/
			
			top_menu = new Chrome.TopMenu();//Settings);
			top_menu.location_bar.path = "";
		
		
			/*/
			/* Contents
			/*/
			
			tabs = new Notebook();
			tabs.show_border = false;
			tabs.show_tabs = false;
			
			//view = new View();
                        isize13 = icon_size_register ("13px", 13, 13);

			/*/
                        /* Pack up all the view
                        /*/
			
			VBox vbox = new VBox(false, 0);
			vbox.pack_start(menu_bar, false, false, 0);
			vbox.pack_start(top_menu, false, false, 0);
			vbox.pack_start(tabs, true, true, 0);

			add(vbox);
                        set_default_size(760, 450);
			set_position(WindowPosition.CENTER);	
			title = "Marlin";
			//this.icon = DrawingService.GetIcon("system-file-manager", 32);
			show_menu_bar(true);
                        show_all();
            
                        /*/
                        /* Connect and abstract signals to local ones
                        /*/
		
			top_menu.go_up.clicked.connect(() => { current_tab.up(); });
			top_menu.go_forward.clicked.connect(() => { current_tab.forward(); });
			top_menu.go_back.clicked.connect(() => { current_tab.back(); });
            top_menu.refresh.clicked.connect(() => { refresh(); });
            top_menu.compact_menu.about.activate.connect(() => { show_about(); });
            //top_menu.view_switcher.viewmode_change.connect((mode) => { viewmode_changed(mode); }); 
		        menu_bar.new_tab.activate.connect(() => { add_tab(File.new_for_commandline_arg(Environment.get_home_dir())); });	
			menu_bar.go_up.activate.connect(() => { current_tab.up(); });
			menu_bar.go_forward.activate.connect(() => { current_tab.forward(); });
			menu_bar.go_back.activate.connect(() => { current_tab.back(); });
            menu_bar.refresh.activate.connect(() => { refresh(); });
            menu_bar.about.activate.connect(() => { show_about(); });
            menu_bar.quit.activate.connect(() => { main_quit(); });
			
            delete_event.connect(() => { main_quit(); });
            
            tabs.switch_page.connect((page, offset) => {
                //stdout.printf ("tab changed: %u\n", offset);
                current_tab = (ViewContainer) tabs.get_children().nth_data(offset);
                if (current_tab.slot != null)
                        current_tab.update_location_state(false);
            });


		}
		
		
		
		//public void add_tab(ViewContainer content){
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
			
			tabs.append_page(content, hbox);
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
				return;
			}
			
			tabs.remove(view_container);
		}
		
		public void show_menu_bar(bool show)
		{
			//Settings.ShowMenuBar = show;
			if (show) {
				menu_bar.show();
			} else {
				menu_bar.hide();
			}
		}
    }
}
