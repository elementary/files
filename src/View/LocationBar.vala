/*
 * Copyright (c) 2010 mathijshenquet
 * Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
 *
 * Marlin is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 */
 
using Gtk;
using GLib;

namespace Marlin.View.Chrome
{
    public class LocationBar : ToolItem
    {
        private Breadcrumbs bread;

        private string _path;
        public new string path{
            set{
                var new_path = value;
                _path = new_path;
                bread.change_breadcrumbs(new_path);
            }
            get{
                return _path;
            }
        }

        public new signal void activate();
        public signal void escape();

        public LocationBar (UIManager ui, Window win)
        {
            bread = new Breadcrumbs(ui, win);
            bread.escape.connect( () => { escape(); });

            bread.changed.connect(on_bread_changed);

            set_expand(true);
                
            //border_width = 0;
            margin_top = 5;
            margin_bottom = 5;
            margin_left = 3;
            
            add(bread);
        }
        
        private void on_bread_changed(string changed)
        {
             _path = changed;
             activate();
        }
    }

    public class Breadcrumbs : BasePathBar
    {
        Gtk.Menu menu;
        private UIManager ui;

        /* Used for auto-copmpletion */
        GOF.Directory.Async files;
        /* The string which contains the text we search in the file. e.g, if the
         * user enter /home/user/a, we will search for "a". */
        string to_search = "";

        /* Used for the context menu we show when there is a right click */
        GOF.Directory.Async files_menu = null;
    
        bool autocompleted = false;

        Window win;
    
        double menu_x_root;
        double menu_y_root;
        
        public Breadcrumbs(UIManager ui, Window win)
        {
            /* grab the UIManager */
            this.ui = ui;
            this.win = win;
            /*add_icon({ Marlin.TRASH_URI, Marlin.ICON_TRASH, true, null, null, true, N_("Trash")});
            add_icon({ Marlin.NETWORK_URI, Marlin.ICON_NETWORK, true, null, null, true, N_("Network")});*/
            /* FIXME the string split of the path url is kinda too basic, we should use the Gile to split our uris and determine the protocol (if any) with g_uri_parse_scheme or g_file_get_uri_scheme */
            add_icon({ "trash://", Marlin.ICON_TRASH, true, null, null, null, true, _("Trash")});
            add_icon({ "network://", Marlin.ICON_NETWORK, true, null, null, null, true, _("Network")});

            /* music */
            string dir;
            dir = Environment.get_user_special_dir(UserDirectory.MUSIC);
            if(dir.contains("/"))
            {
                IconDirectory icon = {dir, "folder-music-symbolic", false, null, null, dir.split("/"), false, null};
                icon.exploded[0] = "/";
                add_icon(icon);
            }
    
            /* image */
            dir = Environment.get_user_special_dir(UserDirectory.PICTURES);
            if(dir.contains("/"))
            {
                IconDirectory icon = {dir, "folder-pictures-symbolic", false, null, null, dir.split("/"), false, null};
                icon.exploded[0] = "/";
                add_icon(icon);
            }

            /* movie */
            dir = Environment.get_user_special_dir(UserDirectory.VIDEOS);
            if(dir.contains("/"))
            {
                IconDirectory icon = {dir, "folder-videos-symbolic", false, null, null, dir.split("/"), false, null};
                icon.exploded[0] = "/";
                add_icon(icon);
            }
    
            /* downloads */
            dir = Environment.get_user_special_dir(UserDirectory.DOWNLOAD);
            if(dir.contains("/"))
            {
                IconDirectory icon = {dir, "folder-downloads-symbolic", false, null, null, dir.split("/"), false, null};
                icon.exploded[0] = "/";
                add_icon(icon);
            }
    
            /* documents */
            dir = Environment.get_user_special_dir(UserDirectory.DOCUMENTS);
            if(dir.contains("/"))
            {
                IconDirectory icon = {dir, "folder-documents-symbolic", false, null, null, dir.split("/"), false, null};
                icon.exploded[0] = "/";
                add_icon(icon);
            }
            
            /* templates */
            dir = Environment.get_user_special_dir(UserDirectory.TEMPLATES);
            if(dir.contains("/"))
            {
                IconDirectory icon = {dir, "folder-templates-symbolic", false, null, null, dir.split("/"), false, null};
                icon.exploded[0] = "/";
                add_icon(icon);
            }

            dir = Environment.get_home_dir();
            if(dir.contains("/"))
            {
                IconDirectory icon = {dir, "go-home-symbolic", false, null, null, dir.split("/"), true, null};
                icon.exploded[0] = "/";
                add_icon(icon);
            }

            
            IconDirectory icon = {"/", Marlin.ICON_FILESYSTEM, false, null, null, null, false, null};
            icon.exploded = {"/"};
            add_icon(icon);

            entry.down.connect(() => {
                ((FM.Directory.View) win.current_tab.slot.view_box).grab_focus(); 
            });

            menu = new Gtk.Menu();
            menu.show_all();
            
            need_completion.connect(on_need_completion);


        }
        

