/* Copyright (c) 2018 elementary LLC (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

public class Files.IconInfo : GLib.Object {
    public static bool is_testing_remote = false;

    private int64 last_use_time;
    private Gdk.Paintable? _paintable = null;
    public Gdk.Paintable? paintable {
        get {
            return _paintable;
        }

        set {
            _paintable = value;
        }
    }

    public string icon_name { get; construct; }

    public IconInfo (Gdk.Paintable paintable, string name) {
        Object (
            paintable: paintable,
            icon_name: name
        );

    }

    construct {
        last_use_time = GLib.get_monotonic_time ();
        schedule_reap_cache ();
    }

    public static Files.IconInfo? lookup_by_gicon (
        GLib.Icon gicon,
        int size,
        int scale,
        bool is_remote
    ) {
        if (gicon is FileIcon) {
            return lookup_fileicon (
                (FileIcon) gicon,
                size,
                scale,
                is_remote || is_testing_remote
            );
        } else {
            var theme = get_icon_theme ();
            var icon_paintable = theme.lookup_by_gicon (
                gicon,
                size,
                scale,
                Gtk.TextDirection.NONE,
                Gtk.IconLookupFlags.PRELOAD
            );

            assert_nonnull (icon_paintable);
            return new IconInfo (icon_paintable, icon_paintable.icon_name);
        }
    }

    private static Files.IconInfo lookup_fileicon (
        FileIcon ficon,
        int size,
        int scale,
        bool is_remote
    ) {
        size = int.max (1, size);
        Gdk.Paintable? tx = null;
        Files.IconInfo? icon_info = null;

        if (is_remote) {
            icon_info = lookup_cache (ficon, size, scale );
        }

        if (icon_info == null) {
            try {
                tx = Gdk.Texture.from_file (ficon.file);
            } catch (Error e) {
                debug ("Error creating texture for %s", ficon.file.get_uri ());
            }

            if (tx != null) {
                icon_info = new IconInfo (tx, ficon.file.get_basename ());
                if (is_remote) {
                    loadable_icon_cache.insert (
                        new LoadableIconKey (ficon, size, scale),
                        icon_info
                    );
                }
            }
        }

        if (icon_info != null) {
            icon_info.last_use_time = get_monotonic_time ();
        }

        return icon_info;
    }

    public static Files.IconInfo? get_generic_icon (int size, int scale) {
        var generic_icon = new GLib.ThemedIcon ("text-x-generic");
        return IconInfo.lookup_by_gicon (generic_icon, size, scale, false);
    }

    /*
     * Use for testing only
     */

    /*
     * This is required for testing themed icon functions under ctest when there is no default screen and
     * we have to set the icon theme manually.  We assume that any system being used for testing will have
     * the "Adwaita" theme.
     */
    public static Gtk.IconTheme get_icon_theme () {
        if (Gdk.Display.get_default () != null) {
            return Gtk.IconTheme.get_for_display (Gdk.Display.get_default ());
        } else {
            var theme = new Gtk.IconTheme ();
            theme.set_theme_name ("Adwaita");
            return theme;
        }
    }

    public static uint loadable_icon_cache_info () {
        uint size = 0u;
        if (loadable_icon_cache != null) {
            size = loadable_icon_cache.size ();
        }

        return size;
    }

    /*
     * This is the part of the icon cache
     */

    private static GLib.HashTable<LoadableIconKey, Files.IconInfo> loadable_icon_cache;
    private static uint reap_cache_timeout = 0;
    private static int64 reap_time = 5000 * 1000;

    [Compact]
    private class LoadableIconKey {
        public GLib.Icon icon;
        public int size;
        public int scale;

        public LoadableIconKey (GLib.Icon _icon, int _size, int _scale) {
            icon = _icon;
            size = _size;
            scale = _scale;
        }

        public LoadableIconKey.from_path (string path, int _size, int _scale) {
            icon = new GLib.FileIcon (GLib.File.new_for_path (path));
            size = _size;
            scale = _scale;
        }

        public static uint hash (LoadableIconKey a) {
            return a.icon.hash () ^ a.size;
        }

        public static bool equal (LoadableIconKey a, LoadableIconKey b) {
            return (a.size == b.size && a.scale == b.scale && a.icon.equal (b.icon));
        }
    }

    private static Files.IconInfo? lookup_cache (FileIcon ficon, int size, int scale) {
        if (loadable_icon_cache == null) {
            loadable_icon_cache = new GLib.HashTable<LoadableIconKey, Files.IconInfo> (
                LoadableIconKey.hash,
                LoadableIconKey.equal
            );

            return null;
        } else {
            return loadable_icon_cache.lookup (new LoadableIconKey (ficon, size, scale));
        }
    }

    public static void remove_cache (string path, int size, int scale) {
        if (loadable_icon_cache != null) {
            var loadable_key = new LoadableIconKey.from_path (path, size, scale);
            loadable_icon_cache.remove (loadable_key);
        }
    }

    private static bool end_reap_cache_timeout () {
        if (reap_cache_timeout > 0) {
            GLib.Source.remove (reap_cache_timeout);
            reap_cache_timeout = 0;
            return true;
        }

        return false;
    }

    private static void schedule_reap_cache () {
        if (reap_cache_timeout == 0) {
            reap_cache_timeout = GLib.Timeout.add ((int) reap_time, reap_cache);
        }
    }

    public static void set_reap_time (int milliseconds) {
        if (milliseconds > 10 && milliseconds < 100000) {
            reap_time = milliseconds; // Convert to microseconds
            if (end_reap_cache_timeout ()) {
                schedule_reap_cache ();
            }
        }
    }

    private static bool reap_cache () {
        bool reapable_icons_left = false;
        var time_now = GLib.get_monotonic_time ();
        int64 reap_time_extended = (int64) (reap_time * 6000);
        if (loadable_icon_cache != null) {
            // Only reap cached icons that are no longer referenced by any other object
            loadable_icon_cache.foreach_remove ((loadableicon, icon_info) => {
                if (icon_info.paintable != null && icon_info.paintable.ref_count <= 2) {
                    if ((time_now - icon_info.last_use_time) > reap_time_extended) {
                        return true;
                    }
                }

                return false;
            });

            reapable_icons_left |= (loadable_icon_cache.size () > 0);
        }

        if (reapable_icons_left) {
            return GLib.Source.CONTINUE;
        } else {
            reap_cache_timeout = 0;
            return GLib.Source.REMOVE;
        }
    }

    public static void clear_caches () {
        if (loadable_icon_cache != null) {
            loadable_icon_cache.remove_all ();
        }
    }

}
