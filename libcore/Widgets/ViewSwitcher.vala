/***
    ViewSwicher.cs

    Authors:
       mathijshenquet <mathijs.henquet@gmail.com>
       ammonkey <am.monkeyd@gmail.com>

    Copyright (c) 2010 mathijshenquet

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
***/

namespace Files.View.Chrome {
    public class ViewSwitcher : Gtk.Box {
        private List<Gtk.ToggleButton> buttons;

        public GLib.SimpleAction action { get; construct; }

        public ViewSwitcher (GLib.SimpleAction view_mode_action) {
            Object (action: view_mode_action);
        }

        construct {
            get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);

            buttons = new List<Gtk.ToggleButton> ();
            /* Grid View item */
            var id = (uint32)ViewMode.ICON;
            var grid_view_btn = new Gtk.ToggleButton () {
                image = new Gtk.Image.from_icon_name ("view-grid-symbolic", Gtk.IconSize.BUTTON),
                tooltip_markup = get_tooltip_for_id (id, _("View as Grid"))
            };
            grid_view_btn.set_mode (false);
            grid_view_btn.toggled.connect (on_mode_changed);
            grid_view_btn.set_data<uint32> ("id", id);
            buttons.append (grid_view_btn);

            /* List View */
            id = (uint32)ViewMode.LIST;
            var list_view_btn = new Gtk.ToggleButton () {
                image = new Gtk.Image.from_icon_name ("view-list-symbolic", Gtk.IconSize.BUTTON),
                tooltip_markup = get_tooltip_for_id (id, _("View as List"))
            };
            list_view_btn.set_mode (false);
            list_view_btn.toggled.connect (on_mode_changed);
            list_view_btn.set_data<uint32> ("id", id);
            buttons.append (list_view_btn);


            /* Item 2 */
            id = (uint32)ViewMode.MILLER_COLUMNS;
            var column_view_btn = new Gtk.ToggleButton () {
                image = new Gtk.Image.from_icon_name ("view-column-symbolic", Gtk.IconSize.BUTTON),
                tooltip_markup = get_tooltip_for_id (id, _("View in Columns"))
            };
            column_view_btn.set_mode (false);
            column_view_btn.toggled.connect (on_mode_changed);
            column_view_btn.set_data<ViewMode> ("id", ViewMode.MILLER_COLUMNS);
            buttons.append (column_view_btn);

            valign = Gtk.Align.CENTER;
            add (grid_view_btn);
            add (list_view_btn);
            add (column_view_btn);
        }

        private string get_tooltip_for_id (uint32 id, string description) {
            var app = (Gtk.Application)Application.get_default ();
            var detailed_name = Action.print_detailed_name ("win." + action.name, new Variant.uint32 (id));
            var accels = app.get_accels_for_action (detailed_name);
            return Granite.markup_accel_tooltip (accels, description);
        }

        private void on_mode_changed (Gtk.ToggleButton source) {
            if (!source.active) {
                return;
            }

            var id = source.get_data<uint32> ("id");
            set_mode (id);
            action.activate (id);
        }

        public void set_mode (uint32 mode) {
            foreach (var btn in buttons) {
                if (btn.get_data<uint32> ("id") != mode) {
                    btn.active = false;
                } else {
                    btn.active = true;
                }
            }
        }
    }
}
