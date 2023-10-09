/*
 * SPDX-License-Identifier: GPL-2.0+
 * SPDX-FileCopyrightText: 2020-2023 elementary, Inc. (https://elementary.io)
 *
 * Authors : Jeremy Wootten <jeremy@elementaryos.org>
 */

public interface Sidebar.SidebarListInterface : Object {
    public abstract Files.SidebarInterface sidebar { get; construct; }
    public abstract Gtk.ListBox list_box { get; internal set; }

    public abstract void select_item (Gtk.ListBoxRow? item);
    public abstract void unselect_all_items ();

    public virtual void open_item (SidebarItemInterface item, Files.OpenFlag flag = DEFAULT) {
        sidebar.path_change_request (item.uri, flag);
    }

    public abstract void refresh (); //Clear and recreate all rows
    public virtual void refresh_info () {} //Update all rows without recreating them

    public virtual uint32 add_plugin_item (Files.SidebarPluginItem plugin_item) {
        return 0;
    }

    public virtual void clear () {
        foreach (Gtk.Widget child in list_box.get_children ()) {
            list_box.remove (child);
            if (child is SidebarItemInterface) {
                ((SidebarItemInterface) child).destroy_bookmark ();
            }
        }
    }

    public virtual void rename_bookmark_by_uri (string uri, string new_name) {}

    public virtual bool has_uri (string uri, out unowned Gtk.ListBoxRow? row = null) {
        row = null;
        foreach (unowned var child in list_box.get_children ()) {
            if (child is SidebarItemInterface) {
                if (((SidebarItemInterface)child).uri == uri) {
                    row = (Gtk.ListBoxRow) child;
                    return true;
                }
            }
        }

        return false;
    }

    public virtual bool select_uri (string uri) {
        unselect_all_items ();
        Gtk.ListBoxRow? row = null;
        if (has_uri (uri, out row)) {
            select_item (row);
            return true;
        }

        return false;
    }

    public virtual bool remove_item_by_id (uint32 id) {
        foreach (unowned var child in list_box.get_children ()) {
            if (child is SidebarItemInterface) {
                unowned var row = (SidebarItemInterface)child;
                if (row.permanent) {
                    continue;
                }

                if (row.id == id) {
                    list_box.remove (child);
                    row.destroy_bookmark ();
                    return true;
                }
            }
        }

        return false;
    }

    /* Returns true if favorite successfully added */
    public virtual bool add_favorite (string uri, string label = "", int index = 0) { return false; }

    public virtual SidebarItemInterface? get_item_at_index (int index) { return null; }

    /* Second parameter is index of target after which the item should be inserted */
    public virtual bool move_item_after (SidebarItemInterface item, int target_index) {
        return false; // By default not-reorderable
    }

    // Whether can drop rows or uris onto list itself (as opposed to onto rows in list)
    public virtual bool is_drop_target () {
        return false;
    }
}
