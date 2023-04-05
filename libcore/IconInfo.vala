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


// Cache of Paintables, removed if not used withing reap time.
public class Files.IconInfo : GLib.Object {
    private static GLib.HashTable<Icon, Files.IconInfo> loadable_icon_cache;
    //TODO Do we need to reimplement thened icon cache?
    private static uint reap_cache_timeout = 0;
    private static uint reap_time = 5000;

    public static void set_reap_time (uint milliseconds) {
        if (milliseconds > 10 && milliseconds < 100000) {
            reap_time = milliseconds;
            if (end_reap_cache_timeout ()) {
                schedule_reap_cache ();
            }
        }
    }

    public static void remove_cache (string path) {
        if (loadable_icon_cache != null) {
            var loadable_key = new FileIcon (GLib.File.new_for_path (path));
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
            reap_cache_timeout = GLib.Timeout.add (reap_time, reap_cache);
        }
    }

    private static bool reap_cache () {
        bool reapable_icons_left = false;
        var time_now = GLib.get_monotonic_time ();
        var reap_time_extended = reap_time * 6;
        if (loadable_icon_cache != null) {
            loadable_icon_cache.foreach_remove ((loadableicon, icon_info) => {
                if (icon_info.paintable != null && icon_info.paintable.ref_count == 1) {
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

    public static Gdk.Paintable? lookup_paintable_from_path (string path) {
        var file_icon = new FileIcon (GLib.File.new_for_path (path));
        return Files.IconInfo.lookup_paintable (file_icon);
    }

    public static Gdk.Paintable? lookup_paintable (GLib.LoadableIcon loadable) {
        if (loadable_icon_cache == null) {
            loadable_icon_cache = new GLib.HashTable<Icon, Files.IconInfo> (Icon.hash, Icon.equal);
        } else {
            var icon_info = loadable_icon_cache.lookup (loadable);
            if (icon_info != null) {
                var paintable = icon_info.paintable;
                if (paintable == null) {
                    debug ("IconInfo with null paintable");
                } else {
                    return icon_info.paintable;
                }
            }
        }

        //TODO Paintable only has intrinsic dimensions from file so do not need size and scale in key?
        Gdk.Paintable paintable = null;
        try {
            paintable = Gdk.Texture.from_filename (loadable.to_string ());
        } catch (Error e) {
            debug ("Unable to load %s", loadable.to_string ());
        }

        if (paintable != null) {
            var icon_info = new IconInfo (paintable);
            try {
                loadable_icon_cache.insert ((Icon)loadable, icon_info);
            } catch (Error e) {
                debug ("Could not insert new icon info. %s", e.message);
            }
        } else {
            debug ("Null paintable after loading texture %s", loadable.to_string ());
        }

        return paintable;
    }

    /*
     * This is required for testing themed icon functions under ctest when there is no default screen and
     * we have to set the icon theme manually.  We assume that any system being used for testing will have
     * the "hicolor" theme.
     */
    public static Gtk.IconTheme get_icon_theme () {
        var display = Gdk.Display.get_default ();
        if (display != null) {
            return Gtk.IconTheme.get_for_display (display);
        } else {
            var theme = new Gtk.IconTheme ();
            theme.set_theme_name ("hicolor");
            return theme;
        }
    }

    /* FOR TESTING */
    public static uint loadable_icon_cache_info () {
        uint size = 0u;
        if (loadable_icon_cache != null) {
            size = loadable_icon_cache.size ();
        }

        return size;
    }

    /* INSTANCE METHODS */
    private int64 last_use_time;
    public Gdk.Paintable paintable { get; construct; }

    public IconInfo (Gdk.Paintable paintable) {
        Object (
            paintable: paintable
        );
    }

    construct {
        last_use_time = GLib.get_monotonic_time ();
        schedule_reap_cache ();
    }

    public bool is_fallback () {
        return paintable == null;
    }

    public Gdk.Paintable? get_paintable_nodefault () {
        last_use_time = GLib.get_monotonic_time ();
        return paintable;
    }
}
