/***
    Copyright (c) 2015-2020 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremywootten@gmail.com>
***/

namespace Files {
    public class ColumnView : AbstractTreeView {
        /** Miller View support */
        bool awaiting_double_click = false;
        uint double_click_timeout_id = 0;

        public ColumnView (View.Slot _slot) {
            base (_slot);
            /* We do not need to load the directory - this is done by Miller View*/
            /* We do not need to connect to "row-activated" signal - we handle left-clicks ourselves */
        }

        protected override void set_up_icon_renderer () {
            icon_renderer = new IconRenderer ();
        }

        protected new void on_view_selection_changed () {
            set_active_slot ();
            base.on_view_selection_changed ();
        }

        private void cancel_await_double_click () {
            if (awaiting_double_click) {
                GLib.Source.remove (double_click_timeout_id);
                double_click_timeout_id = 0;
                awaiting_double_click = false;
                is_frozen = false;
            }
        }

        private bool not_double_click () {
            if (double_click_timeout_id != 0) {
                awaiting_double_click = false;
                double_click_timeout_id = 0;
                is_frozen = false;

                if (source_drag_file_list == null && selection_only_contains_folders (get_selected_files ())) {
                    activate_selected_items ();
                }
            }

            return false;
        }

        public override Settings? get_view_settings () {
            return Files.column_view_settings;
        }

        protected override Gtk.Widget? create_view () {
            model.has_child = false;
            base.create_view ();
            tree.show_expanders = false;
            return tree as Gtk.Widget;
        }


        protected override bool handle_primary_button_click (
            uint n_press,
            Gdk.ModifierType mods,
            Gtk.TreePath? path
        ) {
            Files.File? file = null;
            Files.File? selected_folder = null;
            Gtk.TreeIter? iter = null;

            if (path != null) {
                model.get_iter (out iter, path);
            }

            if (iter != null) {
                model.@get (iter, ListModel.ColumnID.FILE_COLUMN, out file, -1);
            }

            if (file == null || !file.is_folder ()) {
                return base.handle_primary_button_click (n_press, mods, path);
            }

            selected_folder = file;
            bool result = true;
            if (n_press == 1) {
                /* Ignore second GDK_BUTTON_PRESS event of double-click */
                if (awaiting_double_click) {
                    result = true;
                } else {
                    /*  ... store clicked folder and start double-click timeout */
                    awaiting_double_click = true;
                    is_frozen = true;
                    double_click_timeout_id = GLib.Timeout.add (300, () => {
                        not_double_click ();
                        return GLib.Source.REMOVE;
                    });
                }
            } else if (n_press == 2) {
                should_activate = false;
                cancel_await_double_click ();

                if (selected_folder != null) {
                    load_root_location (selected_folder.get_target_location ());
                }

                result = true;
            }

            return result;
        }

        protected override bool handle_default_button_click () {
            cancel_await_double_click ();
            return base.handle_default_button_click ();
        }

        public override void cancel () {
            base.cancel ();
            cancel_await_double_click ();
        }
    }
}
