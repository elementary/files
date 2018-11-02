/***
    Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>

    Marlin is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of the
    License, or (at your option) any later version.

    Marlin is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this program; see the file COPYING.  If not,
    write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1335 USA.

***/

namespace Marlin.View.Chrome {
    public class BreadcrumbsEntry : BasicBreadcrumbsEntry {
        /** Breadcrumb context menu support **/
        ulong files_menu_dir_handler_id = 0;
        Gtk.Menu menu;

        /** Completion support **/
        GOF.Directory.Async? current_completion_dir = null;
        string completion_text = "";
        bool autocompleted = false;
        bool multiple_completions = false;
        /* The string which contains the text we search in the file. e.g, if the
         * user enter /home/user/a, we will search for "a". */
        string to_search = "";

        public bool search_mode = false; // Used to suppress activate events while searching

        /** Drag and drop support **/
        protected const Gdk.DragAction file_drag_actions = (Gdk.DragAction.COPY |
                                                            Gdk.DragAction.MOVE |
                                                            Gdk.DragAction.LINK);

        private bool drop_data_ready = false; /* whether the drop data was received already */
        private bool drop_occurred = false; /* whether the data was dropped */
        private GLib.List<GLib.File> drop_file_list = null; /* the list of URIs in the drop data */
        protected static Marlin.DndHandler dnd_handler = new Marlin.DndHandler ();
        Gdk.DragAction current_suggested_action = 0; /* No action */
        Gdk.DragAction current_actions = 0; /* No action */
        GOF.File? drop_target_file = null;

        /** Long button press support **/
        uint button_press_timeout_id = 0;
        /** Right-click menu support **/
        double menu_x_root;
        double menu_y_root;

        public signal void open_with_request (File file, AppInfo? app);

        public BreadcrumbsEntry () {
            base ();
            set_up_drag_drop ();
        }

        private void set_up_drag_drop () {
            /* Drag and drop */
            Gtk.TargetEntry target_uri_list = {"text/uri-list", 0, Marlin.TargetType.TEXT_URI_LIST};
            Gtk.drag_dest_set (this, Gtk.DestDefaults.MOTION, {target_uri_list}, Gdk.DragAction.ASK|file_drag_actions);
            drag_leave.connect (on_drag_leave);
            drag_motion.connect (on_drag_motion);
            drag_data_received.connect (on_drag_data_received);
            drag_drop.connect (on_drag_drop);
        }

    /** Overridden Navigatable interface functions **/
    /************************************************/
        public override bool on_key_press_event (Gdk.EventKey event) {
            autocompleted = false;
            multiple_completions = false;

            switch (event.keyval) {
                case Gdk.Key.Return:
                case Gdk.Key.KP_Enter:
                case Gdk.Key.ISO_Enter:
                    if (search_mode) {
                        return true;
                    }
                    break;
                case Gdk.Key.KP_Tab:
                case Gdk.Key.Tab:
                    complete ();
                    return true;
            }

            return base.on_key_press_event (event);
        }

        public override void reset () {
            base.reset ();
            clear_completion ();
            cancel_completion_dir ();
        }

        protected override bool on_button_release_event (Gdk.EventButton event) {
            if (button_press_timeout_id > 0) {
                Source.remove (button_press_timeout_id);
                button_press_timeout_id = 0;
            }
            if (drop_file_list != null) {
                return true;
            }
            if (event.button == 1) {
                return base.on_button_release_event (event);
            } else { /* other buttons act on press */
                return true;
            }
        }


    /** Search related functions **/
    /******************************/
        public void set_primary_icon_name (string? icon_name) {
            primary_icon_name = icon_name;
        }

        public void hide_primary_icon () {
            primary_icon_pixbuf = null;
        }

    /** Completion related functions
      * Implementing interface virtual functions **/
    /****************************/
        public void completion_needed () {
            string? txt = this.text;
            if (txt == null || txt.length < 1) {
                return;
            }

            to_search = "";
            /* don't use get_basename (), it will return "folder" for "/folder/" */
            int last_slash = txt.last_index_of_char ('/');
            if (last_slash > -1 && last_slash < txt.length) {
                to_search = txt.slice (last_slash + 1, text.length);
            }
            if (to_search.length > 0) {
                do_completion (txt);
            } else {
                clear_completion ();
            }
        }

