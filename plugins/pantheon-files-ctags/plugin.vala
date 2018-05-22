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
    public abstract async bool record_uris (Variant[] entries, string directory) throws GLib.DBusError, GLib.IOError;
    public abstract async bool deleteEntry (string uri) throws GLib.DBusError, GLib.IOError;

}

public class Marlin.Plugins.CTags : Marlin.Plugins.Base {
    private MarlinDaemon daemon;
    GOF.File directory;
    private bool is_user_dir;
    private bool ignore_dir;

    private Queue<GOF.File> unknowns;
    private Queue<GOF.File> knowns;
    private uint idle_consume_unknowns = 0;
    private uint t_consume_knowns = 0;
    private Cancellable cancellable;

    public CTags () {
        unknowns = new Queue<GOF.File> ();
        knowns = new Queue<GOF.File> ();
        cancellable = new Cancellable ();

        try {
            daemon = Bus.get_proxy_sync (BusType.SESSION, "io.elementary.files.db",
                                         "/io/elementary/files/db");
        } catch (IOError e) {
            stderr.printf ("%s\n", e.message);
        }
    }

    /* Arbitrary user dir list */
    private const string users_dirs[2] = {
        "file:///home",
        "file:///media"
    };

    private const string ignore_schemes [5] = {
        "ftp",
        "sftp",
        "afp",
        "dav",
        "davs"
    };

    private bool f_is_user_dir (string uri) {
        return_val_if_fail (uri != null, false);
        foreach (var duri in users_dirs) {
            if (Posix.strncmp (uri, duri, duri.length) == 0) {
                return true;
            }
        }

        return false;
    }

    private bool f_ignore_dir (string uri) {
        return_val_if_fail (uri != null, true);

        if (uri == "file:///tmp") {
            return true;
        }

        var uri_scheme = Uri.parse_scheme (uri);
        foreach (var scheme in ignore_schemes) {
            if (scheme == uri_scheme) {
                return true;
            }
        }

        return false;
    }

    public override void directory_loaded (void* user_data) {
        cancellable.cancel ();

        if (idle_consume_unknowns > 0) {
            Source.remove (idle_consume_unknowns);
            idle_consume_unknowns = 0;
        }

        unknowns.clear ();
        cancellable = new Cancellable ();

        directory = ((Object[]) user_data)[2] as GOF.File;
        assert (directory != null);
        debug ("CTags Plugin dir %s", directory.uri);
        is_user_dir = f_is_user_dir (directory.uri);
        ignore_dir = f_ignore_dir (directory.uri);
    }

    private void add_entry (GOF.File gof, GenericArray<Variant> entries) {
        return_if_fail (gof != null);

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
        if (directory == null) {
            warning ("Color tag plugin consume knowns queue called with null directory");
            return;
        }

        var entries = new GenericArray<Variant> ();
        GOF.File gof;
        while ((gof = knowns.pop_head ()) != null) {
            add_entry (gof, entries);
        }

        if (entries != null) {
            debug ("--- known entries %d", entries.length);
            try {
                yield daemon.record_uris (entries.data, directory.uri);
            } catch (Error err) {
                warning ("%s", err.message);
            }
        }
    }