        protected void merge_in_clipboard_actions ()
        {
            ui.insert_action_group (clipboard_actions, 0);
            ui.ensure_update ();        
        }

        protected void merge_out_clipboard_actions ()
        {
            ui.remove_action_group (clipboard_actions);
            ui.ensure_update ();        
        }
        
        /**
         * This function is used as a callback for files.file_loaded. 
         * We check that the file can be used
         * in auto-completion, if yes we put it in our entry.
         *
         * @param file The file you want to load
         *
         **/
        private void on_file_loaded(GOF.File file)
        {
            if(file.is_folder () && file.get_display_name ().length > to_search.length)
            {
                if(file.get_display_name ().ascii_ncasecmp (to_search, to_search.length) == 0)
                {
                    if(!autocompleted)
                    {
                        entry.completion = file.get_display_name ().slice(to_search.length, file.get_display_name ().length);
                        autocompleted = true;
                    }
                    else
                    {
                        string file_complet = file.get_display_name ().slice(to_search.length, file.get_display_name ().length);
                        string to_add = "";
                        for(int i = 0; i < (entry.completion.length > file_complet.length ? file_complet.length : entry.completion.length); i++)
                        {
                            if(entry.completion[i] == file_complet[i])
                                to_add += entry.completion[i].to_string();
                            else
                                break;
                        }
                        entry.completion = to_add;
                    }
                    /* autocompletion is case insensitive so we have to change the first completed 
                     * parts: the entry.text.
                     */
                    string str = entry.text.slice(0, entry.text.length - to_search.length);
                    if (str == null)
                        str = "";
                    entry.text = str + file.get_display_name ().slice(0, to_search.length);
                }
            }
        }
        
        public void on_need_completion()
        {
            string path = get_elements_path ();

//#if 0
            string[] stext = entry.text.split("/");

            switch(stext.length)
            {
            case 0:
                to_search = "";
                break;
            case 1:
                to_search = stext[0];
                break;
            default: /* if it is > 1 */
                update_breadcrumbs (entry.text, path);
                break;
            }
//#endif
//            to_search = entry.text;

            entry.completion = "";
            autocompleted = false;

            path += entry.text;
            if(to_search != "")
                path = Marlin.Utils.get_parent(path);

            if (path != null && path.length > 0)
            {
                var directory = File.new_for_uri (path);
                files = GOF.Directory.Async.from_gfile (directory);
                if(files.file.exists)
                {
                    files.file_loaded.connect(on_file_loaded);
                    files.load();
                }
            }
        }
        
        private void on_files_loaded_menu()
        {
            unowned List<GOF.File>? sorted_dirs = files_menu.get_sorted_dirs ();
            foreach (var gof in sorted_dirs) {
                var menuitem = new Gtk.MenuItem.with_label(gof.get_display_name ());
                menuitem.set_data ("location", gof.get_target_location ());
                menu.append(menuitem);
                menuitem.activate.connect(() => {
                    unowned File loc = menu.get_active ().get_data ("location");
                    win.current_tab.path_changed (loc);
                });
            }
            menu.show_all();
        }

        protected override void on_file_droped(List<GLib.File> uris, GLib.File target_file, Gdk.DragAction real_action) {
            Marlin.FileOperations.copy_move(uris, null, target_file, real_action);
        }
        
        public override string? update_breadcrumbs(string new_path, string base_path)
        {
            string strloc = base.update_breadcrumbs(new_path, base_path);
            if(strloc != null)
            {
                File location = File.new_for_commandline_arg (strloc);
                win.current_tab.path_changed (location);
                grab_focus();
            }
            return strloc;
        }
        
        public override bool focus_out_event(Gdk.EventFocus event)
        {
            base.focus_out_event(event);
            merge_out_clipboard_actions ();
            return true;
        }
        
        public override bool focus_in_event(Gdk.EventFocus event)
        {
            base.focus_in_event(event);
            merge_in_clipboard_actions ();
            return true;
        }
        
        private void get_menu_position (Gtk.Menu menu, out int x, out int y, out bool push_in)
        {
            x = (int)menu_x_root;
            y = (int)menu_y_root;
            push_in = true;
        }

        protected override void load_right_click_menu(double x, double y)
        {
            menu_x_root = x;
            menu_y_root = y;
            menu = new Gtk.Menu();
            var directory = File.new_for_uri (current_right_click_root);
            if (files_menu != null)
                files_menu.done_loading.disconnect(on_files_loaded_menu);
            files_menu = GOF.Directory.Async.from_gfile (directory);
            files_menu.done_loading.connect (on_files_loaded_menu);
            files_menu.load();

            menu.popup (null,
                        null,
                        get_menu_position,
                        0,
                        Gtk.get_current_event_time());
        }
    }
}
