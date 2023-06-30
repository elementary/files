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
    public signal void right_click (Gdk.EventButton ev);
    public signal void slow_press ();

    private Gtk.Menu _menu;
    public Gtk.Menu menu {
        get {
            return _menu;
        }

        set {
            _menu = value;
            update_menu_properties ();
        }
    }

    private int long_press_time = Gtk.Settings.get_default ().gtk_double_click_time * 2;
    private uint timeout = 0;
    private uint last_click_time = 0;

    public ButtonWithMenu (string icon_name) {
        image = new Gtk.Image.from_icon_name (icon_name, Gtk.IconSize.LARGE_TOOLBAR);
    }

    construct {
        use_underline = true;

        menu = new Gtk.Menu ();

        mnemonic_activate.connect (on_mnemonic_activate);

        events |= Gdk.EventMask.BUTTON_PRESS_MASK |
                  Gdk.EventMask.BUTTON_RELEASE_MASK |
                  Gdk.EventMask.BUTTON_MOTION_MASK;

        button_press_event.connect (on_button_press_event);
        button_release_event.connect (on_button_release_event);
        motion_notify_event.connect (() => {
            if (timeout > 0) {
                Source.remove (timeout);
                timeout = 0;
                active = false;
            }

            return Gdk.EVENT_PROPAGATE;
        });

        timeout = 0;

        realize.connect (() => {
            get_toplevel ().configure_event.connect (() => {
                if (timeout > 0) {
                    Source.remove (timeout);
                    timeout = 0;
                }

                return false;
            });
        });
    }

    private void update_menu_properties () {
        menu.attach_to_widget (this, null);
        menu.deactivate.connect ( () => {
            active = false;
        });
        menu.deactivate.connect (menu.popdown);
    }

    public override void show_all () {
        menu.show_all ();
        base.show_all ();
    }

    private bool on_button_release_event (Gdk.EventButton ev) {
        if (ev.time - last_click_time < long_press_time) {
            slow_press ();
            active = false;
        }

        if (timeout > 0) {
            Source.remove (timeout);
            timeout = 0;
        }

        return false;
    }

    private bool on_button_press_event (Gdk.EventButton ev) {
        /* If the button is kept pressed, don't make the user wait when there's no action */
        int max_press_time = long_press_time;
        if (ev.button == 1 || ev.button == 3) {
            active = true;
        }

        if (timeout == 0 && ev.button == 1) {
            last_click_time = ev.time;
            timeout = Timeout.add (max_press_time, () => {
                /* long click */
                timeout = 0;
                popup_menu (ev);
                return GLib.Source.REMOVE;
            });
        }

        if (ev.button == 3) {
            /* right_click */
            right_click (ev);
            popup_menu (ev);
        }
        return true;

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

    protected new void popup_menu (Gdk.EventButton? ev = null) {
        menu.popup_at_widget (this, Gdk.Gravity.SOUTH_WEST, Gdk.Gravity.NORTH_WEST, ev);

        menu.select_first (false);
    }
}
