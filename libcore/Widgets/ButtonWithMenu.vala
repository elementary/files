/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2011-2013 Mathijs Henquet
 *                         2023 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Mathijs Henquet <mathijs.henquet@gmail.com>,
 *              ammonkey <am.monkeyd@gmail.com>
 */

/**
 * ButtonWithMenu
 * - support long click / right click with depressed button states
 * - activate a GtkAction if any or popup a menu
 * (used in history navigation buttons)
 */
public class Files.View.Chrome.ButtonWithMenu : Gtk.ToggleButton {
    public signal void slow_press ();

    private Gtk.PopoverMenu popover;
    public Menu? menu { get; set; default = null; }

    public ButtonWithMenu (string icon_name) {
        image = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.LARGE_TOOLBAR);
    }

    construct {
        use_underline = true;

        can_focus = false; // Have a shortcut to operate so no need to focus
        popover = new Gtk.PopoverMenu ();
        popover.relative_to = this;

        mnemonic_activate.connect (on_mnemonic_activate);

        var press_gesture = new Gtk.GestureMultiPress (this) {
            button = Gdk.BUTTON_PRIMARY
        };
        press_gesture.released.connect (() => {
            slow_press ();
            press_gesture.set_state (CLAIMED);
        });

        var secondary_click_gesture = new Gtk.GestureMultiPress (this) {
            button = Gdk.BUTTON_SECONDARY
        };
        secondary_click_gesture.pressed.connect (() => {
            show_popover ();
            secondary_click_gesture.set_state (CLAIMED);
        });

        var long_press_gesture = new Gtk.GestureLongPress (this);

        long_press_gesture.pressed.connect (() => {
            show_popover ();
            long_press_gesture.set_state (CLAIMED);
        });
    }

    private void show_popover () {
        popover.bind_model (menu, null);
        popover.popup ();
    }

    private bool on_mnemonic_activate (bool group_cycling) {
        /* ToggleButton always grabs focus away from the editor,
         * so reimplement Widget's version, which only grabs the
         * focus if we are group cycling.
         */
        if (!group_cycling) {
            activate ();
        } else if (can_focus) {
            grab_focus ();
        }

        return true;
    }
}
