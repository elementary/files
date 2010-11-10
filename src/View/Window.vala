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
using Gee;

namespace Marlin.View {
	public class Window : Gtk.Window
	{
		Chrome.MenuBar menu_bar;
		Chrome.TopMenu top_menu;
		EventBox content_box;
		Widget content_item;
                Object active_slot_item;
                Browser<string> browser;
		
		public Widget content{
			set{
				content_box.remove(content_item);
				content_box.add(value);
				content_item = value;
				content_item.show();
                                ((Bin)value).get_child().grab_focus();
			}
			get{
				return content_item;
			}
		}

                public Object active_slot{
                        set{
                                active_slot_item = value;
                        }
                        get{
                                return active_slot_item;
                        }
                }
		
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

		public signal void up();
		public signal void refresh();
		public signal void quit();
		public signal void column_path_changed(File file);
		public signal void path_changed(File file);
		public signal void browser_path_changed(File file);
        public signal void show_about();
		
//		new Settings Settings;
		
		public Window (string path)
		{
			/*/
            /* Menubar
            /*/

			menu_bar = new Chrome.MenuBar();
			
			add_accel_group(menu_bar.Accels);
			
			/*/
            /* Topmenu
            /*/
                        browser =  new Browser<string> ();	

			top_menu = new Chrome.TopMenu();//Settings);
			
			top_menu.location_bar.activate.connect(() => {
				path_changed(File.new_for_commandline_arg(top_menu.location_bar.path));
			});
			path_changed.connect((myfile) => {
                                update_location_state(myfile, true);
			});
                        /* allow the column to change the location path */
                        column_path_changed.connect((myfile) => {
				top_menu.location_bar.path = myfile.get_path();
                        });
			top_menu.location_bar.path = path;
		
		
			/*/
			/* Contents
            /* TODO: Implement this
			/*/
			
			content_box = new EventBox();
			content_item = new Label("Loading..."); 
			content_box.add(content_item);
			
			//view = new View();

			/*/
            /* Pack up all the view
            /*/
			
			VBox vbox = new VBox(false, 0);
			vbox.pack_start(menu_bar, false, false, 0);
			vbox.pack_start(top_menu, false, false, 0);
			vbox.pack_start(content_box, true, true, 0);

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
			
			top_menu.go_up.clicked.connect(() => { up(); });
			top_menu.go_forward.clicked.connect(() => { go_forward(); });
			top_menu.go_back.clicked.connect(() => { go_back(); });
            //top_menu.refresh.clicked.connect(() => { refresh(); });
            top_menu.compact_menu.about.activate.connect(() => { show_about(); });
			
			menu_bar.go_up.activate.connect(() => { up(); });
			menu_bar.go_forward.activate.connect(() => { go_forward(); });
			menu_bar.go_back.activate.connect(() => { go_back(); });
            menu_bar.refresh.activate.connect(() => { refresh(); });
            menu_bar.about.activate.connect(() => { show_about(); });
            menu_bar.quit.activate.connect(() => { quit(); });


                        //unowned Gtk.BindingSet binding_set;

                        //binding_set = Gtk.BindingSet.by_class (typeof (Window).class_ref ());
                        /*binding_set = Gtk.BindingSet.by_class (this.get_class());
                        Gtk.BindingEntry.add_signal (binding_set, Gdk.keyval_from_name ("plus"), 0, "show-about", 0);*/
                        /*Signal.connect (this, "up",
                    (GLib.Callback)up, null);*/


            delete_event.connect(() => { quit(); });
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

                private void go_back()
                {
		        var myfile = File.new_for_commandline_arg(browser.go_back());
                        browser_path_changed(myfile);
                        update_location_state(myfile, false);
                }
		
                private void go_forward()
                {
		        var myfile = File.new_for_commandline_arg(browser.go_forward());
                        browser_path_changed(myfile);
                        update_location_state(myfile, false);
                }
		
                private void update_location_state(File myfile, bool save_history)
                {
                        can_go_up = (myfile.get_parent() != null);
			var p = myfile.get_path();
			top_menu.location_bar.path = p;
                        if (save_history)
                                browser.record_uri(p);
                        can_go_back = browser.can_go_back();
                        can_go_forward = browser.can_go_forward();
                }
    }
}
