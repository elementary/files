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

    public class ContextView : Gtk.EventBox
    {
        public const int height = 50;
        public const int width = 190;
        public const int key_value_padding = 8;
        public const int key_value_width = 90;
        public Gtk.Menu toolbar_menu;

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
        private uint timeout = 0;
        private bool first_alloc = true;
        private Allocation cv_alloc;    /* last allocation of the contextview */
        private bool should_sync;

        private GOF.File? last_gof = null;
        private unowned GLib.List<GOF.File>? last_selection = null;

        private Orientation _orientation = Orientation.HORIZONTAL;
        public Orientation orientation{
            set{
                if(timeout != 0){
                    Source.remove(timeout);
                    timeout = 0;
                }
                first_alloc = true;
                
                _orientation = value;
                change_css_class ();
                /* reset pane position to original values */
                window.main_box.set_position (window.main_box.max_position - panel_size);
                update(last_selection);
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

        public ContextView(Window window, bool _should_sync, Orientation parent_orientation = Orientation.VERTICAL) {
            this.window = window;
            _orientation = convert_parent_orientation(parent_orientation);

            should_sync = _should_sync;
            if (should_sync) { 
                window.selection_changed.connect(update);
                change_css_class ();
            }
            
            label = new Label("");
            var font_style = new Pango.FontDescription();
            font_style.set_size(14 * 1000);
            label.modify_font(font_style);
            label.ellipsize = Pango.EllipsizeMode.MIDDLE;
            label.set_padding(key_value_padding, -1);

            image = new Image ();

            info = new LinkedList<Pair<string, string>>();
        
            toolbar_menu = (Gtk.Menu) window.ui.get_widget("/ToolbarMenu");
            button_press_event.connect(right_click);
            size_allocate.connect(size_allocate_changed);
        }
        
        private void change_css_class () {
            var ctx = window.main_box.get_style_context();

            if (orientation == Orientation.VERTICAL) {
                ctx.remove_class("contextview-horizontal");
                ctx.add_class("contextview-vertical");
            } else {
                ctx.remove_class("contextview-vertical");
                ctx.add_class("contextview-horizontal");
            }
            
            window.main_box.reset_style ();
        }

#if VALA_0_14
        private void size_allocate_changed (Gtk.Allocation s)
#else
        private void size_allocate_changed (Widget w, Gdk.Rectangle s)
#endif
        {
            /* first allocations can be tricky ignore all allocations different 
               than the panel requested size at first */
            if (first_alloc) {
                if (orientation == Orientation.VERTICAL && 
                    s.width > 1 && s.width <= panel_size)
                    first_alloc = false;
                if (orientation == Orientation.HORIZONTAL && 
                    s.height > 1 && s.height <= panel_size)
                    first_alloc = false;
            }
            /*if (first_alloc && should_sync)*/ 
            /*if (should_sync) 
                return;*/

            //amtest
            stdout.printf ("::::: %d %d :: %d %d\n", cv_alloc.width, cv_alloc.height,
                           s.width, s.height);
            if ((orientation == Orientation.VERTICAL && cv_alloc.width != s.width) ||
                (orientation == Orientation.HORIZONTAL && cv_alloc.height != s.height)) {
                //stdout.printf ("$$$$$$$$$$$ img alloc %d\n", s.width);
                    message ("zz");
                if(timeout != 0){
                    Source.remove(timeout);
                    timeout = 0;
                }
                timeout = Timeout.add(500, () => {
                    timeout = 0;
                    message ("wwwwwwwwwwwww");
                    update_icon();

                    return false;
                });
            }
        
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

        private void update_icon()
        {
            //int w_height, w_width;
            Allocation alloc;
            Nautilus.IconInfo icon_info;
            int icon_size_req;
    		
            if (last_gof == null)
                return;

            //window.get_size(out w_width, out w_height);
            get_allocation(out alloc);
            cv_alloc = alloc;
            //stdout.printf ("$$$$$$$$$ real alloc %d %d\n", alloc.width, alloc.height);
           
            if (orientation == Orientation.VERTICAL) {
                //icon_size_req = int.min (alloc.width, w_width/2);
                icon_size_req = int.min (alloc.width, 256);
            } else {
                //icon_size_req = int.min (alloc.height, w_height/2);
                icon_size_req = int.min (alloc.height, 256);
            }

            /* FIXME problem with thumbs */
            //icon_info = last_gof.get_icon(icon_size_req, GOF.FileIconFlags.USE_THUMBNAILS);
            icon_info = last_gof.get_icon(icon_size_req, GOF.FileIconFlags.NONE);
            icon = icon_info.get_pixbuf_nodefault();
            
            /* TODO ask tumbler a LARGE thumb for size > 128 */
            /*if (should_sync && (icon_size_req > w_width/2 || icon_size_req > w_height/2))
                window.main_box.set_position (window.main_box.max_position - icon_size_req);*/
        }

        public void update(GLib.List<GOF.File> selection){
            if (selection != null && selection.data != null) {
                last_gof = selection.data as GOF.File;
                last_selection = selection;
            } else {
                last_gof = null;
                /* if empty selection then pass the currentslot folder */
                if (window.current_tab != null)
                    last_gof = window.current_tab.slot.directory.file;
                last_selection = null;
            }
            if (last_gof == null)
                return;

            var file_info = last_gof.info;

            /* don't update icon if we are in column view as the preview pane is 
               built/destroyed foreach selection changed */
            //if (!first_alloc || !should_sync) 
            if (should_sync) 
                update_icon();

            info.clear();
            var raw_type = file_info.get_file_type();

            /* TODO hide infos for ListView mode: we don't want the COLUMNS infos to show if
               we are in listview: size, type, modified */
            info.add(new Pair<string, string>(_("Name"), last_gof.name));
            info.add(new Pair<string, string>(_("Type"), last_gof.formated_type));

            if (file_info.get_is_symlink())
                info.add(new Pair<string, string>(_("Target"), file_info.get_symlink_target()));
            if(raw_type != FileType.DIRECTORY)
                info.add(new Pair<string, string>(_("Size"), last_gof.format_size));
            /* localized time depending on MARLIN_PREFERENCES_DATE_FORMAT locale, iso .. */
            info.add(new Pair<string, string>(_("Modified"), last_gof.formated_modified));
            info.add(new Pair<string, string>(_("Owner"), file_info.get_attribute_string(FILE_ATTRIBUTE_OWNER_USER_REAL)));

            label.label = last_gof.name;

            update_info_panel();
            show();
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
            var box = new VBox(false, 0);

            /*var blank_box = new VBox(false, 0);
            blank_box.set_size_request (-1, 20);
            box.pack_start(blank_box, false, false, 0);*/

            if (image != null) {
                if (image.parent != null)
                    image.parent.remove(image);
                image.set_tooltip_text (last_gof.name);
                box.pack_start(image, false, false, 0);
                //box.pack_start(image, false, true, 0);
            }
            if (label != null) {
                if (label.parent != null)
                    label.parent.remove(label);
                label.set_selectable(true);
                label.set_tooltip_text (last_gof.name);
                box.pack_start(label, false, false);
            }
            box.pack_start(new Gtk.Separator(Orientation.HORIZONTAL), false, false);

            var spacer_box = new VBox(false, 0);
            spacer_box.set_size_request (-1, 15);
            box.pack_start(spacer_box, false, false);

            var information = new Grid();
            information.row_spacing = 10;
            var alignment_ = new Gtk.Alignment(0.5f, 0, 0, 0);

            int n = 0;
            foreach(var pair in item_info){
                /* skip the firs parameter "name" for vertical panel */
                if (n>0) {

                    var value_label = new Gtk.Label(pair.value);
                    var key_label = new Gtk.Label(pair.key);
                    key_label.set_sensitive(false);
                    key_label.set_alignment(1, 0.5f);
                    value_label.set_alignment(0, 0.5f);
                    key_label.set_ellipsize(Pango.EllipsizeMode.START);
                    value_label.set_ellipsize(Pango.EllipsizeMode.MIDDLE);

                    information.attach(key_label, 0, n, 1, 1);
                    information.attach(value_label, 1, n, 1, 1);
                }
                n++;
            }
            alignment_.add(information);
            box.pack_start(alignment_);
            
            box.show_all();
            set_content(box);
        }

        private void construct_info_panel_horizontal(Gee.List<Pair<string, string>> item_info){
            var box = new HBox(false, 0);

            var alignment_img = new Gtk.Alignment(0.5f, 0.5f, 0, 0);
            alignment_img.set_padding(0, 0, 5, 0); 

            if (image != null) {
                if (image.parent != null)
                    image.parent.remove(image);
                image.set_tooltip_text (last_gof.name);
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

                table.attach(key_value_pair, column, column+1, row, row+1, AttachOptions.FILL, AttachOptions.FILL, key_value_padding/2, key_value_padding/4);

                n++;
            }
            
            var vbox = new VBox(false, 0);
            vbox.pack_start(table, true, true);

            box.pack_start(vbox, true, true);
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

