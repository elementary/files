//  
//  CompactMenu.cs
//  
//  Author:
//       mathijshenquet <mathijs.henquet@gmail.com>
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
        public CheckMenuItem show_menubar;
        public CheckMenuItem show_hiddenitems;
        public ImageMenuItem about;

        public CompactMenu (/*Settings settings*/)
        {
            //
            // Compact Menu
            //

            show_menubar = new CheckMenuItem.with_mnemonic ("Show _Menubar");
            //ShowMenuBar.active = settings.ShowMenuBar;

            show_hiddenitems = new CheckMenuItem.with_mnemonic ("Show _Hidden Items");
            //ShowHiddenItems.active = settings.ShowHiddenItems;

            about = new ImageMenuItem.with_mnemonic ("_About") {
                image = new Image.from_stock (Stock.ABOUT, IconSize.MENU)
            };
            about.activate.connect(() => { });

            append (show_menubar);
            append (new SeparatorMenuItem());
            append (show_hiddenitems);
            append (new SeparatorMenuItem());
            append (about);

            show_all();
        }
    }
}

