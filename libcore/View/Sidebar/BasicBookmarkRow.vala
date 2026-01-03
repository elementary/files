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

public class Sidebar.BasicBookmarkRow : Gtk.ListBoxRow, SidebarItemInterface {
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
    public MenuModel? menu_model {get; set; default = null;}
    public ActionGroup? action_group {get; set; default = null;}
    public string? action_group_namespace { get; set; default = null;}

    protected Gtk.Grid content_grid;
    protected Gtk.Grid icon_label_grid;
    protected Gtk.Stack label_stack;
    protected Gtk.Entry editable;
    protected Gtk.Label label;

    private Gtk.Image icon;
    protected Files.File target_file;
    private Gtk.EventControllerKey key_controller;
    private Gtk.GestureMultiPress button_controller;
    private bool valid = true; //Set to false if scheduled for removal

    public BasicBookmarkRow (string _custom_name,
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

        icon = new Gtk.Image.from_gicon (gicon, Gtk.IconSize.MENU);
        icon_label_grid = new Gtk.Grid () {
            column_spacing = 6
        };

        icon_label_grid.attach (icon, 0, 0, 1, 2);
        icon_label_grid.add (label);

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

        var open_action = new SimpleAction ("open", null);
        open_action.activate.connect (() => activated ());
        var action_group = new SimpleActionGroup ();
        action_group.add_action (open_action);
        insert_action_group ("bookmark", action_group);
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
        return false;
    }

    protected virtual void on_button_release_event (int n_press, double x, double y) {
        if (!valid) { //Ignore if in the process of being removed
            return;
        }

        Gdk.ModifierType state;
        Gtk.get_current_event_state (out state);
        var mods = state & Gtk.accelerator_get_default_mod_mask ();
        switch (button_controller.get_current_button ()) {
            case Gdk.BUTTON_PRIMARY:
                break;
            case Gdk.BUTTON_SECONDARY:
                popup_context_menu ();
                break;

            case Gdk.BUTTON_MIDDLE:
                break;

            default:
                break;
        }
    }

    protected virtual void popup_context_menu () {
        var glib_menu = new GLib.Menu ();
        glib_menu.append (_("Open"), "bookmark.open");

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
}
