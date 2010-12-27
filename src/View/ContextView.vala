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
        public static int width{
            get{
                return 180;
            }
        }

        private VBox box;
        private Window window;
        private Gdk.Pixbuf icon{
            set{
                image.pixbuf = value;
            }
        }

        private Image image;
        private EventBox information_wrap;
        private Table information;
        private Label label;

        public ContextView(Window window){
            this.window = window;
            set_size_request(width, -1);

            window.selection_changed.connect(update);

            var alignment = new Gtk.Alignment(0.5f, 0.381966f, 0, 0); // Yes that is 1 - 1/golden_ratio, in doublt always golden ratio
            box = new VBox(false, 4);

            image = new Image.from_stock(Stock.INFO, window.isize128);
            image.set_size_request(-1, 128+24);
            box.pack_start(image, false, false);

            label = new Label("");
            var font_style = new Pango.FontDescription();
            font_style.set_size(14 * 1000);
            label.modify_font(font_style);
            label.ellipsize = Pango.EllipsizeMode.MIDDLE;
            box.pack_start(label, false, false);

            box.pack_start(new Gtk.Separator(Orientation.HORIZONTAL), false, false);

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

            /* TODO hide infos for ListView mode: we don't want the COLUMNS infos to show if
               we are in listview: size, type, modified */
            //info.append(new Pair<string, string>("Name", gof_file.name));
            var nice_type = ContentType.get_description(file_info.get_attribute_string(FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE));
            info.append(new Pair<string, string>("Type", nice_type));
            if(raw_type != FileType.DIRECTORY)
                info.append(new Pair<string, string>("Size", gof_file.format_size));
            /* localized time depending on MARLIN_PREFERENCES_DATE_FORMAT locale, iso .. */
            info.append(new Pair<string, string>("Modified", gof_file.formated_modified.replace(" ", "\n")));
            info.append(new Pair<string, string>("Owner", file_info.get_attribute_string(FILE_ATTRIBUTE_OWNER_USER_REAL)));
            info.append(new Pair<string, string>("Mimetype", file_info.get_attribute_string(FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE)));

            //label.label = file_info.get_display_name();
            label.label = gof_file.name;

            update_info_list(info);

            show();
        }

        private void update_info_list(List<Pair<string, string>> item_info){
            int spacing = 10;

            if (information != null)
                box.remove(information);

            information = new Table (item_info.length(), 2, false);
            information.set_col_spacings (spacing);
            information.set_row_spacings (3);

            int n = 0;
            item_info.foreach((pair) => {
                var key_alignment = new Alignment(1f, 0f, 0f, 0f);
                var key_label = new Label(((Pair<string, string>) pair).key);
                key_label.set_state(StateType.INSENSITIVE);
                key_label.set_justify(Justification.RIGHT);
                key_label.set_single_line_mode(false);
                key_label.set_line_wrap(true);
                key_label.set_line_wrap_mode(Pango.WrapMode.CHAR);
                key_alignment.add(key_label);

                information.attach_defaults (key_alignment, 0, 1, 0+n, 1+n);

                var value_alignment = new Alignment(0f, 0f, 0f, 0f);
                var value_label = new Label(((Pair<string, string>) pair).value);
                value_label.set_line_wrap(true);
                value_label.set_single_line_mode(false);
                value_label.set_justify(Justification.LEFT);
                value_label.set_line_wrap_mode(Pango.WrapMode.CHAR);
                value_alignment.add(value_label);

                information.attach_defaults (value_alignment, 1, 2, 0+n, 1+n);
                n++;
            });

            box.pack_start(information, false, false);
            information.show_all();
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

