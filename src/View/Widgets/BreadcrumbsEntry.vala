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
        Gtk.Menu menu;

        /** Completion support **/
        Directory? current_completion_dir = null;

        bool match_found = false;
        bool multiple_completions = false;
        string to_complete = ""; // Beginning of filename to be completed
        string completion_text {
            get {
                return this.placeholder;
            }

            set {
                if (placeholder != value) {
                    placeholder = value;
                    queue_draw ();
                    /* This corrects undiagnosed bug after completion required on remote filesystem */
                    set_position (-1);
                }
            }
        } // Candidate completion (placeholder)

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
            /* Drag and drop */
            Gtk.TargetEntry target_uri_list = {"text/uri-list", 0, Files.TargetType.TEXT_URI_LIST};
            Gtk.drag_dest_set (this, Gtk.DestDefaults.MOTION,
                               {target_uri_list},
                               Gdk.DragAction.ASK | FILE_DRAG_ACTIONS);

            drag_leave.connect (on_drag_leave);
            drag_motion.connect (on_drag_motion);
            drag_data_received.connect (on_drag_data_received);
            drag_drop.connect (on_drag_drop);
        }

    /** Overridden Navigatable interface functions **/
    /************************************************/
        public override bool on_key_press_event (uint keyval, uint keycode, Gdk.ModifierType state) {
            switch (keyval) {
                case Gdk.Key.Return:
                case Gdk.Key.KP_Enter:
                case Gdk.Key.ISO_Enter:
                    if (search_mode) {
                        return true;
                    }

                    break;
                case Gdk.Key.KP_Tab:
                case Gdk.Key.Tab:
                    set_entry_text (text + completion_text);
                    return true;
            }

            return base.on_key_press_event (keyval, keycode, state);
        }

        public override void reset () {
            base.reset ();
            completion_text = "";
            current_completion_dir = null; // Do not cancel as this could interfere with a loading tab
        }

    /** Search related functions **/
    /******************************/
        public void set_primary_icon_name (string? icon_name) {
            primary_icon_name = icon_name;
        }

        public void hide_primary_icon () {
            primary_icon_pixbuf = null;
        }

        protected override void set_default_entry_tooltip () {
            set_tooltip_markup (_("Search or Type Path"));
        }

    /** Completion related functions
      * Implementing interface virtual functions **/
    /****************************/
        public void completion_needed () {
            string? path = this.text;
            if (path == null || path.length < 1) {
                return;
            }

            to_complete = "";
            completion_text = "";
            /* don't use get_basename (), it will return "folder" for "/folder/" */
            int last_slash = path.last_index_of_char ('/');
            if (last_slash > -1 && last_slash < path.length) {
                to_complete = path.slice (last_slash + 1, path.length);
            }

            if (to_complete.length > 0) {
                if (path == current_dir_path) {
                    return; // Nothing typed yet
                }

                var file = FileUtils.get_file_for_path (path);
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

                multiple_completions = false;
                match_found = false;
                current_completion_dir.init (on_file_loaded, () => {});
            }
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
                    var residue = file_display_name.slice (to_complete.length, file_display_name.length);
                    if (!match_found) {
                        match_found = true;
                        completion_text = residue;
                    } else {
                        multiple_completions = true;
                        unichar c1, c2 = 0;
                        int index1 = 0, index2 = 0;
                        var new_common_chars = "";
                        while (completion_text.get_next_char (ref index1, out c1) &&
                               residue.get_next_char (ref index2, out c2)) {

                            if (c1 == c2 && index1 == index2) {
                                new_common_chars += c1.to_string ();
                            } else {
                                break;
                            }
                        }

                        completion_text = new_common_chars;
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

            var el = get_element_from_coordinates ((double) x);
            current_suggested_action = Gdk.DragAction.DEFAULT;
            if (el != null && drop_file_list != null) {
                el.pressed = true;
                drop_target_file = get_target_location (x, y);
                current_actions = DndHandler.file_accepts_drop (
                    drop_target_file,
                    drop_file_list,
                    context.get_selected_action (),
                    context.get_actions (),
                    out current_suggested_action
                );
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
                if (DndHandler.selection_data_is_uri_list (selection_data, info, out text)) {
                    drop_file_list = FileUtils.files_from_uris (text);
                    drop_data_ready = true;
                }
            }

            GLib.Signal.stop_emission_by_name (this, "drag-data-received");
            if (drop_data_ready && drop_occurred && info == Files.TargetType.TEXT_URI_LIST) {
                drop_occurred = false;
                current_actions = 0;
                current_suggested_action = 0;
                drop_target_file = get_target_location (x, y);
                if (drop_target_file != null) {
                    current_actions = DndHandler.file_accepts_drop (
                        drop_target_file,
                        drop_file_list,
                        context.get_selected_action (),
                        context.get_actions (),
                        out current_suggested_action
                    );

                    if ((current_actions & FILE_DRAG_ACTIONS) != 0) {
                        success = dnd_handler.handle_file_drag_actions (
                            this,
                            drop_target_file,
                            drop_file_list,
                            current_actions,
                            current_suggested_action,
                            (Gtk.ApplicationWindow)Files.get_active_window (),
                            timestamp
                        );
                    }
                }
                Gtk.drag_finish (context, success, false, timestamp);
                on_drag_leave (context, timestamp);
            }
        }

        protected void on_drag_leave (uint time) {
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
        private void load_right_click_menu (Gdk.Event event, BreadcrumbElement clicked_element) {
            string path = get_path_from_element (clicked_element);
            string parent_path = FileUtils.get_parent_path_from_path (path);
            GLib.File? root = FileUtils.get_file_for_path (parent_path);

            var style_context = get_style_context ();
            var padding = style_context.get_padding (style_context.get_state ());
            double x, y, x_root, y_root;
            event.get_coords (out x, out y);
            event.get_root_coords (out x_root, out y_root);
            if (clicked_element.x - BREAD_SPACING < 0) {
                menu_x_root = x_root - x + clicked_element.x;
            } else {
                menu_x_root = x_root - x + clicked_element.x - BREAD_SPACING;
            }

            menu_y_root = y_root - y + get_allocated_height () - padding.bottom - padding.top;

            menu = new Gtk.Menu ();
            menu.cancel.connect (() => {reset_elements_states ();});
            menu.deactivate.connect (() => {reset_elements_states ();});

            build_base_menu (menu, path);
            Directory? files_menu_dir = null;
            if (root != null) {
                files_menu_dir = Directory.from_gfile (root);
                files_menu_dir_handler_id = files_menu_dir.done_loading.connect (() => {
                    append_subdirectories (menu, files_menu_dir);
                    files_menu_dir.disconnect (files_menu_dir_handler_id);
                    // Do not show popup until all children have been appended.
                    menu.show_all ();
                    menu.popup_at_pointer (event);
                });
            } else {
                warning ("Root directory null for %s", path);
                menu.show_all ();
                menu.popup_at_pointer (event);
            }

            if (files_menu_dir != null) {
                files_menu_dir.init ();
            }
        }

        private void build_base_menu (Gtk.Menu menu, string path) {
            /* First the "Open in new tab" menuitem is added to the menu. */
            var menuitem_newtab = new Gtk.MenuItem.with_label (_("Open in New Tab"));
            menu.append (menuitem_newtab);
            menuitem_newtab.activate.connect (() => {
                activate_path (path, Files.OpenFlag.NEW_TAB);
            });

            /* "Open in new window" menuitem is added to the menu. */
            var menuitem_newwin = new Gtk.MenuItem.with_label (_("Open in New Window"));
            menu.append (menuitem_newwin);
            menuitem_newwin.activate.connect (() => {
                activate_path (path, Files.OpenFlag.NEW_WINDOW);
            });

            menu.append (new Gtk.SeparatorMenuItem ());

            var submenu_open_with = new Gtk.Menu ();
            var loc = GLib.File.new_for_uri (FileUtils.escape_uri (path));
            var root = Files.File.get_by_uri (path);
            var app_info_list = MimeActions.get_applications_for_folder (root);
            bool at_least_one = false;
            foreach (AppInfo app_info in app_info_list) {
                if (app_info != null && app_info.get_executable () != Environment.get_application_name ()) {
                    at_least_one = true;
                    var item_grid = new Gtk.Grid ();
                    var img = new Gtk.Image.from_gicon (app_info.get_icon (), Gtk.IconSize.MENU) {
                        pixel_size = 16
                    };

                    item_grid.add (img);
                    item_grid.add (new Gtk.Label (app_info.get_name ()));
                     var menu_item = new Gtk.MenuItem ();
                    menu_item.add (item_grid);
                    menu_item.set_data ("appinfo", app_info);
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

        private void append_subdirectories (Gtk.Menu menu, Directory dir) {
            /* Append list of directories at the same level */
            if (dir.can_load) {
                unowned List<unowned Files.File>? sorted_dirs = dir.get_sorted_dirs ();

                if (sorted_dirs != null) {
                    menu.append (new Gtk.SeparatorMenuItem ());
                    foreach (unowned Files.File gof in sorted_dirs) {
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
            dir = null;
        }

        private Files.File? get_target_location (int x, int y) {
            Files.File? file;
            var el = get_element_from_coordinates ((double) x);
            if (el != null) {
                file = Files.File.get (GLib.File.new_for_commandline_arg (get_path_from_element (el)));
                file.ensure_query_info ();
                return file;
            }
            return null;
        }

        protected override void on_button_pressed_event (int n_press, double x, double y) {
            /* Only handle if not on icon and breadcrumbs are visible.
             * Note, breadcrumbs are hidden when in home directory even when the pathbar does not have focus.*/
            if (is_icon_event (x) || has_focus || hide_breadcrumbs) {
                base.on_button_pressed_event (n_press, x, y);
            } else { // Clicked on breadcrumb?
                var el = mark_pressed_element (x);
                if (el != null) {
                    switch (button_controller.get_current_button ()) {
                        case 2:
                            if (el != null) {
                                button_controller.set_state (Gtk.EventSequenceState.CLAIMED);
                                activate_path (get_path_from_element (el), Files.OpenFlag.NEW_TAB);
                            }

                            break;

                        case 3:
                            button_controller.set_state (Gtk.EventSequenceState.CLAIMED);
                            load_right_click_menu (Gtk.get_current_event (), el);

                            break;

                        default:
                            base.on_button_pressed_event (n_press, x, y);
                            break;
                    }
                }
            }
        }

        protected override void on_button_released_event (int n_press, double x, double y) {
            if (drop_file_list != null) {
                return;
            }

            base.on_button_released_event (n_press, x, y);
        }

        private BreadcrumbElement? mark_pressed_element (double x) {
            reset_elements_states ();
            BreadcrumbElement? el = get_element_from_coordinates (x);
            if (el != null) {
                el.pressed = true;
                queue_draw ();
            }
            return el;
        }




    }
}
