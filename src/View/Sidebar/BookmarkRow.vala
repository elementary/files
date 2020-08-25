/* BookmarkRow.vala
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
 * Authors: Jeremy Wootten <jeremy@elementaryos.org>
 */

public class Sidebar.BookmarkRow : Gtk.ListBoxRow, SidebarItemInterface {

    static construct {
        SidebarItemInterface.row_id = new Rand.with_seed (
            int.parse (get_real_time ().to_string ())
        ).next_int ();

        SidebarItemInterface.item_map_lock = Mutex ();
        SidebarItemInterface.item_id_map = new Gee.HashMap<uint32, SidebarItemInterface> ();
    }

    private bool valid = true; //Set to false if scheduled for removal
    private Gtk.Image icon;
    protected Gtk.Grid content_grid;
    public string custom_name { get; set construct; }
    public SidebarListInterface list { get; construct; }
    public uint32 id { get; construct; }
    public string uri { get; set construct; }
    public Icon gicon { get; set construct; }

    public BookmarkRow (string name,
                        string uri,
                        Icon gicon,
                        SidebarListInterface list) {
        Object (
            custom_name: name,
            uri: uri,
            gicon: gicon,
            list: list,
            hexpand: true
        );
    }

    construct {
        //Set a fallback tooltip to stop category tooltip appearing inappropriately
        set_tooltip_text (PF.FileUtils.sanitize_path (uri, null, false));

        selectable = true;
        id = SidebarItemInterface.get_next_item_id ();
        item_map_lock.@lock ();
        SidebarItemInterface.item_id_map.@set (id, this);
        item_map_lock.unlock ();

        var event_box = new Gtk.EventBox () {
            above_child = false
        };

        content_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.HORIZONTAL
        };

        var label = new Gtk.Label (custom_name) {
            xalign = 0.0f,
            halign = Gtk.Align.START,
            hexpand = true,
            margin_start = 6
        };

        button_press_event.connect (on_button_press_event);
        button_release_event.connect_after (after_button_release_event);

        activate.connect (() => {activated ();});

        icon = new Gtk.Image.from_gicon (gicon, Gtk.IconSize.MENU) {
            halign = Gtk.Align.START,
            hexpand = false,
            margin_start = 12
        };

        content_grid.add (icon);
        content_grid.add (label);
        event_box.add (content_grid);
        add (event_box);
        show_all ();
    }

    public void destroy_bookmark () {
        valid = false;
        item_map_lock.@lock ();
        SidebarItemInterface.item_id_map.unset (id);
        item_map_lock.unlock ();
        base.destroy ();
    }

    protected virtual bool on_button_press_event (Gdk.EventButton event) {
        list.select_item (this);
        return false;
    }

    protected virtual bool after_button_release_event (Gdk.EventButton event) {
        if (!valid) { //Ignore if in the process of being removed
            return true;
        }

        switch (event.button) {
            case Gdk.BUTTON_PRIMARY:
                activated ();
                return true;

            case Gdk.BUTTON_SECONDARY:
                popup_context_menu (event);
                return true;

            default:
                return false;
        }
    }

    protected void popup_context_menu (Gdk.EventButton event) {
        var menu_builder = new PopupMenuBuilder ()
            .add_open (() => {activated ();})
            .add_separator ()
            .add_open_tab (() => {activated (Marlin.OpenFlag.NEW_TAB);})
            .add_open_window (() => {activated (Marlin.OpenFlag.NEW_WINDOW);});

        add_extra_menu_items (menu_builder);
        menu_builder.build ().popup_at_pointer (event);
    }

    protected void add_extra_menu_items (PopupMenuBuilder menu_builder) {
        menu_builder.add_separator ();
        menu_builder.add_remove (() => {list.remove_item_by_id (id);});
    }

    protected void activated (Marlin.OpenFlag flag = Marlin.OpenFlag.DEFAULT) {
        list.open_item (this, flag);
    }
}
