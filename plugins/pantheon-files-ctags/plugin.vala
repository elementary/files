/***
    Copyright (c) ammonkey 2011 <am.monkeyd@gmail.com>

    Marlin is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the
    Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Marlin is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
    See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program.  If not, see <http://www.gnu.org/licenses/>.
***/

[DBus (name = "io.elementary.files.db")]
interface MarlinDaemon : Object {
    public abstract async Variant get_uri_infos (string raw_uri) throws GLib.DBusError, GLib.IOError;
    public abstract async bool record_uris (Variant[] entries) throws GLib.DBusError, GLib.IOError;
    public abstract async bool delete_entry (string uri) throws GLib.DBusError, GLib.IOError;

}

public class Files.Plugins.CTags : Files.Plugins.Base {
    /* May be used by more than one directory simultaneously so do not make assumptions */
    private MarlinDaemon daemon;
    private Cancellable cancellable;
    private GLib.List<Files.File> current_selected_files;

    public CTags () {
        cancellable = new Cancellable ();

        try {
            daemon = Bus.get_proxy_sync (BusType.SESSION, "io.elementary.files.db",
                                         "/io/elementary/files/db");
        } catch (IOError e) {
            stderr.printf ("%s\n", e.message);
        }
    }

    private async void rreal_update_file_info (Files.File file) {
        try {
            if (!file.exists || file.color >= 0) {
                // Delete the entry if file no longer exists or we obtained color info from metadata
                yield daemon.delete_entry (file.uri);
                return;
            }

            var info = yield file.location.query_info_async ("metadata::color-tag", FileQueryInfoFlags.NONE);
            if (info.has_attribute ("metadata::color-tag")) {
                file.color = int.parse (info.get_attribute_string ("metadata::color-tag"));
            } else {
                // Look for color in Files daemon database
                var rc = yield daemon.get_uri_infos (file.uri);

                VariantIter iter = rc.iterator ();
                assert (iter.n_children () == 1);
                VariantIter row_iter = iter.next_value ().iterator ();

                if (row_iter.n_children () == 3) {
                    /* Only interested in color tag */
                    int64.parse (row_iter.next_value ().get_string ()); // Skip modified date
                    row_iter.next_value ().get_string (); // Skip file type
                    file.color = int.parse (row_iter.next_value ().get_string ());
                    file.location.set_attribute_string ("metadata::color-tag", file.color.to_string (), FileQueryInfoFlags.NONE);
                    yield daemon.delete_entry (file.uri);
                }
            }
        } catch (Error err) {
            warning ("%s", err.message);
        }
    }

    public override void update_file_info (Files.File file) {
        if (!file.is_hidden || Files.Preferences.get_default ().show_hidden_files) {
            rreal_update_file_info.begin (file);
        }
    }

    public override void context_menu (Gtk.Widget widget, GLib.List<Files.File> selected_files) {
        if (selected_files == null) {
            return;
        }

        var menu = widget as Gtk.Menu;
        var color_menu_item = new ColorWidget ();
        current_selected_files = selected_files.copy_deep ((GLib.CopyFunc) GLib.Object.ref);

        /* Check the colors currently set */
        foreach (Files.File gof in current_selected_files) {
            color_menu_item.check_color ((TagColor) gof.color);
        }

        color_menu_item.color_changed.connect ((color) => {
            set_color.begin (current_selected_files, color);
        });

        add_menuitem (menu, new Gtk.SeparatorMenuItem ());
        add_menuitem (menu, color_menu_item);
    }

    private void add_menuitem (Gtk.Menu menu, Gtk.MenuItem menu_item) {
        menu.append (menu_item);
        menu_item.show ();
    }

