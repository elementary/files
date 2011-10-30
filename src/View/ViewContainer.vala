//
//  ViewContainer.vala
//
//  Authors:
//       Mathijs Henquet <mathijs.henquet@gmail.com>
//       ammonkey <am.monkeyd@gmail.com>
//
//  Copyright (c) 2010 Mathijs Henquet
//
//  This program is free software; you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation; either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program; if not, write to the Free Software
//  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
//
using Gtk;

namespace Marlin.View {
    public class ViewContainer : Gtk.EventBox {
        public Gtk.Widget? content_item;
        public Gtk.Label label;
        private Marlin.View.Window window;
        public GOF.Window.Slot? slot;
        public Marlin.Window.Columns? mwcol;
        Browser browser;
        public int view_mode = 0;
        private ulong file_info_callback;

        public signal void path_changed(File file);
        public signal void up();
        public signal void back(int n=1);
        public signal void forward(int n=1);

        public ViewContainer(Marlin.View.Window win, GLib.File location, int _view_mode = 0){
            window = win;
            view_mode = _view_mode;
            /* set active tab */
            browser = new Browser ();
            label = new Gtk.Label("Loading...");
            change_view (view_mode, location);
            label.set_ellipsize(Pango.EllipsizeMode.END);
            label.set_single_line_mode(true);
            label.set_alignment(0.0f, 0.5f);
            label.set_padding(0, 0);
            update_location_state(true);
            plugin_directory_loaded ();
            window.button_back.fetcher = get_back_menu;
            window.button_forward.fetcher = get_forward_menu;

            //add(content_item);

            this.show_all();

            path_changed.connect((myfile) => {
                /* location didn't change, do nothing */
                if (slot != null && myfile != null && slot.directory.file.exists
                    && slot.location.equal (myfile))
                    return;
                change_view(view_mode, myfile);
                update_location_state(true);
                plugin_directory_loaded ();
            });
            up.connect(() => {
                if (slot.directory.has_parent()) {
                    change_view(view_mode, slot.directory.get_parent());
                    update_location_state(true);
                }
            });
            back.connect((n) => {
                change_view(view_mode, File.new_for_commandline_arg(browser.go_back(n)));
                update_location_state(false);
            });
            forward.connect((n) => {
                change_view(view_mode, File.new_for_commandline_arg(browser.go_forward(n)));
                update_location_state(false);
            });
            win.reload_tabs.connect(() => { reload(); });
        }

        public Widget content{
            set{
                if (content_item != null)
                    remove(content_item);
                add(value);
                content_item = value;
                show_all ();
            }
            get{
                return content_item;
            }
        }

        public string tab_name{
            set{
                label.label = value;
            }
            get{
                return label.label;
            }
        }

        private void plugin_directory_loaded () 
        {
            Object[] data = new Object[2];
            data[0] = window;
            data[1] = slot;
            //data[2] = GOF.File.get(slot.location);
            data[2] = slot.directory.file;
            plugins.directory_loaded((void*)data);
        }

        private void connect_available_info() {
            file_info_callback = slot.directory.file.info_available.connect((gof) => {
                if (slot.location.get_path () == Environment.get_home_dir ())
                    tab_name = _("Home");
                else if (slot.location.get_path () == "/")
                    tab_name = _("File System");
                else
                    tab_name = slot.directory.file.info.get_attribute_string(FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME);
                if(window.current_tab == this){
                    window.set_title(tab_name);
                    window.loading_uri (slot.directory.file.uri, window.sidebar);
                }
                
                if (window.contextview != null)
                    window.contextview.update ();

                Source.remove((uint) file_info_callback);
            });
        }