        private void do_completion (string path) {
            File? file = PF.FileUtils.get_file_for_path (PF.FileUtils.sanitize_path (path, current_dir_path));
            if (file == null || autocompleted) {
                return;
            }

            if (file.has_parent (null)) {
                file = file.get_parent ();
            } else {
                return;
            }

            if (current_completion_dir == null || !file.equal (current_completion_dir.location)) {
                current_completion_dir = GOF.Directory.Async.from_gfile (file);
                current_completion_dir.init (on_file_loaded);
            } else if (current_completion_dir != null && current_completion_dir.can_load) {
                clear_completion ();
                /* Completion text set by on_file_loaded () */
                current_completion_dir.init (on_file_loaded);
            }
        }

        private void cancel_completion_dir () {
            if (current_completion_dir != null) {
                current_completion_dir.cancel ();
                current_completion_dir = null;
            }
        }

        protected void complete () {
            if (completion_text.length == 0) {
                return;
            }

            string path = text + completion_text;
            /* If there are multiple results, tab as far as we can, otherwise do the entire result */
            if (!multiple_completions) {
                completed (path);
            } else {
                set_entry_text (path);
            }
        }

        private void completed (string txt) {
            var gfile = PF.FileUtils.get_file_for_path (txt); /* Sanitizes path */
            var newpath = gfile.get_path ();

            /* If path changed, update breadcrumbs and continue editing */
            if (newpath != null) {
                /* If completed, then GOF File must exist */
                if ((GOF.File.@get (gfile)).is_directory) {
                    newpath += GLib.Path.DIR_SEPARATOR_S;
                }

                set_entry_text (newpath);
            }

            set_completion_text ("");
        }

        private void set_completion_text (string txt) {
            completion_text = txt;
            if (placeholder != completion_text) {
                placeholder = completion_text;
                queue_draw ();
                /* This corrects undiagnosed bug after completion required on remote filesystem */
                set_position (-1);
            }
        }

        private void clear_completion () {
            set_completion_text ("");
        }

        /**
         * This function is used as a callback for files.file_loaded.
         * We check that the file can be used
         * in auto-completion, if yes we put it in our entry.
         *
         * @param file The file you want to load
         *
         **/
        private void on_file_loaded (GOF.File file) {
            if (!file.is_directory) {
                return;
            }

            string file_display_name = file.get_display_name ();
            if (file_display_name.length > to_search.length) {
                if (file_display_name.ascii_ncasecmp (to_search, to_search.length) == 0) {
                    if (!autocompleted) {
                        set_completion_text (file_display_name.slice (to_search.length, file_display_name.length));
                        autocompleted = true;
                    } else {
                        string file_complet = file_display_name.slice (to_search.length, file_display_name.length);
                        string to_add = "";
                        for (int i = 0; i < int.min (completion_text.length, file_complet.length); i++) {
                            if (completion_text[i] == file_complet[i]) {
                                to_add += completion_text[i].to_string ();
                            } else {
                                break;
                            }
                        }

                        set_completion_text (to_add);
                        multiple_completions = true;
                    }

                    string? str = null;
                    if (text.length >= 1) {
                        str = text.slice (0, text.length - to_search.length);
                    }

                    if (str == null) {
                        return;
                    }

                    /* autocompletion is case insensitive so we have to change the first completed
                     * parts to the match the filename (if unique match and if the user did not
                     * deliberately enter an uppercase character).
                     */
                    if (!multiple_completions && !(to_search.down () != to_search)) {
                        set_text (str + file_display_name.slice (0, to_search.length));
                    }
                }
            }
        }

    /** Drag-drop functions **/
    /****************************/

        protected bool on_drag_motion (Gdk.DragContext context, int x, int y, uint time) {
            if (!drop_data_ready) {
                Gtk.TargetList list = null;
                Gdk.Atom target = Gtk.drag_dest_find_target (this, context, list);
                if (target != Gdk.Atom.NONE) {
                    Gtk.drag_get_data (this, context, target, time); /* emits "drag_data_received" */
                }
            }

            Gtk.drag_unhighlight (this);
            GLib.Signal.stop_emission_by_name (this, "drag-motion");

            foreach (BreadcrumbElement element in elements) {
                element.pressed = false;
            }

            var el = get_element_from_coordinates (x, y);
            current_suggested_action = Gdk.DragAction.DEFAULT;
            if (el != null && drop_file_list != null) {
                el.pressed = true;
                drop_target_file = get_target_location (x, y);
                current_actions = PF.FileUtils.file_accepts_drop (drop_target_file, drop_file_list,
                                                                  context,
                                                                  out current_suggested_action);
            }

            Gdk.drag_status (context, current_suggested_action, time);
            queue_draw ();
            return true;
        }

