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
    private string completion_text = "";
    private bool autocompleted = false;
    private bool multiple_completions = false;
    /* The string which contains the text we search in the file. e.g, if the
     * user enter /home/user/a, we will search for "a". */
    private string to_search = "";

    construct {
        var secondary_gesture = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        breadcrumbs.scrolled_window.add_controller (secondary_gesture);
        secondary_gesture.pressed.connect ((n_press, x, y) => {
            secondary_gesture.set_state (Gtk.EventSequenceState.CLAIMED);
            handle_secondary_press (x, y);
        });

        path_entry.completion_request.connect (completion_needed);
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

        to_search = "";
        /* don't use get_basename (), it will return "folder" for "/folder/" */
        int last_slash = txt.last_index_of_char ('/');
        if (last_slash > -1 && last_slash < txt.length) {
            to_search = txt.slice (last_slash + 1, txt.length);
        }
        if (to_search.length > 0) {
            do_completion (txt);
        } else {
            set_completion_text ("");
        }
    }

    private void do_completion (string path) {
        GLib.File? file = FileUtils.get_file_for_path (FileUtils.sanitize_path (path, display_uri));
        if (file == null || autocompleted) {
            return;
        }

        if (file.has_parent (null)) {
            file = file.get_parent ();
        } else {
            return;
        }

        if (current_completion_dir == null || !file.equal (current_completion_dir.location)) {
            current_completion_dir = Directory.from_gfile (file);
        } else if (current_completion_dir != null && current_completion_dir.can_load) {
            set_completion_text ("");
        } else {
            return;
        }

        /* Completion text set by on_file_loaded () */
        current_completion_dir.init.begin (on_file_loaded);
    }

    protected void complete () {
        if (completion_text.length == 0) {
            return;
        }

        string path = path_entry.text + completion_text;
        /* If there are multiple results, tab as far as we can, otherwise do the entire result */
        if (!multiple_completions) {
            completed (path);
        } else {
            path_entry.set_entry_text (path);
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

            path_entry.set_entry_text (newpath);
        }

        set_completion_text ("");
    }

    private void set_completion_text (string txt) {
        completion_text = txt;
        if (path_entry.completion_placeholder != completion_text) {
            path_entry.completion_placeholder = completion_text;
            queue_draw ();
            /* This corrects undiagnosed bug after completion required on remote filesystem */
            path_entry.cursor_position = -1;
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
                if (path_entry.text.length >= 1) {
                    str = path_entry.text.slice (0, path_entry.text.length - to_search.length);
                }

                if (str == null) {
                    return;
                }

                /* autocompletion is case insensitive so we have to change the first completed
                 * parts to the match the filename (if unique match and if the user did not
                 * deliberately enter an uppercase character).
                 */
                if (!multiple_completions && !(to_search.down () != to_search)) {
                    path_entry.text = (str + file_display_name.slice (0, to_search.length));
                }
            }
        }
    }
}
