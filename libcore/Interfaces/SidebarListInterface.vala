/*
 * SPDX-License-Identifier: GPL-2.0+
 * SPDX-FileCopyrightText: 2020-2023 elementary, Inc. (https://elementary.io)
 *
 * Authors : Jeremy Wootten <jeremywootten@gmail.com>
 */

public interface Sidebar.SidebarListInterface : Object {
    public abstract Files.SidebarInterface sidebar { get; set construct; }
    public abstract Gtk.ListBox list_box { get; set construct; }

    public abstract void select_item (Gtk.ListBoxRow? item);
    public abstract void unselect_all_items ();
    public abstract void refresh (); //Clear and recreate all rows

    public virtual void refresh_info () {} //Update all rows without recreating them
    public virtual void rename_bookmark_by_uri (string uri, string new_name) {}
    public virtual void open_item (SidebarItemInterface item, Files.OpenFlag flag = DEFAULT) {
        sidebar.path_change_request (item.uri, flag);
    }

    public virtual uint32 add_plugin_item (Files.SidebarPluginItem plugin_item) {
        return 0;
    }

    public virtual void clear () {
        Gtk.ListBoxRow? row = list_box.get_row_at_index (0);
        while (row != null) {
            list_box.remove (row);
            if (row is SidebarItemInterface) {
                ((SidebarItemInterface)row).destroy_bookmark ();
            }

            row = list_box.get_row_at_index (0);
        }
    }

    public virtual bool has_uri (string uri, out unowned Gtk.ListBoxRow? row = null) {
        row = null;
        int index = 0;
        unowned var child = list_box.get_row_at_index (index);
        while (child != null) {
            if (child is SidebarItemInterface) {
                if (((SidebarItemInterface)child).uri == uri) {
                    row = (Gtk.ListBoxRow) child;
                    return true;
                }
            }

            child = list_box.get_row_at_index (++index);
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

    // Returns true if item was both found and removed
    public virtual bool remove_item_by_id (uint32 id) {
        int index = 0;
        unowned var child = list_box.get_row_at_index (index);
        while (child != null) {
            if (child is SidebarItemInterface) {
                unowned var row = (SidebarItemInterface)child;
                if (row.id == id) {
                    if (row.permanent) {
                        critical ("Attempt to remove permanent row ignored");
                        return false;
                    } else {
                        list_box.remove (child);
                        row.destroy_bookmark ();
                        return true;
                    }
                }
            }

            child = list_box.get_row_at_index (++index);
        }

        return false;
    }

    /* Returns true if favorite successfully added */
    public virtual bool add_favorite (string uri, string label = "", int index = 0) {
        return false;
    }

    public virtual SidebarItemInterface? get_item_at_index (int index) {
        return null;
    }

    /* Second parameter is index of target after which the item should be inserted */
    public virtual bool move_item_after (SidebarItemInterface item, int target_index) {
        return false; // By default not-reorderable
    }

    // Whether can drop rows or uris onto list itself (as opposed to onto rows in list)
    public virtual bool is_drop_target () {
        return false;
    }

    public void focus () {
        var focus_row = list_box.get_selected_row ();
        if (focus_row == null) {
            focus_row = list_box.get_row_at_index (0);
        }

        focus_row.grab_focus ();
    }
}
