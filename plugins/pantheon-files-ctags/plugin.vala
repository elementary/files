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
    private bool ignore_dir;

    private Queue<Files.File> unknowns;
    private Queue<Files.File> knowns;
    private uint idle_consume_unknowns = 0;
    private uint t_consume_knowns = 0;
    private Cancellable cancellable;
    private GLib.List<Files.File> current_selected_files;

    public CTags () {
        unknowns = new Queue<Files.File> ();
        knowns = new Queue<Files.File> ();
        cancellable = new Cancellable ();

        try {
            daemon = Bus.get_proxy_sync (BusType.SESSION, "io.elementary.files.db",
                                         "/io/elementary/files/db");
        } catch (IOError e) {
            stderr.printf ("%s\n", e.message);
        }
    }

    /* Arbitrary user dir list */
    private const string USER_DIRS[2] = {
        "file:///home",
        "file:///media"
    };

    private const string IGNORE_SCHEMES [5] = {
        "ftp",
        "sftp",
        "afp",
        "dav",
        "davs"
    };

    private bool f_is_user_dir (GLib.File dir) {
        return_val_if_fail (dir != null, false);
        var uri = dir.get_uri ();

        foreach (var duri in USER_DIRS) {
            if (Posix.strncmp (uri, duri, duri.length) == 0) {
                return true;
            }
        }

        return false;
    }

    private bool f_ignore_dir (GLib.File dir) {
        return_val_if_fail (dir != null, true);
        var uri = dir.get_uri ();

        if (uri == "file:///tmp") {
            return true;
        }

        var uri_scheme = Uri.parse_scheme (uri);
        foreach (var scheme in IGNORE_SCHEMES) {
            if (scheme == uri_scheme) {
                return true;
            }
        }

        return false;
    }

    public override void directory_loaded (Gtk.ApplicationWindow window, Files.AbstractSlot view, Files.File directory) {
        /* It is possible more than one directory will call this simultaneously so do not cancel */
    }

    private void add_entry (Files.File gof, GenericArray<Variant> entries) {
        var entry = new Variant.strv (
                        { gof.uri,
                          gof.get_ftype (),
                          gof.info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED).to_string (),
                          gof.color.to_string ()
                        }
                    );

        entries.add (entry);
    }

    private async void consume_knowns_queue () {
        var entries = new GenericArray<Variant> ();
        Files.File gof;
        while ((gof = knowns.pop_head ()) != null) {
            add_entry (gof, entries);
        }

        if (entries.length > 0) {
            debug ("--- known entries %d", entries.length);
            try {
                yield daemon.record_uris (entries.data);
            } catch (Error err) {
                warning ("%s", err.message);
            }
        }
    }

    private async void consume_unknowns_queue () {
        Files.File gof = null;
        /* Length of unknowns queue limited to visible files by AbstractDirectoryView.
         * Avoid querying whole directory in case very large. */
        while ((gof = unknowns.pop_head ()) != null) {
            try {
                FileInfo? info = gof.info; /* file info should already be up to date at this point */
                if (info == null) {
                    info = yield gof.location.query_info_async (FileAttribute.STANDARD_CONTENT_TYPE, 0, 0, cancellable);
                }

                add_to_knowns_queue (gof, info);
            } catch (Error err2) {
                warning ("query_info failed: %s %s", err2.message, gof.uri);
            }

        }
    }

    private void add_to_knowns_queue (Files.File file, FileInfo info) {
        file.tagstype = info.get_content_type ();
        file.update_type ();

        knowns.push_head (file);
        if (t_consume_knowns != 0) {
            Source.remove (t_consume_knowns);
            t_consume_knowns = 0;
        }

        t_consume_knowns = Timeout.add (300, () => {
                                        consume_knowns_queue.begin ();
                                        t_consume_knowns = 0;
                                        return GLib.Source.REMOVE;
                                        });
    }

    private void add_to_unknowns_queue (Files.File file) {
        if (file.get_ftype () == "application/octet-stream") {
            unknowns.push_head (file);

            if (idle_consume_unknowns == 0) {
                idle_consume_unknowns = Idle.add (() => {
                      consume_unknowns_queue.begin ();
                      idle_consume_unknowns = 0;
                      return GLib.Source.REMOVE;
                  });
            }
        }
    }

    private async void rreal_update_file_info (Files.File file) {
        try {
            if (!file.exists) {
                yield daemon.delete_entry (file.uri);
                return;
            }

            var rc = yield daemon.get_uri_infos (file.uri);

            VariantIter iter = rc.iterator ();
            assert (iter.n_children () == 1);
            VariantIter row_iter = iter.next_value ().iterator ();

            if (row_iter.n_children () == 3) {
                uint64 modified = int64.parse (row_iter.next_value ().get_string ());
                unowned string type = row_iter.next_value ().get_string ();
                var color = int.parse (row_iter.next_value ().get_string ());
                if (file.color != color) {
                    file.color = color;
                    file.icon_changed (); /* Just need to trigger redraw - the underlying GFile has not changed */
                }
                /* check modified time field only on user dirs. We don't want to query again and
                 * again system directories */

                /* Is this necessary ? */
                if (file.info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED) > modified &&
                    f_is_user_dir (file.directory)) {

                    add_to_unknowns_queue (file);
                    return;
                }

                if (type.length > 0 && file.get_ftype () == "application/octet-stream") {
                    if (type != "application/octet-stream") {
                        file.tagstype = type;
                        file.update_type ();
                    }
                }
            } else {
                add_to_unknowns_queue (file);
            }
        } catch (Error err) {
            warning ("%s", err.message);
        }
    }

    private async void rreal_update_file_info_for_recent (Files.File file, string? target_uri) {
        if (target_uri == null) { /* e.g. for recent:/// */
            return;
        }

        try {
            var rc = yield daemon.get_uri_infos (target_uri);

            VariantIter iter = rc.iterator ();
            assert (iter.n_children () == 1);
            VariantIter row_iter = iter.next_value ().iterator ();

            if (row_iter.n_children () == 3) {
                /* Only interested in color tag in recent:// at the moment */
                row_iter.next_value ();
                row_iter.next_value ();
                file.color = int.parse (row_iter.next_value ().get_string ());
            }
        } catch (Error err) {
            warning ("%s", err.message);
        }
    }

    public override void update_file_info (Files.File file) {
        if (file.info != null && !f_ignore_dir (file.directory) &&
            (!file.is_hidden || Files.Preferences.get_default ().show_hidden_files)) {

            if (file.location.has_uri_scheme ("recent")) {
                rreal_update_file_info_for_recent.begin (file, file.get_display_target_uri ());
            } else {
                rreal_update_file_info.begin (file);
            }
        }
    }

    public override void context_menu (Gtk.Widget widget, GLib.List<Files.File> selected_files) {
        if (selected_files == null || ignore_dir) {
            return;
        }

        var menu = widget as Gtk.Menu;
        var color_menu_item = new ColorWidget ();
        current_selected_files = selected_files.copy_deep ((GLib.CopyFunc) GLib.Object.ref);

        /* Check the colors currently set */
        foreach (Files.File gof in current_selected_files) {
            color_menu_item.check_color (gof.color);
        }

        color_menu_item.color_changed.connect ((ncolor) => {
            set_color.begin (current_selected_files, ncolor);
        });

        add_menuitem (menu, new Gtk.SeparatorMenuItem ());
        add_menuitem (menu, color_menu_item);
    }

    private void add_menuitem (Gtk.Menu menu, Gtk.MenuItem menu_item) {
        menu.append (menu_item);
        menu_item.show ();
    }

    private async void set_color (GLib.List<Files.File> files, int n) throws IOError {
        var entries = new GenericArray<Variant> ();
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
                add_entry (target_file, entries);
            }
        }

        if (entries != null) {
            try {
                yield daemon.record_uris (entries.data);
                /* If the color of the target is set while in recent view, we have to
                 * update the recent view to reflect this */
                foreach (unowned Files.File file in files) {
                    if (file.location.has_uri_scheme ("recent")) {
                        update_file_info (file);
                        file.icon_changed (); /* Just need to trigger redraw */
                    }
                }
            } catch (Error err) {
                warning ("%s", err.message);
            }
        }
    }

    private class ColorButton : Gtk.CheckButton {
        private static Gtk.CssProvider css_provider;
        public string color_name { get; construct; }

        static construct {
            css_provider = new Gtk.CssProvider ();
            css_provider.load_from_resource ("io/elementary/files/ColorButton.css");
        }

        public ColorButton (string color_name) {
            Object (color_name: color_name);
        }

        construct {
            var style_context = get_style_context ();
            style_context.add_provider (css_provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
            style_context.add_class (Granite.STYLE_CLASS_COLOR_BUTTON);
            style_context.add_class (color_name);
        }
    }

    private class ColorWidget : Gtk.MenuItem {
        public signal void color_changed (int ncolor);
        private Gee.ArrayList<ColorButton> color_buttons;
        private const int COLORBOX_SPACING = 3;

        construct {
            var color_button_remove = new ColorButton ("none");
            color_buttons = new Gee.ArrayList<ColorButton> ();
            color_buttons.add (new ColorButton ("blue"));
            color_buttons.add (new ColorButton ("mint"));
            color_buttons.add (new ColorButton ("green"));
            color_buttons.add (new ColorButton ("yellow"));
            color_buttons.add (new ColorButton ("orange"));
            color_buttons.add (new ColorButton ("red"));
            color_buttons.add (new ColorButton ("pink"));
            color_buttons.add (new ColorButton ("purple"));
            color_buttons.add (new ColorButton ("brown"));
            color_buttons.add (new ColorButton ("slate"));

            var colorbox = new Gtk.Grid () {
                column_spacing = COLORBOX_SPACING,
                margin_start = 3,
                halign = Gtk.Align.START
            };

            colorbox.add (color_button_remove);

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

        private void clear_checks () {
            color_buttons.foreach ((b) => { b.active = false; return true;});
        }

        public void check_color (int color) {
            if (color == 0 || color > color_buttons.size) {
                return;
            }

            color_buttons[color - 1].active = true;
        }

        private bool button_pressed_cb (Gdk.EventButton event) {
            var color_button_width = color_buttons[0].get_allocated_width ();

            int y0 = (get_allocated_height () - color_button_width) / 2;
            int x0 = COLORBOX_SPACING + color_button_width;
            int x, y;
            EventUtils.get_coords (event, out x, out y);
            if (y < y0 || y > y0 + color_button_width) {
                return true;
            }

            if (Gtk.StateFlags.DIR_RTL in get_style_context ().get_state ()) {
                var width = get_allocated_width ();
                int x1 = width - 27;
                for (int i = 0; i < Files.Preferences.TAGS_COLORS.length; i++) {
                    if (x <= x1 && x >= x1 - color_button_width) {
                        color_changed (i);
                        clear_checks ();
                        check_color (i);
                        break;
                    }

                    x1 -= x0;
                }
            } else {
                int x1 = 27;
                for (int i = 0; i < Files.Preferences.TAGS_COLORS.length; i++) {
                    if (x >= x1 && x <= x1 + color_button_width) {
                        color_changed (i);
                        clear_checks ();
                        check_color (i);
                        break;
                    }

                    x1 += x0;
                }
            }

            return true;
        }
    }
}

public Files.Plugins.Base module_init () {
    return new Files.Plugins.CTags ();
}
