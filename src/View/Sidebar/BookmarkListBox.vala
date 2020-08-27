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

public class Sidebar.BookmarkListBox : Gtk.ListBox, Sidebar.SidebarListInterface {
    private Marlin.BookmarkList bookmark_list;
    private unowned Marlin.TrashMonitor trash_monitor;
    private SidebarItemInterface? trash_bookmark;

    public Marlin.SidebarInterface sidebar {get; construct;}

    public BookmarkListBox (Marlin.SidebarInterface sidebar) {
        Object (
            sidebar: sidebar
        );
    }

    construct {
        hexpand = true;
        selection_mode = Gtk.SelectionMode.SINGLE;
        trash_monitor = Marlin.TrashMonitor.get_default ();
        bookmark_list = Marlin.BookmarkList.get_instance ();
        bookmark_list.loaded.connect (() => {
            refresh ();
        });
    }

    public override SidebarItemInterface? add_sidebar_row (string label, string uri, Icon gicon) {
        var row = new BookmarkRow (label, uri, gicon, this);
        if (!has_uri (uri, null)) { //Should duplicate uris be allowed? Or duplicate labels forbidden?
            add (row);
        } else {
            return null;
        }

        return row;
    }

    public void select_item (SidebarItemInterface? item) {
        if (item != null && item is BookmarkRow) {
            select_row ((BookmarkRow)item);
        } else {
            unselect_all_items ();
        }
    }

    public void unselect_all_items () {
        unselect_all ();
    }

    public void refresh () {
        clear ();

        SidebarItemInterface? row;
        var home_uri = "";
        try {
            home_uri = GLib.Filename.to_uri (PF.UserUtils.get_real_user_home (), null);
        }
        catch (ConvertError e) {}

        if (home_uri != "") {
            row = add_sidebar_row (
                _("Home"),
                home_uri,
                new ThemedIcon (Marlin.ICON_HOME)
            );

            row.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>Home"}, _("View the home folder"))
            );

            row.pinned = true;
            row.permanent = true;
        }

        if (PF.FileUtils.protocol_is_supported ("recent")) {
            row = add_sidebar_row (
                _(Marlin.PROTOCOL_NAME_RECENT),
                Marlin.RECENT_URI,
                new ThemedIcon (Marlin.ICON_RECENT)
            );

            row.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>R"}, _("View the list of recently used files"))
            );

            row.pinned = true;
            row.permanent = true;
        }


        foreach (Marlin.Bookmark bm in bookmark_list.list) {
            row = add_sidebar_row (bm.label, bm.uri, bm.get_icon ());
            row.set_tooltip_text (PF.FileUtils.sanitize_path (bm.uri, null, false));
        }

        if (!Marlin.is_admin ()) {
            trash_bookmark = add_sidebar_row (
                _("Trash"),
                _(Marlin.TRASH_URI),
                trash_monitor.get_icon ()
            );
        }

        trash_bookmark.set_tooltip_markup (
            Granite.markup_accel_tooltip ({"<Alt>T"}, _("Open the Trash"))
        );

        trash_bookmark.pinned = true;
        trash_bookmark.permanent = true;

        trash_monitor.notify["is-empty"].connect (() => {
            if (trash_bookmark != null) {
                trash_bookmark.update_icon (trash_monitor.get_icon ());
            }
        });
    }

    public override void add_favorite (string uri, string? label = null) {
        var bm = bookmark_list.insert_uri_at_end (uri, label);
        add_sidebar_row (bm.label, bm.uri, bm.get_icon ());
    }
}
