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

public class Sidebar.BookmarkListBox : Gtk.Box, Sidebar.SidebarListInterface {
    public Gtk.Widget list_widget { get; construct; }
    private Gtk.ListBox list_box {
        get {
            return (Gtk.ListBox)list_widget;
        }
    }
    private Files.BookmarkList bookmark_list;
    private unowned Files.TrashMonitor trash_monitor;

    public Files.SidebarInterface sidebar {get; construct;}

    public BookmarkListBox (Files.SidebarInterface sidebar) {
        Object (
            sidebar: sidebar
        );
    }

    construct {
        list_widget = new Gtk.ListBox () {
            hexpand = true,
            selection_mode = Gtk.SelectionMode.SINGLE
        };

        append (list_widget);

        trash_monitor = Files.TrashMonitor.get_default ();
        bookmark_list = Files.BookmarkList.get_instance ();
        if (bookmark_list.loaded) {
            refresh ();
        }

        bookmark_list.notify["loaded"].connect (() => {
            if (bookmark_list.loaded) {
                refresh ();
            }
        });

        list_box.row_activated.connect ((row) => {
            if (row is SidebarItemInterface) {
                ((SidebarItemInterface) row).activated ();
            }
        });
        list_box.row_selected.connect ((row) => {
            if (row is SidebarItemInterface) {
                select_item ((SidebarItemInterface) row);
            }
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

        var row = new BookmarkRow (label, uri, gicon, this, pinned, permanent);
        if (index >= 0) {
            list_box.insert (row, index);
        } else {
            list_box.append (row);
        }

        return row;
    }

    public override uint32 add_plugin_item (Files.SidebarPluginItem plugin_item) {
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
            list_box.select_row ((BookmarkRow)item);
        } else {
            unselect_all_items ();
        }
    }

    public void unselect_all_items () {
        list_box.unselect_all ();
    }

    public void refresh () {
        clear_list ();
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
                new ThemedIcon (Files.ICON_HOME),
                true,
                true
            );

            row.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>Home"}, _("View the home folder"))
            );

            row.can_insert_before = false;
            row.can_insert_after = false;
        }

        if (Files.FileUtils.protocol_is_supported ("recent")) {
            row = add_bookmark (
                _(Files.PROTOCOL_NAME_RECENT),
                Files.RECENT_URI,
                new ThemedIcon (Files.ICON_RECENT),
                true,
                true
            );

            row.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>R"}, _("View the list of recently used files"))
            );

            row.can_insert_before = false;
            row.can_insert_after = true;
        }

        foreach (unowned Files.Bookmark bm in bookmark_list.list) {
            row = add_bookmark (bm.custom_name, bm.uri, bm.get_icon ());
            row.set_tooltip_text (Files.FileUtils.sanitize_path (bm.uri, null, false));
            row.notify["custom-name"].connect (() => {
                bm.custom_name = row.custom_name;
            });
        }

        if (!Files.is_admin ()) {
            row = add_bookmark (
                _("Trash"),
                _(Files.TRASH_URI),
                trash_monitor.get_icon (),
                true,
                true
            );

            row.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>T"}, _("Open the Trash"))
            );

            row.can_insert_before = true;
            row.can_insert_after = false;

            trash_monitor.notify["is-empty"].connect (() => {
                row.update_icon (trash_monitor.get_icon ());
            });
        }
    }

    public virtual void rename_bookmark_by_uri (string uri, string new_name) {
        bookmark_list.rename_item_with_uri (uri, new_name);
    }

    public override bool add_favorite (string uri,
                                       string custom_name = "",
                                       int pos = 0) {

        int pinned = 0; // Assume pinned items only at start and end of list
        var child = list_box.get_first_child ();
        while (child != null && ((SidebarItemInterface)child).pinned) {
            pinned++;
            child = child.get_next_sibling ();
        }

        if (pos < pinned) {
            pos = pinned;
        }

        var bm = bookmark_list.insert_uri (uri, pos - pinned, custom_name); //Assume non_builtin items are not pinned
        if (bm != null) {
            insert_bookmark (bm.custom_name, bm.uri, bm.get_icon (), pos);
            return true;
        } else {
            return false;
        }
    }

    public override bool remove_item_by_id (uint32 id) {
        var row = list_box.get_row_at_index (0);
        bool removed = false;
        while (row != null && !removed) {
            if (row is SidebarItemInterface) {
                var item = (SidebarItemInterface)row;
                if (!item.permanent && item.id == id) {
                    list_box.remove (item);
                    bookmark_list.delete_items_with_uri (item.uri); //Assumes no duplicates
                    removed = true;
                }
            }
        };

        return removed;
    }

    public SidebarItemInterface? get_item_at_index (int index) {
        return (SidebarItemInterface?)(list_box.get_row_at_index (index));
    }

    public override bool move_item_after (SidebarItemInterface item, int target_index) {
        if (item.list != this) { // Only move within one list atm
            return false;
        }

        var old_index = item.get_index ();
        if (old_index == target_index) {
            return false;
        }

        list_box.remove (item);

        if (old_index > target_index) {
            list_box.insert (item, ++target_index);
        } else {
            list_box.insert (item, target_index);
        }

        bookmark_list.move_item_uri (item.uri, target_index - old_index);

        return true;
    }

    public virtual bool is_drop_target () { return true; }
}
