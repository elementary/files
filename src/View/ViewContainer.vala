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
        Browser<string> browser;
        public int view_mode = 0;
        private ulong file_info_callback;

        public signal void path_changed(File file);
        public signal void up();
        public signal void back();
        public signal void forward();

        public ViewContainer(Marlin.View.Window win, GLib.File location){
            window = win;
            /* set active tab */
            window.current_tab = this;
            browser = new Browser<string> ();
            slot = new GOF.Window.Slot(location, this);
            slot.make_view();
            /*mwcol = new Marlin.Window.Columns(location, this);
              slot = mwcol.active_slot;*/
            //content_item = slot.get_view();
            //label = new Gtk.Label("test");
            label = new Gtk.Label(slot.directory.get_uri());
            label.set_ellipsize(Pango.EllipsizeMode.END);
            label.set_single_line_mode(true);
            label.set_alignment(0.0f, 0.5f);
            label.set_padding(0, 0);
            update_location_state(true);

            //add(content_item);

            this.show_all();

            path_changed.connect((myfile) => {
                                 change_view(view_mode, myfile);
                                 update_location_state(true);
                                 });
            up.connect(() => {
                       if (slot.directory.has_parent()) {
                       change_view(view_mode, slot.directory.get_parent());
                       update_location_state(true);
                       }
                       });
            back.connect(() => {
                         change_view(view_mode, File.new_for_commandline_arg(browser.go_back()));
                         update_location_state(false);
                         });
            forward.connect(() => {
                            change_view(view_mode, File.new_for_commandline_arg(browser.go_forward()));
                            update_location_state(false);
                            });
        }

        public Widget content{
            set{
                if (content_item != null)
                    remove(content_item);
                add(value);
                content_item = value;
                content_item.show();
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

        public void change_view(int nview, GLib.File? location){
            if (location == null)
                location = slot.location;
            view_mode = nview;
            if (window.top_menu.view_switcher != null)
                window.top_menu.view_switcher.mode = (ViewMode) view_mode;
            slot.directory.cancel();
            switch (nview) {
            case ViewMode.MILLER:
                mwcol = new Marlin.Window.Columns(location, this);
                slot = mwcol.active_slot;
                mwcol.make_view();
                break;
            default:
                slot = new GOF.Window.Slot(location, this);
                slot.make_view();
                break;
            }
            /* focus the main view */
            ((FM.Directory.View) slot.view_box).grab_focus();
            sync_contextview();
        }

        /* TODO save selections in slot or fmdirectoryview and set the ContextView */
        public void sync_contextview(){
            switch (view_mode) {
            case ViewMode.MILLER:
                if (window.contextview != null) {
                    window.main_box.remove (window.contextview);
                    window.contextview = null;
                }
                break;
            default:
                if (window.contextview == null) {
                    window.contextview = new ContextView(window);
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
            file_info_callback = slot.directory.info_available.connect(() => {
                tab_name = slot.directory.info.get_attribute_string(FILE_ATTRIBUTE_STANDARD_DISPLAY_NAME);
                if(window.current_tab == this){
                    window.set_title(tab_name);
                }

                Source.remove((uint) file_info_callback);
            });

            window.can_go_up = slot.directory.has_parent();
            if (window.top_menu.location_bar != null)
                    window.top_menu.location_bar.path = slot.directory.get_uri();
            if (save_history)
                browser.record_uri(slot.directory.get_uri());
            window.can_go_back = browser.can_go_back();
            window.can_go_forward = browser.can_go_forward();
            if (window.top_menu.view_switcher != null)
                window.top_menu.view_switcher.mode = (ViewMode) view_mode;
        }

        public new Gtk.Widget get_window()
        {
            return ((Gtk.Widget) window);
        }
    }
}

