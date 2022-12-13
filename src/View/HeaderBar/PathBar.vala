/***
    Copyright (c) 2022 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISitem_factory QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

public class Files.PathBar : Files.BasicPathBar, PathBarInterface {
    /** Completion support **/
    private Directory? current_completion_dir = null;
    private Gtk.PopoverMenu completion_popover;
    private Menu completion_model;
    //For sorting suggestions
    private Gee.ArrayList<string> completion_list;
    private string to_complete = "";

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

        var key_controller = new Gtk.EventControllerKey () {
            propagation_phase = Gtk.PropagationPhase.CAPTURE
        };
        key_controller.key_pressed.connect ((keyval, keycode, state) => {
            if (Gdk.keyval_name (keyval) == "Tab") {
                if (completion_popover.visible) {
                    tab_complete_action.activate (null);
                    return true;
                }
            }

            return false;
        });
        path_entry.add_controller (key_controller);

        var pathbar_action_group = new SimpleActionGroup ();
        pathbar_action_group.add_action (set_text_action);
        insert_action_group ("pathbar", pathbar_action_group);

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
            files_menu_dir.init.begin (null, (obj, res) => {
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
                warning ("basename %s", basename);
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
}
