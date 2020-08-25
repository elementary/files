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

public interface Sidebar.SidebarListInterface : Gtk.Container {
    public abstract Marlin.SidebarInterface sidebar { get; construct; }

    public abstract void select_item (SidebarItemInterface? item);
    public abstract void unselect_all_items ();

    public virtual void open_item (SidebarItemInterface item, Marlin.OpenFlag flag = Marlin.OpenFlag.DEFAULT) {
        sidebar.path_change_request (item.uri, flag);
    }

    public abstract void refresh ();

    public virtual SidebarItemInterface? add_sidebar_row (string label, string uri, Icon gicon) {return null;}
    public virtual uint32 add_plugin_item (Marlin.SidebarPluginItem plugin_item) {return 0;}

    public virtual void clear () {
        foreach (Gtk.Widget child in get_children ()) {
            remove (child);
            if (child is SidebarItemInterface) {
                ((SidebarItemInterface)child).destroy_bookmark ();
            }
        }
    }

    public virtual void remove_bookmark_by_uri (string uri) {
        SidebarItemInterface? row = null;
        if (has_uri (uri, out row)) {
            remove (row);
            row.destroy_bookmark ();
        }
    }

    public virtual bool has_uri (string uri, out unowned SidebarItemInterface? row = null) {
        row = null;
        foreach (var child in get_children ()) {
            if (child is SidebarItemInterface) {
                if (((SidebarItemInterface)child).uri == uri) {
                    row = (SidebarItemInterface)child;
                    return true;
                }
            }
        }

        return false;
    }

    public virtual bool remove_item_by_id (uint32 id) {
        foreach (Gtk.Widget child in get_children ()) {
            if (child is SidebarItemInterface) {
                var row = (SidebarItemInterface)child;
                if (row.id == id) {
                    remove (row);
                    row.destroy_bookmark ();
                    return true;
                }
            }
        }

        return false;
    }

    public virtual void add_favorite (string uri, string? label = null) {}

}

