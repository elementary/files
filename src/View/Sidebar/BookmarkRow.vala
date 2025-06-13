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
 * Authors: Jeremy Wootten <jeremywootten@gmail.com>
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
    static Gdk.Atom text_data_atom = Gdk.Atom.intern_static_string ("text/plain");

    /* Each row gets a unique id.  The methods relating to this are in the SidebarItemInterface */
    static construct {
        row_id = new Rand.with_seed (
            int.parse (get_real_time ().to_string ())
        ).next_int ();

        item_map_lock = Mutex ();
        item_id_map = new Gee.HashMap<uint32, SidebarItemInterface> ();
    }

    public SidebarListInterface list { get; set construct; }
    public Icon gicon { get; set construct; }
    public string uri { get; set construct; }
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
    public uint32 id { get; set construct; }
    public bool pinned { get; set construct; } // Cannot be dragged
    public bool permanent { get; set construct; } // Cannot be removed
    public bool can_insert_before { get; set; default = true; }
    public bool can_insert_after { get; set; default = true; }
    public MenuModel? menu_model {get; set; default = null;}
    public ActionGroup? action_group {get; set; default = null;}
    public string? action_group_namespace { get; set; default = null;}

    protected Gtk.Grid content_grid;
    protected Gtk.Grid icon_label_grid;
    protected Gtk.Stack label_stack;
    protected Gtk.Entry editable;
    protected Gtk.Label label;
    protected Gtk.Revealer drop_revealer;

    private Gtk.Image icon;
    protected Files.File target_file;
    private List<GLib.File> drop_file_list = null;
    private Gdk.DragAction? current_suggested_action = Gdk.DragAction.DEFAULT;
    private Gtk.EventControllerKey key_controller;
    private Gtk.GestureMultiPress button_controller;
    private SimpleAction empty_all_trash_action;
    private string? drop_text = null;
    private bool drop_occurred = false;
    private bool valid = true; //Set to false if scheduled for removal

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
        id = get_next_item_id ();
        item_map_lock.@lock ();
        item_id_map.@set (id, this);
        item_map_lock.unlock ();

        label = new Gtk.Label (display_name) {
            xalign = 0.0f,
            halign = Gtk.Align.START,
            hexpand = true,
            ellipsize = Pango.EllipsizeMode.END
        };

        label_stack = new Gtk.Stack () {
            hhomogeneous = false,
            vhomogeneous = false
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

        content_grid = new Gtk.Grid ();
        content_grid.attach (icon_label_grid, 0, 0);

        var event_box = new Gtk.EventBox ();
        event_box.add (content_grid);
        add (event_box);
        show_all ();

        key_controller = new Gtk.EventControllerKey (this) {
            propagation_phase = CAPTURE
        };
        key_controller.key_pressed.connect (on_key_press_event);

        button_controller = new Gtk.GestureMultiPress (this) {
            propagation_phase = BUBBLE,
            button = 0
        };
        button_controller.released.connect (on_button_release_event);

        notify["gicon"].connect (() => {
            icon.set_from_gicon (gicon, Gtk.IconSize.MENU);
        });

        notify["custom-name"].connect (() => {
            label.label = display_name;
        });

        set_up_drag ();
        set_up_drop ();

        var open_action = new SimpleAction ("open", null);
        open_action.activate.connect (() => activated ());

        var open_tab_action = new SimpleAction ("open-tab", null);
        open_tab_action.activate.connect (() => activated (NEW_TAB));

        var open_window_action = new SimpleAction ("open-window", null);
        open_window_action.activate.connect (() => activated (NEW_WINDOW));

        var rename_action = new SimpleAction ("rename", null);
        rename_action.activate.connect (rename);

        var remove_action = new SimpleAction ("remove", null);
        remove_action.activate.connect (() => list.remove_item_by_id (id));

        empty_all_trash_action = new SimpleAction ("empty-all-trash", null);
        empty_all_trash_action.activate.connect (() => {
            new Files.FileOperations.EmptyTrashJob ((Gtk.Window) get_toplevel ()).empty_trash.begin ();
        });

        var action_group = new SimpleActionGroup ();
        action_group.add_action (open_action);
        action_group.add_action (open_tab_action);
        action_group.add_action (open_window_action);
        action_group.add_action (rename_action);
        action_group.add_action (remove_action);
        action_group.add_action (empty_all_trash_action);

        insert_action_group ("bookmark", action_group);

        ((Gtk.Application) Application.get_default ()).set_accels_for_action ("bookmark.rename", { "F2" });
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
        item_id_map.unset (id);
        item_map_lock.unlock ();
        base.destroy ();
    }

    protected virtual bool on_key_press_event (uint keyval, uint keycode, Gdk.ModifierType state) {
        switch (keyval) {
            case Gdk.Key.Escape:
                cancel_rename ();
                return true;

            case Gdk.Key.Menu:
                popup_context_menu ();
                return true;

            default:
                break;
        }

        return false;
    }

    protected virtual void on_button_release_event (int n_press, double x, double y) {
        if (!valid) { //Ignore if in the process of being removed
            return;
        }

        if (label_stack.visible_child_name == "editable") { //Do not interfere with renaming
            return;
        }

        Gdk.ModifierType state;
        Gtk.get_current_event_state (out state);
        var mods = state & Gtk.accelerator_get_default_mod_mask ();
        var control_pressed = ((mods & Gdk.ModifierType.CONTROL_MASK) != 0);
        var other_mod_pressed = (((mods & ~Gdk.ModifierType.SHIFT_MASK) & ~Gdk.ModifierType.CONTROL_MASK) != 0);
        var only_control_pressed = control_pressed && !other_mod_pressed; /* Shift can be pressed */

        switch (button_controller.get_current_button ()) {
            case Gdk.BUTTON_PRIMARY:
                if (only_control_pressed) {
                    activated (Files.OpenFlag.NEW_TAB);
                }

                break;
            case Gdk.BUTTON_SECONDARY:
                popup_context_menu ();
                break;

            case Gdk.BUTTON_MIDDLE:
                activated (Files.OpenFlag.NEW_TAB);
                break;

            default:
                break;
        }
    }

    protected virtual void popup_context_menu () {
        var open_section = new GLib.Menu ();
        open_section.append (_("Open in New _Tab"), "bookmark.open-tab");
        open_section.append (_("Open in New _Window"), "bookmark.open-window");

        var glib_menu = new GLib.Menu ();
        glib_menu.append (_("Open"), "bookmark.open");
        glib_menu.append_section (null, open_section);

        add_extra_menu_items (glib_menu);

        var popupmenu = new Gtk.Menu.from_model (glib_menu) {
            attach_widget = this
        };

        if (menu_model != null) {
            popupmenu.insert_action_group (action_group_namespace, action_group);
            glib_menu.append_section (null, menu_model);
        }

        popupmenu.popup_at_pointer (null);
    }

    protected override void add_extra_menu_items (GLib.Menu menu) {
    /* Rows under "Bookmarks" can be removed or renamed */
        var menu_section = new GLib.Menu ();
        if (!permanent) {
            menu_section.append (_("Remove"), "bookmark.remove");
        }

        if (!pinned) {
            menu_section.append (_("Rename"), "bookmark.rename");
        }

        menu.append_section (null, menu_section);

        if (Uri.parse_scheme (uri) == "trash") {
            var volume_monitor = VolumeMonitor.@get ();
            int mounts_with_trash = 0;
            foreach (Mount mount in volume_monitor.get_mounts ()) {
                if (Files.FileOperations.mount_has_trash (mount)) {
                    mounts_with_trash++;
                }
            }

            var text = mounts_with_trash > 0 ? _("Permanently Delete All Trash") : _("Permanently Delete Trash");

            var trash_section = new GLib.Menu ();
            // FIXME: any way to make destructive?
            trash_section.append (text, "bookmark.empty-all-trash");

            menu.append_section (null, trash_section);

            empty_all_trash_action.set_enabled (!Files.TrashMonitor.get_default ().is_empty);
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
            child = drop_revealer_child,
            transition_type = Gtk.RevealerTransitionType.SLIDE_UP
        };
        drop_revealer.show_all ();

        content_grid.attach (drop_revealer, 0, 1);

        Gtk.drag_dest_set (
            this,
            Gtk.DestDefaults.MOTION | Gtk.DestDefaults.HIGHLIGHT,
            dest_targets,
            Gdk.DragAction.MOVE | Gdk.DragAction.COPY | Gdk.DragAction.LINK | Gdk.DragAction.ASK
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
                        success = process_dropped_row (
                            drop_text,
                            drop_revealer.child_revealed
                        );
                        break;

                    case Files.TargetType.TEXT_URI_LIST:
                        success = process_dropped_uris (
                            ctx.get_selected_action (),
                            ctx.get_actions (),
                            drop_file_list,
                            drop_revealer.child_revealed
                        );
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

            var pos = get_index ();
            var previous_item = (BookmarkRow?)(list.get_item_at_index (pos - 1));
            var next_item = (BookmarkRow?)(list.get_item_at_index (pos + 1));

            if (previous_item != null) {
                previous_item.reveal_drop_target (false);
            }

            var row_height = icon_label_grid.get_allocated_height ();
            bool reveal = false;

            current_suggested_action = Gdk.DragAction.DEFAULT;
            switch (target.name ()) {
                case "text/plain":
                    reveal = can_insert_after &&
                             (next_item == null || next_item.can_insert_before) &&
                              y > row_height / 2;

                    break;

                case "text/uri-list": // File(s) being dragged
                    reveal = can_insert_after &&
                             (next_item == null || next_item.can_insert_before) &&
                              y > row_height - 1;

                    // When dropping onto a row, determine what actions are possible
                    if (target_file != null && !reveal && drop_file_list != null) {
                        Files.DndHandler.file_accepts_drop (
                            target_file,
                            drop_file_list,
                            ctx.get_selected_action (),
                            ctx.get_actions (),
                            out current_suggested_action
                        );

                        if (current_suggested_action != Gdk.DragAction.DEFAULT) {
                            highlight (true);
                        }
                    } else {
                        highlight (false);
                    }

                    break;
                default:
                    break;
            }

            if (reveal_drop_target (reveal)) {
                current_suggested_action = Gdk.DragAction.LINK; //A bookmark is effectively a link
                if (target.name () == "text/uri-list" && drop_text != null &&
                    list.has_uri (drop_text.strip ())) { //Need to remove trailing newline

                    current_suggested_action = Gdk.DragAction.DEFAULT; //Do not allowing dropping duplicate URI
                    reveal = false;
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

    protected void highlight (bool show) {
        if (show && !get_style_context ().has_class (Gtk.STYLE_CLASS_HIGHLIGHT)) {
            get_style_context ().add_class (Gtk.STYLE_CLASS_HIGHLIGHT);
        } else if (!show && get_style_context ().has_class (Gtk.STYLE_CLASS_HIGHLIGHT)) {
            get_style_context ().remove_class (Gtk.STYLE_CLASS_HIGHLIGHT);
        }
    }

    private void reset_drag_drop () {
        drop_file_list = null;
        drop_text = null;
        drop_occurred = false;
        current_suggested_action = Gdk.DragAction.DEFAULT;
        reveal_drop_target (false);
        highlight (false);
    }

    private bool process_dropped_row (string drop_text, bool dropped_between) {
        var id = (uint32)(uint.parse (drop_text));
        var item = get_item (id);

        if (item == null ||
            !dropped_between ||
            item.list != list) { //Cannot drop on self or different list

            return false;
        }

        list.move_item_after (item, get_index ()); // List takes care of saving changes
        return true;
    }

    private bool process_dropped_uris (Gdk.DragAction selected_action,
                                       Gdk.DragAction possible_actions,
                                       List<GLib.File> drop_file_list,
                                       bool dropped_between) {

        if (dropped_between && drop_file_list.next == null) { //Only create one new bookmark at a time
            var pos = get_index ();
            pos++;
            return list.add_favorite (drop_file_list.data.get_uri (), "", pos);
        } else {
            var dnd_handler = new Files.DndHandler ();
            var real_action = selected_action;

            if (real_action == Gdk.DragAction.ASK) {
                var actions = possible_actions;

                if (uri.has_prefix ("trash://")) {
                    actions &= Gdk.DragAction.MOVE;
                }

                real_action = dnd_handler.drag_drop_action_ask (
                    this,
                    (Gtk.ApplicationWindow)(Files.get_active_window ()),
                    actions
                );
            }

            if (real_action == 0) {
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

    protected bool reveal_drop_target (bool reveal) {
        if (list.is_drop_target ()) {
            drop_revealer.reveal_child = reveal;
            return reveal;
        } else {
            return false; //Suppress dropping between rows (e.g. for Storage list)
        }
    }
}