        protected bool on_drag_drop (Gdk.DragContext context,
                                     int x,
                                     int y,
                                     uint timestamp) {
            Gtk.TargetList list = null;
            bool ok_to_drop = false;

            Gdk.Atom target = Gtk.drag_dest_find_target (this, context, list);

            ok_to_drop = (target != Gdk.Atom.NONE);
            if (ok_to_drop) {
                drop_occurred = true;
                Gtk.drag_get_data (this, context, target, timestamp);
            }

            return ok_to_drop;
        }

        protected void on_drag_data_received (Gdk.DragContext context,
                                            int x,
                                            int y,
                                            Gtk.SelectionData selection_data,
                                            uint info,
                                            uint timestamp
                                            ) {
            bool success = false;

            if (!drop_data_ready) {
                /* We don't have the drop data - extract uri list from selection data */
                string? text;
                if (Marlin.DndHandler.selection_data_is_uri_list (selection_data, info, out text)) {
                    drop_file_list = PF.FileUtils.files_from_uris (text);
                    drop_data_ready = true;
                }
            }

            GLib.Signal.stop_emission_by_name (this, "drag-data-received");
            if (drop_data_ready && drop_occurred && info == Marlin.TargetType.TEXT_URI_LIST) {
                drop_occurred = false;
                current_actions = 0;
                current_suggested_action = 0;
                drop_target_file = get_target_location (x, y);
                if (drop_target_file != null) {
                    current_actions = PF.FileUtils.file_accepts_drop (drop_target_file, drop_file_list,
                                                                     context,
                                                                     out current_suggested_action);

                    if ((current_actions & file_drag_actions) != 0) {
                        success = dnd_handler.handle_file_drag_actions (this,
                                                                        this.get_toplevel () as Gtk.ApplicationWindow,
                                                                        context,
                                                                        drop_target_file,
                                                                        drop_file_list,
                                                                        current_actions,
                                                                        current_suggested_action,
                                                                        timestamp);
                    }
                }
                Gtk.drag_finish (context, success, false, timestamp);
                on_drag_leave (context, timestamp);
            }
        }

