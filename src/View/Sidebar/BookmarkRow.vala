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
    enum TargetType {
        TEXT_URI_LIST,
        BOOKMARK_ROW,
    }

    static Gtk.TargetEntry[] SOURCE_TARGETS = {
        {"text/plain", Gtk.TargetFlags.SAME_APP, TargetType.BOOKMARK_ROW}
    };

    static Gtk.TargetEntry[] DEST_TARGETS = {
        {"text/uri-list", Gtk.TargetFlags.SAME_APP, TargetType.TEXT_URI_LIST},
        {"text/plain", Gtk.TargetFlags.SAME_APP, TargetType.BOOKMARK_ROW},
    };

    static Gtk.TargetEntry[] PINNED_TARGETS = {
        {"text/uri-list", Gtk.TargetFlags.SAME_APP, TargetType.TEXT_URI_LIST}
    };

    static Gdk.Atom source_data_type = Gdk.Atom.intern_static_string ("text/plain");

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
    protected Gtk.Grid icon_label_grid;
    public string custom_name { get; set construct; }
    public SidebarListInterface list { get; construct; }
    public uint32 id { get; construct; }
    public string uri { get; set construct; }
    public Icon gicon { get; set construct; }
    public bool pinned { get; set; default = false;}
    public bool permanent { get; set; default = false;}

    public BookmarkRow (string name,
                        string uri,
                        Icon gicon,
                        SidebarListInterface list,
                        bool pinned,
                        bool permanent) {
        Object (
            custom_name: name,
            uri: uri,
            gicon: gicon,
            list: list,
            hexpand: true,
            pinned: pinned,
            permanent: permanent
        );

        set_up_drag ();
        set_up_drop ();
    }

    construct {
        margin_bottom = 3;
        //Set a fallback tooltip to stop category tooltip appearing inappropriately
        set_tooltip_text (PF.FileUtils.sanitize_path (uri, null, false));

        selectable = true;
        id = SidebarItemInterface.get_next_item_id ();
        item_map_lock.@lock ();
        SidebarItemInterface.item_id_map.@set (id, this);
        item_map_lock.unlock ();

        var label = new Gtk.Label (custom_name) {
            xalign = 0.0f,
            halign = Gtk.Align.START,
            hexpand = true,
            margin_start = 6
        };

        icon = new Gtk.Image.from_gicon (gicon, Gtk.IconSize.MENU) {
            halign = Gtk.Align.START,
            hexpand = false,
            margin_start = 12
        };

        icon_label_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.HORIZONTAL
        };
        icon_label_grid.add (icon);
        icon_label_grid.add (label);

        var event_box = new Gtk.EventBox () {
            above_child = false
        };
        event_box.add (icon_label_grid);

        content_grid = new Gtk.Grid () {
            orientation = Gtk.Orientation.HORIZONTAL
        };
        content_grid.attach (event_box, 0, 0, 1, 1);

        add (content_grid);
        show_all ();

        button_press_event.connect (on_button_press_event);
        button_release_event.connect_after (after_button_release_event);

        activate.connect (() => {activated ();});
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

    private void set_up_drag () {
        if (pinned) { //Pinned items cannot be dragged
            return;
        }
        /*Set up as Drag Source*/
        Gtk.drag_source_set (
            this,
            Gdk.ModifierType.BUTTON1_MASK,
            SOURCE_TARGETS,
            Gdk.DragAction.MOVE
        );

        drag_begin.connect ((ctx) => {
            var drag_icon = new Gtk.Image.from_gicon (gicon, Gtk.IconSize.LARGE_TOOLBAR);
            drag_icon.show ();
            Gtk.drag_set_icon_widget (ctx, drag_icon, 0, 0);
            //TODO Set an image of the row itself?
        });

        /* Pass the item id as selection data by converting to string.*/
        //TODO There may be a more elegant method of passing a pointer to `this` directly.
        drag_data_get.connect ((ctx, sel_data, info, time) => {
            if (pinned) {
                return;
            }

            uint8[] data = id.to_string ().data;
            sel_data.@set (source_data_type, 8, data);
        });

        drag_failed.connect ((ctx, res) => {
            if (res == Gtk.DragResult.NO_TARGET) {
                Gdk.Window app_window = list.get_window ().get_effective_toplevel ();
                Gdk.Window drag_window = ctx.get_drag_window ();


                Gdk.Rectangle app_rect, drag_rect, intersect_rect;
                app_window.get_frame_extents (out app_rect);
                drag_window.get_frame_extents (out drag_rect);

                if (!drag_rect.intersect (app_rect, out intersect_rect)) {
                    list.remove_item_by_id (id);

                    var device = ctx.get_device ();
                    int x, y;
                    device.get_position (null, out x, out y);
                    Plank.PoofWindow poof_window;
                    poof_window = Plank.PoofWindow.get_default ();
                    poof_window.show_at (x, y);
                    return true;
                }
            }

            return false;
        });
    }

    private void set_up_drop () {
        /*Set up as Drop Target for rows/uris*/
        Gtk.drag_dest_set (
            this,
            Gtk.DestDefaults.ALL,
            pinned ? PINNED_TARGETS : DEST_TARGETS,
            Gdk.DragAction.MOVE | Gdk.DragAction.COPY | Gdk.DragAction.LINK
        );

        drag_data_received.connect ((ctx, x, y, sel_data, info, time) => {
            if (pinned) {
                critical ("drag data received but pinned - should not happen");
                return;
            }

            var text = sel_data.get_text ();
            if (text == null) {
                return;
            }

            if (info == TargetType.BOOKMARK_ROW) {
                var id = (uint32)(uint.parse (text));
                var item = SidebarItemInterface.get_item (id);

                if (item == null ||
                    item.id == this.id ||
                    item.list != list) { //Cannot drop on self or different list

                    return;
                }

                list.remove (item);
                //We do not remove from map as we are not destroying the item and need to maintain a reference

                var pos = get_index ();
                if (y > get_allocated_height () / 2) { //Insert at point nearest to where dropped
                    pos++;
                }

                ((Gtk.ListBox)list).insert (item, pos);
            } else if (info == TargetType.TEXT_URI_LIST) {
                //TODO Handle uris.
            }
        });

        /* Handle motion over a potention drop target */
        drag_motion.connect ((ctx, x, y, time) => {
            if (pinned) {
                Gdk.drag_status (ctx, Gdk.DragAction.DEFAULT, time);
                return true;
            }

            return false;
        });
    }
}
