/*
 Copyright (C) 2014 elementary Developers

 This program is free software: you can redistribute it and/or modify it
 under the terms of the GNU Lesser General Public License version 3, as published
 by the Free Software Foundation.

 This program is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY; without even the implied warranties of
 MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 PURPOSE. See the GNU General Public License for more details.

 You should have received a copy of the GNU General Public License along
 with this program. If not, see <http://www.gnu.org/licenses/>.

 Authors : Jeremy Wootten <jeremy@elementary.org>
*/


namespace FM {
    public class ColumnView : AbstractTreeView {
        /** Miller View support */
        bool awaiting_double_click = false;
        uint double_click_timeout_id = 0;
        private unowned GOF.File? selected_folder = null;

        public ColumnView (Marlin.View.Slot _slot) {
            base (_slot);
            /* We do not need to load the directory - this is done by Miller View*/
            /* We do not need to connect to "row-activated" signal - we handle left-clicks ourselves */
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
                unfreeze_updates ();
            }
        }

        private bool not_double_click (Gdk.EventButton event, Gtk.TreePath? path) {
            if (double_click_timeout_id != 0) {
                double_click_timeout_id = 0;
                awaiting_double_click = false;
                unfreeze_updates ();
                if (should_activate) /* button already released */
                    activate_selected_items ();
            }
            return false;
        }

        protected override Marlin.ZoomLevel get_set_up_zoom_level () {
            var zoom = Preferences.marlin_column_view_settings.get_enum ("zoom-level");
            Preferences.marlin_column_view_settings.bind ("zoom-level", this, "zoom-level", GLib.SettingsBindFlags.SET);

            return (Marlin.ZoomLevel)zoom;
        }

        public override Marlin.ZoomLevel get_normal_zoom_level () {
            var zoom = Preferences.marlin_column_view_settings.get_enum ("default-zoom-level");
            Preferences.marlin_column_view_settings.set_enum ("zoom-level", zoom);

            return (Marlin.ZoomLevel)zoom;
        }

        protected override Gtk.Widget? create_view () {
            model.set_property ("has-child", false);
            base.create_view ();
            tree.show_expanders = false;

            return tree as Gtk.Widget;
        }

        protected override bool on_view_button_release_event (Gdk.EventButton event) {
            /* Invoke default handler unless waiting for a double-click in single-click mode */
            if (Preferences.settings.get_boolean ("single-click") && awaiting_double_click) {
                should_activate = true; /* will activate when times out */
                return true;
            } else
                return base.on_view_button_release_event (event);
        }

        protected override bool handle_primary_button_click (Gdk.EventButton event, Gtk.TreePath? path) {
            unowned GOF.File file = selected_files.data;
            bool is_folder = file.is_folder ();

            selected_folder = null;

            if (!is_folder || !Preferences.settings.get_boolean ("single-click"))
                return base.handle_primary_button_click (event, path);

            selected_folder = file;
            bool result = true;

            if (event.type == Gdk.EventType.BUTTON_PRESS) {
                /* Ignore second GDK_BUTTON_PRESS event of double-click */
                if (awaiting_double_click)
                    result = true;
                else {
                    /*  ... store clicked folder and start double-click timeout */
                    awaiting_double_click = true;
                    freeze_updates ();
                    double_click_timeout_id = GLib.Timeout.add (drag_delay, () => {
                        not_double_click (event, path);
                        return false;
                    });
                }
            } else if (event.type == Gdk.EventType.@2BUTTON_PRESS) {
                cancel_await_double_click ();

                if (selected_folder != null)
                    load_root_location (selected_folder.location);

                result = true;
            }
            return result;
        }

        protected override bool handle_default_button_click (Gdk.EventButton event) {
            cancel_await_double_click ();
            return base.handle_default_button_click (event);
        }

        protected override void change_zoom_level () {
            base.change_zoom_level ();
            slot.autosize_slot ();
        }
    }
}
