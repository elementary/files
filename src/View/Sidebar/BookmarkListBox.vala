/* BookmarkListBox.vala
 *
 * Copyright 2020 elementary, Inc. <https://elementary.io>
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

public class Sidebar.BookmarkListBox : Gtk.Box, Sidebar.SidebarListInterface {
    public Gtk.ListBox list_box { get; construct; }
    public Files.BookmarkList bookmark_list { get; construct; }
    private unowned Files.TrashMonitor trash_monitor;
    private bool drop_accepted = false;
    private BookmarkRow? current_drop_target = null;

    public Files.SidebarInterface sidebar {get; construct;}

    public BookmarkListBox (Files.SidebarInterface sidebar) {
        Object (
            sidebar: sidebar
        );
    }

    construct {
        list_box = new Gtk.ListBox () {
            hexpand = true,
            selection_mode = Gtk.SelectionMode.SINGLE
        };

        append (list_box);

        trash_monitor = Files.TrashMonitor.get_default ();
        bookmark_list = Files.BookmarkList.get_instance ();
        if (bookmark_list.loaded) {
            refresh ();
        }

        bookmark_list.notify["loaded"].connect (() => {
            if (bookmark_list.loaded) {
                refresh ();
            }
        });

        list_box.row_activated.connect ((row) => {
            if (row is SidebarItemInterface) {
                ((SidebarItemInterface) row).activated ();
            }
        });
        list_box.row_selected.connect ((row) => {
            if (row is SidebarItemInterface) {
                select_item ((SidebarItemInterface) row);
            }
        });

        //Set up as drag source
        var drag_source = new Gtk.DragSource () {
            propagation_phase = Gtk.PropagationPhase.CAPTURE,
            actions = Gdk.DragAction.LINK
        };
        list_box.add_controller (drag_source);
        drag_source.prepare.connect ((x, y) => {
            var widget = pick (x, y, Gtk.PickFlags.DEFAULT);
            var row = widget.get_ancestor (typeof (BookmarkRow));
            if (row != null && (row is BookmarkRow)) {
                var bm = ((BookmarkRow)row);
                list_box.set_data<BookmarkRow> ("dragged-row", bm);
                var uri_val = new Value (typeof (string));
                uri_val.set_string (bm.uri);
                return new Gdk.ContentProvider.for_value (uri_val);
            }

            return null;
        });
        drag_source.drag_begin.connect ((drag) => {
            //TODO Set drag icon
            return;
        });
        drag_source.drag_end.connect ((drag, delete_data) => {
            list_box.set_data<BookmarkRow> ("dragged-row", null);
            return;
        });
        drag_source.drag_cancel.connect ((drag, reason) => {
            list_box.set_data<BookmarkRow> ("dragged-row", null);
            return true;
        });
        //Set up as drag target
        var drop_target = new Gtk.DropTarget (
            typeof (string),
            Gdk.DragAction.LINK | Gdk.DragAction.COPY
        ) {
            propagation_phase = Gtk.PropagationPhase.CAPTURE,
            preload = true
        };
        list_box.add_controller (drop_target);
        drop_target.accept.connect ((drop) => {
            var bm = list_box.get_data<BookmarkRow> ("dragged-data");
            if (bm != null) {
                drop_accepted = true;
                return true;
            } else {
                var formats = drop.get_formats ();
                if (formats.contain_gtype (typeof (string))) {
                    drop.read_value_async.begin (
                        typeof (string),
                        Priority.DEFAULT,
                        null,
                        (obj, res) => {
                            try {
                                var val = drop.read_value_async.end (res);
                                if (val != null) {
                                    Uri.is_valid (val.get_string (), UriFlags.PARSE_RELAXED);
                                    drop_accepted = true;
                                }
                            } catch (Error e) {
                                warning ("Could not retrieve valid uri");
                                drop_accepted = false;
                            }
                        }
                    );
                }
            }

            return true;
        });
        drop_target.enter.connect ((x, y) => {
            var dragged_row = (BookmarkRow)list_box.get_data<BookmarkRow> ("dragged-row");
            if (dragged_row != null) {
                return Gdk.DragAction.LINK;
            } else {
                return Gdk.DragAction.COPY;
            }
        });
        drop_target.leave.connect (() => {
            drop_accepted = false;
            if (current_drop_target != null) {
                current_drop_target.reveal_drop_target (false);
                current_drop_target = null;
            }
        });
        drop_target.motion.connect ((x, y) => {
            if (!drop_accepted) {
                return 0;
            }

            var widget = pick (x, y, Gtk.PickFlags.DEFAULT);
            var row = widget.get_ancestor (typeof (BookmarkRow));
            if (row != null && (row is BookmarkRow)) {
                var bm = ((BookmarkRow)row);
                if (current_drop_target != bm) {
                    current_drop_target.reveal_drop_target (false);
                    current_drop_target = bm;
                }

                Graphene.Point bm_point;
                list_box.compute_point (bm, {(float)x, (float)y}, out bm_point);
                //TODO Avoid hard coded threshold values
                if (bm_point.y > 16) {
                    bm.reveal_drop_target (true);
                } else {
                    bm.reveal_drop_target (false);
                }

                if (bm.can_accept_drops) {
                    var dragged_row = (BookmarkRow)list_box.get_data<BookmarkRow> ("dragged-row");
                    if (dragged_row != null) {
                        return Gdk.DragAction.LINK;
                    } else {
                        return Gdk.DragAction.COPY;
                    }
                }
            }

            return 0;
        });
        drop_target.on_drop.connect ((val, x, y) => {
            warning ("on drop");
            bool accepted = false;
            var dragged_row = (BookmarkRow)list_box.get_data<BookmarkRow> ("dragged-row");
            var dragged_uri = val.get_string (); //This has already been checked as valid
            warning ("dragged_uri %s", dragged_uri);
            if (current_drop_target != null) {
                if (current_drop_target.drop_target_revealed ()) {
                    if (dragged_row != null) {
                        move_item_after (dragged_row, current_drop_target.get_index ());
                        accepted = true;
                    } else {
                        warning ("dragged uri");
                        add_favorite (dragged_uri, "", current_drop_target.get_index () + 1);
                        accepted = true;
                    }
                } else {
                    //Dropping row onto another row not supported
                    warning ("dropping onto %s", current_drop_target.display_name);
                    if (dragged_row != null) {
                        warning ("dragged row");
                    } else {
                        warning ("dragged uri");
                    }
                }
            }

            drop_accepted = false;
            if (current_drop_target != null) {
                current_drop_target.reveal_drop_target (false);
                current_drop_target = null;
            }

            return accepted;
        });

    }

    public void remove_item (SidebarItemInterface item, bool force) {
        if (!item.permanent || force) {
            bookmark_list.delete_items_with_uri (item.uri);
            list_box.remove (item);
            item.destroy_item ();
        }
    }

    public SidebarItemInterface? add_bookmark (string label,
                                               string uri,
                                               Icon gicon,
                                               bool pinned = false,
                                               bool permanent = false) {

        return insert_bookmark (label, uri, gicon, -1, pinned, permanent);
    }

    private SidebarItemInterface? insert_bookmark (string label,
                                                   string uri,
                                                   Icon gicon,
                                                   int index,
                                                   bool pinned = false,
                                                   bool permanent = false) {

        if (has_uri (uri, null)) { //Should duplicate uris be allowed? Or duplicate labels forbidden?
            return null;
        }

        var row = new BookmarkRow (label, uri, gicon, this, pinned, permanent);
        if (index >= 0) {
            list_box.insert (row, index);
        } else {
            list_box.append (row);
        }

        return row;
    }

    public override uint32 add_plugin_item (Files.SidebarPluginItem plugin_item) {
        var row = add_bookmark (plugin_item.name,
                                plugin_item.uri,
                                plugin_item.icon,
                                true,
                                true);

        row.update_plugin_data (plugin_item);
        return row.id;
    }


    public void select_item (SidebarItemInterface? item) {
        if (item != null && item is BookmarkRow) {
            list_box.select_row ((BookmarkRow)item);
        } else {
            unselect_all_items ();
        }
    }

    public void unselect_all_items () {
        list_box.unselect_all ();
    }

    public void refresh () {
        clear_list ();
        SidebarItemInterface? row;
        var home_uri = "";
        try {
            home_uri = GLib.Filename.to_uri (PF.UserUtils.get_real_user_home (), null);
        }
        catch (ConvertError e) {}
        if (home_uri != "") {
            row = add_bookmark (
                _("Home"),
                home_uri,
                new ThemedIcon (Files.ICON_HOME),
                true,
                true
            );

            row.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>Home"}, _("View the home folder"))
            );

            row.can_insert_before = false;
            row.can_insert_after = false;
        }

        if (Files.FileUtils.protocol_is_supported ("recent")) {
            row = add_bookmark (
                _(Files.PROTOCOL_NAME_RECENT),
                Files.RECENT_URI,
                new ThemedIcon (Files.ICON_RECENT),
                true,
                true
            );

            row.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>R"}, _("View the list of recently used files"))
            );

            row.can_insert_before = false;
            row.can_insert_after = true;
            ((BookmarkRow)row).can_accept_drops = false;
        }

        foreach (unowned Files.Bookmark bm in bookmark_list.list) {
            row = add_bookmark (bm.custom_name, bm.uri, bm.get_icon ());
            row.set_tooltip_text (Files.FileUtils.sanitize_path (bm.uri, null, false));
            row.notify["custom-name"].connect (() => {
                bm.custom_name = row.custom_name;
            });
        }

        if (!Files.is_admin ()) {
            row = add_bookmark (
                _("Trash"),
                _(Files.TRASH_URI),
                trash_monitor.get_icon (),
                true,
                true
            );

            row.set_tooltip_markup (
                Granite.markup_accel_tooltip ({"<Alt>T"}, _("Open the Trash"))
            );

            row.can_insert_before = true;
            row.can_insert_after = false;

            trash_monitor.notify["is-empty"].connect (() => {
                row.update_icon (trash_monitor.get_icon ());
            });
        }
    }

    public virtual void rename_bookmark_by_uri (string uri, string new_name) {
        bookmark_list.rename_item_with_uri (uri, new_name);
    }

    public override bool add_favorite (string uri,
                                       string custom_name = "",
                                       int pos = 0) {

        int pinned = 0; // Assume pinned items only at start and end of list
        int index = 0;
        var row = list_box.get_row_at_index (index);
        while (row != null && ((SidebarItemInterface)row).pinned) {
            pinned++;
            index++;
            row = list_box.get_row_at_index (index);
        }

        // pinned now index of row after last pinned item
        if (pos < pinned) {
            pos = pinned;
        }

        //Bookmark list does not include pinned items like Home and Recent
        var bm = bookmark_list.insert_uri (uri, pos - pinned, custom_name); //Assume non_builtin items are not pinned
        if (bm != null) {
            insert_bookmark (bm.custom_name, bm.uri, bm.get_icon (), pos);
            return true;
        } else {
            return false;
        }
    }

    public override bool move_item_after (SidebarItemInterface item, int target_index) {
        if (item.list != this) { // Only move within one list atm
            return false;
        }

        var old_index = item.get_index ();
        if (old_index == target_index) {
            return false;
        }

        list_box.remove (item);

        if (old_index > target_index) {
            list_box.insert (item, ++target_index);
        } else {
            list_box.insert (item, target_index);
        }

        bookmark_list.move_item_uri (item.uri, target_index - old_index);

        return true;
    }

    public virtual bool is_drop_target () { return true; }
}
