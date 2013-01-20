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
using Granite.Widgets;

namespace Marlin.View {

    public class ContextView : Gtk.EventBox
    {
        public const int height = 48;
        public const int width = 190;
        public const int key_value_padding = 8;
        public const int key_value_width = 90;
        public Gtk.Menu toolbar_menu;

        public int panel_size{
            get{
                switch (orientation){
                case Gtk.Orientation.HORIZONTAL:
                    return height;
                case Gtk.Orientation.VERTICAL:
                default:
                    return width;
                }
            }
        }

        private Window window;
        private Gdk.Pixbuf? pixbuf {
            set{
                if (value != null)
                    evbox.set_from_pixbuf (value);
            }
        }

        private ImgEventBox evbox;
        private Label label;
        private Gee.List<Pair<string, string>> info;
        private uint timeout = 0;
        private uint timeout_update = 0;
        private bool first_alloc = true;
        private Allocation cv_alloc;    /* last allocation of the contextview */
        private bool should_sync;

        private GOF.File? last_gof = null;
        private ulong icon_changed_callback = 0;
        private unowned GLib.List<GOF.File>? last_selection = null;

        private Orientation _orientation = Gtk.Orientation.HORIZONTAL;
        public Orientation orientation {
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
                //SPOTTED!
                update(last_selection);
            }
            get{
                return _orientation;
            }
        }

        public Orientation parent_orientation {
            set{
                orientation = convert_parent_orientation(value);
            }
        }

        private Orientation convert_parent_orientation (Orientation o) {
            switch (o){
            case Gtk.Orientation.HORIZONTAL:
                return Gtk.Orientation.VERTICAL;
            case Gtk.Orientation.VERTICAL:
            default:
                return Gtk.Orientation.HORIZONTAL;
            }
        }

