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

namespace Files.Chrome {
    public class ViewSwitcher : Gtk.Box {
        public string action_name { get; construct; }
        private GLib.ListModel children;
        public ViewSwitcher (string action_name) {
            Object (action_name: action_name);
        }

        construct {
            // children = observe_children ();
            add_css_class ("linked");

            /* Grid View item */
            var id = (uint32)ViewMode.ICON;
            var grid_view_btn = new Gtk.ToggleButton () {
                child = new Gtk.Image.from_icon_name ("view-grid-symbolic"),
                tooltip_markup = get_tooltip_for_id (id, _("View as Grid")),
                action_name = this.action_name,
                action_target = new Variant.uint32 (id),
                focusable = false
            };
            grid_view_btn.toggled.connect (() => {
                if (grid_view_btn.active) {
                    set_mode ((uint32)ViewMode.ICON);
                }
            });
            grid_view_btn.set_data<uint32> ("id", id);

            /* List View */
            id = (uint32)ViewMode.LIST;
            var list_view_btn = new Gtk.ToggleButton () {
                child = new Gtk.Image.from_icon_name ("view-list-symbolic"),
                tooltip_markup = get_tooltip_for_id (id, _("View as List")),
                action_name = this.action_name,
                action_target = new Variant.uint32 (id),
                focusable = false
            };
            list_view_btn.toggled.connect (() => {
                if (list_view_btn.active) {
                    set_mode ((uint32)ViewMode.LIST);
                }
            });
            list_view_btn.set_data<uint32> ("id", id);


            /* Item 2 */
            id = (uint32)ViewMode.MILLER_COLUMNS;
            var column_view_btn = new Gtk.ToggleButton () {
                child = new Gtk.Image.from_icon_name ("view-column-symbolic"),
                tooltip_markup = get_tooltip_for_id (id, _("View in Columns")),
                action_name = this.action_name,
                action_target = new Variant.uint32 (id),
                focusable = false
            };
            column_view_btn.toggled.connect (() => {
                if (column_view_btn.active) {
                    set_mode ((uint32)ViewMode.MILLER_COLUMNS);
                }
            });
            column_view_btn.set_data<uint32> ("id", ViewMode.MILLER_COLUMNS);

            valign = Gtk.Align.CENTER;
            append (grid_view_btn);
            append (list_view_btn);
            append (column_view_btn);
        }

        private string get_tooltip_for_id (uint32 id, string description) {
            var app = (Gtk.Application)Application.get_default ();
            var detailed_name = Action.print_detailed_name (action_name, new Variant.uint32 (id));
            var accels = app.get_accels_for_action (detailed_name);
            return Granite.markup_accel_tooltip (accels, description);
        }

        public void set_mode (uint32 mode) {
            var child = get_first_child ();
            while (child != null) {
                if (child.get_data<uint32> ("id") != mode) {
                    ((Gtk.ToggleButton)child).active = false;
                } else {
                    ((Gtk.ToggleButton)child).active = true;
                }

                child = child.get_next_sibling ();
            }
        }
    }
}
