/* BookmarkListBox.vala
 *
 * Copyright 2020 elementary, Inc. <https://elementary.io>
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

    public SidebarItemInterface? add_bookmark (string label,
                                               string uri,
                                               Icon gicon,
                                               bool pinned = false,
                                               bool permanent = false) {

        return insert_bookmark (label, uri, gicon, -1, pinned, permanent);
    }

    private SidebarItemInterface? insert_bookmark (string label,
                                                   string uri,
                                                   Icon gicon,
                                                   int index,
                                                   bool pinned = false,
                                                   bool permanent = false) {

        if (has_uri (uri, null)) { //Should duplicate uris be allowed? Or duplicate labels forbidden?
            return null;
        }

        var row = new BookmarkRow (label, uri, gicon, this, pinned, pinned || permanent);
        if (index >= 0) {
            insert (row, index);
        } else {
            add (row);
        }

        return row;
    }

    public override uint32 add_plugin_item (Marlin.SidebarPluginItem plugin_item) {
        var row = add_bookmark (plugin_item.name,
                                plugin_item.uri,
                                plugin_item.icon,
                                true,
                                true);

        row.update_plugin_data (plugin_item);
        return row.id;
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
            row = add_bookmark (
                _("Home"),
                home_uri,
                new ThemedIcon (Marlin.ICON_HOME),
                true
            );

            row.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>Home"}, _("View the home folder"))
            );
        }

        if (PF.FileUtils.protocol_is_supported ("recent")) {
            row = add_bookmark (
                _(Marlin.PROTOCOL_NAME_RECENT),
                Marlin.RECENT_URI,
                new ThemedIcon (Marlin.ICON_RECENT),
                true
            );

            row.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>R"}, _("View the list of recently used files"))
            );
        }

        foreach (unowned Marlin.Bookmark bm in bookmark_list.list) {
            row = add_bookmark (bm.label, bm.uri, bm.get_icon ());
            row.set_tooltip_text (PF.FileUtils.sanitize_path (bm.uri, null, false));
            row.notify["custom-name"].connect (() => {
                bm.label = row.custom_name;
            });
        }

        if (!Marlin.is_admin ()) {
            trash_bookmark = add_bookmark (
                _("Trash"),
                _(Marlin.TRASH_URI),
                trash_monitor.get_icon (),
                true
            );
        }

        trash_bookmark.set_tooltip_markup (
            Granite.markup_accel_tooltip ({"<Alt>T"}, _("Open the Trash"))
        );

        trash_monitor.notify["is-empty"].connect (() => {
            if (trash_bookmark != null) {
                trash_bookmark.update_icon (trash_monitor.get_icon ());
            }
        });
    }

    public override bool add_favorite (string uri,
                                       string? label = null,
                                       int pos = 0) {

        int pinned = 0; // Assume pinned items only at start and end of list
        foreach (unowned Gtk.Widget child in get_children ()) {
            if (((SidebarItemInterface)child).pinned) {
                pinned++;
            } else {
                break;
            }
        }

        if (pos < pinned) {
            pos = pinned;
        }

        var bm = bookmark_list.insert_uri (uri, pos - pinned, label); //Assume non_builtin items are not pinned
        if (bm != null) {
            insert_bookmark (bm.label, bm.uri, bm.get_icon (), pos);
            return true;
        } else {
            return false;
        }
    }

    public override bool remove_item_by_id (uint32 id) {
        foreach (unowned Gtk.Widget child in get_children ()) {
            if (child is SidebarItemInterface) {
                unowned var row = (SidebarItemInterface)child;
                if (row.permanent) {
                    continue;
                } else if (row.id == id) {
                    remove (row);
                    bookmark_list.delete_items_with_uri (row.uri); //Assumes no duplicates
                    row.destroy_bookmark ();
                    return true;
                }
            }
        }

        return false;
    }

    public SidebarItemInterface? get_item_at_index (int index) {
        return (SidebarItemInterface?)(get_row_at_index (index));
    }

    public override bool move_item_after (SidebarItemInterface item, int target_index) {
        if (item.list != this) { // Only move within one list atm
            return false;
        }

        var old_index = item.get_index ();
        if (old_index == target_index) {
            return false;
        }

        remove (item);

        if (old_index > target_index) {
            insert (item, ++target_index);
        } else {
            insert (item, target_index);
        }

        bookmark_list.move_item_uri (item.uri, target_index - old_index);

        return true;
    }
}
