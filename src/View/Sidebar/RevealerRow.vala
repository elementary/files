/* RevealerRow.vala
 *
 * Copyright 2022 elementary LLC. <https://elementary.io>
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

public class Sidebar.RevealerRow : Gtk.ListBoxRow {
    public Sidebar.SidebarItemInterface parent_row { get; construct; }
    public Gtk.Revealer drop_revealer { get; construct; }

    // Drag and drop support
    private List<GLib.File> drop_file_list = null;
    private string? drop_text = null;
    private bool drop_occurred = false;
    private Gdk.DragAction? current_suggested_action = Gdk.DragAction.DEFAULT;
    static Gtk.TargetEntry[] dest_targets = {
        {"text/uri-list", Gtk.TargetFlags.SAME_APP, Files.TargetType.TEXT_URI_LIST},
        {"text/plain", Gtk.TargetFlags.SAME_APP, Files.TargetType.BOOKMARK_ROW},
    };
    public RevealerRow (Sidebar.SidebarItemInterface row) {
        Object (
            parent_row: row
        );

    }

    construct {
        margin = 0;
        selectable = false;
        activatable = false;
        sensitive = false;

        var drop_revealer_child = new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
            margin_top = 6,
            margin_bottom = 6
        };
        drop_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_UP
        };
        drop_revealer.add (drop_revealer_child);
        drop_revealer.reveal_child = false;
        add (drop_revealer);

        // Set up as drag destination
        Gtk.drag_dest_set (
            this,
            Gtk.DestDefaults.MOTION | Gtk.DestDefaults.HIGHLIGHT,
            dest_targets,
            Gdk.DragAction.LINK | Gdk.DragAction.MOVE
        );

        drag_data_received.connect ((ctx, x, y, sel_data, info, time) => {
            drop_text = null;
            // Extract the require text from info and convert to file list if appropriate
            switch (info) {
                case Files.TargetType.BOOKMARK_ROW:
                    drop_text = sel_data.get_text ();
                    break;

                case Files.TargetType.TEXT_URI_LIST:
                    if (!Files.DndHandler.selection_data_is_uri_list (sel_data, info, out drop_text)) {
                        warning ("sel data not uri list");
                        drop_text = null;
                    } else {
                        drop_file_list = Files.FileUtils.files_from_uris (drop_text);
                    }

                    break;

                default:
                    return;
            }

            if (drop_occurred) {
                var success = false;
                switch (info) {
                    case Files.TargetType.BOOKMARK_ROW:
                        success = process_dropped_row (ctx, drop_text);
                        break;

                    case Files.TargetType.TEXT_URI_LIST:
                        success = process_dropped_uris (ctx, drop_file_list);
                        break;

                    default:
                        break;
                }

                /* Signal source to cleanup after drag */
                Gtk.drag_finish (ctx, success, false, time);
                reset_drag_drop ();
            }
        });

        /* Handle motion over a potential drop target, update current suggested action */
        drag_motion.connect ((ctx, x, y, time) => {
            var target = Gtk.drag_dest_find_target (this, ctx, null);
            if (drop_text == null) {
                if (target != Gdk.Atom.NONE) {
                    Gtk.drag_get_data (this, ctx, target, time);
                }

                return true;
            }

            current_suggested_action = Gdk.DragAction.DEFAULT;

            switch (target.name ()) {
                case "text/plain": // dragging a row
                    drop_revealer.reveal_child = true;
                    current_suggested_action = Gdk.DragAction.LINK; //A bookmark is effectively a link
                case "text/uri-list": // File(s) being dragged
                    drop_revealer.reveal_child = (drop_file_list != null && drop_file_list.next == null);
                    if (drop_revealer.reveal_child) {
                        current_suggested_action = Gdk.DragAction.LINK;
                    }
                    break;

                default:
                    break;
            }

            Gdk.drag_status (ctx, current_suggested_action, time);
            return true;
        });

        drag_leave.connect (() => {
            reset_drag_drop ();
        });

        drag_drop.connect ((ctx, x, y, time) => {
            var target = Gtk.drag_dest_find_target (this, ctx, null);
            if (target != Gdk.Atom.NONE) {
            /* Source info obtained during `drag_motion` is cleared in `drag_leave` (which occurs first)
             * so we have to get it again.  The drop is actioned in `drag_data_received` when `drop_occurred`
             * is set to true */
                drop_occurred = true;
                Gtk.drag_get_data (this, ctx, target, time);
            } else {
                return false; // Indicate not a valid drop site
            }

            return true;
        });

        show_all ();
    }

    private bool process_dropped_row (Gdk.DragContext ctx, string drop_text) {
        var id = (uint32)(uint.parse (drop_text));
        var item = SidebarItemInterface.get_item (id);

        if (item == null || item.list != parent_row.list ) {
            return false;
        }

        parent_row.list.move_item_before (item, parent_row); // List takes care of saving changes
        return true;
    }

    private bool process_dropped_uris (Gdk.DragContext ctx,
                                       List<GLib.File> drop_file_list) {

        assert (drop_file_list.next == null);
        return parent_row.list.add_favorite (drop_file_list.data.get_uri (), "", parent_row);
    }

    private void reset_drag_drop () {
        drop_file_list = null;
        drop_text = null;
        drop_occurred = false;
        current_suggested_action = Gdk.DragAction.DEFAULT;
        drop_revealer.reveal_child = false;
    }
}
