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
    public uint n_items { get { return menu_items.length; }}

    public Gtk.Menu build (Gtk.Widget attach_widget) {
        var popupmenu = new Gtk.Menu () {
            attach_widget = attach_widget
        };
        foreach (var menu_item in menu_items) {
            popupmenu.append (menu_item);
        }

        return popupmenu;
    }

    public Gtk.Menu build_from_model (MenuModel model,
                                      string? action_group_namespace = null,
                                      ActionGroup? action_group = null) {

        var menu = new Gtk.Menu.from_model (model);
        menu.insert_action_group (action_group_namespace, action_group);

        for (int i = 0; i < menu_items.length; i++) {
            menu.append (menu_items[i]);
            menu.reorder_child (menu_items[i], i);
        }

        return menu;
    }

    public void add_safely_remove () {
        // Do we need different text for USB sticks and optical drives?
        add_with_action_name (_("Safely Remove"), "mountable.safely-remove");
    }

    public PopupMenuBuilder add_separator () {
        return add_item (new Gtk.SeparatorMenuItem ());
    }

    public void add_with_action_name (string label, string action_name) {
        var menu_item = new Gtk.MenuItem.with_mnemonic (label);
        menu_item.set_detailed_action_name (
            Action.print_detailed_name (action_name, null)
        );

        menu_item.show ();
        menu_items += menu_item;
    }

    public PopupMenuBuilder add_item (Gtk.MenuItem menu_item) {
        menu_item.show ();
        menu_items += menu_item;
        return this;
    }
}
