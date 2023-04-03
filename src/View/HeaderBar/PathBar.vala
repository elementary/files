/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later

 * Authored by: Jeremy Wootten jeremywootten@gmail.com
*/

public class Files.PathBar : Files.BasicPathBar, PathBarInterface {
    /** Completion support **/
    private Directory? current_completion_dir = null;
    private Gtk.PopoverMenu completion_popover;
    private Menu completion_model;
    /** Drop support **/
    private string current_drop_uri { get; set; default = "";}
    private bool drop_accepted { get; set; default = false; }
    private Gdk.DragAction accepted_actions { get; set; default = 0; }
    private static List<GLib.File> dropped_files;

    //For sorting suggestions
    private Gee.ArrayList<string> completion_list;
    private string to_complete = "";

    //Dearching
    private Gtk.SearchEntry search_entry;
    private Gtk.Popover search_popover;
    private Files.SearchResults search_results;

    construct {
        // Enable path entry completions
        var set_text_action = new SimpleAction ("set-text", new VariantType ("s"));
        set_text_action.activate.connect ((param) => {
            path_entry.text = param.get_string ();
        });
        var tab_complete_action = new SimpleAction ("tab-complete", null);
        tab_complete_action.activate.connect (() => {
            var common_text = get_common_completion ();
            if (common_text != "") {
                path_entry.text = common_text;
                Idle.add (() => {
                    path_entry.select_all = false;
                    path_entry.cursor_position = -1;
                    return Source.REMOVE;
                });
            }
        });

        var pathbar_action_group = new SimpleActionGroup ();
        pathbar_action_group.add_action (set_text_action);
        insert_action_group ("pathbar", pathbar_action_group);

        //Attempt to add local shortcuts did not work for some reason so do it the old way
        var key_controller = new Gtk.EventControllerKey () {
            propagation_phase = Gtk.PropagationPhase.CAPTURE
        };
        path_entry.add_controller (key_controller);
        key_controller.key_pressed.connect ((keyval, keycode, state) => {
            switch (keyval) {
                case Gdk.Key.Tab:
                    if (state == 0 && completion_popover.visible) {
                        tab_complete_action.activate (null);
                        return true;
                    }

                    break;
                case Gdk.Key.Escape:
                    if (state == 0) {
                        activate_action ("win.focus-view", null, null);
                        return true;
                    }

                    break;
                default:
                    return false;
            }
        });

        completion_popover = new Gtk.PopoverMenu.from_model (null) {
            autohide = false,
            can_focus = false
        };
        completion_popover.set_parent (this);
        completion_model = new Menu ();
        completion_list = new Gee.ArrayList<string> ();

        path_entry.completion_request.connect (completion_needed);
        notify["mode"].connect (() => {
            if (mode != PathBarMode.ENTRY) {
                completion_popover.popdown ();
            }
        });

        // Enable breadcrumb context menu
        var secondary_gesture = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        breadcrumbs.scrolled_window.add_controller (secondary_gesture);
        secondary_gesture.pressed.connect ((n_press, x, y) => {
            secondary_gesture.set_state (Gtk.EventSequenceState.CLAIMED);
            handle_secondary_press (x, y);
        });

        //Set drop target
        set_up_drop_target ();

        search_entry = new Gtk.SearchEntry ();
        search_popover = new Gtk.Popover () {
            has_arrow = false,
            autohide = false, // Not modal
            width_request = 500 // For now. Simpler than dynamic resizing.
        };

        search_results = new Files.SearchResults ();
        search_popover.child = search_results.content;

        var search_size_group = new Gtk.SizeGroup (Gtk.SizeGroupMode.HORIZONTAL);
        search_size_group.add_widget (search_entry);
        search_size_group.add_widget (search_results.content);

        search_entry.search_changed.connect ((se) => {
            if (!search_popover.visible && search_entry.text != "") {
                search_popover.popup ();
            } else if (search_popover.visible && search_entry.text == "") {
                search_popover.popdown ();
            }

            search_results.search (se.text);
        });

        search_entry.stop_search.connect (() => {
            warning ("search stopped");
            search_results.cancel ();
            search_popover.popdown ();
        });
        stack.add_child (search_entry);

        var search_button = new Gtk.Button () {
            icon_name = "edit-find-symbolic",
            action_name = "win.find",
            action_target = "",
            hexpand = false,
            halign = Gtk.Align.START,
            margin_end = 24,
            can_focus = false
       };

        search_popover.set_parent (search_entry);

        search_button.clicked.connect (() => {
            var cw = search_entry.get_size (Gtk.Orientation.HORIZONTAL);
            mode = PathBarMode.SEARCH;
            stack.visible_child = search_entry;
            search_entry.grab_focus ();
            search_results.root_search_folder = GLib.File.new_for_uri (
                Files.FileUtils.sanitize_path (display_uri)
            );
        });

        content.prepend (search_button);
    }

