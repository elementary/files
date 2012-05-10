//  
//  ViewSwicher.cs
//  
//  Authors:
//       mathijshenquet <mathijs.henquet@gmail.com>
//       ammonkey <am.monkeyd@gmail.com>
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
using Granite.Widgets;
using Config;

namespace Marlin.View.Chrome
{
    public class ViewSwitcher : ToolItem
    {
        public ModeButton switcher;
        
        private ViewMode _mode;
        public ViewMode mode{
        //private ViewMode mode{
            set{
                Widget target;

                switch (value) {
                case ViewMode.LIST:
                    target = list;
                    break;
                case ViewMode.COMPACT:
                    target = compact;
                    break;
                case ViewMode.MILLER:
                    target = miller;
                    break;
                default:
                    target = icon;
                    break;
                }

                Preferences.settings.set_enum ("default-viewmode", value);
                //switcher.focus(target);
                //switcher.set_active_widget (target);
                _mode = mode;
            }
            private get{
                return _mode;
            }
        }

        private Gtk.ActionGroup main_actions;

        private Image icon;
        private Image list;
        private Image compact;
        private Image miller;

        public ViewSwitcher (Gtk.ActionGroup action_group)
        {
            main_actions = action_group;
            //border_width = 6;
            margin = 3;

            switcher = new ModeButton ();
            switcher.set_margin_top (5);
            switcher.set_margin_bottom (5);
            Varka.IconFactory icon_factory = Varka.IconFactory.get_default ();
            Gtk.StyleContext style = get_style_context ();

            icon = new Image.from_pixbuf (icon_factory.load_symbolic_icon (style, "view-list-icons-symbolic", 16));
            switcher.append(icon);
            list = new Image.from_pixbuf (icon_factory.load_symbolic_icon (style, "view-list-details-symbolic", 16));
            switcher.append(list);
            compact = new Image.from_pixbuf (icon_factory.load_symbolic_icon (style, "view-list-compact-symbolic", 16));
            switcher.append(compact);
            miller = new Image.from_pixbuf (icon_factory.load_symbolic_icon (style, "view-list-column-symbolic", 16));
            switcher.append(miller);
            
            mode = (ViewMode)Preferences.settings.get_enum("default-viewmode");
           
            switcher.mode_changed.connect((mode) => {
                Gtk.Action action;

                //You cannot do a switch here, only for int and string
                if (mode == list){
                    action = main_actions.get_action("view-as-detailed-list");
                    action.activate();
                } else if (mode == compact){
                    action = main_actions.get_action("view-as-compact");
                    action.activate();
                } else if (mode == miller){
                    action = main_actions.get_action("view-as-columns");
                    action.activate();
                } else {
                    action = main_actions.get_action("view-as-icons");
                    action.activate();
                }
                
            });

            switcher.sensitive = true;

            add (switcher);
        }
    }
}

