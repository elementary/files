//  
//  MenuBar.cs
//  
//  Author:
//       mathijshenquet <${AuthorEmail}>
// 
//  Copyright (c) 2010 mathijshenquet
// 
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
// 
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
// 
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <http://www.gnu.org/licenses/>.
using Gtk;

namespace Marlin.View.Chrome
{
	public class MenuBar : Gtk.MenuBar
	{
		public AccelGroup Accels;
		
		public Menu FileMenu;
		
		public MenuItem go_up;
		public MenuItem go_back;
		public MenuItem go_forward;
		public MenuItem refresh;
		public MenuItem quit;
        public MenuItem about;
		
		public MenuBar (/*Settings settings*/)
		{
			FileMenu = new Menu();
			
			MenuItem file = new MenuItem.with_mnemonic("_File");
			file.submenu = FileMenu;
			
			Accels = new AccelGroup();
			
			quit = new ImageMenuItem.with_mnemonic("_Quit"){
				image = new Image.from_stock (Stock.QUIT, IconSize.MENU)
			};
			quit.add_accelerator("activate", Accels, Gdk.keyval_from_name("q"), Gdk.ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
//			Quit.Activated.connect
			
			Menu gomenu = new Menu();
			MenuItem go = new MenuItem.with_mnemonic("_Go");
			go.submenu = gomenu;
			
			go_back = new ImageMenuItem.with_mnemonic("_Back"){
	    		image = new Image.from_stock (Stock.GO_BACK, IconSize.MENU)
			};
			go_back.add_accelerator("activate", Accels, Gdk.keyval_from_name("Left"), Gdk.ModifierType.MOD1_MASK, AccelFlags.VISIBLE);
			
			go_forward = new ImageMenuItem.with_mnemonic("_Forward"){
	    		image = new Image.from_stock (Stock.GO_FORWARD, IconSize.MENU)
			};
			go_forward.add_accelerator("activate", Accels, Gdk.keyval_from_name("Right"), Gdk.ModifierType.MOD1_MASK, AccelFlags.VISIBLE);

			go_up = new ImageMenuItem.with_mnemonic("Open _Parent"){
	    		image = new Image.from_stock (Stock.GO_UP, IconSize.MENU)
			};
			go_up.add_accelerator("activate", Accels, Gdk.keyval_from_name("Up"), Gdk.ModifierType.MOD1_MASK, AccelFlags.VISIBLE);
			
			refresh = new ImageMenuItem.with_mnemonic("_Refresh"){
	    		image = new Image.from_stock (Stock.REFRESH, IconSize.MENU)
			};
			refresh.add_accelerator("activate", Accels, Gdk.keyval_from_name("F5"), (Gdk.ModifierType) 0, AccelFlags.VISIBLE);
			
		
			Menu viewmenu = new Menu();
	        MenuItem view = new MenuItem.with_mnemonic("_View");
			view.submenu = viewmenu;
			
			CheckMenuItem viewmenubar = new CheckMenuItem.with_mnemonic("_Menubar");
			//viewmenubar.active = settings.ShowMenuBar;
			viewmenubar.add_accelerator("activate", Accels, Gdk.keyval_from_name("m"), Gdk.ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
	        viewmenubar.toggled.connect(() => {
				//settings.ShowMenuBar = viewmenubar.active;
			});
			
			CheckMenuItem showhiddenbar = new CheckMenuItem.with_mnemonic ("Show _Hidden Items");
			//showhiddenbar.active = settings.ShowHiddenItems;
			showhiddenbar.add_accelerator("activate", Accels, Gdk.keyval_from_name("h"), Gdk.ModifierType.CONTROL_MASK, AccelFlags.VISIBLE);
	        showhiddenbar.toggled.connect(() => {
				//settings.ShowHiddenItems = showhiddenbar.Active;
			});
			/*settings.ShowHiddenItemsChanged.format(() => {
				showhiddenbar.active = (bool) e.Value;
			});*/
			
			Menu helpmenu = new Menu();
			MenuItem help = new MenuItem.with_mnemonic("_Help");
			help.submenu = helpmenu;
			
			about = new ImageMenuItem.with_mnemonic("_About"){
	    		image = new Image.from_stock (Stock.ABOUT, IconSize.MENU)
			};
			//about.activate += new EventHandler(Marlin.ShowAbout);
			
			FileMenu.append(quit);
			gomenu.append(go_back);
			gomenu.append(go_forward);
			gomenu.append(go_up);
			gomenu.append(refresh);
			viewmenu.append(viewmenubar);
//			viewmenu.append();
			viewmenu.append(showhiddenbar);
			helpmenu.append(about);
			
			append(file);
			append(go);
			append(view);
			append(help);
		}
	}
}

