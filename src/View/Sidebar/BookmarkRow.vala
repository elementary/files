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
     * Each row gets a unique id.  The methods relating to this are in the SidebarItemInterface */
    //TODO Implement key control once means to focus keyboard on sidebar provided?
    //TODO Impement modified button event to open in new tab??
    static construct {
        SidebarItemInterface.row_id = new Rand.with_seed (
            int.parse (get_real_time ().to_string ())
        ).next_int ();

        SidebarItemInterface.item_map_lock = Mutex ();
        SidebarItemInterface.item_id_map = new Gee.HashMap<uint32, SidebarItemInterface> ();
    }

    private bool valid = true; //Set to false if scheduled for removal
    private Gtk.Image icon;
    public bool can_accept_drops {
        get {
            return Files.DndHandler.can_accept_drops (target_file);
        }
    }
    public Files.File target_file { get; construct; }
    public bool is_renaming { get; private set; default = false; }

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

        // Must be grid in order to show storage bar if required
        icon_label_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        icon_label_box.append (icon);
        icon_label_box.append (label_stack);

        content_grid = new Gtk.Grid ();
        content_grid.attach (icon_label_box, 0, 0);

        set_child (content_grid);

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
                menu_builder.add_remove (
                    Action.print_detailed_name ("bm.remove-bookmark", new Variant.uint32 (id))
                );
            }

            if (!pinned) {
                menu_builder.add_rename (
                    Action.print_detailed_name ("bm.rename-bookmark", new Variant.uint32 (id))
                );
            }

            menu_builder.add_separator ();
            add_extra_menu_items (menu_builder);

            popover = menu_builder.build ();
        }

        return popover;
    }

    protected override void add_extra_menu_items (PopupMenuBuilder menu_builder) {
        if (Uri.parse_scheme (uri) == "trash") {
            menu_builder.add_empty_all_trash ("bm.empty-all-trash");
        }
    }

    public void reveal_drop_target (bool reveal) {
        drop_revealer.reveal_child = reveal;
    }

    public bool drop_target_revealed () {
        return drop_revealer.reveal_child;
    }
}