    public override void navigate_to_uri (string uri) {
        // Use an existing action rather than the signal used for the filechooser
        activate_action (
            "win.path-change-request", "(su)", uri, Files.OpenFlag.DEFAULT
        );
    }

/** Context menu related functions
/*******************************/
    private void handle_secondary_press (double x, double y) {
        var crumb = breadcrumbs.get_crumb_from_coords (x, y);
        if (crumb == null) {
            return;
        }

        string path = crumb.dir_path;
        string parent_path = FileUtils.get_parent_path_from_path (path);
        GLib.File? root = FileUtils.get_file_for_path (parent_path);

        var menu = new GLib.Menu ();
        menu.append (
            _("Open in New Tab"),
            Action.print_detailed_name (
                "win.path-change-request",
                new Variant ("(su)", path, Files.OpenFlag.NEW_TAB)
            )
        );
        menu.append (
            _("Open in New Window"),
            Action.print_detailed_name (
                "win.path-change-request",
                new Variant ("(su)", path, Files.OpenFlag.NEW_WINDOW)
            )
        );
        menu.append (
            _("Properties"),
            Action.print_detailed_name (
                "win.properties",
                new Variant ("s", path)
            )
        );

        if (root != null) {
            var files_menu_dir = Directory.from_gfile (root);
            files_menu_dir.init.begin (null, null, (obj, res) => {
                if (files_menu_dir.can_load) {
                    unowned List<unowned Files.File>? sorted_dirs = files_menu_dir.get_sorted_dirs ();
                    if (sorted_dirs != null) {
                        var subdir_menu = new Menu ();
                        foreach (unowned Files.File gof in sorted_dirs) {
                            subdir_menu.append (
                                gof.get_display_name (),
                                Action.print_detailed_name (
                                    "win.path-change-request",
                                    new Variant ("(su)", gof.uri, Files.OpenFlag.DEFAULT)
                                )
                            );
                        }
                        menu.append_section (null, subdir_menu);
                    }

                    show_context_menu (menu, x, y);
                }
            });
        } else {
            warning ("Root directory null for %s", path);
            show_context_menu (menu, x, y);
        }
    }

    private void show_context_menu (Menu menu_model, double x, double y) {
        var popover = new Gtk.PopoverMenu.from_model (menu_model);
        popover.set_parent (this);
        popover.set_pointing_to ({(int)x, (int)y, 1, 1});
        Idle.add (() => {
          popover.popup ();
          return Source.REMOVE;
        });
    }

/** Completion related functions
/*******************************/
    public void completion_needed () {
        string? txt = path_entry.text;
        if (txt == null || txt.length < 1) {
            return;
        }

        to_complete = "";
        /* don't use get_basename (), it will return "folder" for "/folder/" */
        int last_slash = txt.last_index_of_char ('/');
        if (last_slash > -1 && last_slash < txt.length) {
            to_complete = txt.slice (last_slash + 1, txt.length);
        }
        if (to_complete.length > 0) {
            do_completion (txt);
        } else {
            completion_popover.popdown ();
        }
    }

    private void do_completion (string path) {
        GLib.File? file = FileUtils.get_file_for_path (FileUtils.sanitize_path (path, display_uri));
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
            current_completion_dir.init.begin ();
            completion_popover.popdown ();
        } else if (current_completion_dir != null && current_completion_dir.can_load) {
            completion_list.clear ();
            /* Completion text set by on_file_loaded () */
            current_completion_dir.init.begin (
                on_file_loaded,
                null,
                (obj, res) => {
                    if (current_completion_dir.init.end (res)) {
                        var completion_menu = new Menu ();
                        completion_list.sort ();
                        completion_list.foreach ((uri) => {
                            completion_menu.append (
                                Path.get_basename (uri),
                                Action.print_detailed_name (
                                    "pathbar.set-text",
                                    new Variant ("s", uri)
                                )
                            );

                            return true;
                        });

                        completion_popover.menu_model = completion_menu;
                        completion_popover.popup ();
                    }
                }
            );
        }
    }

    private string get_common_completion () {
        if (completion_list.size == 0) {
            return "";
        } else {
            var previous_common_text = "";
            int n_chars = int.MAX;
            completion_list.foreach ((uri) => {
                var basename = Path.get_basename (uri);
                if (previous_common_text == "") {
                    previous_common_text = basename;
                    n_chars = basename.length;
                } else {
                    int i = 0;
                    while (basename[i] == previous_common_text[i] && i <= n_chars) {
                        i++;
                    }
                    n_chars = i;
                    return n_chars > 0;
                }

                return true;
            });

            if (n_chars <= previous_common_text.length) {
                var common_dir = current_completion_dir.file.uri;
                var common_base = previous_common_text.slice (0, n_chars);
                return Path.build_filename (common_dir, common_base);
            } else {
                return "";
            }
        }
    }

    // Update the list of possible completions based on entry so far
    // If non-zero completions popup suggestion popover
    private void on_file_loaded (Files.File file) {
        if (!file.is_directory) {
            return;
        }

        string file_display_name = file.get_display_name ();
        if (file_display_name.length > to_complete.length) {
            if (file_display_name.ascii_ncasecmp (to_complete, to_complete.length) == 0) {
                //Start of filename matches search term
                completion_list.add (file.uri);
            }
        }
    }

