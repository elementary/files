/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 *                         2010 mathijshenquet
 */

public class Files.View.Chrome.ViewSwitcher : Gtk.Box {
    construct {
        var id = (uint32) ViewMode.ICON;
        var grid_view_btn = new Gtk.RadioButton (null) {
            action_name = "win.view-mode",
            action_target = new Variant.uint32 (id),
            image = new Gtk.Image.from_icon_name ("view-grid-symbolic", BUTTON),
            tooltip_markup = get_tooltip_for_id (id, _("View as Grid"))
        };
        grid_view_btn.set_mode (false);

        id = (uint32) ViewMode.LIST;
        var list_view_btn = new Gtk.RadioButton.from_widget (grid_view_btn) {
            action_name = "win.view-mode",
            action_target = new Variant.uint32 (id),
            image = new Gtk.Image.from_icon_name ("view-list-symbolic", BUTTON),
            tooltip_markup = get_tooltip_for_id (id, _("View as List"))
        };
        list_view_btn.set_mode (false);

        id = (uint32) ViewMode.MILLER_COLUMNS;
        var column_view_btn = new Gtk.RadioButton.from_widget (grid_view_btn) {
            action_name = "win.view-mode",
            action_target = new Variant.uint32 (id),
            image = new Gtk.Image.from_icon_name ("view-column-symbolic", BUTTON),
            tooltip_markup = get_tooltip_for_id (id, _("View in Columns"))
        };
        column_view_btn.set_mode (false);

        get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);
        valign = CENTER;
        add (grid_view_btn);
        add (list_view_btn);
        add (column_view_btn);
    }

    private string get_tooltip_for_id (uint32 id, string description) {
        var app = (Gtk.Application) Application.get_default ();
        var detailed_name = Action.print_detailed_name ("win.view-mode", new Variant.uint32 (id));
        var accels = app.get_accels_for_action (detailed_name);
        return Granite.markup_accel_tooltip (accels, description);
    }
}
