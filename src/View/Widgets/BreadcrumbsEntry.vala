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

namespace Files.View.Chrome {
    public class BreadcrumbsEntry : BasicBreadcrumbsEntry {
        /** Breadcrumb context menu support **/
        ulong files_menu_dir_handler_id = 0;
        // Gtk.PopoverMenu menu;

        /** Completion support **/
        Directory? current_completion_dir = null;

        bool match_found = false;
        bool multiple_completions = false;
        string to_complete = ""; // Beginning of filename to be completed
        string completion_text = ""; // Candidate completion (placeholder)
        string matching_filename = "";
        string common_chars = "";

        public bool search_mode = false; // Used to suppress activate events while searching

        /** Drag and drop support **/
        protected const Gdk.DragAction FILE_DRAG_ACTIONS = (Gdk.DragAction.COPY |
                                                            Gdk.DragAction.MOVE |
                                                            Gdk.DragAction.LINK);

        private bool drop_data_ready = false; /* whether the drop data was received already */
        private bool drop_occurred = false; /* whether the data was dropped */
        private GLib.List<GLib.File> drop_file_list = null; /* the list of URIs in the drop data */
        protected static DndHandler dnd_handler = new DndHandler ();
        Gdk.DragAction current_suggested_action = 0; /* No action */
        Gdk.DragAction current_actions = 0; /* No action */
        Files.File? drop_target_file = null;

        /** Right-click menu support **/
        double menu_x_root;
        double menu_y_root;

        public signal void open_with_request (GLib.File file, AppInfo? app);

        public BreadcrumbsEntry () {
            base ();
            set_up_drag_drop ();
        }

        private void set_up_drag_drop () {
            //TODO Set up DnD
            // /* Drag and drop */
            // Gtk.TargetEntry target_uri_list = {"text/uri-list", 0, Files.TargetType.TEXT_URI_LIST};
            // Gtk.drag_dest_set (this, Gtk.DestDefaults.MOTION,
            //                    {target_uri_list},
            //                    Gdk.DragAction.ASK | FILE_DRAG_ACTIONS);

            // drag_leave.connect (on_drag_leave);
            // drag_motion.connect (on_drag_motion);
            // drag_data_received.connect (on_drag_data_received);
            // drag_drop.connect (on_drag_drop);
        }

    /** Overridden Navigatable interface functions **/
    /************************************************/
        //TODO Use EventController
        // public override bool on_key_press_event (Gdk.EventKey event) {
        //     uint keyval;
        //     event.get_keyval (out keyval);
        //     switch (keyval) {
        //         case Gdk.Key.Return:
        //         case Gdk.Key.KP_Enter:
        //         case Gdk.Key.ISO_Enter:
        //             if (search_mode) {
        //                 return true;
        //             }
        //             break;
        //         case Gdk.Key.KP_Tab:
        //         case Gdk.Key.Tab:
        //             complete ();
        //             return true;
        //     }
        //     return base.on_key_press_event (event);
        // }
        // protected override bool on_button_release_event (Gdk.Event event) {
        //     if (drop_file_list != null) {
        //         return true;
        //     }

        //     return base.on_button_release_event (event);
        // }

        public override void reset () {
            base.reset ();
            clear_completion ();
            current_completion_dir = null; // Do not cancel as this could interfere with a loading tab
        }


    /** Search related functions **/
    /******************************/
        public void set_primary_icon_name (string? icon_name) {
            primary_icon_name = icon_name;
        }

        public void hide_primary_icon () {
            primary_icon_paintable = null;
        }

        protected override void set_default_entry_tooltip () {
            set_tooltip_markup (_("Search or Type Path"));
        }

    /** Completion related functions
      * Implementing interface virtual functions **/
    /****************************/
        public void completion_needed () {
            string? txt = this.text;
            if (txt == null || txt.length < 1) {
                return;
            }

            to_complete = "";
            /* don't use get_basename (), it will return "folder" for "/folder/" */
            int last_slash = txt.last_index_of_char ('/');
            if (last_slash > -1 && last_slash < txt.length) {
                to_complete = txt.slice (last_slash + 1, text.length);
            }
            if (to_complete.length > 0) {
                do_completion (txt);
            } else {
                clear_completion ();
            }
        }

