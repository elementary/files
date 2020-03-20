/***
    Copyright (c) 2019 elementary LLC <https://elementary.io>

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
        menu_grid.margin = 6;
        menu_grid.row_spacing = 6;
        menu_grid.column_spacing = 6;
        menu_grid.orientation = Gtk.Orientation.VERTICAL;

        var click_mode_label = new Gtk.Label (_("Click Mode"));
        click_mode_label.get_style_context ().add_class (Granite.STYLE_CLASS_H3_LABEL);
        var single_button = new Gtk.RadioButton.with_label (null, _("Single"));
        var double_button = new Gtk.RadioButton.with_label_from_widget (single_button, _("Double"));

        menu_grid.attach (click_mode_label, 0, 0, 3, 1);
        menu_grid.attach (single_button, 0, 1, 1, 1);
        menu_grid.attach (double_button, 1, 1, 1, 1);

        menu_grid.show_all ();
        add (menu_grid);

        single_button.clicked.connect (() => {
            GOF.Preferences.get_default ().click_mode = Marlin.ClickMode.SINGLE;
            hide ();
        });

        double_button.clicked.connect (() => {
            GOF.Preferences.get_default ().click_mode = Marlin.ClickMode.DOUBLE;
            hide ();
        });
    }
}
