/* ActionRow.vala
 *
 * Copyright 2020 elementary LLC. <https://elementary.io>
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

public delegate void Sidebar.ActionRowFunc ();

public class Sidebar.ActionRow : Gtk.ListBoxRow {
    public string custom_name { get; set construct; }
    public unowned ActionRowFunc action;
    public Icon gicon { get; construct; }
    private Gtk.Image icon;
    public Sidebar.SidebarWindow sidebar { get; construct; }
    protected Gtk.Grid content_grid;

    public ActionRow (string name,
                      Icon gicon,
                      ActionRowFunc func) {
        Object (
            custom_name: name,
            gicon: gicon,
            hexpand: true
        );

        action = func;
    }

    construct {
        selectable = false;

        var event_box = new Gtk.EventBox () {
            above_child = false
        };

        content_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.HORIZONTAL,
            hexpand = true
        };

        var label = new Gtk.Label (custom_name) {
            xalign = 0.0f,
            margin_start = 6
        };

        button_press_event.connect_after (() => {
            activated ();
            return false;
        });

        activate.connect (() => {
            activated ();
        });

        icon = new Gtk.Image.from_gicon (gicon, Gtk.IconSize.MENU) {
            margin_start = 12
        };

        content_grid.add (icon);
        content_grid.add (label);
        event_box.add (content_grid);
        add (event_box);
        show_all ();
    }

    public virtual void activated () {
        action ();
    }

    public void update_icon (Icon gicon) {
        icon.gicon = gicon;
    }
}
