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
            set_size_request(150, -1);
            
            window.selection_changed.connect(update);
            
            var alignment = new Gtk.Alignment(0.5f, 0.381966f, 0, 0); // Yes that is 1 - 1/golden_ratio, in doublt always golden ratio
            box = new VBox(false, 4);
              
            image = new Image.from_stock(Stock.INFO, window.isize128);
                                         /*icon_size_from_name ("128px"));
                                         icon_size_register ("128px", 128, 128));*/
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
            
            alignment.add(box);
            add(alignment);
            
            alignment.show_all();
        }
        
        public void update(GOF.File? gof_file){
            if(gof_file == null){
                hide();
                return;
            }
        
            var file_info = gof_file.info;
            Nautilus.IconInfo icon_info = Nautilus.IconInfo.lookup(gof_file.icon, 96);
            icon = icon_info.get_pixbuf_nodefault();
            var info = new List<Pair<string, string>>();
            var raw_type = file_info.get_file_type();
            
            info.append(new Pair<string, string>("Mimetype", file_info.get_attribute_string(FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE)));
            if(raw_type != FileType.DIRECTORY)
                info.append(new Pair<string, string>("Size", (file_info.get_size() / 1024).to_string() + " KB")); //TODO nice filesizes
                
            TimeVal modified;
            file_info.get_modification_time(out modified);
            info.append(new Pair<string, string>("Modified", modified.to_iso8601().replace("T", "\n").replace("Z", ""))); //TODO nice localized time
            
            //label.label = file_info.get_display_name();
            label.label = gof_file.name;
            
            update_info_list(info);
            
            show();
        }
        
        private void update_info_list(List<Pair<string, string>> item_info){
            if (information != null)
                information_wrap.remove(information);
            information = new VBox(false, 2);

            Gtk.Table table = new Table (4, 2, false);
            table.set_col_spacing (0, 10);
            table.set_row_spacings (3);
            information.add (table);

            int n = 0;
            item_info.foreach((pair) => {
                var key_alignment = new Alignment(1f, 0f, 0f, 0f);
                var key_label = new Label(((Pair<string, string>) pair).key);
                key_label.set_state(StateType.INSENSITIVE);
                key_label.set_justify(Justification.RIGHT);
                key_label.set_line_wrap(true);
                key_label.set_line_wrap_mode(Pango.WrapMode.WORD);
                key_alignment.add(key_label);
                
                table.attach_defaults (key_alignment, 0, 1, 0+n, 1+n);
                
                var value_alignment = new Alignment(0f, 0f, 0f, 0f);
                var value_label = new Label(((Pair<string, string>) pair).value);
                value_label.set_line_wrap(true);
                value_label.set_justify(Justification.LEFT);
                value_label.set_line_wrap_mode(Pango.WrapMode.WORD);
                value_alignment.add(value_label);
                
                table.attach_defaults (value_alignment, 1, 2, 0+n, 1+n);
                n++;
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