        /* TODO remove should_sync? */
        public ContextView (Window window, bool _should_sync, 
                           Gtk.Orientation parent_orientation = Gtk.Orientation.VERTICAL) 
        {
            this.window = window;
            _orientation = convert_parent_orientation(parent_orientation);

            should_sync = _should_sync;
            if (should_sync) { 
                window.selection_changed.connect (update);
                window.item_hovered.connect (update_hovered);
                change_css_class ();
            }
            
            label = new Label("");
            var font_style = new Pango.FontDescription();
            font_style.set_size(14 * 1000);
            label.override_font(font_style);
            //label.ellipsize = Pango.EllipsizeMode.MIDDLE;
            label.set_line_wrap (true);
            label.set_line_wrap_mode (Pango.WrapMode.CHAR);
            label.set_width_chars (10);
            label.set_padding(key_value_padding, -1);

            evbox = new ImgEventBox(Orientation.HORIZONTAL);

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
            /*if (first_alloc && !should_sync) 
                return;*/

            //amtest
            /*stdout.printf ("::::: %d %d :: %d %d\n", cv_alloc.width, cv_alloc.height,
                           s.width, s.height);*/
            if ((orientation == Orientation.VERTICAL && cv_alloc.width != s.width) ||
                (orientation == Orientation.HORIZONTAL && cv_alloc.height != s.height)) {
                //stdout.printf ("$$$$$$$$$$$ img alloc %d\n", s.width);
                /* TODO don't create/destroy the contextview in miller */
                //message ("zz");
                if(timeout != 0){
                    Source.remove(timeout);
                    timeout = 0;
                }
                timeout = Timeout.add(300, () => {
                    //message ("wwwwwwwwwwwww");
                    update_icon();
                    timeout = 0;

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
            Allocation alloc;
            int icon_size_req;
    		
            if (last_gof == null)
                return;

            //window.get_size(out w_width, out w_height);
            get_allocation(out alloc);
            cv_alloc = alloc;
            //stdout.printf ("$$$$$$$$$ real alloc %d %d\n", alloc.width, alloc.height);
           
            /* fixing a minimum and maximum value */
            if (orientation == Orientation.VERTICAL) {
                /* add a little 16px padding for normal icons */
                if (last_gof.info.has_attribute (FileAttribute.THUMBNAIL_PATH) &&
                    last_gof.info.get_attribute_byte_string (FileAttribute.THUMBNAIL_PATH) != null) {
                    icon_size_req = alloc.width.clamp (height, 256);
                } else {
                    icon_size_req = alloc.width.clamp (height, width-16);
                }
            } else {
                icon_size_req = alloc.height.clamp (height, 256);
            }

            /*if (last_gof.thumbnail_path != null) {
                //pixbuf = yield Pixbuf from_stream_at_scale_async ();
                pixbuf = new Pixbuf.from_file (last_gof.thumbnail_path);
            }*/

            //pixbuf = last_gof.get_icon_pixbuf (icon_size_req, false, GOF.FileIconFlags.USE_THUMBNAILS);
            string preview = last_gof.get_preview_path();
            bool use_previewed = false;
            if(preview != null)
            {
                try
                {
                    pixbuf = new Gdk.Pixbuf.from_file_at_size (preview, icon_size_req, -1); // FIXME need cache
                    use_previewed = true;
                }
                catch(Error e)
                {
                }
            }
            else if(last_gof.get_thumbnail_path() != null && last_gof.flags == GOF.File.ThumbState.READY)
            {
                Marlin.Thumbnailer.get().queue_file(last_gof, null, true);
            }
            if(!use_previewed)
            {
                var micon = last_gof.get_icon (128, GOF.FileIconFlags.USE_THUMBNAILS);
                pixbuf = micon.get_pixbuf_at_size (icon_size_req);
            }

            
            /* TODO ask tumbler a LARGE thumb for size > 128 */
            /*if (should_sync && (icon_size_req > w_width/2 || icon_size_req > w_height/2))
                window.main_box.set_position (window.main_box.max_position - icon_size_req);*/
        }

        public void update (GLib.List<GOF.File>? selection = null) {
            if (icon_changed_callback > 0) {
                Source.remove((uint) icon_changed_callback);
                icon_changed_callback = 0;
            }

            if (selection != null && selection.data != null && selection.data is GOF.File) {
                last_gof = selection.data as GOF.File;
                last_selection = selection;
            } else {
                last_gof = null;
                /* if empty selection then pass the currentslot folder */
                if (window.current_tab != null) {
                    var aslot = window.current_tab.get_active_slot ();
                    if (aslot != null)
                        last_gof = aslot.directory.file;
                }
                last_selection = null;
            }
            if (last_gof == null)
                return;
            if (last_gof.info == null)
                return;

            timed_update ();
        }
        
        public void update_hovered (GOF.File? file) {
            if (file != null) {
                last_gof = file;
                timed_update ();
            } else {
                update (last_selection);       
            }
        }

        private void timed_update () {
            if(timeout_update != 0){
                Source.remove(timeout_update);
                timeout_update = 0;
            }
            timeout_update = Timeout.add(60, () => {
                real_update ();
                timeout_update = 0;

                return false;
            });
        }

        private void real_update () {
            //warning ("ctx pane update");
            return_if_fail (last_gof != null && last_gof.info != null);

            /* don't update icon if we are in column view as the preview pane is 
               built/destroyed foreach selection changed */
            if (should_sync) 
                update_icon();
            icon_changed_callback = last_gof.icon_changed.connect (() => {
                if (should_sync) 
                    update_icon ();
            });

            info.clear();
            var raw_type = last_gof.info.get_file_type();

            /* TODO hide infos for ListView mode: we don't want the COLUMNS infos to show if
               we are in listview: size, type, modified */
            info.add(new Pair<string, string>(_("Name") + (": "), last_gof.info.get_name ()));
            info.add(new Pair<string, string>(_("Type") + (": "), last_gof.formated_type));

            if (last_gof.info.get_is_symlink())
                info.add(new Pair<string, string>(_("Target") + (": "), last_gof.info.get_symlink_target ()));
            if(raw_type != FileType.DIRECTORY)
                info.add(new Pair<string, string>(_("Size") + (": "), last_gof.format_size));
            /* localized time depending on MARLIN_PREFERENCES_DATE_FORMAT locale, iso .. */
            info.add(new Pair<string, string>(_("Modified") + (": "), last_gof.formated_modified));
            info.add(new Pair<string, string>(_("Owner") + (": "), last_gof.info.get_attribute_string(FileAttribute.OWNER_USER_REAL)));

            label.label = last_gof.info.get_name ();

            update_info_panel();
            show();
        }

        public void update_info_panel(){
            if(orientation == Gtk.Orientation.HORIZONTAL)
                construct_info_panel_horizontal(info);
            else
                construct_info_panel_vertical(info);
        }

        private void construct_info_panel_vertical(Gee.List<Pair<string, string>> item_info){
            var box = new Box (Gtk.Orientation.VERTICAL, 0);
            
            set_size_request (width, -1);

            /*var blank_box = new VBox(false, 0);
            blank_box.set_size_request (-1, 20);
            box.pack_start(blank_box, false, false, 0);*/

            if (evbox != null) {
                if (evbox.parent != null)
                    evbox.parent.remove(evbox);
                evbox.orientation = convert_parent_orientation(orientation);
                box.pack_start(evbox, false, true, 0);
            }
            if (label != null) {
                if (label.parent != null)
                    label.parent.remove(label);
                label.set_selectable(true);
                label.set_tooltip_text (last_gof.info.get_name ());
                box.pack_start(label, false, false);
            }
            
            var sep = new Gtk.Separator(Gtk.Orientation.HORIZONTAL);
            sep.set_margin_top (4);
            sep.set_margin_bottom (10);
            box.pack_start(sep, false, false);

            var information = new Grid();
            information.row_spacing = 3;
            var alignment_ = new Gtk.Alignment(0.5f, 0, 0, 0);

            int n = 0;
            foreach(var pair in item_info){
                /* skip the firs parameter "name" for vertical panel */
                if (n>0) {

                    var lval = new Gtk.Label (pair.value);
                    var lkey = new Gtk.Label (pair.key);
                    lval.set_selectable(true);
                    lkey.set_sensitive (false);
                    lkey.set_alignment (1, 0);
                    lval.set_alignment (0, 0);
                    //lval.set_ellipsize(Pango.EllipsizeMode.MIDDLE);
                    lval.set_line_wrap (true);
                    lval.set_width_chars (10);

                    information.attach(lkey, 0, n, 1, 1);
                    information.attach(lval, 1, n, 1, 1);
                }
                n++;
            }
            alignment_.add(information);
            box.pack_start(alignment_);
            
            box.show_all();
            set_content(box);
        }

        private void construct_info_panel_horizontal(Gee.List<Pair<string, string>> item_info){
            var box = new Box (Gtk.Orientation.HORIZONTAL, 0);

            set_size_request (-1, height);
            if (evbox != null) {
                if (evbox.parent != null)
                    evbox.parent.remove(evbox);
                evbox.orientation = convert_parent_orientation(orientation);
                box.pack_start(evbox, false, true, 0);
            }

            var alignment = new Gtk.Alignment(0, 0.5f, 0, 0);
            var grid = new Grid ();
            grid.set_orientation (Gtk.Orientation.HORIZONTAL);
            alignment.add (grid);
            box.add (alignment);

            var i = 0;
            foreach(var pair in item_info){
                var left = (int) i/2 + i/2;
                var top = i % 2;
                //warning ("left %d top %d", left, top);
            
                var lkey = new Gtk.Label (pair.key);
                //lkey.set_size_request (65, -1);
                lkey.set_state_flags (Gtk.StateFlags.INSENSITIVE, false);
                //lkey.set_justify(Justification.RIGHT);
                lkey.set_alignment(1, 0);
                grid.attach (lkey, left, top, 1, 1);

                var lval = new Label (pair.value);
                lval.set_selectable(true);
                lval.set_margin_right (10);
                lval.set_alignment(0, 0);
                lval.set_width_chars (10);
                lval.set_ellipsize (Pango.EllipsizeMode.END);
                grid.attach (lval, left+1, top, 1, 1);
                i++;
            }
            
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

