//  
//  ViewSwicher.cs
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
	public class ViewSwitcher : ToolItem
	{
		private ModeButton switcher;
		
		//Gdk.Pixbuf iconviewIcon = DrawingService.GetIcon("view-list-icons-symbolic;;view-list-icons", 16);
		//Gdk.Pixbuf detailsviewIcon = DrawingService.GetIcon("view-list-details-symbolic;;view-list-details", 16);
		//Gdk.Pixbuf compactviewIcon = DrawingService.GetIcon("view-list-compact-symbolic;;view-list-compact", 16);
		
		public ViewSwitcher ()
		{
			border_width = 5;
			
			switcher = new ModeButton();
			
			Image modeicons = new Image.from_stock(Stock.ABOUT, IconSize.MENU);
			switcher.append(modeicons);
			Image modedetails = new Image.from_stock(Stock.ABOUT, IconSize.MENU);
			switcher.append(modedetails);
			Image modecompact = new Image.from_stock(Stock.ABOUT, IconSize.MENU);
			switcher.append(modecompact);
			
			switcher.selected = 0;
			//switcher.ModeChanged += delegate(object sender, ModeButtonEventArgs args) {};
			switcher.sensitive = true;
			
			add (switcher);
		}
	}
}

