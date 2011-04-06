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
using Gee;

namespace Marlin.View {
    public class ContextView : Gtk.EventBox
    {
        public const int height = 80;
        public const int width = 190;
        public const int key_value_padding = 8;
        public const int key_value_width = 90;

        public int panel_size{
            get{
                switch(orientation){
                    case(orientation.HORIZONTAL):
                        return height;
                    case(orientation.VERTICAL):
                    default:
                        return width;
                }
            }
        }

        private Window window;
        private Gdk.Pixbuf icon{
            set{
                image.pixbuf = value;
            }
        }

        private Image image;
        private Label label;
        private Gee.List<Pair<string, string>> info;

        private Orientation _orientation = Orientation.HORIZONTAL;
        public Orientation orientation{
            set{
                _orientation = value;
                update_info_panel();
            }
            get{
                return _orientation;
            }
        }

        public Orientation parent_orientation{
            set{
                switch(value){
                    case(Orientation.HORIZONTAL):
                        orientation = orientation.VERTICAL;
                        break;
                    case(Orientation.VERTICAL):
                    default:
                        orientation = orientation.HORIZONTAL;
                        break;
                }
            }
        }

        public ContextView(Window window, bool should_sync, Orientation initialOrientation = Orientation.VERTICAL) {
            this.window = window;
            _orientation = initialOrientation;

            if (should_sync)
                window.selection_changed.connect(update);

            label = new Label("");
            var font_style = new Pango.FontDescription();
            font_style.set_size(14 * 1000);
            label.modify_font(font_style);
            label.ellipsize = Pango.EllipsizeMode.MIDDLE;
            label.set_padding(key_value_padding, -1);

            image = new Image.from_stock(Stock.INFO, window.isize128);
            image.set_size_request(-1, 128+24);

            info = new LinkedList<Pair<string, string>>();
        }

        public void update(GOF.File? gof_file){
            if(gof_file == null){
                gof_file = window.current_tab.slot.directory.file;
            }

            var file_info = gof_file.info;
            Nautilus.IconInfo icon_info = Nautilus.IconInfo.lookup(gof_file.icon, 96);
            icon = icon_info.get_pixbuf_nodefault();

            info.clear();
            var raw_type = file_info.get_file_type();

            /* TODO hide infos for ListView mode: we don't want the COLUMNS infos to show if
               we are in listview: size, type, modified */
            info.add(new Pair<string, string>("Name", gof_file.name));
            info.add(new Pair<string, string>("Type", gof_file.formated_type));

            if (file_info.get_is_symlink())
                info.add(new Pair<string, string>("Target", file_info.get_symlink_target()));
            if(raw_type != FileType.DIRECTORY)
                info.add(new Pair<string, string>("Size", gof_file.format_size));
            /* localized time depending on MARLIN_PREFERENCES_DATE_FORMAT locale, iso .. */
            info.add(new Pair<string, string>("Modified", gof_file.formated_modified.replace(" ", "\n")));
            info.add(new Pair<string, string>("Owner", file_info.get_attribute_string(FILE_ATTRIBUTE_OWNER_USER_REAL)));

            label.label = gof_file.name;

            update_info_panel();
            show();
        }

        private void populate_key_value_pair(Box box, Pair<string, string> pair){
            var key_label = new Label(pair.key);
            key_label.set_state(StateType.INSENSITIVE);
            key_label.set_size_request((int) (key_value_width * 0.618033f), -1);
            key_label.set_justify(Justification.RIGHT);
            key_label.size_allocate.connect((l, s) => l.set_size_request(s.width, -1));
            key_label.set_alignment(1, 0);

            box.pack_start(key_label, true, true, 0);

            var value_label = new Label(((Pair<string, string>) pair).value);
            value_label.set_alignment(0, 0);
            value_label.set_size_request(key_value_width, -1);
            value_label.size_allocate.connect((l, s) => l.set_size_request(s.width, -1));
            value_label.wrap = true;
            value_label.wrap_mode = Pango.WrapMode.WORD_CHAR;
            value_label.set_justify(Justification.LEFT);

            box.pack_start(value_label, true, true, 0);
        }

        public void update_info_panel(){
            if(orientation == Orientation.HORIZONTAL)
                construct_info_panel_horizontal(info);
            else
                construct_info_panel_vertical(info);
        }

        private void construct_info_panel_vertical(Gee.List<Pair<string, string>> item_info){
            set_size_request(panel_size, -1);

            var alignment = new Gtk.Alignment(0.5f, 0.381966f, 0, 0); // Yes that is 1 - 1/golden_ratio, in doublt always golden ratio
            var box = new VBox(false, 4);

            image.parent.remove(image);
            box.pack_start(image, false, false);
            label.parent.remove(label);
            box.pack_start(label, false, false);
            box.pack_start(new Gtk.Separator(Orientation.HORIZONTAL), false, false);

            var information = new VBox (false, key_value_padding);

            int n = 0;
            foreach(var pair in item_info){
                var key_value_pair = new HBox (false, key_value_padding);
                populate_key_value_pair(key_value_pair, pair);

                var alignment_ = new Gtk.Alignment(0, 0, 0, 0);
                alignment_.add(key_value_pair);

                information.pack_start(alignment_, true, true, 0);

                n++;
            }

            box.pack_start(information, true, true);

            alignment.add(box);
            alignment.show_all();

            set_content(alignment);
        }

        private void construct_info_panel_horizontal(Gee.List<Pair<string, string>> item_info){
            set_size_request(-1, panel_size);

            var box = new HBox(false, 0);

            var alignment_img = new Gtk.Alignment(0, 0.5f, 0, 0);
            alignment_img.set_padding(0, 0, 36, 0); // TODO: change this is something more concrete
            image.parent.remove(image);
            alignment_img.add(image);

            box.pack_start(alignment_img, false, false);

            //box.pack_start(label, false, false);
            //box.pack_start(new Gtk.Separator(Orientation.VERTICAL), false, false);

            var table = new Table(2, (int) Math.ceil(item_info.size / 2), false);
            //var columns = new HBox (false, 0);
            //var column = new VBox (false, key_value_padding);

            int n = 0;
            foreach(var pair in item_info){
                var column = (int) Math.floor(n/2);
                var row = n % 2;

                var key_value_pair = new HBox (false, key_value_padding);
                populate_key_value_pair(key_value_pair, pair);

                var alignment = new Gtk.Alignment(0, 0, 0, 0);
                alignment.add(key_value_pair);

                table.attach(alignment, column, column+1, row, row+1, AttachOptions.FILL, AttachOptions.FILL, key_value_padding/2, key_value_padding/2);

                n++;
            }

            var alignment = new Gtk.Alignment(0, 0.5f, 0, 0);
            alignment.add(table);

            box.pack_start(alignment, true, true);
            box.show_all();

            set_content(box);
        }

        private void set_content(Widget w){
            var lw = get_child();
            remove(lw);
            add(w);
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
}

