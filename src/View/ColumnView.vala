/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/


namespace FM {
    public class ColumnView : AbstractTreeView {
        /** Miller View support */
        bool awaiting_double_click = false;
        uint double_click_timeout_id = 0;

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
                is_frozen = false;
            }
        }

        private bool not_double_click (Gdk.EventButton event, Gtk.TreePath? path) {
            if (double_click_timeout_id != 0) {
                double_click_timeout_id = 0;
                awaiting_double_click = false;
                is_frozen = false;

                if (should_activate) { /* button already released */
                    activate_selected_items ();
                }
            }
            return false;
        }

        protected override void set_up_zoom_level () {
            Preferences.marlin_column_view_settings.bind ("zoom-level",
                                                           this, "zoom-level",
                                                           GLib.SettingsBindFlags.DEFAULT);

            minimum_zoom = (Marlin.ZoomLevel)Preferences.marlin_column_view_settings.get_enum ("minimum-zoom-level");
            maximum_zoom = (Marlin.ZoomLevel)Preferences.marlin_column_view_settings.get_enum ("maximum-zoom-level");

            if (zoom_level < minimum_zoom) {
                zoom_level = minimum_zoom;
            }

            if (zoom_level > maximum_zoom) {
                zoom_level = maximum_zoom;
            }
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

        protected override bool on_view_key_press_event (Gdk.EventKey event) {
            var mods = event.state & Gtk.accelerator_get_default_mod_mask ();
            bool no_mods = (mods == 0);

            switch (event.keyval) {
                /* Do not emit alert sound on left and right cursor keys in Miller View */
                case Gdk.Key.Left:
                case Gdk.Key.Right:
                case Gdk.Key.BackSpace:
                    if (no_mods) {
                        /* Pass event to MillerView */
                        slot.colpane.key_press_event (event);
                        return true;
                    }
                    break;

                default:
                    break;
            }

            return base.on_view_key_press_event (event);
        }


        protected override bool on_view_button_release_event (Gdk.EventButton event) {
            /* Invoke default handler unless waiting for a double-click in single-click mode */
            if (Preferences.settings.get_boolean ("single-click") && awaiting_double_click) {
                should_activate = true; /* will activate when times out */
                return true;
            } else {
                return base.on_view_button_release_event (event);
            }
        }

        protected override bool handle_primary_button_click (Gdk.EventButton event, Gtk.TreePath? path) {
            GOF.File? file = null;
            GOF.File? selected_folder = null;
            Gtk.TreeIter? iter = null;

            if (path != null) {
                model.get_iter (out iter, path);
            }

            if (iter != null) {
                model.@get (iter, FM.ListModel.ColumnID.FILE_COLUMN, out file, -1);
            }

            if (file == null || !file.is_folder () || !Preferences.settings.get_boolean ("single-click")) {
                return base.handle_primary_button_click (event, path);
            }

            selected_folder = file;
            bool result = true;

            if (event.type == Gdk.EventType.BUTTON_PRESS) {
                /* Ignore second GDK_BUTTON_PRESS event of double-click */
                if (awaiting_double_click) {
                    result = true;
                } else {
                    /*  ... store clicked folder and start double-click timeout */
                    awaiting_double_click = true;
                    is_frozen = true;
                    double_click_timeout_id = GLib.Timeout.add (300, () => {
                        not_double_click (event, path);
                        return GLib.Source.REMOVE;
                    });
                }
            } else if (event.type == Gdk.EventType.@2BUTTON_PRESS) {
                should_activate = false;
                cancel_await_double_click ();

                if (selected_folder != null) {
                    load_root_location (selected_folder.get_target_location ());
                }

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
        }

        public override void cancel () {
            base.cancel ();
            cancel_await_double_click ();
        }
    }
}
