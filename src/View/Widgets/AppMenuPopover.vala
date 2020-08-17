
/***
    Copyright (c) 2020 elementary LLC <https://elementary.io>
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

public class PF.AppMenuPopover : Gtk.Popover {
    construct {
        var menu_grid = new Gtk.Grid ();
        menu_grid.column_spacing = 12;
        menu_grid.margin = 12;
        menu_grid.orientation = Gtk.Orientation.VERTICAL;
        menu_grid.row_spacing = 6;

        var click_mode_label = new Gtk.Label (_("Single Click"));
        click_mode_label.halign = Gtk.Align.START;
        click_mode_label.vexpand = true;

        var click_mode_switch = new Gtk.Switch ();
        click_mode_switch.halign = Gtk.Align.START;

        menu_grid.attach (click_mode_label, 0, 0, 1, 1);
        menu_grid.attach (click_mode_switch, 1, 0, 1, 1);
        menu_grid.show_all ();

        add (menu_grid);

        Marlin.app_settings.bind (
            "single-click",
            click_mode_switch,
            "active",
            SettingsBindFlags.DEFAULT
        );
    }
}
