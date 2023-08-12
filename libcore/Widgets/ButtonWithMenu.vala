/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
*/
public class Files.ButtonWithMenu : Gtk.EventBox {
    private Gtk.Popover popover;
    private Menu? menu;
    public string icon_name { get; construct; }
    public signal void activated ();
    public ButtonWithMenu (string icon_name) {
        Object (
            icon_name: icon_name
        );
    }

    construct {
        var image = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.BUTTON);
        menu = new Menu ();
        popover = new Gtk.Popover.from_model (this, menu);

        var longpress_controller = new Gtk.GestureLongPress (this) {
            button = Gdk.BUTTON_PRIMARY,
            delay_factor = 2.0,
            propagation_phase = Gtk.PropagationPhase.BUBBLE
        };

        longpress_controller.pressed.connect ((x, y) => {
            longpress_controller.set_state (Gtk.EventSequenceState.CLAIMED);
            show_popover ();
        });
        longpress_controller.cancelled.connect (() => {
            activated ();
        });

        var secondary_click_controller = new Gtk.GestureMultiPress (this) {
            button = Gdk.BUTTON_SECONDARY,
            propagation_phase = Gtk.PropagationPhase.BUBBLE
        };
        secondary_click_controller.pressed.connect (() => {
            secondary_click_controller.set_state (Gtk.EventSequenceState.CLAIMED);
            show_popover ();
        });

        add (image);
        show_all ();

        //TODO Dim image when insensitive (this happens automatically in Gtk4)
    }

    public void update_menu (Gee.List<string> path_list) {
        /* Clear the menu and re-add the correct entries. */
        menu.remove_all ();
        for (int i = 0; i < path_list.size; i++) {
            var path = path_list.@get (i);
            var item = new MenuItem (
                FileUtils.sanitize_path (path, null, false),
                Action.print_detailed_name ("win.back", new Variant.int32 (i + 1))
            );
            menu.append_item (item);
        }
    }

    private void show_popover () {
        if (menu.get_n_items () > 0) {
            popover.popup ();
        }
    }
}
