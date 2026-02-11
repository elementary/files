/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 *                         2010 mathijshenquet
 */

public class Files.View.Chrome.ViewSwitcher : Gtk.Box {
    construct {
        var grid_view_btn = new Gtk.ToggleButton () {
            action_name = "win.default-viewmode",
            action_target = new Variant.string ("icon"),
            image = new Gtk.Image.from_icon_name ("view-grid-symbolic", BUTTON),
            tooltip_markup = get_tooltip_for_id ((uint32) ViewMode.ICON, _("View as Grid"))
        };

        var list_view_btn = new Gtk.ToggleButton () {
            action_name = "win.default-viewmode",
            action_target = new Variant.string ("list"),
            image = new Gtk.Image.from_icon_name ("view-list-symbolic", BUTTON),
            tooltip_markup = get_tooltip_for_id ((uint32) ViewMode.LIST, _("View as List"))
        };

        var column_view_btn = new Gtk.ToggleButton () {
            action_name = "win.default-viewmode",
            action_target = new Variant.string ("miller_columns"),
            image = new Gtk.Image.from_icon_name ("view-column-symbolic", BUTTON),
            tooltip_markup = get_tooltip_for_id ((uint32) ViewMode.MILLER_COLUMNS, _("View in Columns"))
        };

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
