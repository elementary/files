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

namespace Marlin.View.Chrome
{
    public class LocationBar : Gtk.Box {
        public Breadcrumbs bread;

        private string _path;
        public new string path {
            set {
                var new_path = GLib.Uri.unescape_string (value);
                if (new_path != null) {
                    _path = new_path;

                    if (!bread.is_focus && !win.freeze_view_changes) {
                        bread.text = "";

                        bread.change_breadcrumbs (new_path);
                    }
                } else {
                    critical ("Tried to set null path");
                }
            }

            get {
                return _path;
            }
        }

        Marlin.View.Window win;

        public new signal void activate (GLib.File file);
        public signal void activate_alternate (GLib.File file);
        public signal void escape ();
        public signal void search_mode_left ();

        public override void get_preferred_width (out int minimum_width, out int natural_width) {
            minimum_width = -1;
            natural_width = 3000;
        }

        public LocationBar (Marlin.View.Window win) {
            this.win = win;
            bread = new Breadcrumbs (win);
            bread.escape.connect (() => { escape(); });
            bread.path_changed.connect (on_path_changed);

            bread.reload.connect (() => {
                win.win_actions.activate_action ("refresh", null);
            });

            bread.activate_alternate.connect ((file) => { activate_alternate(file); });
            bread.notify["search-mode"].connect (() => {
                if (!bread.search_mode) {
                    bread.search_results.clear ();
                    search_mode_left ();
                } else {
                    bread.text = "";
                }
            });

            margin_top = 4;
            margin_bottom = 4;
            margin_left = 3;

            bread.set_entry_secondary_icon (false);
            pack_start (bread, true, true, 0);
        }

        public void enter_search_mode (bool local_only = false, bool begins_with_only = false) {
            bread.search_results.search_current_directory_only = local_only;
            bread.search_results.begins_with_only = begins_with_only;
            bread.search_mode = true;
        }

        private void on_path_changed (File file) {
            if (win.freeze_view_changes)
                return;

            win.grab_focus ();
            activate (file);
        }
    }

    public class Breadcrumbs : BasePathBar {
        public SearchResults search_results { get; private set; }

        Gtk.Menu menu;

        /* Used for auto-copmpletion */
        GOF.Directory.Async files;
        /* The string which contains the text we search in the file. e.g, if the
         * user enter /home/user/a, we will search for "a". */
        string to_search = "";

        /* Used for the context menu we show when there is a right click */
        GOF.Directory.Async files_menu = null;
        
        bool autocompleted = false;

        Marlin.View.Window win;

        double menu_x_root;
        double menu_y_root;

        private bool drop_data_ready = false; /* whether the drop data was received already */
        private bool drop_occurred = false; /* whether the data was dropped */
        private GLib.List<GLib.File> drop_file_list = null; /* the list of URIs in the drop data */
        protected static FM.DndHandler dnd_handler = new FM.DndHandler ();

        Gdk.DragAction current_suggested_action = 0; /* No action */
        Gdk.DragAction current_actions = 0; /* No action */

        GOF.File? drop_target_file = null;

