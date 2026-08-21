/*
 * SPDX-License-Identifier: GPL-3.0-or-later
 * SPDX-FileCopyrightText: 2026 elementary, Inc. (https://elementary.io)
 *                         2010 mathijshenquet
 */

public class Files.View.Chrome.ViewSwitcher : Gtk.Box {
    public GLib.SimpleAction action { get; construct; }

    public ViewSwitcher (GLib.SimpleAction view_mode_action) {
        Object (action: view_mode_action);
    }

    construct {
        get_style_context ().add_class (Gtk.STYLE_CLASS_LINKED);

        /* Grid View item */
        var id = (uint32)ViewMode.ICON;
        var grid_view_btn = new Gtk.RadioButton (null) {
            image = new Gtk.Image.from_icon_name ("view-grid-symbolic", Gtk.IconSize.BUTTON),
            tooltip_markup = get_tooltip_for_id (id, _("View as Grid"))
        };
        grid_view_btn.set_mode (false);
        grid_view_btn.toggled.connect (on_mode_changed);
        grid_view_btn.set_data<uint32> ("id", id);

        /* List View */
        id = (uint32)ViewMode.LIST;
        var list_view_btn = new Gtk.RadioButton.from_widget (grid_view_btn) {
            image = new Gtk.Image.from_icon_name ("view-list-symbolic", Gtk.IconSize.BUTTON),
            tooltip_markup = get_tooltip_for_id (id, _("View as List"))
        };
        list_view_btn.set_mode (false);
        list_view_btn.toggled.connect (on_mode_changed);
        list_view_btn.set_data<uint32> ("id", id);


        /* Item 2 */
        id = (uint32)ViewMode.MILLER_COLUMNS;
        var column_view_btn = new Gtk.RadioButton.from_widget (grid_view_btn) {
            image = new Gtk.Image.from_icon_name ("view-column-symbolic", Gtk.IconSize.BUTTON),
            tooltip_markup = get_tooltip_for_id (id, _("View in Columns"))
        };
        column_view_btn.set_mode (false);
        column_view_btn.toggled.connect (on_mode_changed);
        column_view_btn.set_data<ViewMode> ("id", ViewMode.MILLER_COLUMNS);

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

        action.activate (source.get_data<uint32> ("id"));
    }

    public void set_mode (uint32 mode) {
        this.@foreach ((child) => {
            if (child.get_data<uint32> ("id") == mode) {
                ((Gtk.RadioButton)child).active = true;
                action.activate (child.get_data<uint32> ("id"));
            }
        });
    }
}
