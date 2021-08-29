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
    /* Targets available from BookmarkRow when it is the dragged
     * Just the row ID as text at the moment
     */
    static Gtk.TargetEntry[] source_targets = {
        {"text/plain", Gtk.TargetFlags.SAME_APP, Files.TargetType.BOOKMARK_ROW}
    };

    /* Targets accepted when dropped onto movable BookmarkRow
     * Either BookmarkRow id as text or a list of uris as text is accepted at the moment
     * Depending on where it is dropped (edge or middle) it will either be used to create a
     * new bookmark or to initiate a file operation with the bookmark uri as target  */
    static Gtk.TargetEntry[] dest_targets = {
        {"text/uri-list", Gtk.TargetFlags.SAME_APP, Files.TargetType.TEXT_URI_LIST},
        {"text/plain", Gtk.TargetFlags.SAME_APP, Files.TargetType.BOOKMARK_ROW},
    };

    /* Pinned bookmarks can accept uri lists but not rows */
    static Gtk.TargetEntry[] pinned_targets = {
        {"text/uri-list", Gtk.TargetFlags.SAME_APP, Files.TargetType.TEXT_URI_LIST}
    };

    static Gdk.Atom text_data_atom = Gdk.Atom.intern_static_string ("text/plain");

    /* Each row gets a unique id.  The methods relating to this are in the SidebarItemInterface */
    static construct {
        SidebarItemInterface.row_id = new Rand.with_seed (
            int.parse (get_real_time ().to_string ())
        ).next_int ();

        SidebarItemInterface.item_map_lock = Mutex ();
        SidebarItemInterface.item_id_map = new Gee.HashMap<uint32, SidebarItemInterface> ();
    }

    private bool valid = true; //Set to false if scheduled for removal
    private Gtk.Image icon;
    private Files.File target_file;
    private List<GLib.File> drop_file_list = null;
    private string? drop_text = null;
    private bool drop_occurred = false;
    private Gdk.DragAction? current_suggested_action = Gdk.DragAction.DEFAULT;

    protected Gtk.Grid content_grid;
    protected Gtk.Grid icon_label_grid;
    protected Gtk.Stack label_stack;
    protected Gtk.Entry editable;
    protected Gtk.Label label;
    protected Gtk.Revealer drop_revealer;

    public string custom_name { get; set; default = "";}
    public string display_name {
        get {
            if (custom_name.strip () != "") {
                return custom_name;
            } else {
                return target_file.get_display_name ();
            }
        }
    }

    public SidebarListInterface list { get; construct; }
    public uint32 id { get; construct; }
    public string uri { get; set construct; }
    public Icon gicon { get; set construct; }
    public bool pinned { get; construct; default = false;}
    public bool permanent { get; construct; default = false;}

    public MenuModel? menu_model {get; set; default = null;}
    public ActionGroup? action_group {get; set; default = null;}
    public string? action_group_namespace { get; set; default = null;}

    public BookmarkRow (string _custom_name,
                        string uri,
                        Icon gicon,
                        SidebarListInterface list,
                        bool pinned,
                        bool permanent) {
        Object (
            custom_name: _custom_name,
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
        target_file = Files.File.get_by_uri (uri);
        target_file.ensure_query_info ();

        /* If put margin on the row then drag and drop does not work when over the margin so we put
         * the margin on the content grid */
        //Set a fallback tooltip to stop category tooltip appearing inappropriately
        set_tooltip_text (Files.FileUtils.sanitize_path (uri, null, false));

        selectable = true;
        id = SidebarItemInterface.get_next_item_id ();
        item_map_lock.@lock ();
        SidebarItemInterface.item_id_map.@set (id, this);
        item_map_lock.unlock ();

        var label = new Gtk.Label (display_name) {
            xalign = 0.0f,
            halign = Gtk.Align.START,
            hexpand = true,
            ellipsize = Pango.EllipsizeMode.END
        };

        label_stack = new Gtk.Stack () {
            homogeneous = false
        };
        label_stack.add_named (label, "label");

        if (!pinned) {
            editable = new Gtk.Entry ();
            label_stack.add_named (editable, "editable");
            editable.activate.connect (() => {
                if (custom_name != editable.text) {
                    custom_name = editable.text;
                    list.rename_bookmark_by_uri (uri, custom_name);
                }
                label_stack.visible_child_name = "label";
            });

            editable.focus_out_event.connect (() =>{
                label_stack.visible_child_name = "label";
            });
        }
        label_stack.visible_child_name = "label";

        icon = new Gtk.Image.from_gicon (gicon, Gtk.IconSize.MENU);

        icon_label_grid = new Gtk.Grid () {
            column_spacing = 6
        };
        icon_label_grid.attach (icon, 0, 0, 1, 2);
        icon_label_grid.add (label_stack);

        var event_box = new Gtk.EventBox () {
            above_child = false
        };
        event_box.add (icon_label_grid);

        content_grid = new Gtk.Grid ();
        content_grid.attach (event_box, 0, 0);

        add (content_grid);
        show_all ();

        key_press_event.connect (on_key_press_event);
        button_release_event.connect_after (after_button_release_event);

        notify["gicon"].connect (() => {
            icon.set_from_gicon (gicon, Gtk.IconSize.MENU);
        });

        notify["custom-name"].connect (() => {
            label.label = display_name;
        });
    }

    protected override void update_plugin_data (Files.SidebarPluginItem item) {
        custom_name = item.name;
        uri = item.uri;
        update_icon (item.icon);
        menu_model = item.menu_model;
        action_group = item.action_group;
        action_group_namespace = item.action_group_namespace;
    }

    private void rename () {
        if (!pinned) {
            editable.text = display_name;
            label_stack.visible_child_name = "editable";
            editable.grab_focus ();
        }
    }

    protected void cancel_rename () {
        label_stack.visible_child_name = "label";
        grab_focus ();
    }

    public void destroy_bookmark () {
        /* We destroy all bookmarks - even permanent ones when refreshing */
        valid = false;
        item_map_lock.@lock ();
        SidebarItemInterface.item_id_map.unset (id);
        item_map_lock.unlock ();
        base.destroy ();
    }

    protected virtual bool on_key_press_event (Gdk.EventKey event) {
        switch (event.keyval) {
            case Gdk.Key.F2:
                rename ();
                return true;

            case Gdk.Key.Escape:
                cancel_rename ();
                return true;

            default:
                break;
        }
        return false;
    }

    protected virtual bool after_button_release_event (Gdk.EventButton event) {
        if (!valid) { //Ignore if in the process of being removed
            return true;
        }

        if (label_stack.visible_child_name == "editable") { //Do not interfere with renaming
            return false;
        }

        switch (event.button) {
            case Gdk.BUTTON_SECONDARY:
                popup_context_menu (event);
                return true;

            case Gdk.BUTTON_MIDDLE:
                activated (Files.OpenFlag.NEW_TAB);
                return true;

            default:
                return false;
        }
    }

    protected void popup_context_menu (Gdk.EventButton event) {
        var menu_builder = new PopupMenuBuilder ()
            .add_open (() => {activated ();})
            .add_separator ()
            .add_open_tab (() => {activated (Files.OpenFlag.NEW_TAB);})
            .add_open_window (() => {activated (Files.OpenFlag.NEW_WINDOW);});

        add_extra_menu_items (menu_builder);

        if (menu_model != null) {
            menu_builder
                .build_from_model (menu_model, action_group_namespace, action_group)
                .popup_at_pointer (event);
        } else {
            menu_builder
                .build ()
                .popup_at_pointer (event);
        }
    }

    protected override void add_extra_menu_items (PopupMenuBuilder menu_builder) {
    /* Rows under "Bookmarks" can be removed or renamed */
        if (!permanent) {
            menu_builder
                .add_separator ()
                .add_remove (() => {list.remove_item_by_id (id);});
        }

        if (!pinned) {
            menu_builder.add_rename (() => {
                rename ();
            });
        }

        if (Uri.parse_scheme (uri) == "trash") {
            menu_builder
                .add_separator ()
                .add_empty_all_trash (() => {
                    new Files.FileOperations.EmptyTrashJob (
                        (Gtk.Window)get_ancestor (typeof (Gtk.Window)
                    )).empty_trash.begin ();
                })
            ;
        }
    }

    /* DRAG DROP IMPLEMENTATION */
    private void set_up_drag () {
        if (pinned) { //Pinned items cannot be dragged
            return;
        }
        /*Set up as Drag Source*/
        Gtk.drag_source_set (
            this,
            Gdk.ModifierType.BUTTON1_MASK,
            source_targets,
            Gdk.DragAction.MOVE
        );

        drag_begin.connect ((ctx) => {
            /* Make an image of this row on a new surface */
            Gtk.Allocation alloc;
            get_allocation (out alloc);
            var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, alloc.width, alloc.height);
            var cr = new Cairo.Context (surface);
            draw (cr);
            /* Make drag image semi-transparent (painting on cr does not work) */
            var surface2 = new Cairo.ImageSurface (Cairo.Format.ARGB32, alloc.width, alloc.height);
            var cr2 = new Cairo.Context (surface2);
            cr2.set_source_surface (cr.get_target (), 0, 1);
            cr2.set_operator (Cairo.Operator.OVER);
            cr2.paint_with_alpha (0.5);

            /* Make drag image coincide with dragged row at start */
            var device = Gtk.get_current_event_device ();
            int x, y;
            Gdk.ModifierType mask;
            get_window ().get_device_position (device, out x, out y, out mask);
            surface2.set_device_offset (-x, 0);
            /* Set the drag icon to an image of this row */
            Gtk.drag_set_icon_surface (ctx, surface2);
        });

        /* Pass the item id as selection data by converting to string.*/
        //TODO There may be a more elegant method of passing a pointer to `this` directly.
        drag_data_get.connect ((ctx, sel_data, info, time) => {
            uint8[] data = id.to_string ().data;
            sel_data.@set (text_data_atom, 8, data);
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

        drag_end.connect ((ctx) => {
            reset_drag_drop ();
        });
    }

    /* Set up as a drag destination. */
    private void set_up_drop () {
        var drop_revealer_child = new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
            margin_top = 12,
            margin_bottom = 0
        };

        drop_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_UP
        };
        drop_revealer.add (drop_revealer_child);
        drop_revealer.show_all ();

        content_grid.attach (drop_revealer, 0, 1);

        Gtk.drag_dest_set (
            this,
            Gtk.DestDefaults.MOTION | Gtk.DestDefaults.HIGHLIGHT,
            pinned ? pinned_targets : dest_targets, // Cannot accept rows if pinned
            Gdk.DragAction.MOVE | Gdk.DragAction.COPY | Gdk.DragAction.LINK | Gdk.DragAction.ASK
        );

        drag_data_received.connect ((ctx, x, y, sel_data, info, time) => {
            drop_text = null;
            if (info == Files.TargetType.BOOKMARK_ROW) {
                drop_text = sel_data.get_text ();
            } else if (info == Files.TargetType.TEXT_URI_LIST) {
                if (!Files.DndHandler.selection_data_is_uri_list (sel_data, info, out drop_text)) {
                    warning ("sel data not uri list");
                    drop_text = null;
                }
            }

            if (drop_text != null &&
                info == Files.TargetType.TEXT_URI_LIST) {

                drop_file_list = Files.FileUtils.files_from_uris (drop_text);
                Files.FileUtils.file_accepts_drop (
                    target_file,
                    drop_file_list, ctx,
                    out current_suggested_action
                );
            }

            if (drop_occurred) {
                var success = false;
                switch (info) {
                    case Files.TargetType.BOOKMARK_ROW:
                        success = process_dropped_row (ctx, drop_text, drop_revealer.child_revealed);
                        break;

                    case Files.TargetType.TEXT_URI_LIST:
                        success = process_dropped_uris (ctx, drop_file_list, drop_revealer.child_revealed);
                        break;
                }

                /* Signal source to cleanup after drag */
                Gtk.drag_finish (ctx, success, false, time);
                reset_drag_drop ();
            }
        });

        /* Handle motion over a potention drop target */
        drag_motion.connect ((ctx, x, y, time) => {
            if (drop_text == null) {
                var target = Gtk.drag_dest_find_target (this, ctx, null);
                if (target != Gdk.Atom.NONE) {
                    Gtk.drag_get_data (this, ctx, target, time);
                }

                return true;
            }

            var row_height = icon_label_grid.get_allocated_height ();
            var target = Gtk.drag_dest_find_target (this, ctx, null);
            bool reveal;
            int edge_height;
            if (target.name () == "text/plain") { // Row being dragged
                edge_height = row_height / 2; //Define thickness of edges
            } else {
                edge_height = 1;
            }

            reveal = y > row_height - edge_height;

            // Set the suggested action only when revealer state changes
            if (reveal && !drop_revealer.reveal_child) {
                current_suggested_action = Gdk.DragAction.LINK; //A bookmark is effectively a link
            } else if (!reveal && drop_revealer.reveal_child &&
                       drop_text != null &&
                       target.name () == "text/uri-list") {

                if (drop_file_list == null) {
                    drop_file_list = Files.FileUtils.files_from_uris (drop_text);
                }

                Files.FileUtils.file_accepts_drop (
                    target_file,
                    drop_file_list, ctx,
                    out current_suggested_action
                );
            }

            reveal_drop_target (reveal);

            var pos = get_index ();
            if (pos > 0) {
                var previous_item = (BookmarkRow?)(list.get_item_at_index (pos - 1));
                if (previous_item != null) {
                    previous_item.reveal_drop_target (false);
                }
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
    }

    private void reset_drag_drop () {
        drop_file_list = null;
        drop_text = null;
        drop_occurred = false;
        current_suggested_action = Gdk.DragAction.DEFAULT;
        reveal_drop_target (false);
    }

    private bool process_dropped_row (Gdk.DragContext ctx, string drop_text, bool dropped_between) {
        var id = (uint32)(uint.parse (drop_text));
        var item = SidebarItemInterface.get_item (id);

        if (item == null ||
            !dropped_between ||
            item.list != list) { //Cannot drop on self or different list

            return false;
        }

        list.move_item_after (item, get_index ()); // List takes care of saving changes
        return true;
    }

    private bool process_dropped_uris (Gdk.DragContext ctx,
                                       List<GLib.File> drop_file_list,
                                       bool dropped_between) {

        if (dropped_between && // Dropped on edge
             drop_file_list.next == null && //Only create one new bookmark at a time
             !pinned) {// pinned rows cannot be moved

            var pos = get_index ();
            pos++;
            return list.add_favorite (drop_file_list.data.get_uri (), "", pos);
        } else {
            var dnd_handler = new Files.DndHandler ();
            var real_action = ctx.get_selected_action ();

            if (real_action == Gdk.DragAction.ASK) {
                var actions = ctx.get_actions ();

                if (uri.has_prefix ("trash://")) {
                    actions &= Gdk.DragAction.MOVE;
                }

                real_action = dnd_handler.drag_drop_action_ask (
                    this,
                    (Gtk.ApplicationWindow)(Files.get_active_window ()),
                    actions
                );
            }

            if (real_action == Gdk.DragAction.DEFAULT) {
                return false;
            }

            dnd_handler.dnd_perform (
                this,
                target_file,
                drop_file_list,
                real_action
            );

            return true;
        }
    }

    protected void reveal_drop_target (bool reveal) {
        if (drop_revealer.reveal_child != reveal) {
            drop_revealer.reveal_child = reveal;
        }
    }
}