        public Breadcrumbs (Marlin.View.Window win)
        {
            this.win = win;
            /* FIXME the string split of the path url is kinda too basic, we should use the Gile to split our uris and determine the protocol (if any) with g_uri_parse_scheme or g_file_get_uri_scheme */
            add_icon ({ "afp://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, _("AFP")});
            add_icon ({ "dav://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, _("DAV")});
            add_icon ({ "davs://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, _("DAVS")});
            add_icon ({ "ftp://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, _("FTP")});
            add_icon ({ "network://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, _("Network")});
            add_icon ({ "sftp://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, _("SFTP")});
            add_icon ({ "smb://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, _("SMB")});
            add_icon ({ "trash://", Marlin.ICON_TRASH_SYMBOLIC, true, null, null, null, true, _("Trash")});

            /* music */
            string dir;
            dir = Environment.get_user_special_dir (UserDirectory.MUSIC);
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_FOLDER_MUSIC_SYMBOLIC, false, null, null, dir.split ("/"), false, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }

            /* image */
            dir = Environment.get_user_special_dir (UserDirectory.PICTURES);
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_FOLDER_PICTURES_SYMBOLIC, false, null, null, dir.split ("/"), false, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }

            /* movie */
            dir = Environment.get_user_special_dir (UserDirectory.VIDEOS);
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_FOLDER_VIDEOS_SYMBOLIC, false, null, null, dir.split ("/"), false, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }

            /* downloads */
            dir = Environment.get_user_special_dir (UserDirectory.DOWNLOAD);
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_FOLDER_DOWNLOADS_SYMBOLIC, false, null, null, dir.split ("/"), false, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }

            /* documents */
            dir = Environment.get_user_special_dir (UserDirectory.DOCUMENTS);
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_FOLDER_DOCUMENTS_SYMBOLIC, false, null, null, dir.split ("/"), false, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }

            /* templates */
            dir = Environment.get_user_special_dir (UserDirectory.TEMPLATES);
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_FOLDER_TEMPLATES_SYMBOLIC, false, null, null, dir.split ("/"), false, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }

            /* home */
            dir = Environment.get_home_dir ();
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_GO_HOME_SYMBOLIC, false, null, null, dir.split ("/"), true, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }

            /* media mounted volumes */
            dir = "/media";
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_FILESYSTEM_SYMBOLIC, false, null, null, dir.split ("/"), true, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }

            /* filesystem */
            IconDirectory icon = {"/", Marlin.ICON_FILESYSTEM_SYMBOLIC, false, null, null, null, false, null};
            icon.exploded = {"/"};
            add_icon (icon);
            
            up.connect (() => {
                File file = get_file_for_path (text);
                File parent = file.get_parent ();
                
                if (parent != null && file.get_uri () != parent.get_uri ())
                    change_breadcrumbs (parent.get_uri ());
                    
                win.go_up ();
                grab_focus ();
            });

            down.connect (() => {
                win.grab_focus ();
            });

            completed.connect (() => {
                string path = "";
                string newpath = update_breadcrumbs (get_file_for_path (text).get_uri (), path);
                
                foreach (BreadcrumbsElement element in elements) {
                    if (!element.hidden)
                        path += element.text + "/";
                }
            
                if (path != newpath)
                    change_breadcrumbs (newpath);
                
                grab_focus ();
            });

            need_completion.connect (on_need_completion);

            menu = new Gtk.Menu ();
            menu.show_all ();

            search_results = new SearchResults (this);

            search_results.file_selected.connect ((file) => {
                win.grab_focus ();
                win.current_tab.focus_location (file);

                search_mode = false;
                escape ();
            });

            search_results.cursor_changed.connect ((file) => {
                win.current_tab.focus_location_if_in_current_directory (file, true);
            });

            search_results.first_match_found.connect ((file) => {
                win.current_tab.focus_location_if_in_current_directory (file, true);
            });

            search_results.hide.connect (() => {
                text = "";
            });

            search_changed.connect ((text) => {
                search_results.search (text, win.current_tab.location);
            });
        }

        /**
         * This function is used as a callback for files.file_loaded.
         * We check that the file can be used
         * in auto-completion, if yes we put it in our entry.
         *
         * @param file The file you want to load
         *
         **/
        private void on_file_loaded(GOF.File file) {
            string file_display_name = GLib.Uri.unescape_string (file.get_display_name ());
            if (file_display_name.length > to_search.length) {
                if (file_display_name.ascii_ncasecmp (to_search, to_search.length) == 0) {
                    if (!autocompleted) {
                        text_completion = file_display_name.slice (to_search.length, file_display_name.length);
                        autocompleted = true;
                    } else {
                        string file_complet = file_display_name.slice (to_search.length, file_display_name.length);
                        string to_add = "";
                        for (int i = 0; i < (text_completion.length > file_complet.length ? file_complet.length : text_completion.length); i++) {
                            if (text_completion[i] == file_complet[i])
                                to_add += text_completion[i].to_string ();
                            else
                                break;
                        }
                        text_completion = to_add;
                        multiple_completions = true;
                    }
                    
                    /* autocompletion is case insensitive so we have to change the first completed
                     * parts: the entry.text.
                     */
                    string? str = null;
                    if (text.length >=1)
                        str = text.slice (0, text.length - to_search.length);
                    if (str != null && !multiple_completions) {
                        text = str + file.get_display_name ().slice (0, to_search.length);
                        set_position (-1);
                    }
                }
            }
        }

        public void on_need_completion () {
            File file = get_file_for_path (text);

            // don't use get_basename (), it will return "folder" for "/folder/"
            int last_slash = text.last_index_of_char ('/');
            if (last_slash > -1 && last_slash < text.length)
                to_search = text.slice (last_slash + 1, text.length);
            else
                to_search = "";

            autocompleted = false;
            multiple_completions = false;

            if (to_search != "" && file.has_parent (null))
                file = file.get_parent ();
            else
                return;

            var directory = file;
            var files_cache = files;
            
            files = GOF.Directory.Async.from_gfile (directory);
            if (files.file.exists) {
                /* Verify that we got a new instance of files so we do not double up events */
                if (files_cache != files)
                    files.file_loaded.connect (on_file_loaded);
                
                files.load ();
            }
        }

        private void on_files_loaded_menu () {
            // First the "Open in new tab" menuitem is added to the menu.
            var menuitem_newtab = new Gtk.MenuItem.with_label (_("Open in New Tab"));
            menu.append (menuitem_newtab);
            menuitem_newtab.activate.connect (() => {
                win.add_tab (File.new_for_uri (current_right_click_path), Marlin.ViewMode.CURRENT);
            });

            // Then the "Open with" menuitem is added to the menu.
            var menu_open_with = new Gtk.MenuItem.with_label (_("Open with"));
            menu.append (menu_open_with);

            var submenu_open_with = new Gtk.Menu ();
            var root = GOF.File.get (File.new_for_uri (current_right_click_root));
            var app_info_list = Marlin.MimeActions.get_applications_for_folder (root);

            bool at_least_one = false;
            foreach (AppInfo app_info in app_info_list) {
                if (app_info.get_executable () != APP_NAME) {
                    at_least_one = true;
                    var menu_item = new Gtk.ImageMenuItem.with_label (app_info.get_name ());
                    menu_item.set_data ("appinfo", app_info);
                    Icon icon;
                    icon = app_info.get_icon ();
                    if (icon == null)
                        icon = new ThemedIcon ("application-x-executable");

                    menu_item.set_image (new Gtk.Image.from_gicon (icon, Gtk.IconSize.MENU));
                    menu_item.always_show_image = true;
                    menu_item.activate.connect (() => {
                        AppInfo app = submenu_open_with.get_active ().get_data ("appinfo");
                        launch_uri_with_app (app, current_right_click_path);
                    });
                    submenu_open_with.append (menu_item);
                }
            }

            if (at_least_one)
                submenu_open_with.append (new Gtk.SeparatorMenuItem ());

            var open_with_other_item = new Gtk.MenuItem.with_label (_("Other Application .."));
            open_with_other_item.activate.connect (() => {
                var dialog = new Gtk.AppChooserDialog(
                                win,
                                Gtk.DialogFlags.MODAL|Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                File.new_for_uri (current_right_click_path)
                                );

                var response = dialog.run ();
                if (response == Gtk.ResponseType.OK) {
                    AppInfo app = dialog.get_app_info ();
                    launch_uri_with_app (app, current_right_click_path);
                }

                dialog.destroy ();
            });

            submenu_open_with.append (open_with_other_item);
            menu_open_with.set_submenu (submenu_open_with);
            menu.append (new Gtk.SeparatorMenuItem ());


            unowned List<GOF.File>? sorted_dirs = files_menu.get_sorted_dirs ();
            foreach (var gof in sorted_dirs) {
                var menuitem = new Gtk.MenuItem.with_label(gof.get_display_name ());
                menuitem.set_data ("location", gof.get_target_location ());
                menu.append (menuitem);
                menuitem.activate.connect (() => {
                    unowned File loc = menu.get_active ().get_data ("location");
                    win.file_path_change_request (loc);
                });
            }
            menu.show_all ();
        }

        private void launch_uri_with_app (AppInfo app, string uri) {
            var file = GOF.File.get (File.new_for_uri (uri));
            file.launch (win.get_screen (), app);
        }

        private void get_menu_position (Gtk.Menu menu, out int x, out int y, out bool push_in) {
            x = (int) menu_x_root;
            y = (int) menu_y_root;
            push_in = true;
        }

        protected override void load_right_click_menu (double x, double y) {
            menu_x_root = x;
            menu_y_root = y;
            menu = new Gtk.Menu ();
            menu.cancel.connect (() => { reset_elements_states (); });
            menu.deactivate.connect (() => { reset_elements_states (); });
            var directory = File.new_for_uri (current_right_click_root);
            if (files_menu != null)
                files_menu.done_loading.disconnect (on_files_loaded_menu);
            files_menu = GOF.Directory.Async.from_gfile (directory);
            files_menu.done_loading.connect (on_files_loaded_menu);
            files_menu.load ();

            menu.popup (null,
                        null,
                        get_menu_position,
                        0,
                        Gtk.get_current_event_time ());
        }

        protected override bool on_drag_motion (Gdk.DragContext context, int x, int y, uint time) {
            Gtk.drag_unhighlight (this);

            foreach (BreadcrumbsElement element in elements)
                element.pressed = false;

            var el = get_element_from_coordinates (x, y);

            if (el != null)
                el.pressed = true;
            else
                /* No action taken on drop */
                Gdk.drag_status (context, 0, time);

            queue_draw ();

            return false;
        }

        protected override bool on_drag_drop (Gdk.DragContext context,
                                   int x,
                                   int y,
                                   uint timestamp) {
            Gtk.TargetList list = null;
            bool ok_to_drop = false;

            Gdk.Atom target = Gtk.drag_dest_find_target  (this, context, list);

            ok_to_drop = (target != Gdk.Atom.NONE);

            if (ok_to_drop) {
                drop_occurred = true;
                Gtk.drag_get_data (this, context, target, timestamp);
            }

            return ok_to_drop;
        }

        protected override void on_drag_data_received (Gdk.DragContext context,
                                            int x,
                                            int y,
                                            Gtk.SelectionData selection_data,
                                            uint info,
                                            uint timestamp
                                            ) {
            bool success = false;

            if (!drop_data_ready) {
                drop_file_list = null;
                foreach (var uri in selection_data.get_uris ()) {
                    debug ("Path to move: %s\n", uri);
                    drop_file_list.append (File.new_for_uri (uri));
                    drop_data_ready = true;
                }
            }

            if (drop_data_ready && drop_occurred && info == TargetType.TEXT_URI_LIST) {
                drop_occurred = false;
                current_actions = 0;
                current_suggested_action = 0;

                drop_target_file = get_target_location (x, y);
                if (drop_target_file != null) {
                    current_actions = drop_target_file.accepts_drop (drop_file_list,
                                                                     context,
                                                                     out current_suggested_action);

                    if ((current_actions & file_drag_actions) != 0)
                        success = dnd_handler.handle_file_drag_actions  (this,
                                                                         win,
                                                                         context,
                                                                         drop_target_file,
                                                                         drop_file_list,
                                                                         current_actions,
                                                                         current_suggested_action,
                                                                         timestamp);
                }

                Gtk.drag_finish (context, success, false, timestamp);
                on_drag_leave (context, timestamp);
            }
        }

        protected override void on_drag_leave (Gdk.DragContext drag_context, uint time) {
            foreach (BreadcrumbsElement element in elements) {
                if (element.pressed) {
                    element.pressed = false;
                    break;
                }
            }

            drop_occurred = false;
            drop_data_ready = false;
            drop_file_list = null;

            queue_draw ();
        }

        private GOF.File? get_target_location (int x, int y) {
            GOF.File? file;
            var el = get_element_from_coordinates (x, y);
            if (el != null) {
                file = GOF.File.get_by_uri (get_path_from_element (el));
                file.ensure_query_info ();
                return file;
            }
            return null;
        }
    }
}
