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

/* Contains basic breadcrumb and path entry entry widgets for use in FileChooser */

public class Files.PathBar : Files.BasicPathBar, PathBarInterface {
    private ulong files_menu_dir_handler_id = 0;
    construct {
        var secondary_gesture = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        breadcrumbs.scrolled_window.add_controller (secondary_gesture);
        secondary_gesture.pressed.connect ((n_press, x, y) => {
            secondary_gesture.set_state (Gtk.EventSequenceState.CLAIMED);
            handle_secondary_press (x, y);
        });
    }

    private void handle_secondary_press (double x, double y) {
        var crumb = breadcrumbs.get_crumb_from_coords (x, y);
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

        Directory? files_menu_dir = null;
        // uint files_menu_dir_handler_id = 0;
        if (root != null) {
            files_menu_dir = Directory.from_gfile (root);
            files_menu_dir_handler_id = files_menu_dir.done_loading.connect (() => {
                /* Append list of directories at the same level */
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
                }

                files_menu_dir.disconnect (files_menu_dir_handler_id);
                files_menu_dir_handler_id = 0;
                files_menu_dir = null;
                // Do not show popup until all children have been appended.
                show_context_menu (menu, x, y);
            });
        } else {
            warning ("Root directory null for %s", path);
            show_context_menu (menu, x, y);
        }

        if (files_menu_dir != null) {
            files_menu_dir.init ();
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
}
