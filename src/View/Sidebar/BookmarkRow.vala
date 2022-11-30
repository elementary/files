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

    public virtual Gtk.PopoverMenu? get_context_menu () {
        Gtk.PopoverMenu popover;
        if (menu_model != null) {
            // Use custom menu for plugin item
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

        return popover;
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


    // protected void highlight (bool show) {
    //     if (show && !get_style_context ().has_class (Gtk.STYLE_CLASS_HIGHLIGHT)) {
    //         get_style_context ().add_class (Gtk.STYLE_CLASS_HIGHLIGHT);
    //     } else if (!show && get_style_context ().has_class (Gtk.STYLE_CLASS_HIGHLIGHT)) {
    //         get_style_context ().remove_class (Gtk.STYLE_CLASS_HIGHLIGHT);
    //     }
    // }


    public void reveal_drop_target (bool reveal) {
        drop_revealer.reveal_child = reveal;
    }

    public bool drop_target_revealed () {
        return drop_revealer.reveal_child;
    }
}
