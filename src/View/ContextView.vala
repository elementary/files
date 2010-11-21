// 
//  ContextView.vala
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
    public class ContextView : Gtk.EventBox
    {
        private VBox box;
        private Window window;
        private Gdk.Pixbuf icon{
            set{
                image.pixbuf = value;
            }
        }
        
        private Image image;
        private EventBox information_wrap;
        private VBox information;
        private Label label;
    
        public ContextView(Window window){
            this.window = window;
            set_size_request(160, -1);
            
            window.current_tab.selection_changed.connect(update);
            
            var alignment = new Gtk.Alignment(0.5f, 0.381966f, 0, 0); // Yes that is 1 - 1/golden_ratio, in doublt always golden ratio
            box = new VBox(false, 4);
              
            image = new Image.from_stock(Stock.INFO, icon_size_register ("", 128, 128));
            image.set_size_request(-1, 128+24);
            box.pack_start(image, false, false);
            
            label = new Label("Information");
            var font_style = new Pango.FontDescription();
            font_style.set_size(14 * 1000);
            label.modify_font(font_style);
            box.pack_start(label, false, false);
            
            box.pack_start(new Gtk.Separator(Orientation.HORIZONTAL), false, false);
            
            information_wrap = new EventBox();
            
            box.pack_start(information_wrap, false, false);
            
            var info = new List<Pair<string, string>>();
            info.append(new Pair<string, string>("Type", "Information test test test"));
            info.append(new Pair<string, string>("Information", "Test"));
            
            update_info_list(info);
            
            alignment.add(box);
            add(alignment);
            
            alignment.show_all();
        }
        
        public void update(GOF.File gof_file){
            var file_info = gof_file.info;
        
            Nautilus.IconInfo icon_info = Nautilus.IconInfo.lookup(gof_file.icon, 96);
            icon = icon_info.get_pixbuf_nodefault();
            
            var info = new List<Pair<string, string>>();
            info.append(new Pair<string, string>("Type", file_info.get_content_type()));
            info.append(new Pair<string, string>("Size", file_info.get_size().to_string()));
            TimeVal modified;
            file_info.get_modification_time(out modified);
            info.append(new Pair<string, string>("Modified", modified.to_iso8601()));
            
            label.label = file_info.get_display_name();
            
            update_info_list(info);
        }
        
        private void update_info_list(List<Pair<string, string>> item_info){
            information = new VBox(false, 2);        
            
            item_info.foreach((pair) => {
                var pair_box = new HBox(true, 5);
                
                var key_alignment = new Alignment(1f, 0f, 0f, 0f);
                var key_label = new Label(((Pair<string, string>) pair).key);
                key_label.set_state(StateType.INSENSITIVE);
                key_label.set_justify(Justification.RIGHT);
                key_label.set_line_wrap(true);
                key_label.set_line_wrap_mode(Pango.WrapMode.WORD);
                key_alignment.add(key_label);
                
                pair_box.pack_start(key_alignment, true, true);
                
                var value_alignment = new Alignment(0f, 0f, 0f, 0f);
                var value_label = new Label(((Pair<string, string>) pair).value);
                value_label.set_line_wrap(true);
                value_label.set_justify(Justification.LEFT);
                value_label.set_line_wrap_mode(Pango.WrapMode.WORD);
                value_alignment.add(value_label);
                
                pair_box.pack_start(value_alignment, true, true);
                
                information.pack_start(pair_box, false, false);
            });
            
            information_wrap.add(information);
            information_wrap.show_all();
        }
    }
}

class Pair<F, G>{
    public F key;
    public G value;

    public Pair(F key, G value){
        this.key = key;
        this.value = value;
    }
}
