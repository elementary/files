/* BookmarkRow.vala
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
 * Authors: Jeremy Wootten <jeremy@elementaryos.org>
 */

public class Sidebar.BookmarkRow : Gtk.ListBoxRow {
    private static int row_id;
    protected static Gee.HashMap<int, BookmarkRow> bookmark_id_map;
    protected static Mutex bookmark_lock = Mutex ();

    protected static int get_next_row_id () {
        return ++row_id;
    }

    static construct {
        /* intialise the row_id to a large random number (is this necessary?)*/
        var rand = new Rand.with_seed (int.parse (get_real_time ().to_string ()));
        var min_size = int.MAX / 4;
        while (row_id < min_size) {
            row_id = (int32)(rand.next_int ());
        }


        bookmark_id_map = new Gee.HashMap<int, BookmarkRow> ();
    }

    public static BookmarkRow get_item (int32 id) {
        bookmark_lock.@lock ();
        var row = bookmark_id_map.@get (id);
        bookmark_lock.unlock ();
        return row;
    }

    private bool valid = true; //Set to false if scheduled for removal
    public string custom_name { get; set construct; }
    public string uri { get; set construct; }
    public Icon gicon { get; construct; }
    public int32 id {get; construct; }
    private Gtk.Image icon;
    public Sidebar.SidebarWindow sidebar { get; construct; }
    protected Gtk.Grid content_grid;

    public BookmarkRow (string name,
                        string uri,
                        Icon gicon,
                        Sidebar.SidebarWindow sidebar) {
        Object (
            custom_name: name,
            uri: uri,
            gicon: gicon,
            sidebar: sidebar,
            hexpand: true
        );
    }

    construct {
        selectable = true;
        id = BookmarkRow.get_next_row_id ();
        bookmark_lock.@lock ();
        BookmarkRow.bookmark_id_map.@set (id, this);
        bookmark_lock.unlock ();

        var event_box = new Gtk.EventBox () {
            above_child = false
        };

        content_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.HORIZONTAL,
            hexpand = true
        };

        var label = new Gtk.Label (custom_name) {
            xalign = 0.0f,
            tooltip_text = uri,
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
        sidebar.path_change_request (uri, Marlin.OpenFlag.DEFAULT);
    }

    public void update_icon (Icon gicon) {
        icon.gicon = gicon;
    }

    public void destroy_bookmark () {
        valid = false;
        bookmark_lock.@lock ();
        BookmarkRow.bookmark_id_map.unset (id);
        bookmark_lock.unlock ();
        base.destroy ();
    }

    public virtual async void add_tooltip () {

    }
}

