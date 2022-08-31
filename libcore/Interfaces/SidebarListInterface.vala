/*
 * SidebarListInterface.vala
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

public interface Sidebar.SidebarListInterface : Gtk.Box {
    public abstract Files.SidebarInterface sidebar { get; construct; }

    public abstract void select_item (SidebarItemInterface? item);
    public abstract void unselect_all_items ();

    public virtual void open_item (SidebarItemInterface item, Files.OpenFlag flag = Files.OpenFlag.DEFAULT) {
        sidebar.path_change_request (item.uri, flag);
    }

    public abstract void refresh (); //Clear and recreate all rows
    public virtual void refresh_info () {} //Update all rows without recreating them

    public virtual uint32 add_plugin_item (Files.SidebarPluginItem plugin_item) {return 0;}

    public virtual void clear () {
        Gtk.Widget? child;
        while ((child = get_first_child ()) != null) {
            remove (child);
            if (child is SidebarItemInterface) {
                ((SidebarItemInterface)child).destroy_bookmark ();
            }
        }
    }

    public virtual void rename_bookmark_by_uri (string uri, string new_name) {}

    public virtual void remove_bookmark_by_uri (string uri) {
        SidebarItemInterface? row = null;
        if (has_uri (uri, out row)) {
            if (row.permanent) {
                return;
            }
            remove (row);
            row.destroy_bookmark ();
        }
    }

    public virtual bool has_uri (string uri, out unowned SidebarItemInterface? row = null) {
        row = null;
        Gtk.Widget? child = get_first_child ();
        bool uri_found = false;
        while (child != null) {
            if (child is SidebarItemInterface) {
                if (((SidebarItemInterface)child).uri == uri) {
                    row = (SidebarItemInterface)child;
                    uri_found = true;
                    break;
                }
            }

            child = child.get_next_sibling ();
        }

        return false;
    }

    public virtual bool select_uri (string uri) {
        unselect_all_items ();
        SidebarItemInterface? row = null;
        if (has_uri (uri, out row)) {
            select_item (row);
            return true;
        }

        return false;
    }

    public virtual bool remove_item_by_id (uint32 id) {
        Gtk.Widget? child = get_first_child ();
        bool removed = false;
        while (child != null) {
            if (child is SidebarItemInterface) {
                unowned var row = (SidebarItemInterface)child;
                if (!row.permanent && row.id == id) {
                    remove (row);
                    row.destroy_bookmark ();
                    removed = true;
                    break;
                }
            }
        }

        return removed;
    }

    /* Returns true if favorite successfully added */
    public virtual bool add_favorite (string uri, string label = "", int index = 0) { return false; }

    public virtual SidebarItemInterface? get_item_at_index (int index) { return null; }

    /* Second parameter is index of target after which the item should be inserted */
    public virtual bool move_item_after (SidebarItemInterface item, int target_index) {
        return false;
    } // By default not-reorderable

    public virtual bool is_drop_target () { return false; } // Whether can drop rows or uris onto list itself (as opposed to onto rows in list)
}