        private void do_completion (string path) {
            if (path == current_dir_path) {
                return; // Nothing typed yet
            }

            GLib.File? file = FileUtils.get_file_for_path (FileUtils.sanitize_path (path, current_dir_path));
            if (file == null) {
                return;
            }

            if (file.has_parent (null)) {
                file = file.get_parent ();
            } else {
                return;
            }

            if (current_completion_dir == null || !file.equal (current_completion_dir.location)) {
                current_completion_dir = Directory.from_gfile (file);
            }

            if (current_completion_dir.can_load) {
                clear_completion ();
                matching_filename = "";
                multiple_completions = false;
                match_found = false;
                current_completion_dir.init (on_file_loaded, on_done_loading);
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
            var gfile = FileUtils.get_file_for_path (txt); /* Sanitizes path */
            var newpath = gfile.get_path ();

            /* If path changed, update breadcrumbs and continue editing */
            if (newpath != null) {
                /* If completed, then GOF File must exist */
                if ((Files.File.@get (gfile)).is_directory) {
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
        private void on_file_loaded (Files.File file) {
            if (!file.is_directory) {
                return;
            }

            string file_display_name = file.get_display_name ();
            if (file_display_name.length > to_complete.length) {
                if (file_display_name.up ().has_prefix (to_complete.up ())) {
                    matching_filename = file_display_name;
                    if (!match_found) {
                        match_found = true;
                        common_chars = matching_filename.slice (
                            to_complete.length, matching_filename.length
                        );
                    } else {
                        multiple_completions = true;
                        unichar c1 = {}, c2 = {};
                        int index1 = 0, index2 = common_chars.length - 1;
                        while (common_chars.get_next_char (ref index1, out c1) &&
                               matching_filename.get_next_char (ref index2, out c2)) {

                            if (c1 == c2) {
                                common_chars += c1.to_string ();
                            } else {
                                break;
                            }
                        }


                    }
                }
            }
        }

        private void on_done_loading () {
            if (multiple_completions) {
                // We do not change the typed characters if there are multiple matches
                set_completion_text (common_chars);
            } else if (match_found) {
                string str = Path.DIR_SEPARATOR_S;
                if (text.length >= 1) {
                    str = text.slice (0, text.length - to_complete.length);
                }

                // Change the typed characters to the match the filename when only one match.
                set_text (str + matching_filename.slice (0, to_complete.length));
                set_completion_text (
                    matching_filename.slice (to_complete.length, matching_filename.length)
                );
            }
        }

    /** Drag-drop functions **/
    /****************************/

        //TODO Reimplement DnD for Gtk4
        // protected bool on_drag_motion (Gdk.DragContext context, int x, int y, uint time) {
        //     if (!drop_data_ready) {
        //         Gtk.TargetList list = null;
        //         Gdk.Atom target = Gtk.drag_dest_find_target (this, context, list);
        //         if (target != Gdk.Atom.NONE) {
        //             Gtk.drag_get_data (this, context, target, time); /* emits "drag_data_received" */
        //         }
        //     }

        //     Gtk.drag_unhighlight (this);
        //     GLib.Signal.stop_emission_by_name (this, "drag-motion");

        //     foreach (BreadcrumbElement element in elements) {
        //         element.pressed = false;
        //     }

        //     var el = get_element_from_coordinates (x, y);
        //     current_suggested_action = Gdk.DragAction.DEFAULT;
        //     if (el != null && drop_file_list != null) {
        //         el.pressed = true;
        //         drop_target_file = get_target_location (x, y);
        //         current_actions = FileUtils.file_accepts_drop (drop_target_file, drop_file_list,
        //                                                        context,
        //                                                        out current_suggested_action);
        //     }

        //     Gdk.drag_status (context, current_suggested_action, time);
        //     queue_draw ();
        //     return true;
        // }

        // protected bool on_drag_drop (Gdk.DragContext context,
        //                              int x,
        //                              int y,
        //                              uint timestamp) {
        //     Gtk.TargetList list = null;
        //     bool ok_to_drop = false;

        //     Gdk.Atom target = Gtk.drag_dest_find_target (this, context, list);

        //     ok_to_drop = (target != Gdk.Atom.NONE);
        //     if (ok_to_drop) {
        //         drop_occurred = true;
        //         Gtk.drag_get_data (this, context, target, timestamp);
        //     }

        //     return ok_to_drop;
        // }

        // protected void on_drag_data_received (Gdk.DragContext context,
        //                                     int x,
        //                                     int y,
        //                                     Gtk.SelectionData selection_data,
        //                                     uint info,
        //                                     uint timestamp
        //                                     ) {
        //     bool success = false;

        //     if (!drop_data_ready) {
        //         /* We don't have the drop data - extract uri list from selection data */
        //         string? text;
        //         if (DndHandler.selection_data_is_uri_list (selection_data, info, out text)) {
        //             drop_file_list = FileUtils.files_from_uris (text);
        //             drop_data_ready = true;
        //         }
        //     }

        //     GLib.Signal.stop_emission_by_name (this, "drag-data-received");
        //     if (drop_data_ready && drop_occurred && info == Files.TargetType.TEXT_URI_LIST) {
        //         drop_occurred = false;
        //         current_actions = 0;
        //         current_suggested_action = 0;
        //         drop_target_file = get_target_location (x, y);
        //         if (drop_target_file != null) {
        //             current_actions = FileUtils.file_accepts_drop (drop_target_file, drop_file_list,
        //                                                              context,
        //                                                              out current_suggested_action);

        //             if ((current_actions & FILE_DRAG_ACTIONS) != 0) {
        //                 success = dnd_handler.handle_file_drag_actions (
        //                     this,
        //                     context,
        //                     drop_target_file,
        //                     drop_file_list,
        //                     current_actions,
        //                     current_suggested_action,
        //                     (Gtk.ApplicationWindow)Files.get_active_window (),
        //                     timestamp
        //                 );
        //             }
        //         }
        //         Gtk.drag_finish (context, success, false, timestamp);
        //         on_drag_leave (context, timestamp);
        //     }
        // }

        // protected void on_drag_leave (Gdk.DragContext drag_context, uint time) {
        //     foreach (BreadcrumbElement element in elements) {
        //         if (element.pressed) {
        //             element.pressed = false;
        //             break;
        //         }
        //     }

        //     drop_occurred = false;
        //     drop_data_ready = false;
        //     drop_file_list = null;

        //     queue_draw ();
        // }

        public void right_click_menu_position_func (GLib.Menu menu, out int x, out int y, out bool push_in) {
            x = (int) menu_x_root;
            y = (int) menu_y_root;
            push_in = true;
        }
    /** Context menu functions **/
    /****************************/
        private void load_right_click_menu (Gdk.Event event, BreadcrumbElement clicked_element) {
            string path = get_path_from_element (clicked_element);
            string parent_path = FileUtils.get_parent_path_from_path (path);
            GLib.File? root = FileUtils.get_file_for_path (parent_path);

            var style_context = get_style_context ();
            var padding = style_context.get_padding ();
            double x, y, x_root, y_root;
            event.get_position (out x, out y);
            //TODO Rework getting menu position
            // event.get_root_coords (out x_root, out y_root);
            // if (clicked_element.x - BREAD_SPACING < 0) {
            //     menu_x_root = x_root - x + clicked_element.x;
            // } else {
            //     menu_x_root = x_root - x + clicked_element.x - BREAD_SPACING;
            // }

            // menu_y_root = y_root - y + get_allocated_height () - padding.bottom - padding.top;


            // menu.deactivate.connect (() => {reset_elements_states ();});

            var menu = build_base_menu (path);
            var popover_menu = new Gtk.PopoverMenu.from_model (menu);
            popover_menu.closed.connect (() => {reset_elements_states ();});
            Directory? files_menu_dir = null;
            if (root != null) {
                files_menu_dir = Directory.from_gfile (root);
                files_menu_dir_handler_id = files_menu_dir.done_loading.connect (() => {
                    append_subdirectories (menu, files_menu_dir);
                    files_menu_dir.disconnect (files_menu_dir_handler_id);
                    // Do not show popup until all children have been appended.
                    // menu.show_all ();
                    popover_menu.popup ();
                });
            } else {
                warning ("Root directory null for %s", path);
                popover_menu.popup ();
            }

            if (files_menu_dir != null) {
                files_menu_dir.init ();
            }
        }

        private Menu build_base_menu (string path) {
            /* First the "Open in new tab" menuitem is added to the menu. */
            var menuitem_newtab = new GLib.MenuItem (_("Open in New Tab"), null);
            //TODO Create actions
            var menu = new Menu ();
            menu.append (_("Open in New Tab"), null);
            // menuitem_newtab.activate.connect (() => {
            //     activate_path (path, Files.OpenFlag.NEW_TAB);
            // });

            /* "Open in new window" menuitem is added to the menu. */
            // var menuitem_newwin = new GLib.MenuItem.with_label (_("Open in New Window"));
            menu.append (_("Open in New Window"), null);
            // menuitem_newwin.activate.connect (() => {
            //     activate_path (path, Files.OpenFlag.NEW_WINDOW);
            // });

            // menu.append (new Gtk.SeparatorMenuItem ());

            var submenu_open_with = new GLib.Menu ();
            var loc = GLib.File.new_for_uri (FileUtils.escape_uri (path));
            var root = Files.File.get_by_uri (path);
            var app_info_list = MimeActions.get_applications_for_folder (root);
            bool at_least_one = false;
            foreach (AppInfo app_info in app_info_list) {
                if (app_info != null && app_info.get_executable () != Environment.get_application_name ()) {
                    at_least_one = true;
                    // var item_grid = new Gtk.Grid ();
                    // var img = new Gtk.Image.from_gicon (app_info.get_icon (), Gtk.IconSize.MENU) {
                    //     pixel_size = 16
                    // };

                    // item_grid.add (img);
                    // item_grid.add (new Gtk.Label (app_info.get_name ()));
                    var menu_item = new GLib.MenuItem (app_info.get_name (), null);
                    // menu_item.add (item_grid);
                    menu_item.set_icon (app_info.get_icon ());
                    menu_item.set_data ("appinfo", app_info);
                    // menu_item.activate.connect (() => {
                    //     open_with_request (loc, app_info);
                    // });

                    submenu_open_with.append_item (menu_item);
                }
            }

            if (at_least_one) {
                /* Then the "Open with" menuitem is added to the menu. */
                // var menu_open_with = new GLib.MenuItem.with_label (_("Open with"));
                var menu_open_with = new GLib.MenuItem (_("Open with"), null);
                menu.append_item (menu_open_with);
                menu_open_with.set_submenu (submenu_open_with);
                // submenu_open_with.append (new Gtk.SeparatorMenuItem ());
            }

            /* Then the "Open with other application ..." menuitem is added to the menu. */
            var open_with_other_item = new GLib.MenuItem (_("Open in Other Application…"), null);
            // open_with_other_item.activate.connect (() => {
            //     open_with_request (loc, null);
            // });

            submenu_open_with.append_item (open_with_other_item);
        }

        private void append_subdirectories (Menu menu, Directory dir) {
            /* Append list of directories at the same level */
            if (dir.can_load) {
                unowned List<unowned Files.File>? sorted_dirs = dir.get_sorted_dirs ();

                if (sorted_dirs != null) {
                    // menu.append (new Gtk.SeparatorMenuItem ());
                    foreach (unowned Files.File gof in sorted_dirs) {
                        var menuitem = new GLib.MenuItem (gof.get_display_name (), null);
                        menuitem.set_data ("location", gof.uri);
                        menu.append_item (menuitem);
                        // menuitem.activate.connect ((mi) => {
                        //     activate_path (mi.get_data ("location"));
                        // });
                    }
                }
            }
            // menu.show_all ();
            /* Release the Async directory as soon as possible */
            dir = null;
        }

        private Files.File? get_target_location (int x, int y) {
            Files.File? file;
            var el = get_element_from_coordinates (x, y);
            if (el != null) {
                file = Files.File.get (GLib.File.new_for_commandline_arg (get_path_from_element (el)));
                file.ensure_query_info ();
                return file;
            }
            return null;
        }

        //TODO Use EventControllers and icon_press signal
        // protected void on_icon_press_event () {
        // 
        // }
        // 
        // protected override bool on_button_press_event (Gdk.Event event) {
        //     /* Only handle if not on icon and breadcrumbs are visible.
        //      * Note, breadcrumbs are hidden when in home directory even when the pathbar does not have focus.*/
        //     if (is_icon_event (event) || has_focus || hide_breadcrumbs) {
        //         return base.on_button_press_event (event);
        //     } else {
        //         var el = mark_pressed_element (event);
        //         if (el != null) {
        //             uint button;
        //             event.get_button (out button);
        //             switch (button) {
        //                 case 1:
        //                     break; // Long press support discontinued as provided by system settings
        //                 case 2:
        //                     handle_middle_button_press (event, el);
        //                     break;
        //                 case 3:
        //                     handle_secondary_button_press (event, el);
        //                     break;
        //                 default:
        //                     break;
        //             }
        //         }
        //     }

        //     return true;
        // }

        // private BreadcrumbElement? mark_pressed_element (Gdk.Event event) {
        //     reset_elements_states ();
        //     double x, y;
        //     event.get_coords (out x, out y);
        //     BreadcrumbElement? el = get_element_from_coordinates ((int)x, (int)y);
        //     if (el != null) {
        //         el.pressed = true;
        //         queue_draw ();
        //     }
        //     return el;
        // }

        // protected void handle_middle_button_press (Gdk.Event event, BreadcrumbElement? el) {
        //     if (el != null) {
        //         activate_path (get_path_from_element (el), Files.OpenFlag.NEW_TAB);
        //     }
        // }

        // protected void handle_secondary_button_press (Gdk.Event event, BreadcrumbElement? el) {
        //     load_right_click_menu (event, el);
        // }
    }
}