    private async void consume_unknowns_queue () {
        if (directory == null) {
            warning ("Color tag plugin consume unknowns queue called with null directory");
            return;
        }

        GOF.File gof = null;
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

    private void add_to_knowns_queue (GOF.File file, FileInfo info) {
        return_if_fail (file != null && info != null);

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
                                        return false;
                                        });
    }

    private void add_to_unknowns_queue (GOF.File file) {
        return_if_fail (file != null);

        if (file.get_ftype () == "application/octet-stream") {
            unknowns.push_head (file);

            if (idle_consume_unknowns == 0) {
                idle_consume_unknowns = Idle.add (() => {
                                                  consume_unknowns_queue.begin ();
                                                  idle_consume_unknowns = 0;
                                                  return false;
                                                  });
            }
        }
    }

    private async void rreal_update_file_info (GOF.File file) {
        return_if_fail (file != null);

        if (!file.exists) {
            yield daemon.deleteEntry (file.uri);
            return;
        }

        try {
            var rc = yield daemon.get_uri_infos (file.uri);

            VariantIter iter = rc.iterator ();
            assert (iter.n_children () == 1);
            VariantIter row_iter = iter.next_value ().iterator ();

            if (row_iter.n_children () == 3) {
                uint64 modified = int64.parse (row_iter.next_value ().get_string ());
                unowned string type = row_iter.next_value ().get_string ();
                file.color = int.parse (row_iter.next_value ().get_string ());
                /* check modified time field only on user dirs. We don't want to query again and
                 * again system directories */
                file.icon_changed ();  /* Just need to trigger redraw - the underlying GFile has not changed */

                if (is_user_dir &&
                    file.info.get_attribute_uint64 (FileAttribute.TIME_MODIFIED) > modified) {
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

    private async void rreal_update_file_info_for_recent (GOF.File file, string? target_uri) {
        if (target_uri == null) { /* e.g. for recent:/// */
            return;
        }

        return_if_fail (file != null);

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

    public override void update_file_info (GOF.File file) {
        return_if_fail (file != null);

        if (!ignore_dir && file.info != null &&
            (!file.is_hidden || GOF.Preferences.get_default ().show_hidden_files)) {

            if (file.location.has_uri_scheme ("recent")) {
                rreal_update_file_info_for_recent.begin (file, file.get_display_target_uri ());
            } else {
                rreal_update_file_info.begin (file);
            }
        }
    }

    public override void context_menu  (Gtk.Widget? widget, GLib.List<unowned GOF.File> selected_files) {
        if (selected_files == null || widget == null || ignore_dir) {
            return;
        }

        var menu = widget as Gtk.Menu;
        var color_menu_item = new ColorWidget ();
        color_menu_item.color_changed.connect ((ncolor) => {
            set_color.begin (selected_files, ncolor);
        });

        add_menuitem (menu, new Gtk.SeparatorMenuItem ());
        add_menuitem (menu, color_menu_item);
    }

    private void add_menuitem (Gtk.Menu menu, Gtk.MenuItem menu_item) {
        menu.append (menu_item);
        menu_item.show ();
    }

    private async void set_color (GLib.List<unowned GOF.File> files, int n) throws IOError {
        var entries = new GenericArray<Variant> ();
        GOF.File target_file;

        foreach (unowned GOF.File file in files) {
            if (file == null) {
                continue;
            }

            if (file.location.has_uri_scheme ("recent")) {
                target_file = GOF.File.get_by_uri (file.get_display_target_uri ());
            } else {
                target_file = file;
            }

            target_file.color = n;
            add_entry (target_file, entries);
        }

        if (entries != null) {
            try {
                GOF.File first = (GOF.File) (files.data);
                yield daemon.record_uris (entries.data, first.uri);
                /* If the color of the target is set while in recent view, we have to
                 * update the recent view to reflect this */
                if (first.location.has_uri_scheme ("recent")) {
                    foreach (GOF.File file in files) {
                        update_file_info (file);
                        file.icon_changed (); /* Just need to trigger redraw */
                    }
                }
            } catch (Error err) {
                warning ("%s", err.message);
            }
        }
    }

    private class ColorWidget : Gtk.MenuItem {
        private new bool has_focus;
        private int height;
        public signal void color_changed (int ncolor);

        public ColorWidget () {
            set_size_request (150, 20);
            height = 20;

            button_press_event.connect (button_pressed_cb);
            draw.connect (on_draw);

            select.connect (() => {
                has_focus = true;
            });

            deselect.connect (() => {
                has_focus = false;
            });
        }

        private bool button_pressed_cb (Gdk.EventButton event) {
            determine_button_pressed_event (event);
            return true;
        }

        private void determine_button_pressed_event (Gdk.EventButton event) {
            int i;
            int btnw = 10;
            int btnh = 10;
            int y0 = (height - btnh) /2;
            int x0 = btnw+5;
            int xpad = 9;

            if (event.y >= y0 && event.y <= y0+btnh) {
                for (i=1; i<=10; i++) {
                    if (event.x>= xpad+x0*i && event.x <= xpad+x0*i+btnw) {
                        color_changed (i-1);
                        break;
                    }
                }
            }
        }

        protected bool on_draw (Cairo.Context cr) {
            int i;
            int btnw = 10;
            int btnh = 10;
            int y0 = (height - btnh) /2;
            int x0 = btnw+5;
            int xpad = 9;

            for (i=1; i<=10; i++) {
                if (i==1)
                    DrawCross (cr,xpad + x0*i, y0+1, btnw-2, btnh-2);
                else {
                    DrawRoundedRectangle (cr,xpad + x0*i, y0, btnw, btnh, "stroke", i-1);
                    DrawRoundedRectangle (cr,xpad + x0*i, y0, btnw, btnh, "fill", i-1);
                    DrawGradientOverlay (cr,xpad + x0*i, y0, btnw, btnh);
                }
            }

            return true;
        }

        private void DrawCross (Cairo.Context cr, int x, int y, int w, int h) {
            cr.new_path ();
            cr.set_line_width (2.0);
            cr.move_to (x, y);
            cr.rel_line_to (w, h);
            cr.move_to (x, y+h);
            cr.rel_line_to (w, -h);
            cr.set_source_rgba (0,0,0,0.6);
            cr.stroke();

            cr.close_path ();
        }

        /*
         * Create a rounded rectangle using the Bezier curve.
         * Adapted from http://cairographics.org/cookbook/roundedrectangles/
         */
        private void DrawRoundedRectangle (Cairo.Context cr, int x, int y, int w, int h, string style, int color) {
            int radius_x=2;
            int radius_y=2;
            double ARC_TO_BEZIER = 0.55228475;

            if (radius_x > w - radius_x)
                radius_x = w / 2;

            if (radius_y > h - radius_y)
                radius_y = h / 2;

            /* approximate (quite close) the arc using a bezier curve */
            double ca = ARC_TO_BEZIER * radius_x;
            double cb = ARC_TO_BEZIER * radius_y;

            cr.new_path ();
            cr.set_line_width (0.7);
            cr.set_tolerance (0.1);
            cr.move_to (x + radius_x, y);
            cr.rel_line_to (w - 2 * radius_x, 0.0);
            cr.rel_curve_to (ca, 0.0, radius_x, cb, radius_x, radius_y);
            cr.rel_line_to (0, h - 2 * radius_y);
            cr.rel_curve_to (0.0, cb, ca - radius_x, radius_y, -radius_x, radius_y);
            cr.rel_line_to (-w + 2 * radius_x, 0);
            cr.rel_curve_to (-ca, 0, -radius_x, -cb, -radius_x, -radius_y);
            cr.rel_line_to (0, -h + 2 * radius_y);
            cr.rel_curve_to (0.0, -cb, radius_x - ca, -radius_y, radius_x, -radius_y);

            switch (style) {
            default:
            case "fill":
                Gdk.RGBA rgba = Gdk.RGBA ();
                rgba.parse (GOF.Preferences.TAGS_COLORS[color]);
                Gdk.cairo_set_source_rgba (cr, rgba);
                cr.fill ();
                break;
            case "stroke":
                cr.set_source_rgba (0,0,0,0.5);
                cr.stroke ();
                break;
            }

            cr.close_path ();
        }

        /*
         * Draw the overlaying gradient
         */
        private void DrawGradientOverlay (Cairo.Context cr, int x, int y, int w, int h) {
            var radial = new Cairo.Pattern.radial (w, h, 1, 0.0, 0.0, 0.0);
            radial.add_color_stop_rgba (0, 0.3, 0.3, 0.3,0.0);
            radial.add_color_stop_rgba (1, 0.0, 0.0, 0.0,0.5);

            cr.set_source (radial);
            cr.rectangle (x,y,w,h);
            cr.fill ();
        }
    }
}

public Marlin.Plugins.Base module_init () {
    return new Marlin.Plugins.CTags ();
}

