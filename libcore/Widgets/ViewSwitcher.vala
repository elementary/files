/***
*   Copyright (c) 2016-2023 elementary LLC. <https://elementary.io>
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

    Authors:
       mathijshenquet <mathijs.henquet@gmail.com>
       ammonkey <am.monkeyd@gmail.com>
***/

public class Files.ViewSwitcher : Gtk.Box {
    private const string ACTION_VIEW_MODE = "win.view-mode";
    // Keep a list of children to iterate - compatible with both Gtk3 and Gtk4
    private GLib.List<Gtk.ToggleButton> children = null;

    construct {
        valign = Gtk.Align.CENTER;
        get_style_context ().add_class ("linked");

        var grid_view_btn = new ModeButton (
            (uint32)ViewMode.ICON,
            "view-grid-symbolic",
            _("View as Grid")
        );
        var list_view_btn = new ModeButton (
            (uint32)ViewMode.LIST,
            "view-list-symbolic",
            _("View as List")
        );
        var column_view_btn = new ModeButton (
            (uint32)ViewMode.MILLER_COLUMNS,
            "view-column-symbolic",
            _("View as Columns")
        );

        append_button (grid_view_btn);
        append_button (list_view_btn);
        append_button (column_view_btn);

        // Implement radiobutton behaviour for Gtk3 (in Gtk4 can be added to group)
        grid_view_btn.toggled.connect (set_mode_from_button);
        list_view_btn.toggled.connect (set_mode_from_button);
        column_view_btn.toggled.connect (set_mode_from_button);
    }

    private void append_button (Gtk.ToggleButton child) {
        add (child);
        children.append (child);
    }

    private void set_mode_from_button (Gtk.ToggleButton button) {
        if (button.active) {
            set_mode (button.action_target.get_uint32 ());
        }
    }

    public void set_mode (uint32 mode) {
        unowned var child_list = children.first ();
        while (child_list != null) {
            child_list.data.active = child_list.data.action_target.get_uint32 () == mode;
            child_list = child_list.next;
        }
    }

    public ViewMode get_mode () {
        unowned var child_list = children.first ();
        while (child_list != null) {
            if (child_list.data.active) {
                return (ViewMode)(child_list.data.action_target.get_uint32 ());
            }

            child_list = child_list.next;
        }

        critical ("No active mode found - return 0");
        return 0;
    }

    private class ModeButton : Gtk.ToggleButton {
        public ModeButton (uint32 id, string icon_name, string tooltip) {
            child = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.BUTTON);
            tooltip_markup = get_tooltip_for_id (id, tooltip);
            action_name = ACTION_VIEW_MODE;
            action_target = new Variant.uint32 (id);
            sensitive = true;
            can_focus = false;
        }

        private string get_tooltip_for_id (uint32 id, string description) {
            var app = (Gtk.Application)Application.get_default ();
            var detailed_name = Action.print_detailed_name (ACTION_VIEW_MODE, new Variant.uint32 (id));
            var accels = app.get_accels_for_action (detailed_name);
            return Granite.markup_accel_tooltip (accels, description);
        }
    }
}
