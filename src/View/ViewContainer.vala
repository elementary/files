// 
//  ViewContainer.vala
//  
//  Author:
//       Mathijs Henquet <mathijs.henquet@gmail.com>
// 
//  Copyright (c) 2010 Mathijs Henquet
// 
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 2 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//  
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
// 
using Gtk;

namespace Marlin.View {
	public class ViewContainer : Gtk.EventBox {
		public Gtk.Widget? content_item;
		public Gtk.Label label;
		private Marlin.View.Window? window;
                public GOF.Window.Slot? slot;
                Browser<string> browser;
		
                public signal void path_changed(File file);
                public signal void up();
                public signal void back();
                public signal void forward();

		public ViewContainer(Marlin.View.Window win, File location){
                        //stdout.printf ("$$$$ ViewContainer new\n");
                        window = win;
                        browser =  new Browser<string> ();
                        slot = new GOF.Window.Slot(location, this);
                        //content_item = slot.get_view();
			//label = new Gtk.Label("test");
			label = new Gtk.Label(slot.directory.get_uri());
                        label.set_ellipsize(Pango.EllipsizeMode.END);
                        label.set_single_line_mode(true);
                        label.set_alignment(0.0f, 0.5f);
                        label.set_padding(0, 0);
                        update_location_state(true);
			
			//add(content_item);	
			
			this.show_all();

                        path_changed.connect((myfile) => {
                                slot = new GOF.Window.Slot(myfile, this);
                                update_location_state(true);
			});
                        up.connect(() => {
                                if (slot.directory.has_parent()) {
                                        slot = new GOF.Window.Slot(slot.directory.get_parent(), this);
                                        update_location_state(true);
                                }
			});
                        back.connect(() => {
                                slot = new GOF.Window.Slot(File.new_for_commandline_arg(browser.go_back()) , this);
                                update_location_state(false);
                        });
                        forward.connect(() => {
                                slot = new GOF.Window.Slot(File.new_for_commandline_arg(browser.go_forward()) , this);
                                update_location_state(false);
                        });

		}

                public Widget content{
			set{
                                if (content_item != null)
        				remove(content_item);
				add(value);
				content_item = value;
				content_item.show();
                                ((Bin)value).get_child().grab_focus();
			}
			get{
				return content_item;
			}
		}
		
		public string tab_name{
			set{
				label.label = value;	
			}
		}
		
                public void update_location_state(bool save_history)
                {
                        window.can_go_up = slot.directory.has_parent();
			tab_name = window.top_menu.location_bar.path = slot.directory.get_uri();
                        if (save_history)
                                browser.record_uri(slot.directory.get_uri());
                        window.can_go_back = browser.can_go_back();
                        window.can_go_forward = browser.can_go_forward();
                }
	}
}
