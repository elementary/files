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

     //TODO Rework DnD for Gtk4
    // static Gtk.TargetEntry[] source_targets = {
    //     {"text/plain", Gtk.TargetFlags.SAME_APP, Files.TargetType.BOOKMARK_ROW}
    // };

    // /* Targets accepted when dropped onto movable BookmarkRow
    //  * Either BookmarkRow id as text or a list of uris as text is accepted at the moment
    //  * Depending on where it is dropped (edge or middle) it will either be used to create a
    //  * new bookmark or to initiate a file operation with the bookmark uri as target  */
    // static Gtk.TargetEntry[] dest_targets = {
    //     {"text/uri-list", Gtk.TargetFlags.SAME_APP, Files.TargetType.TEXT_URI_LIST},
    //     {"text/plain", Gtk.TargetFlags.SAME_APP, Files.TargetType.BOOKMARK_ROW},
    // };

    // static Gdk.Atom text_data_atom = Gdk.Atom.intern_static_string ("text/plain");

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
    public bool can_accept_drops { get; set; default = true; }
    private Files.File target_file;
    private List<GLib.File> drop_file_list = null;
    private string? drop_text = null;
    private bool drop_occurred = false;
    private Gdk.DragAction? current_suggested_action = null;
    private bool is_renaming = false;

    protected Gtk.Grid content_grid;
    protected Gtk.Box icon_label_box;
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
    public bool pinned { get; construct; } // Cannot be dragged
    public bool permanent { get; construct; } // Cannot be removed
    public bool can_insert_before { get; set; default = true; }
    public bool can_insert_after { get; set; default = true; }

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

        label = new Gtk.Label (display_name) {
            xalign = 0.0f,
            halign = Gtk.Align.START,
            hexpand = true,
            ellipsize = Pango.EllipsizeMode.END
        };

        label_stack = new Gtk.Stack ();
        label_stack.add_named (label, "label");

        if (!pinned) {
            editable = new Gtk.Entry ();
            label_stack.add_named (editable, "editable");
            editable.activate.connect (() => {
                if (custom_name != editable.text) {
                    custom_name = editable.text;
                    list.rename_bookmark_by_uri (uri, custom_name);
                    cancel_rename ();
                }
            });

            var focus_controller = new Gtk.EventControllerFocus ();
            editable.add_controller (focus_controller);
            focus_controller.leave.connect (() => {
                if (is_renaming) {
                    cancel_rename ();
                }
            });
        }

        label_stack.visible_child_name = "label";

        icon = new Gtk.Image.from_gicon (gicon);

        icon_label_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6); // Must be grid in order to show storage bar if required
        icon_label_box.append (icon);
        icon_label_box.append (label_stack);

        content_grid = new Gtk.Grid ();
        content_grid.attach (icon_label_box, 0, 0);

        set_child (content_grid);

        var secondary_click_controller = new Gtk.GestureClick ();
        secondary_click_controller.set_button (Gdk.BUTTON_SECONDARY);
        secondary_click_controller.released.connect ((n_press, x, y) => {
            if (n_press == 1) {
                popup_context_menu ();
            }
        });

        add_controller (secondary_click_controller);
        //TODO Use EventControllers
        // key_press_event.connect (on_key_press_event);
        // button_release_event.connect_after (after_button_release_event);

        notify["gicon"].connect (() => {
            icon.set_from_gicon (gicon);
        });

        notify["custom-name"].connect (() => {
            label.label = display_name;
        });

        var drop_revealer_child = new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
            margin_top = 12,
            margin_bottom = 0
        };

        drop_revealer = new Gtk.Revealer () {
            transition_type = Gtk.RevealerTransitionType.SLIDE_UP
        };
        drop_revealer.set_child (drop_revealer_child);

        content_grid.attach (drop_revealer, 0, 1);
    }

    protected override void update_plugin_data (Files.SidebarPluginItem item) {
        custom_name = item.name;
        uri = item.uri;
        update_icon (item.icon);
        menu_model = item.menu_model;
        action_group = item.action_group;
        action_group_namespace = item.action_group_namespace;
    }

    public void start_renaming () {
        if (!pinned) {
            label_stack.visible_child_name = "editable";
            editable.grab_focus ();
            //Need to idle so that spurious editable focus-leave event is ignored :(
            Idle.add (() => {
                is_renaming = true;
                return Source.REMOVE;
            });
            editable.text = display_name;
        }
    }

    protected void cancel_rename () {
        label_stack.visible_child_name = "label";
        is_renaming = false;
        grab_focus ();
    }

    //TODO Use EventControllers
    // protected virtual bool on_key_press_event (Gdk.EventKey event) {
    //     uint keyval;
    //     event.get_keyval (out keyval);
    //     switch (keyval) {
    //         case Gdk.Key.F2:
    //             rename ();
    //             return true;

    //         case Gdk.Key.Escape:
    //             cancel_rename ();
    //             return true;

    //         default:
    //             break;
    //     }
    //     return false;
    // }

    // protected virtual bool after_button_release_event (Gdk.EventButton event) {
    //     if (!valid) { //Ignore if in the process of being removed
    //         return true;
    //     }

    //     if (label_stack.visible_child_name == "editable") { //Do not interfere with renaming
    //         return false;
    //     }

    //     Gdk.ModifierType state;
    //     event.get_state (out state);
    //     var mods = state & Gtk.accelerator_get_default_mod_mask ();
    //     var control_pressed = ((mods & Gdk.ModifierType.CONTROL_MASK) != 0);
    //     var other_mod_pressed = (((mods & ~Gdk.ModifierType.SHIFT_MASK) & ~Gdk.ModifierType.CONTROL_MASK) != 0);
    //     var only_control_pressed = control_pressed && !other_mod_pressed; /* Shift can be pressed */

    //     uint button;
    //     event.get_button (out button);
    //     switch (button) {
    //         case Gdk.BUTTON_PRIMARY:
    //             if (only_control_pressed) {
    //                 activated (Files.OpenFlag.NEW_TAB);
    //                 return true;
    //             } else {
    //                 return false;
    //             }

    //         case Gdk.BUTTON_SECONDARY:
    //             popup_context_menu (event);
    //             return true;

    //         case Gdk.BUTTON_MIDDLE:
    //             activated (Files.OpenFlag.NEW_TAB);
    //             return true;

    //         default:
    //             return false;
    //     }
    // }

    protected virtual void popup_context_menu () {
        Gtk.PopoverMenu popover;
        if (menu_model != null) {
            popover = new Gtk.PopoverMenu.from_model (menu_model);
        } else {
            var menu_builder = new PopupMenuBuilder ()
                .add_open (Action.print_detailed_name ("bm.open-bookmark", new Variant.uint32 (id)))
                .add_open_tab (Action.print_detailed_name ("bm.open-tab", new Variant.uint32 (id)))
                .add_open_window (Action.print_detailed_name ("bm.open-window", new Variant.uint32 (id)));

            if (!permanent || !pinned) {
                menu_builder.add_separator ();
            }

            if (!permanent) {
                menu_builder.add_remove (Action.print_detailed_name ("bm.remove-bookmark", new Variant.uint32 (id)));
            }

            if (!pinned) {
                menu_builder.add_rename (Action.print_detailed_name ("bm.rename-bookmark", new Variant.uint32 (id)));
            }

            menu_builder.add_separator ();
            add_extra_menu_items (menu_builder);

            popover = menu_builder.build ();
        }

        popover.set_parent (this);
        popover.position = Gtk.PositionType.RIGHT;
        popover.popup ();
    }

    protected override void add_extra_menu_items (PopupMenuBuilder menu_builder) {
    // /* Rows under "Bookmarks" can be removed or renamed */
        // if (!permanent) {
        //     menu_builder
        //         .add_separator ()
        //         .add_remove (
        //             Action.print_detailed_name ("bm.remove-bookmark", new Variant.uint32 (id))
        //     );
        // }



    //     if (Uri.parse_scheme (uri) == "trash") {
    //         menu_builder
    //             .add_separator ()
    //             .add_empty_all_trash (() => {
    //                 new Files.FileOperations.EmptyTrashJob (
    //                     (Gtk.Window)get_ancestor (typeof (Gtk.Window)
    //                 )).empty_trash.begin ();
    //             })
    //         ;
    //     }
    }

    /* DRAG DROP IMPLEMENTATION */
    // private void set_up_drag () {
    //     if (pinned) { //Pinned items cannot be dragged
    //         return;
    //     }
    //     /*Set up as Drag Source*/
    //     Gtk.drag_source_set (
    //         this,
    //         Gdk.ModifierType.BUTTON1_MASK,
    //         source_targets,
    //         Gdk.DragAction.MOVE
    //     );

    //     drag_begin.connect ((ctx) => {
    //         /* Make an image of this row on a new surface */
    //         Gtk.Allocation alloc;
    //         get_allocation (out alloc);
    //         var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, alloc.width, alloc.height);
    //         var cr = new Cairo.Context (surface);
    //         draw (cr);
    //         /* Make drag image semi-transparent (painting on cr does not work) */
    //         var surface2 = new Cairo.ImageSurface (Cairo.Format.ARGB32, alloc.width, alloc.height);
    //         var cr2 = new Cairo.Context (surface2);
    //         cr2.set_source_surface (cr.get_target (), 0, 1);
    //         cr2.set_operator (Cairo.Operator.OVER);
    //         cr2.paint_with_alpha (0.5);

    //         /* Make drag image coincide with dragged row at start */
    //         var device = Gtk.get_current_event_device ();
    //         int x, y;
    //         Gdk.ModifierType mask;
    //         get_window ().get_device_position (device, out x, out y, out mask);
    //         surface2.set_device_offset (-x, 0);
    //         /* Set the drag icon to an image of this row */
    //         Gtk.drag_set_icon_surface (ctx, surface2);
    //     });

    //     /* Pass the item id as selection data by converting to string.*/
    //     //TODO There may be a more elegant method of passing a pointer to `this` directly.
    //     drag_data_get.connect ((ctx, sel_data, info, time) => {
    //         uint8[] data = id.to_string ().data;
    //         sel_data.@set (text_data_atom, 8, data);
    //     });

    //     drag_failed.connect ((ctx, res) => {
    //         if (res == Gtk.DragResult.NO_TARGET) {
    //             Gdk.Window app_window = list.get_window ().get_effective_toplevel ();
    //             Gdk.Window drag_window = ctx.get_drag_window ();
    //             Gdk.Rectangle app_rect, drag_rect, intersect_rect;

    //             app_window.get_frame_extents (out app_rect);
    //             drag_window.get_frame_extents (out drag_rect);

    //             if (!drag_rect.intersect (app_rect, out intersect_rect)) {
    //                 list.remove_item_by_id (id);
    //                 var device = ctx.get_device ();
    //                 int x, y;
    //                 device.get_position (null, out x, out y);
    //                 Plank.PoofWindow poof_window;
    //                 poof_window = Plank.PoofWindow.get_default ();
    //                 poof_window.show_at (x, y);
    //                 return true;
    //             }
    //         }

    //         return false;
    //     });

    //     drag_end.connect ((ctx) => {
    //         reset_drag_drop ();
    //     });
    // }

    // /* Set up as a drag destination. */
    // private void set_up_drop () {
    //     var drop_revealer_child = new Gtk.Separator (Gtk.Orientation.HORIZONTAL) {
    //         margin_top = 12,
    //         margin_bottom = 0
    //     };

    //     drop_revealer = new Gtk.Revealer () {
    //         transition_type = Gtk.RevealerTransitionType.SLIDE_UP
    //     };
    //     drop_revealer.set_child (drop_revealer_child);

    //     content_grid.attach (drop_revealer, 0, 1);

    //     Gtk.drag_dest_set (
    //         this,
    //         Gtk.DestDefaults.MOTION | Gtk.DestDefaults.HIGHLIGHT,
    //         dest_targets,
    //         Gdk.DragAction.MOVE | Gdk.DragAction.COPY | Gdk.DragAction.LINK | Gdk.DragAction.ASK
    //     );

    //     drag_data_received.connect ((ctx, x, y, sel_data, info, time) => {
    //         drop_text = null;
    //         // Extract the require text from info and convert to file list if appropriate
    //         switch (info) {
    //             case Files.TargetType.BOOKMARK_ROW:
    //                 drop_text = sel_data.get_text ();
    //                 break;

    //             case Files.TargetType.TEXT_URI_LIST:
    //                 if (!Files.DndHandler.get_default ().selection_data_is_uri_list (sel_data, info, out drop_text)) {
    //                     warning ("sel data not uri list");
    //                     drop_text = null;
    //                 } else {
    //                     drop_file_list = Files.FileUtils.files_from_uris (drop_text);
    //                 }

    //                 break;

    //             default:
    //                 return;
    //         }

    //         if (drop_occurred) {
    //             var success = false;
    //             switch (info) {
    //                 case Files.TargetType.BOOKMARK_ROW:
    //                     success = process_dropped_row (ctx, drop_text, drop_revealer.child_revealed);
    //                     break;

    //                 case Files.TargetType.TEXT_URI_LIST:
    //                     success = process_dropped_uris (ctx, drop_file_list, drop_revealer.child_revealed);
    //                     break;
    //             }

    //             /* Signal source to cleanup after drag */
    //             Gtk.drag_finish (ctx, success, false, time);
    //             reset_drag_drop ();
    //         }
    //     });

    //     /* Handle motion over a potential drop target, update current suggested action */
    //     drag_motion.connect ((ctx, x, y, time) => {
    //         var target = Gtk.drag_dest_find_target (this, ctx, null);
    //         if (drop_text == null) {
    //             if (target != Gdk.Atom.NONE) {
    //                 Gtk.drag_get_data (this, ctx, target, time);
    //             }

    //             return true;
    //         }

    //         var pos = get_index ();
    //         var previous_item = (BookmarkRow?)(list.get_item_at_index (pos - 1));
    //         var next_item = (BookmarkRow?)(list.get_item_at_index (pos + 1));

    //         if (previous_item != null) {
    //             previous_item.reveal_drop_target (false);
    //         }

    //         var row_height = icon_label_box.get_allocated_height ();
    //         bool reveal = false;

    //         current_suggested_action = Gdk.DragAction.DEFAULT;
    //         switch (target.name ()) {
    //             case "text/plain":
    //                 reveal = can_insert_after &&
    //                          (next_item == null || next_item.can_insert_before) &&
    //                           y > row_height / 2;

    //                 break;

    //             case "text/uri-list": // File(s) being dragged
    //                 reveal = can_insert_after &&
    //                          (next_item == null || next_item.can_insert_before) &&
    //                           y > row_height - 1;

    //                 // When dropping onto a row, determine what actions are possible
    //                 if (!reveal && drop_file_list != null) {
    //                     Files.FileUtils.file_accepts_drop (
    //                         target_file,
    //                         drop_file_list, ctx,
    //                         out current_suggested_action
    //                     );

    //                     if (current_suggested_action != Gdk.DragAction.DEFAULT) {
    //                         highlight (true);
    //                     }
    //                 } else {
    //                     highlight (false);
    //                 }

    //                 break;
    //             default:
    //                 break;
    //         }

    //         if (reveal_drop_target (reveal)) {
    //             current_suggested_action = Gdk.DragAction.LINK; //A bookmark is effectively a link
    //             if (target.name () == "text/uri-list" && drop_text != null &&
    //                 list.has_uri (drop_text.strip ())) { //Need to remove trailing newline

    //                 current_suggested_action = Gdk.DragAction.DEFAULT; //Do not allowing dropping duplicate URI
    //                 reveal = false;
    //             }
    //         }

    //         Gdk.drag_status (ctx, current_suggested_action, time);
    //         return true;
    //     });

    //     drag_leave.connect (() => {
    //         reset_drag_drop ();
    //     });

    //     drag_drop.connect ((ctx, x, y, time) => {
    //         var target = Gtk.drag_dest_find_target (this, ctx, null);
    //         if (target != Gdk.Atom.NONE) {
    //         /* Source info obtained during `drag_motion` is cleared in `drag_leave` (which occurs first)
    //          * so we have to get it again.  The drop is actioned in `drag_data_received` when `drop_occurred`
    //          * is set to true */
    //             drop_occurred = true;
    //             Gtk.drag_get_data (this, ctx, target, time);
    //         } else {
    //             return false; // Indicate not a valid drop site
    //         }

    //         return true;
    //     });
    // }

    // protected void highlight (bool show) {
    //     if (show && !get_style_context ().has_class (Gtk.STYLE_CLASS_HIGHLIGHT)) {
    //         get_style_context ().add_class (Gtk.STYLE_CLASS_HIGHLIGHT);
    //     } else if (!show && get_style_context ().has_class (Gtk.STYLE_CLASS_HIGHLIGHT)) {
    //         get_style_context ().remove_class (Gtk.STYLE_CLASS_HIGHLIGHT);
    //     }
    // }

    // private void reset_drag_drop () {
    //     drop_file_list = null;
    //     drop_text = null;
    //     drop_occurred = false;
    //     current_suggested_action = Gdk.DragAction.DEFAULT;
    //     reveal_drop_target (false);
    //     highlight (false);
    // }

    // private bool process_dropped_row (Gdk.Drag ctx, string drop_text, bool dropped_between) {
    //     var id = (uint32)(uint.parse (drop_text));
    //     var item = SidebarItemInterface.get_item_by_id (id);

    //     if (item == null ||
    //         !dropped_between ||
    //         item.list != list) { //Cannot drop on self or different list

    //         return false;
    //     }

    //     list.move_item_after (item, get_index ()); // List takes care of saving changes
    //     return true;
    // }

    // private bool process_dropped_uris (Gdk.Drag ctx,
    //                                    List<GLib.File> drop_file_list,
    //                                    bool dropped_between) {

    //     if (dropped_between && drop_file_list.next == null) { //Only create one new bookmark at a time
    //         var pos = get_index ();
    //         pos++;
    //         return list.add_favorite (drop_file_list.data.get_uri (), "", pos);
    //     } else {
    //         var dnd_handler = Files.DndHandler.get_default ();
    //         var real_action = ctx.get_selected_action ();

    //         if (real_action == Gdk.DragAction.ASK) {
    //             var actions = ctx.get_actions ();

    //             if (uri.has_prefix ("trash://")) {
    //                 actions &= Gdk.DragAction.MOVE;
    //             }

    //             real_action = dnd_handler.drag_drop_action_ask (
    //                 this,
    //                 actions
    //             );
    //         }

    //         if (real_action == 0) {
    //             return false;
    //         }

    //         dnd_handler.dnd_perform (
    //             this,
    //             target_file,
    //             drop_file_list,
    //             real_action
    //         );

    //         return true;
    //     }
    // }

    public void reveal_drop_target (bool reveal) {
        // if (list.is_drop_target ()) {
            drop_revealer.reveal_child = reveal;
        //     return reveal;
        // } else {
        //     return false; //Suppress dropping between rows (e.g. for Storage list)
        // }
    }

    public bool drop_target_revealed () {
        return drop_revealer.reveal_child;
    }
}
