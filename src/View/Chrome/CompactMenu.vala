//  
//  CompactMenu.cs
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
	public class CompactMenu : Gtk.Menu
	{
		public CheckMenuItem show_menu_bar;
		public CheckMenuItem show_hidden_items;
		public ImageMenuItem about;
		
		public CompactMenu (/*Settings settings*/)
		{
			//
			// Compact Menu
			//
			
			show_menu_bar = new CheckMenuItem.with_mnemonic ("Show _Menubar");
			//ShowMenuBar.active = settings.ShowMenuBar;
			
			show_menu_bar.toggled.connect(() => {
				//settings.ShowMenuBar = ShowMenuBar.Active;	
			});
			/*settings.ShowMenuBarChanged.connect(() => {
				ShowMenuBar.Active = (bool) e.Value;
			});*/
			
			show_hidden_items = new CheckMenuItem.with_mnemonic ("Show _Hidden Items");
			//ShowHiddenItems.Active = settings.ShowHiddenItems;
			
	        show_hidden_items.toggled.connect( () => {
				//settings.ShowHiddenItems = ShowHiddenItems.Active;	
			});
			/*settings.ShowHiddenItemsChanged.connect( (value) => {
				ShowHiddenItems.Active = (bool) e.Value;
			});*/
			
			about = new ImageMenuItem.with_mnemonic ("_About") {
	    		image = new Image.from_stock (Stock.ABOUT, IconSize.MENU)
			};
			about.activate.connect(() => { });
			
			append (show_menu_bar);
			append (new SeparatorMenuItem());
			append (show_hidden_items);
			append (new SeparatorMenuItem());
			append (about);
			
			show_all();
		}
	}
}

