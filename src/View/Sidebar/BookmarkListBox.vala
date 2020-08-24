/* BookmarkListBox.vala
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

public class Sidebar.BookmarkListBox : Gtk.ListBox {
    public SidebarWindow sidebar { get; construct; }
    public BookmarkListBox (SidebarWindow sidebar) {
        Object (
            sidebar: sidebar,
            hexpand: true
        );
    }

    construct {
        selection_mode = Gtk.SelectionMode.SINGLE;
    }

    public BookmarkRow? add_bookmark (string label, string uri, Icon gicon) {
        var row = new BookmarkRow (label, uri, gicon, sidebar);
        if (!has_uri (uri, null)) { //Should duplicate uris be allowed? Or duplicate labels forbidden?
            add (row);
        } else {
            return null;
        }

        return row;
    }

    public void clear () {
        foreach (Gtk.Widget child in get_children ()) {
            remove (child);
            ((BookmarkRow)child).destroy_bookmark ();
        }
    }

    public void remove_bookmark (string uri) {
        Gtk.Widget? row = null;
        if (has_uri (uri, out row)) {
            remove ((BookmarkRow)row);
            ((BookmarkRow)row).destroy_bookmark ();
        }
    }

    public void remove_bookmark_id (int32 id) {
        foreach (Gtk.Widget child in get_children ()) {
            if (child is BookmarkRow) {
                var row = (BookmarkRow)child;
                if (row.id == id) {
                    remove ((BookmarkRow)child);
                    ((BookmarkRow)child).destroy_bookmark ();
                }
            }
        }
    }

    public bool has_uri (string uri, out unowned BookmarkRow row = null) {
        row = null;
        foreach (var child in get_children ()) {
            if (child is BookmarkRow) {
                if (((BookmarkRow)child).uri == uri) {
                    row = (BookmarkRow)child;
                    return true;
                }
            }
        }

        return false;
    }
}
