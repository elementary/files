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

        var popover = new Gtk.PopoverMenu.from_model (menu);
        popover.set_parent (this);
        popover.set_pointing_to ({(int)x, (int)y, 1, 1});
        Idle.add (() => {
          popover.popup ();
          return Source.REMOVE;
        });

        // menu.cancel.connect (() => {reset_elements_states ();});
        // menu.deactivate.connect (() => {reset_elements_states ();});

        // build_base_menu (menu, path);
        // Directory? files_menu_dir = null;
        // if (root != null) {
        //     files_menu_dir = Directory.from_gfile (root);
        //     files_menu_dir_handler_id = files_menu_dir.done_loading.connect (() => {
        //         append_subdirectories (menu, files_menu_dir);
        //         files_menu_dir.disconnect (files_menu_dir_handler_id);
        //         // Do not show popup until all children have been appended.
        //         menu.show_all ();
        //         menu.popup_at_pointer (event);
        //     });
        // } else {
        //     warning ("Root directory null for %s", path);
        //     menu.show_all ();
        //     menu.popup_at_pointer (event);
        // }

        // if (files_menu_dir != null) {
        //     files_menu_dir.init ();
        // }
    }

    // private void append_subdirectories (Gtk.Menu menu, Directory dir) {
    //     /* Append list of directories at the same level */
    //     if (dir.can_load) {
    //         unowned List<unowned Files.File>? sorted_dirs = dir.get_sorted_dirs ();

    //         if (sorted_dirs != null) {
    //             menu.append (new Gtk.SeparatorMenuItem ());
    //             foreach (unowned Files.File gof in sorted_dirs) {
    //                 var menuitem = new Gtk.MenuItem.with_label (gof.get_display_name ());
    //                 menuitem.set_data ("location", gof.uri);
    //                 menu.append (menuitem);
    //                 menuitem.activate.connect ((mi) => {
    //                     activate_path (mi.get_data ("location"));
    //                 });
    //             }
    //         }
    //     }
    //     menu.show_all ();
    //     /* Release the Async directory as soon as possible */
    //     dir = null;
    // }
}
