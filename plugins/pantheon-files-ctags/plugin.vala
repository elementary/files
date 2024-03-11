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
                file.icon_changed ();
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
                    file.icon_changed (); /* Just need to trigger redraw - the underlying GFile has not changed */
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

    public override void context_menu (Gtk.PopoverMenu menu_widget, GLib.List<Files.File> selected_files) {
        if (selected_files == null) {
            return;
        }

        var color_menu_item = new ColorWidget ();
        current_selected_files = selected_files.copy_deep ((GLib.CopyFunc) GLib.Object.ref);

        /* Check the colors currently set */
        foreach (Files.File gof in current_selected_files) {
            color_menu_item.check_color (gof.color);
        }

        color_menu_item.color_changed.connect ((ncolor) => {
            set_color.begin (current_selected_files, ncolor);
        });

        menu_widget.add_child (color_menu_item, "color-tag");
    }


    private async void set_color (GLib.List<Files.File> files, int n) throws IOError {
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
                target_file.icon_changed ();
            }
        }

        if (files != null) {
            /* If the color of the target is set while in recent view, we have to
             * update the recent view to reflect this */
            foreach (unowned Files.File file in files) {
                if (file.location.has_uri_scheme ("recent")) {
                    file.color = n;
                    file.icon_changed (); /* Just need to trigger redraw */
                }
            }
        }
    }

    private class ColorButton : Gtk.CheckButton {
        private static Gtk.CssProvider css_provider;
        public string color_name { get; construct; }
        public int color_index { get; construct; }
        public ColorWidget parent {get; construct;}

        static construct {
            css_provider = new Gtk.CssProvider ();
            css_provider.load_from_resource ("io/elementary/files/ColorButton.css");
        }

        public ColorButton (string color_name, int color_index, ColorWidget parent) {
            Object (
                color_name: color_name,
                color_index: color_index,
                parent: parent
            );
        }

        construct {
            var style_context = get_style_context ();
            style_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            style_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
            style_context.add_class (color_name);

            toggled.connect (() => {
                if (active) {
                    parent.color_button_activated (color_index);
                }
            });
        }
    }

    private class ColorWidget : Gtk.Box {
        public signal void color_changed (int ncolor);
        private Gee.ArrayList<ColorButton> color_buttons;
        private const int COLORBOX_SPACING = 3;

        construct {
            orientation = HORIZONTAL;
            spacing = COLORBOX_SPACING;
            halign = START;
            margin_start = 3;

            append (new ColorButton ("none", 0, this));
            append (new ColorButton ("blue", 1, this));
            append (new ColorButton ("mint", 2, this));
            append (new ColorButton ("green", 3, this));
            append (new ColorButton ("yellow", 4, this));
            append (new ColorButton ("orange", 5, this));
            append (new ColorButton ("red", 6, this));
            append (new ColorButton ("pink", 7, this));
            append (new ColorButton ("purple", 8, this));
            append (new ColorButton ("brown", 9, this));
            append (new ColorButton ("slate", 10, this));

            try {
                string css = ".nohover { background: none; }";

                var css_provider = new Gtk.CssProvider ();
                css_provider.load_from_data (css.data);

                var style_context = get_style_context ();
                style_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
                style_context.add_class ("nohover");
            } catch (GLib.Error e) {
                warning ("Failed to parse css style : %s", e.message);
            }
        }

        public void color_button_activated (int color_index) {
            clear_checks ();
            check_color (color_index);
            color_changed (color_index);
        }

        private void clear_checks () {
            var child = (ColorButton) get_first_child ();
            while (child != null) {
                child.active = false;
                child = (ColorButton) get_next_sibling ();
            }
        }

        public void check_color (int color) {
            var child = (ColorButton) get_first_child ();
            while (child != null && child.color_index != color) {
                child = (ColorButton) get_next_sibling ();
            }

            if (child != null && child.color_index == color) {
                child.active = true;
            }
        }
    }
}

public Files.Plugins.Base module_init () {
    return new Files.Plugins.CTags ();
}