    private async void set_color (GLib.List<Files.File> files, TagColor color) throws Error {
        var n = (int) color; // Maintain existing interface

        foreach (unowned Files.File file in files) {
            if (!(file is Files.File)) {
                continue;
            }

            Files.File target_file;
            if (file.location.has_uri_scheme ("recent")) {
                target_file = Files.File.get_by_uri (file.get_display_target_uri ());
            } else {
                target_file = file;
            }

            if (target_file.color != n) {
                target_file.color = n;
                target_file.location.set_attribute_string ("metadata::color-tag", n.to_string (), FileQueryInfoFlags.NONE);
            }
        }

        if (files != null) {
            /* If the color of the target is set while in recent view, we have to
             * update the recent view to reflect this */
            foreach (unowned Files.File file in files) {
                if (file.location.has_uri_scheme ("recent")) {
                    file.color = n;
                }
            }
        }
    }

    private class ColorButton : Gtk.CheckButton {
        private static Gtk.CssProvider css_provider;
        public TagColor color { get; construct; }
        static construct {
            css_provider = new Gtk.CssProvider ();
            css_provider.load_from_resource ("io/elementary/files/ColorButton.css");
        }

        public ColorButton (TagColor color) {
            Object (
                color: color
            );
        }

        construct {
            var style_context = get_style_context ();
            style_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            style_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
            style_context.add_class (color.get_css_name ());
        }
    }

    private class ColorWidget : Gtk.MenuItem {
        public signal void color_changed (TagColor color);
        private Gee.ArrayList<ColorButton> color_buttons;
        private Gtk.Grid colorbox;
        private const int COLORBOX_SPACING = 3;

        construct {
            color_buttons = new Gee.ArrayList<ColorButton> ();
            color_buttons.add (new ColorButton (NONE));
            color_buttons.add (new ColorButton (BLUE));
            color_buttons.add (new ColorButton (MINT));
            color_buttons.add (new ColorButton (GREEN));
            color_buttons.add (new ColorButton (YELLOW));
            color_buttons.add (new ColorButton (ORANGE));
            color_buttons.add (new ColorButton (RED));
            color_buttons.add (new ColorButton (PINK));
            color_buttons.add (new ColorButton (PURPLE));
            color_buttons.add (new ColorButton (LATTE));
            color_buttons.add (new ColorButton (BROWN));
            color_buttons.add (new ColorButton (SLATE));

            colorbox = new Gtk.Grid () {
                column_spacing = COLORBOX_SPACING,
                margin_start = 3,
                halign = Gtk.Align.START
            };

            for (int i = 0; i < color_buttons.size; i++) {
                colorbox.add (color_buttons[i]);
            }

            add (colorbox);

            try {
                string css = ".nohover { background: none; }";

                var css_provider = new Gtk.CssProvider ();
                css_provider.load_from_data (css, -1);

                var style_context = get_style_context ();
                style_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                style_context.add_class ("nohover");
            } catch (GLib.Error e) {
                warning ("Failed to parse css style : %s", e.message);
            }

            show_all ();

            // Cannot use this for every button due to this being a MenuItem
            button_press_event.connect (button_pressed_cb);
        }

        // Check the button with the color of the parameter
        // Do not change other buttons
        public void check_color (TagColor color) {
            foreach (var button in color_buttons) {
                if (button.color == color) {
                    button.active = true;
                    return;
                }
            }
        }

        private bool button_pressed_cb (Gdk.EventButton event) {
            double ex, ey;
            int cbx, cby;
            event.get_coords (out ex, out ey);
            translate_coordinates (colorbox, (int)ex, (int)ey, out cbx, out cby);
            var cb_width = colorbox.get_allocated_width ();
            var n_buttons = color_buttons.size;
            var button_index = (int)(cbx * (double) n_buttons / (double) cb_width);
            if (Gtk.StateFlags.DIR_RTL in get_style_context ().get_state ()) {
                button_index = color_buttons.size - 1 - button_index;
            }

            var button_pressed = color_buttons[button_index];
            color_changed (button_pressed.color);

            // Set all selected items to the pressed button's color.
            foreach (var button in color_buttons) {
                button.active = false;
            }

            button_pressed.active = true;

            return true;
        }
    }
}

public Files.Plugins.Base module_init () {
    return new Files.Plugins.CTags ();
}
