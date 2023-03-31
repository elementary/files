/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
*/
public class Files.ButtonWithMenu : Gtk.Widget {
    static construct {
        set_layout_manager_type (typeof (Gtk.BinLayout));
    }

    private Gtk.PopoverMenu popover;
    public Menu? menu { get; set; default = null; }
    public signal void activated ();
    public ButtonWithMenu (string icon_name) {
        var image = new Gtk.Image.from_icon_name (icon_name);
        image.set_parent (this);
    }

    construct {
        focusable = false; // Have a shortcut to operate so no need to focus
        popover = new Gtk.PopoverMenu.from_model (null);
        popover.set_offset (48, 0);
        popover.set_parent (this);
        var longpress_controller = new Gtk.GestureLongPress () {
            delay_factor = 2.0
        };
        longpress_controller.pressed.connect ((x, y) => {
            show_popover ();
        });
        longpress_controller.cancelled.connect (() => {
            activated (); // To be tested - can this be cancelled for other reason?
        });

        var secondary_click_controller = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        secondary_click_controller.pressed.connect (() => {
            secondary_click_controller.set_state (Gtk.EventSequenceState.CLAIMED);
            show_popover ();
        });
        this.add_controller (longpress_controller);
        this.add_controller (secondary_click_controller);
    }

    private void show_popover () {
        popover.set_menu_model (menu);
        popover.popup ();
    }
}
