//  
//  LocationBar.cs
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
	public class LocationBar : ToolItem
	{
		private Entry entry;
		
		public new string path{
			set{
                var new_path = value;

                if(new_path.has_prefix("file://")){
                    new_path = new_path.substring(6);
                }

				entry.text = new_path;
			}
			get{
				return entry.text;
			}
		}
		
		public new signal void activate();
		
		public LocationBar ()
		{
			entry = new Entry ();
			
			set_expand(true);
			add(entry);
			
			entry.activate.connect(() => { activate(); });
		}
	}
}

