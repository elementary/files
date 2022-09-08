/***
    Copyright (c) 2018 elementary LLC <https://elementary.io>

    Pantheon Files is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of the
    License, or (at your option) any later version.

    Pantheon Files is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program.  If not, see <http://www.gnu.org/licenses/>.

    Author(s):  Fernando da Silva Sousa <wild.nando@gmail.com>
***/

public class PopupMenuBuilder : Object {
    public delegate void MenuitemCallback (MenuItem menu_item);
    MenuItem[] menu_items = {};
    public uint n_items { get { return menu_items.length; }}

    public Gtk.PopoverMenu build () {
        var menu = new Menu ();
        foreach (var menu_item in menu_items) {
            menu.append_item (menu_item);
        }

        return new Gtk.PopoverMenu.from_model (menu);
    }

    // public Gtk.PopoverMenu build_from_model (MenuModel model) {
    //     var menu = new Menu.from_model (model);
    //     menu.insert_action_group (action_group_namespace, action_group);

    //     for (int i = 0; i < menu_items.length; i++) {
    //         menu.append (menu_items[i]);
    //         menu.reorder_child (menu_items[i], i);
    //     }

    //     return menu;
    // }

    public PopupMenuBuilder add_open (string? detailed_action_name) {
        return add_item (_("Open"), detailed_action_name);
    }
    public PopupMenuBuilder add_open_tab (string? detailed_action_name) {
        return add_item (_("New Tab"), detailed_action_name);
    }
    public PopupMenuBuilder add_open_window (string? detailed_action_name) {
        return add_item (_("New Window"), detailed_action_name);
    }
    public PopupMenuBuilder add_remove (string? detailed_action_name) {
        return add_item (_("Remove"), detailed_action_name);
    }
    public PopupMenuBuilder add_rename (string? detailed_action_name) {
        return add_item (_("Rename"), detailed_action_name);
    }
    public PopupMenuBuilder add_mount (string? detailed_action_name) {
        return add_item (_("Mount"), detailed_action_name);
    }
    public PopupMenuBuilder add_unmount (string? detailed_action_name) {
        return add_item (_("Unmount"), detailed_action_name);
    }
    public PopupMenuBuilder add_properties (string? detailed_action_name) {
        return add_item (_("Properties"), detailed_action_name);
    }
    public PopupMenuBuilder add_eject_drive (string? detailed_action_name) {
        return add_item (_("Eject Media"), detailed_action_name);
    }
    public PopupMenuBuilder add_safely_remove (string? detailed_action_name) {
        return add_item (_("Safely Remove"), detailed_action_name);
    }
    public PopupMenuBuilder add_bookmark (string? detailed_action_name) {
        return add_item (_("Add to Bookmarks"), detailed_action_name);
    }
    public PopupMenuBuilder add_empty_all_trash (string? detailed_action_name) {
        var volume_monitor = VolumeMonitor.@get ();
        int mounts_with_trash = 0;
        foreach (Mount mount in volume_monitor.get_mounts ()) {
            if (Files.FileOperations.mount_has_trash (mount)) {
                mounts_with_trash++;
            }
        }

        var text = mounts_with_trash > 0 ? _("Permanently Delete All Trash") : _("Permanently Delete Trash");

        return add_item (text, detailed_action_name);
    }

    public PopupMenuBuilder add_empty_mount_trash (string? detailed_action_name) {
        return add_item (_("Permanently Delete Trash on this Mount"), detailed_action_name);
    }

    public PopupMenuBuilder add_separator () {
        //TODO Use add section
        menu_items += new MenuItem ("---", null);
        return this;
    }

    //TODO Link MenuItems to actions not callbacks
    public PopupMenuBuilder add_item (string name, string? detailed_action_name) {
        menu_items += new MenuItem (name, detailed_action_name);;
        return this;
    }
}
