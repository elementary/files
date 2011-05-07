//
//  ContextView.vala
//
//  Authors:
//       Mathijs Henquet <mathijs.henquet@gmail.com>
//       ammonkey <am.monkeyd@gmail.com>
//
//  Copyright (c) 2011 Mathijs Henquet
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

    class AppButton : Gtk.Button
    {
        AppInfo app_info;
        GOF.File file;
        HBox hbox;
        public AppButton(AppInfo app_info, GOF.File file)
        {
            this.app_info = app_info;
            this.file = file;
            Image image;
            if(app_info.get_icon() == null)
                image = new Image.from_stock(Gtk.Stock.EXECUTE, IconSize.BUTTON);
            else
                image = new Image.from_gicon(app_info.get_icon(), IconSize.BUTTON);
            //set_image(image);
            hbox = new HBox(false, 5);
            hbox.pack_start(image, false, false);
            set_tooltip_text(app_info.get_name());
            if((bool)Preferences.settings.get_value("show-open-with-text"))
            {
                var label = new Label(app_info.get_name());
                label.ellipsize = Pango.EllipsizeMode.END;
                label.set_alignment(0, 0.5f);
                hbox.pack_start(label, true, true);
            }
            add(hbox);
            pressed.connect(() => { file.launch_with(get_screen(), app_info); } );
        }
    }

    public class ContextView : Gtk.EventBox
    {
        public const int height = -1;
        public const int width = 190;
        public const int key_value_padding = 8;
        public const int key_value_width = 90;
        public Gtk.Menu toolbar_menu;
        private Box apps;
        private ScrolledWindow apps_scrolled;

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

        private GOF.File? last_geof_cache = null;

        private Orientation _orientation = Orientation.HORIZONTAL;
        public Orientation orientation{
            set{
                _orientation = value;
                update(last_geof_cache);
            }
            get{
                return _orientation;
            }
        }

        public Orientation parent_orientation{
            set{
                orientation = convert_parent_orientation(value);
            }
        }

        private Orientation convert_parent_orientation(Orientation o){
            switch(o){
                case(Orientation.HORIZONTAL):
                    return orientation.VERTICAL;
                case(Orientation.VERTICAL):
                default:
                    return orientation.HORIZONTAL;
            }
        }

        public ContextView(Window window, bool should_sync, Orientation parent_orientation = Orientation.VERTICAL) {
            this.window = window;
            _orientation = convert_parent_orientation(parent_orientation);

            if (should_sync)
                window.selection_changed.connect(update);

            label = new Label("");
            var font_style = new Pango.FontDescription();
            font_style.set_size(14 * 1000);
            label.modify_font(font_style);
            label.ellipsize = Pango.EllipsizeMode.MIDDLE;
            label.set_padding(key_value_padding, -1);

            image = new Image.from_stock(Stock.INFO, window.isize128);
            //image.set_size_request(-1, );

            info = new LinkedList<Pair<string, string>>();

            toolbar_menu = (Gtk.Menu) window.ui.get_widget("/ToolbarMenu");
            button_press_event.connect(right_click);
        }

        public bool right_click(Gdk.EventButton event)
        {
            if(event.button == 3)
            {
                Eel.pop_up_context_menu(toolbar_menu, 0, 0, event);
                return true;
            }
            return false;
        }



        public void update(GOF.File gof_file){
            last_geof_cache = gof_file;

            var file_info = gof_file.info;
            var icon_size_request = 96;
            if(orientation == Orientation.HORIZONTAL){
                icon_size_request = 42;
            }

            Nautilus.IconInfo icon_info = Nautilus.IconInfo.lookup(gof_file.icon, icon_size_request);
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
                info.add(new Pair<string, string>(_("Size"), gof_file.format_size));
            /* localized time depending on MARLIN_PREFERENCES_DATE_FORMAT locale, iso .. */
            info.add(new Pair<string, string>("Modified", gof_file.formated_modified));
            info.add(new Pair<string, string>("Owner", file_info.get_attribute_string(FILE_ATTRIBUTE_OWNER_USER_REAL)));

            label.label = gof_file.name;

            /* Apps list */
            apps_scrolled = new ScrolledWindow(null,null);
            if((bool)Preferences.settings.get_value("show-open-with-text"))
            {
                apps = new VBox(false, 5);
            }
            else
            {
                apps = new HBox(true, 5);
            }

            if (!(gof_file.is_symlink() && !gof_file.link_known_target) && 
                gof_file.ftype != "application/octet-stream") 
            {
                var button = new AppButton(AppInfo.get_default_for_type(gof_file.ftype, false), gof_file);
                string name = AppInfo.get_default_for_type(gof_file.ftype, false).get_name();

                apps.pack_start(button, false, false);
                int i = 0;
                foreach(AppInfo app_info in AppInfo.get_all_for_type(gof_file.ftype))
                {
                    if(app_info.get_name() != name)
                    {
                        button = new AppButton(app_info, gof_file);
                        apps.pack_start(button, false, false);
                    }
                    if(i > 3)
                        break;
                    i++;
                }
            }

            set_as_default = false;
            
            app_chooser = new Button.with_label(N_("Other..."));
            app_chooser.pressed.connect(() => {
                dial = new AppChooserDialog(window, 0, gof_file.location);
                var check_button = new CheckButton.with_label(N_("Set as default"));
                check_button.toggled.connect( () => {set_as_default = ! set_as_default; });
                ((Box)dial.get_content_area()).pack_start(check_button);
                dial.get_content_area().show_all();
                dial.response.connect(launch_gof);
                dial.run();
            });

            update_info_panel();
            show();
        }
        AppChooserDialog dial;
        Button app_chooser;
        bool set_as_default;
        
        private void launch_gof(int response)
        {
            if(response == -5)
                last_geof_cache.launch_with(get_screen(), dial.get_app_info());
            if(set_as_default)
            {
                try
                {
                    dial.get_app_info().set_as_default_for_type(last_geof_cache.ftype);
                }
                catch(Error e)
                {
                    print("Can't set the default app: %s\n", e.message);
                }
            }
            dial.destroy();
        }

        private void populate_key_value_pair(Box box, Pair<string, string> pair, bool limit_width = false){
            var key_label = new Label(pair.key);
            key_label.set_state(StateType.INSENSITIVE);
            key_label.set_size_request((int) (key_value_width * 0.618033f), -1);
            key_label.set_justify(Justification.RIGHT);
            key_label.size_allocate.connect((l, s) => l.set_size_request(s.width, -1));
            key_label.set_alignment(1, 0);

            box.pack_start(key_label, false, true, 0);

            var value_label = new Label(((Pair<string, string>) pair).value);
            value_label.set_alignment(0, 0);
            value_label.set_selectable(true);
            if(limit_width)
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

            var box = new VBox(false, 4);

            if (image != null) {
                if (image.parent != null)
                    image.parent.remove(image);
                box.pack_start(image, false, false);
            }
            if (label != null) { 
                if (label.parent != null)
                    label.parent.remove(label);
                box.pack_start(label, false, false);
            }
            box.pack_start(new Gtk.Separator(Orientation.HORIZONTAL), false, false);

            var information = new VBox (false, key_value_padding);

            int n = 0;
            foreach(var pair in item_info){
                var key_value_pair = new HBox (false, key_value_padding);
                key_value_pair.set_size_request(key_value_width, -1);
                populate_key_value_pair(key_value_pair, pair, true);

                var alignment_ = new Gtk.Alignment(0, 0, 0, 0);
                alignment_.add(key_value_pair);

                information.pack_start(alignment_, true, true, 0);

                n++;
            }

            box.pack_start(information, false, false);
            if(!last_geof_cache.is_directory)
            {
                var label = new Label(N_("Open with:"));
                label.set_sensitive(false);
                box.pack_start(label, false, false);
                var vbox = new VBox(false, 5);
                vbox.pack_start(apps, true, true);
                vbox.pack_start(app_chooser, true, true);
                box.pack_start(vbox);
            }
            var scrolled = new ScrolledWindow(null, null);
            var box_ = new VBox(false, 0);
            box_.pack_start(box, true, false);
            scrolled.add_with_viewport(box_);
            box.set_margin_right(3);

            scrolled.show_all();

            set_content(scrolled);
        }

        private void construct_info_panel_horizontal(Gee.List<Pair<string, string>> item_info){
            set_size_request(-1, panel_size);

            var box = new HBox(false, 0);

            var alignment_img = new Gtk.Alignment(0, 0.5f, 0, 0);
            alignment_img.set_padding(2, 8, 4, 0); // TODO: change this is something more concrete
            if (image != null) {
                if (image.parent != null)
                    image.parent.remove(image);
                alignment_img.add(image);
            }

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
                key_value_pair.set_size_request(key_value_width, -1);
                populate_key_value_pair(key_value_pair, pair);

                var alignment = new Gtk.Alignment(0, 0, 0, 0);
                alignment.add(key_value_pair);

                table.attach(alignment, column, column+1, row, row+1, AttachOptions.FILL, AttachOptions.FILL, key_value_padding/2, key_value_padding/4);

                n++;
            }

            var alignment = new Gtk.Alignment(0, 0.5f, 0, 0);
            alignment.set_padding(0, 4, 0, 0);
            alignment.add(table);

            box.pack_start(alignment, true, true);
            box.show_all();

            set_content(box);
        }

        private void set_content(Widget w){
            var lw = get_child();
            if (lw != null)
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

