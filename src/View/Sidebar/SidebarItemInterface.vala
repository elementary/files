/*
 * SidebarItemInterface.vala
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

public interface Sidebar.SidebarItemInterface : Gtk.Widget {
    /* Non constant static members must be initialised in implementing class */
    protected static uint32 row_id;
    protected static Gee.HashMap<uint32, SidebarItemInterface> item_id_map;
    protected static Mutex item_map_lock;

    protected static uint32 get_next_item_id () {
        return ++row_id; //Must be > 0
    }

    public static SidebarItemInterface? get_item (uint32 id) {
        if (id == 0) {
            return null;
        }

        item_map_lock.@lock ();
        var item = item_id_map.@get (id);
        item_map_lock.unlock ();
        return item;
    }

    public abstract SidebarListInterface list { get; construct; }
    public abstract uint32 id { get; construct; }
    public abstract string uri { get; set construct; }
    public abstract string custom_name { get; set construct; }
    public abstract Icon gicon { get; set construct; }
    public abstract bool pinned { get; construct; default = false;} //Whether can be reordered
    public abstract bool permanent { get; construct; default = false;} //Whether can be deleted

    /* Provision of plugin items with additional menu options */
    //TODO Make a separate interface?
    public abstract MenuModel? menu_model {get; set; default = null;}
    public abstract ActionGroup? action_group {get; set; default = null;}
    public abstract string? action_group_namespace { get; set; default = null;}

    public abstract void destroy_bookmark ();
    public virtual void update_icon (Icon icon) {
        gicon = icon;
    }

    public virtual void add_extra_menu_items (PopupMenuBuilder menu_builder) {}
    public virtual void update_plugin_data (Marlin.SidebarPluginItem item) {}

    protected virtual void activated (Marlin.OpenFlag flag = Marlin.OpenFlag.DEFAULT) {
        list.open_item (this, flag);
    }
}
