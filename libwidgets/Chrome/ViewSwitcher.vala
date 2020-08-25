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

namespace Marlin.View.Chrome {
    public class ViewSwitcher : Granite.Widgets.ModeButton {
        private const int SWITCH_DELAY_MSEC = 100;
        public GLib.SimpleAction view_mode_action { get; construct; }
        private uint mode_change_timeout_id = 0;
        private ViewMode last_selected;

        construct {
            /* Item 0 */
            var icon = new Gtk.Image.from_icon_name ("view-grid-symbolic", Gtk.IconSize.BUTTON) {
                tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>1"}, _("View as Grid"))
            };

            append (icon);

            /* Item 1 */
            var list = new Gtk.Image.from_icon_name ("view-list-symbolic", Gtk.IconSize.BUTTON) {
                tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>2"}, _("View as List"))
            };

            append (list);

            /* Item 2 */
            var miller = new Gtk.Image.from_icon_name ("view-column-symbolic", Gtk.IconSize.BUTTON) {
                tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl>3"}, _("View in Columns"))
            };

            append (miller);

            mode_changed.connect (() => {
                last_selected = (ViewMode)selected;
                if (mode_change_timeout_id > 0) {
                    return;
                }

                mode_change_timeout_id = Timeout.add (SWITCH_DELAY_MSEC, () => {
                    view_mode_action.activate (new GLib.Variant.uint32 (last_selected));
                    mode_change_timeout_id = 0;
                    return Source.REMOVE;
                });
            });

            margin_top = 4;
            margin_bottom = 4;
        }

        public ViewSwitcher (GLib.SimpleAction _view_mode_action) {
            Object (
                orientation: Gtk.Orientation.HORIZONTAL,
                view_mode_action: _view_mode_action
            );
        }
    }
}
