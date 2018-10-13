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
    public delegate void MenuitemCallback (Gtk.MenuItem menu_item);
    Gtk.MenuItem[] menu_items = {};

    public Gtk.Menu build () {
        var popupmenu = new Gtk.Menu ();
        foreach (var menu_item in menu_items) {
            popupmenu.append (menu_item);
        }

        return popupmenu;
    }

    public PopupMenuBuilder add_open (MenuitemCallback open_cb) {
        return add_item (new Gtk.MenuItem.with_mnemonic (_("Open")), open_cb);
    }

    public PopupMenuBuilder add_open_tab (MenuitemCallback open_in_new_tab_cb) {
        return add_item (new Gtk.MenuItem.with_mnemonic (_("Open in New _Tab")), open_in_new_tab_cb);
    }

    public PopupMenuBuilder add_open_window (MenuitemCallback open_in_new_window_cb) {
        return add_item (new Gtk.MenuItem.with_mnemonic (_("Open in New _Window")), open_in_new_window_cb);
    }

    public PopupMenuBuilder add_remove (MenuitemCallback remove_cb) {
        return add_item (new Gtk.MenuItem.with_label (_("Remove")), remove_cb);
    }

    public PopupMenuBuilder add_rename (MenuitemCallback rename_cb) {
        return add_item (new Gtk.MenuItem.with_label (_("Rename")), rename_cb);
    }

    public PopupMenuBuilder add_mount (MenuitemCallback mount_selected) {
        return add_item (new Gtk.MenuItem.with_mnemonic (_("_Mount")), mount_selected);
    }

    public PopupMenuBuilder add_unmount (MenuitemCallback unmount_cb) {
        return add_item (new Gtk.MenuItem.with_mnemonic (_("_Unmount")), unmount_cb);
    }

    public PopupMenuBuilder add_eject (MenuitemCallback eject_cb) {
        return add_item (new Gtk.MenuItem.with_mnemonic (_("_Eject")), eject_cb);
    }

    public PopupMenuBuilder add_property (MenuitemCallback show_drive_info_cb) {
        return add_item (new Gtk.MenuItem.with_mnemonic (_("Properties")), show_drive_info_cb);
    }

    public PopupMenuBuilder add_separator () {
        return add_item (new Gtk.SeparatorMenuItem ());
    }

    public PopupMenuBuilder add_item (Gtk.MenuItem menu_item, MenuitemCallback? cb = null) {
        if (cb != null) {
            menu_item.activate.connect ((menu_item) => {
                cb (menu_item);
            });
        }

        menu_item.show ();
        menu_items += menu_item;
        return this;
    }
}