/** Drop related functions
/*******************************/
    // Copied from DNDInterface with modification (may be able to DRY?)
    private void set_up_drop_target () {
        //Set up as drop target. Use simple (synchronous) string target for now as most reliable
        //Based on code for BookmarkListBox (some DRYing may be possible?)
        //TODO Use Gdk.FileList target when Gtk4 version 4.8+ available
        var drop_target = new Gtk.DropTarget (
            Type.STRING,
            Gdk.DragAction.LINK |
            Gdk.DragAction.COPY |
            Gdk.DragAction.MOVE |
            Gdk.DragAction.ASK
        ) {
            propagation_phase = Gtk.PropagationPhase.CAPTURE,
        };
        breadcrumbs.add_controller (drop_target);
        drop_target.accept.connect ((drop) => {
            drop_accepted = false;
            drop.read_value_async.begin (
                Type.STRING,
                Priority.DEFAULT,
                null,
                (obj, res) => {
                    try {
                        var val = drop.read_value_async.end (res);
                        if (val != null) {
                            // Error thrown if string does not contain valid uris as uri-list
                            drop_accepted = Files.FileUtils.files_from_uris (
                                val.get_string (),
                                out dropped_files
                            );
                        } else {
                            warning ("dropped value null");
                        }
                    } catch (Error e) {
                        warning ("Could not retrieve valid uri (s)");
                    }
                }
            );

            return true;
        });
        // drop_target.enter.connect (() => {
        //     return 0;
        // });
        drop_target.leave.connect (() => {
            drop_accepted = false;
            dropped_files = null;
            accepted_actions = 0;
        });
        drop_target.motion.connect ((x, y) => {
            if (!drop_accepted) {
                return 0;
            }

            var drop = drop_target.get_current_drop ();
            var path = breadcrumbs.get_dir_path_from_coords (x, y);
            if (path != null) {
                path = Files.FileUtils.sanitize_path (path);
                current_drop_uri = path;
                var file = Files.File.@get (GLib.File.new_for_uri (path));
                file.query_update ();

                // Getting mods from the drop object does not work for some reason
                var seat = Gdk.Display.get_default ().get_default_seat ();
                var mods = seat.get_keyboard ().modifier_state & Gdk.MODIFIER_MASK;
                var alt_pressed = (mods & Gdk.ModifierType.ALT_MASK) > 0;
                var alt_only = alt_pressed && ((mods & ~Gdk.ModifierType.ALT_MASK) == 0);

                Files.DndHandler.valid_and_preferred_actions (
                    file,
                    dropped_files, // read-only
                    drop,
                    alt_only
                );

                return Files.DndHandler.preferred_action;
            } else {
                accepted_actions = 0;
                return 0;
            }
        });

        //Gtk already filters available actions according to keyboard modifier state
        //Drag unmodified = selected_action = as returned by DndHandler in motion handler
        // drag_actions = drop_target common actions
        //Drag with Ctrl - selected action == COPY drag actions = COPY
        //Drag with Shift - selected action = MOVE drag_actions = MOVE
        //Drag with Shift+Ctrl - selected action == LINK, drag actions LINK
        //Note: Gtk does not seem to implement a Gtk.DragAction.ASK modifier so we use <ALT>
        drop_target.on_drop.connect ((val, x, y) => {
            if (dropped_files != null &&
                current_drop_uri != null &&
                Files.DndHandler.valid_actions > 0) {

                // Getting mods from the drop object does not work for some reason
                var seat = Gdk.Display.get_default ().get_default_seat ();
                var mods = seat.get_keyboard ().modifier_state & Gdk.MODIFIER_MASK;
                var alt_pressed = (mods & Gdk.ModifierType.ALT_MASK) > 0;
                var alt_only = alt_pressed && ((mods & ~Gdk.ModifierType.ALT_MASK) == 0);

                Files.DndHandler.handle_file_drop_actions (
                    this,
                    x, y,
                    Files.File.@get (GLib.File.new_for_uri (current_drop_uri)),
                    dropped_files
                );
            }

            drop_accepted = false;
            if (current_drop_uri != null) {
                current_drop_uri = null;
            }

            return true;
        });
    }
}
