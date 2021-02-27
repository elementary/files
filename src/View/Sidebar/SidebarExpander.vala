/* SidebarWindow.vala
 *
 * Copyright 2021 elementary LLC. <https://elementary.io>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 *
 * Authors : Jeremy Wootten <jeremy@elementaryos.org>
 */

public class Sidebar.SidebarExpander : Gtk.Grid {
    public Gtk.Revealer revealer { get; construct; }
    public Gtk.ToggleButton toggle_button { get; construct; }

    public SidebarListInterface list {
        get {
            return (SidebarListInterface)(revealer.get_child ());
        }
    }

    public bool active {
        get {
            return toggle_button.active;
        }

        set {
            toggle_button.active = value;
        }
    }

    public string expander_label { get; construct; }
    private static Gtk.CssProvider expander_provider;

    public SidebarExpander (string label, SidebarListInterface revealer_child) {
        Object (
            expander_label: label
        );

        revealer.margin_start = 6;
        revealer.add (revealer_child);
    }

    static construct {
        expander_provider = new Gtk.CssProvider ();
        expander_provider.load_from_resource ("/io/elementary/files/SidebarExpander.css");
    }

    construct {
        hexpand = true;
        orientation = Gtk.Orientation.VERTICAL;

        var title = new Gtk.Label (expander_label) {
            hexpand = true,
            xalign = 0
        };

        toggle_button = new Gtk.ToggleButton ();
        revealer = new Gtk.Revealer ();
        unowned var revealer_style_context = revealer.get_style_context ();
        revealer_style_context.add_class ("revealer");
        revealer_style_context.add_provider (expander_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var arrow = new Gtk.Spinner ();
        unowned var arrow_style_context = arrow.get_style_context ();
        arrow_style_context.add_class (Gtk.STYLE_CLASS_ARROW);
        arrow_style_context.add_provider (expander_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var grid = new Gtk.Grid ();
        grid.add (title);
        grid.add (arrow);

        toggle_button.add (grid);

        unowned var style_context = toggle_button.get_style_context ();
        style_context.add_class (Granite.STYLE_CLASS_H4_LABEL);
        style_context.add_class (Gtk.STYLE_CLASS_EXPANDER);
        style_context.add_provider (expander_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        add (toggle_button);
        add (revealer);

        toggle_button.bind_property ("active", revealer, "reveal-child", BindingFlags.DEFAULT);

        show_all ();
    }

    public void set_gicon (Icon gicon) {
        var icon = new Gtk.Image.from_gicon (gicon, Gtk.IconSize.MENU);
        attach_next_to (icon, toggle_button, Gtk.PositionType.LEFT);
    }
}
