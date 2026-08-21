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

    private Gtk.Menu gtk_menu;

    public Menu menu {
        set {
            gtk_menu.bind_model (value, null, false);
        }
    }

    public ButtonWithMenu (string icon_name) {
        image = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.LARGE_TOOLBAR);
    }

    construct {
        use_underline = true;

        gtk_menu = new Gtk.Menu ();
        gtk_menu.attach_to_widget (this, null);
        gtk_menu.deactivate.connect ( () => {
            active = false;
        });

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
            popup_menu ();
            secondary_click_gesture.set_state (CLAIMED);
        });

        var long_press_gesture = new Gtk.GestureLongPress (this);

        long_press_gesture.pressed.connect (() => {
            popup_menu ();
            long_press_gesture.set_state (CLAIMED);
        });
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
        gtk_menu.popup_at_widget (this, SOUTH_WEST, NORTH_WEST, Gtk.get_current_event ());
        gtk_menu.select_first (false);
    }
}