        protected void on_drag_leave (Gdk.DragContext drag_context, uint time) {
            foreach (BreadcrumbElement element in elements) {
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

        public void right_click_menu_position_func (Gtk.Menu menu, out int x, out int y, out bool push_in) {
            x = (int) menu_x_root;
            y = (int) menu_y_root;
            push_in = true;
        }
    /** Context menu functions **/
    /****************************/
        private void load_right_click_menu (Gdk.EventButton event, BreadcrumbElement clicked_element) {
            string path = get_path_from_element (clicked_element);
            GLib.File loc = PF.FileUtils.get_file_for_path (path);
            string parent_path = PF.FileUtils.get_parent_path_from_path (path);
            GLib.File? root = PF.FileUtils.get_file_for_path (parent_path);

            var style_context = get_style_context ();
            var padding = style_context.get_padding (style_context.get_state ());
            if (clicked_element.x - BREAD_SPACING < 0) {
                menu_x_root = event.x_root - event.x + clicked_element.x;
            } else {
                menu_x_root = event.x_root - event.x + clicked_element.x - BREAD_SPACING;
            }

            menu_y_root = event.y_root - event.y + get_allocated_height () - padding.bottom - padding.top;

            menu = new Gtk.Menu ();
            menu.cancel.connect (() => {reset_elements_states ();});
            menu.deactivate.connect (() => {reset_elements_states ();});

            build_base_menu (menu, loc);
            GOF.Directory.Async? files_menu_dir = null;
            if (root != null) {
                files_menu_dir = GOF.Directory.Async.from_gfile (root);
                files_menu_dir_handler_id = files_menu_dir.done_loading.connect (() => {
                    append_subdirectories (menu, files_menu_dir);
                    files_menu_dir.disconnect (files_menu_dir_handler_id);
                });
            } else {
                warning ("Root directory null for %s", path);
            }

            menu.show_all ();
            menu.popup (null,
                        null,
                        right_click_menu_position_func,
                        0,
                        event.time);

            if (files_menu_dir != null) {
                files_menu_dir.init ();
            }
        }

        private void build_base_menu (Gtk.Menu menu, GLib.File loc) {
            /* First the "Open in new tab" menuitem is added to the menu. */
            var path = loc.get_uri ();
            var menuitem_newtab = new Gtk.MenuItem.with_label (_("Open in New Tab"));
            menu.append (menuitem_newtab);
            menuitem_newtab.activate.connect (() => {
                activate_path (path, Marlin.OpenFlag.NEW_TAB);
            });

            /* "Open in new window" menuitem is added to the menu. */
            var menuitem_newwin = new Gtk.MenuItem.with_label (_("Open in New Window"));
            menu.append (menuitem_newwin);
            menuitem_newwin.activate.connect (() => {
                activate_path (path, Marlin.OpenFlag.NEW_WINDOW);
            });

            menu.append (new Gtk.SeparatorMenuItem ());

            var submenu_open_with = new Gtk.Menu ();
            var root = GOF.File.get (loc);
            var app_info_list = Marlin.MimeActions.get_applications_for_folder (root);
            bool at_least_one = false;
            foreach (AppInfo app_info in app_info_list) {
                if (app_info != null && app_info.get_executable () != Environment.get_application_name ()) {
                    at_least_one = true;
                    var menu_item = new Gtk.ImageMenuItem.with_label (app_info.get_name ());
                    menu_item.set_data ("appinfo", app_info);
                    Icon icon;
                    icon = app_info.get_icon ();
                    if (icon == null) {
                        icon = new ThemedIcon ("application-x-executable");
                    }

                    menu_item.set_image (new Gtk.Image.from_gicon (icon, Gtk.IconSize.MENU));
                    menu_item.always_show_image = true;
                    menu_item.activate.connect (() => {
                        open_with_request (loc, app_info);
                    });
                    submenu_open_with.append (menu_item);
                }
            }
            if (at_least_one) {
                /* Then the "Open with" menuitem is added to the menu. */
                var menu_open_with = new Gtk.MenuItem.with_label (_("Open with"));
                menu.append (menu_open_with);
                menu_open_with.set_submenu (submenu_open_with);
                submenu_open_with.append (new Gtk.SeparatorMenuItem ());
            }

            /* Then the "Open with other application ..." menuitem is added to the menu. */
            var open_with_other_item = new Gtk.MenuItem.with_label (_("Open in Other Application…"));
            open_with_other_item.activate.connect (() => {
                open_with_request (loc, null);
            });

            submenu_open_with.append (open_with_other_item);
        }

        private void append_subdirectories (Gtk.Menu menu, GOF.Directory.Async dir) {
            /* Append list of directories at the same level */
            if (dir.can_load) {
                unowned List<GOF.File>? sorted_dirs = dir.get_sorted_dirs ();

                if (sorted_dirs != null) {
                    menu.append (new Gtk.SeparatorMenuItem ());
                    foreach (var gof in sorted_dirs) {
                        var menuitem = new Gtk.MenuItem.with_label (gof.get_display_name ());
                        menuitem.set_data ("location", gof.uri);
                        menu.append (menuitem);
                        menuitem.activate.connect ((mi) => {
                            activate_path (mi.get_data ("location"));
                        });
                    }
                }
            }
            menu.show_all ();
            /* Release the Async directory as soon as possible */
            dir.cancel ();
            dir = null;
        }

        private GOF.File? get_target_location (int x, int y) {
            GOF.File? file;
            var el = get_element_from_coordinates (x, y);
            if (el != null) {
                file = GOF.File.get (GLib.File.new_for_commandline_arg (get_path_from_element (el)));
                file.ensure_query_info ();
                return file;
            }
            return null;
        }

        protected override bool on_button_press_event (Gdk.EventButton event) {
            if (icon_event (event) || has_focus) {
                return base.on_button_press_event (event);
            } else {
                var el = mark_pressed_element (event);
                if (el != null) {
                    switch (event.button) {
                        case 1:
                            handle_primary_button_press (event, el);
                            break;
                        case 2:
                            handle_middle_button_press (event, el);
                            break;
                        case 3:
                            handle_secondary_button_press (event, el);
                            break;
                        default:
                            break;
                    }
                }
            }
            return true;
        }

        private BreadcrumbElement? mark_pressed_element (Gdk.EventButton event) {
            reset_elements_states ();
            BreadcrumbElement? el = get_element_from_coordinates ((int) event.x, (int) event.y);
            if (el != null) {
                el.pressed = true;
                queue_draw ();
            }
            return el;
        }
        protected void handle_primary_button_press (Gdk.EventButton event, BreadcrumbElement? el) {
            if (el != null) {
                if (button_press_timeout_id == 0) {
                    button_press_timeout_id = Timeout.add (Marlin.BUTTON_LONG_PRESS, () => {
                        load_right_click_menu (event, el);
                        button_press_timeout_id = 0;
                        return false;
                    });
                }
            }
        }
        protected void handle_middle_button_press (Gdk.EventButton event, BreadcrumbElement? el) {
            if (el != null) {
                activate_path (get_path_from_element (el), Marlin.OpenFlag.NEW_TAB);
            }
        }
        protected void handle_secondary_button_press (Gdk.EventButton event, BreadcrumbElement? el) {
            load_right_click_menu (event, el);
        }
    }
}
