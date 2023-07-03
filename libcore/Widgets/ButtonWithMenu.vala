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

    public Menu menu {
        set {
            popover.menu_model = value;
        }
    }

    public ButtonWithMenu (string icon_name) {
        Object (icon_name: icon_name);
    }

    construct {
        add_css_class (Granite.STYLE_CLASS_LARGE_ICONS);
        use_underline = true;

        popover = new Gtk.PopoverMenu.from_model (null) {
            autohide = true,
            has_arrow = false
        };
        popover.set_parent (this);

        popover.closed.connect (() => {
            active = false;
        });

        mnemonic_activate.connect (on_mnemonic_activate);

        var press_gesture = new Gtk.GestureClick () {
            button = Gdk.BUTTON_PRIMARY
        };
        press_gesture.released.connect (() => {
            slow_press ();
            press_gesture.set_state (CLAIMED);
        });

        var secondary_click_gesture = new Gtk.GestureClick () {
            button = Gdk.BUTTON_SECONDARY
        };
        secondary_click_gesture.pressed.connect (() => {
            popup_menu ();
            secondary_click_gesture.set_state (CLAIMED);
        });

        var long_press_gesture = new Gtk.GestureLongPress ();

        long_press_gesture.pressed.connect (() => {
            popup_menu ();
            long_press_gesture.set_state (CLAIMED);
        });

        add_controller (press_gesture);
        add_controller (secondary_click_gesture);
        add_controller (long_press_gesture);
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

    protected new void popup_menu () {
        active = true;
        popover.popup ();
    }
}
