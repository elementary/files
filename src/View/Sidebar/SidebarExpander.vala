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

public class SidebarExpander : Gtk.ToggleButton {
    public string expander_label { get; construct; }
    private static Gtk.CssProvider expander_provider;

    public SidebarExpander (string label) {
        Object (expander_label: label);
    }

    static construct {
        expander_provider = new Gtk.CssProvider ();
        expander_provider.load_from_resource ("/io/elementary/files/SidebarExpander.css");
    }

    construct {
        var title = new Gtk.Label (expander_label) {
            hexpand = true,
            xalign = 0
        };

        var arrow = new Gtk.Spinner ();

        unowned Gtk.StyleContext arrow_style_context = arrow.get_style_context ();
        arrow_style_context.add_class (Gtk.STYLE_CLASS_ARROW);
        arrow_style_context.add_provider (expander_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);

        var grid = new Gtk.Grid ();
        grid.add (title);
        grid.add (arrow);

        add (grid);

        unowned Gtk.StyleContext style_context = get_style_context ();
        style_context.add_class (Granite.STYLE_CLASS_H4_LABEL);
        style_context.add_class (Gtk.STYLE_CLASS_EXPANDER);
        style_context.add_provider (expander_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
    }
}