        public void change_view(int nview, GLib.File? location){
            if (location == null)
                location = slot.location;
            view_mode = nview;
            if (window.top_menu.view_switcher != null)
                window.top_menu.view_switcher.mode = (ViewMode) view_mode;
            if (slot != null && slot.directory.file.exists) {
                slot.directory.cancel();
            }

            switch (nview) {
            case ViewMode.LIST:
                slot = new GOF.Window.Slot(location, this);
                connect_available_info();
                if (slot.directory.file.exists)
                    slot.make_list_view();
                break;
            case ViewMode.MILLER:
                mwcol = new Marlin.Window.Columns(location, this);
                slot = mwcol.active_slot;
                connect_available_info();
                if (slot.directory.file.exists)
                    mwcol.make_view();
                break;
            default:
                slot = new GOF.Window.Slot(location, this);
                connect_available_info();
                if (slot.directory.file.exists) 
                    slot.make_icon_view();
                break;
            }
            //SPOTTED!
            /*if (!slot.directory.file.exists) 
                content = new DirectoryNotFound (slot.directory, this);*/
            
            sync_contextview();
        }

        /* TODO save selections in slot or fmdirectoryview and set the ContextView */
        public void sync_contextview(){
            if (!slot.directory.file.exists) {
                if (window.contextview != null) {
                    window.main_box.remove (window.contextview);
                    window.contextview = null;
                }
                return;
            }

            switch (view_mode) {
            case ViewMode.MILLER:
                /* reset the panes style */
                var ctx = window.main_box.get_style_context();
                ctx.remove_class("contextview-horizontal");
                ctx.remove_class("contextview-vertical");
                window.main_box.reset_style ();

                if (window.contextview != null) {
                    window.main_box.remove (window.contextview);
                    window.contextview = null;
                }
                break;
            default:
                if (window.contextview == null &&
                    ((Gtk.ToggleAction) window.main_actions.get_action("Show Hide Context Pane")).get_active())
                {
                    window.contextview = new ContextView(window, true, window.main_box.orientation);
                    
                    window.main_box.notify.connect((prop) => {
                        if(window.contextview != null && prop.name == "orientation")
                            window.contextview.parent_orientation = window.main_box.orientation;
                    });
                    window.main_box.pack2(window.contextview, false, true);
                }
                break;
            }
        }

        public void reload(){
            change_view(view_mode, null);
        }

        public void update_location_state(bool save_history)
        {
            if (!slot.directory.file.exists)
                return;

            window.can_go_up = slot.directory.has_parent();
            if (window.top_menu.location_bar != null)
                window.top_menu.location_bar.path = slot.location.get_parse_name();
            if (save_history)
                browser.record_uri(slot.directory.location.get_parse_name ());
            window.can_go_back = browser.can_go_back();
            window.can_go_forward = browser.can_go_forward();
            if (window.top_menu.view_switcher != null)
                window.top_menu.view_switcher.mode = (ViewMode) view_mode;
        }

        public Menu get_back_menu()  {
            /* Clear the back menu and re-add the correct entries. */
            var back_menu = new Gtk.Menu ();
            var list = browser.go_back_list();
            var n = 1;
            foreach(var path in list){
                int cn = n++; // No i'm not mad, thats just how closures work in vala (and other langs).
                              // You see if I would just use back(n) the reference to n would be passed
                              // in the clusure, restulting in a value of n which would always be n=1. So
                              // by introducting a new variable I can bypass this anoyance.
                var item = new MenuItem.with_label (path.replace("file://", "")); //TODO add `real' escaping/serializing
                item.activate.connect(() => { back(cn); });
                back_menu.insert(item, -1);
            }

            back_menu.show_all();
            return back_menu;
        }

        public Menu get_forward_menu() {
            /* Same for the forward menu */
            var forward_menu = new Gtk.Menu ();
            var list = browser.go_forward_list();
            var n = 1;
            foreach(var path in list){
                int cn = n++; // For explenation look up
                var item = new MenuItem.with_label (path.replace("file://", "")); //TODO add `real' escaping/serializing
                item.activate.connect(() => forward(cn));
                forward_menu.insert(item, -1);
            }

            forward_menu.show_all();
            return forward_menu;
        }

        public new Gtk.Widget get_window()
        {
            return ((Gtk.Widget) window);
        }
    }
}

