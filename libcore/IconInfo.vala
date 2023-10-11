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
    private int64 last_use_time;
    private Gdk.Pixbuf? pixbuf;
    private string icon_name;

    public Files.IconInfo.for_pixbuf (Gdk.Pixbuf? pixbuf) {
        this.pixbuf = pixbuf;
    }

    public Files.IconInfo.for_icon_info (Gtk.IconInfo icon_info) {
        try {
            pixbuf = icon_info.load_icon ();
        } catch (Error e) {
            critical (e.message);
        }

        var filename = icon_info.get_filename ();
        if (filename != null) {
            filename = GLib.Path.get_basename (filename);
            var last = filename.last_index_of_char ('.');
            icon_name = filename.substring (0, last);
        }
    }

    construct {
        last_use_time = GLib.get_monotonic_time ();
        schedule_reap_cache ();
        pixbuf = null;
    }

    public static Files.IconInfo? lookup (
        GLib.Icon icon,
        int size,
        int scale,
        bool cache_loadable = false
    ) {
        size = int.max (1, size);

        IconInfo? icon_info = null;
        if (icon is GLib.LoadableIcon) {
            if (cache_loadable) {
                if (loadable_icon_cache == null) {
                    loadable_icon_cache = new GLib.HashTable<LoadableIconKey, Files.IconInfo> (
                        LoadableIconKey.hash,
                        LoadableIconKey.equal
                    );
                } else {
                    icon_info = loadable_icon_cache.lookup (new LoadableIconKey (icon, size, scale));
                    if (icon_info != null) {
                        return icon_info;
                    }
                }
            }

            var str_icon = icon.to_string ();
            int width;
            int height;
            Gdk.Pixbuf.get_file_info (str_icon, out width, out height);
            Gdk.Pixbuf pixbuf = null;
            if ((width >= 1 || width == -1) && (height >= 1 || height == -1)) {
                try {
                    pixbuf = new Gdk.Pixbuf.from_file_at_scale (str_icon, int.min (size, width) * scale,
                                                                int.min (size, height) * scale, true);
                } catch (Error e) {
                    critical (e.message);
                }
            }

            if (pixbuf != null) {
                icon_info = new IconInfo.for_pixbuf (pixbuf);
                if (cache_loadable) {
                    loadable_icon_cache.insert (new LoadableIconKey (icon, size, scale), icon_info);
                }
            }

            return icon_info;
        } else if (icon is GLib.ThemedIcon) {
            var theme = get_icon_theme ();
            Gtk.IconInfo? gtkicon_info = null;
            // lookup_by_gicon_for_scale is treating all the icons equally, keep using the first found one before any fallback one
            foreach (unowned string name in ((GLib.ThemedIcon) icon).get_names ()) {
                gtkicon_info = theme.lookup_icon_for_scale (name, size, scale, Gtk.IconLookupFlags.FORCE_SIZE);
                if (gtkicon_info != null)
                    break;
            }

            if (gtkicon_info != null) {
                icon_info = new Files.IconInfo.for_icon_info (gtkicon_info);
            }

            return icon_info;
        } else {
            var theme = get_icon_theme ();
            try {
                var gtk_icon_info = theme.lookup_by_gicon_for_scale (icon, size, scale,
                                                                     Gtk.IconLookupFlags.GENERIC_FALLBACK);
                var pixbuf = gtk_icon_info.load_icon ();
                return new Files.IconInfo.for_pixbuf (pixbuf);
            } catch (Error e) {
                critical (e.message);
                return new Files.IconInfo.for_pixbuf (null);
            }
        }
    }

    public static Files.IconInfo? get_generic_icon (int size, int scale) {
        var generic_icon = new GLib.ThemedIcon ("text-x-generic");
        return IconInfo.lookup (generic_icon, size, scale);
    }

    public static Files.IconInfo? lookup_from_name (string icon_name, int size, int scale) {
        var themed_icon = new GLib.ThemedIcon (icon_name);
        return Files.IconInfo.lookup (themed_icon, size, scale);
    }

    public static Files.IconInfo? lookup_from_path (string? path, int size, int scale, bool is_remote = false) {
        if (path != null) {
            var file_icon = new GLib.FileIcon (GLib.File.new_for_path (path));
            return Files.IconInfo.lookup (file_icon, size, scale, is_remote);
        }

        return null;
    }

    public bool is_fallback () {
        return pixbuf == null;
    }

    public Gdk.Pixbuf? get_pixbuf_nodefault () {
        last_use_time = GLib.get_monotonic_time ();
        return pixbuf;
    }

    /*
     * Use for testing only
     */

    /*
     * This is required for testing themed icon functions under ctest when there is no default screen and
     * we have to set the icon theme manually.  We assume that any system being used for testing will have
     * the "hicolor" theme.
     */
    public static Gtk.IconTheme get_icon_theme () {
        if (Gdk.Screen.get_default () != null) {
            return Gtk.IconTheme.get_default ();
        } else {
            var theme = new Gtk.IconTheme ();
            theme.set_custom_theme ("hicolor");
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

    public static uint themed_icon_cache_info () {
        uint size = 0u;
        if (themed_icon_cache != null) {
            size = themed_icon_cache.size ();
        }

        return size;
    }

    /*
     * This is the part of the icon cache
     */

    private static GLib.HashTable<LoadableIconKey, Files.IconInfo> loadable_icon_cache;
    private static GLib.HashTable<ThemedIconKey, Files.IconInfo> themed_icon_cache;
    private static uint reap_cache_timeout = 0;
    private static uint reap_time = 5000;

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

        public LoadableIconKey dup () {
            return new LoadableIconKey (icon, size, scale);
        }

        public static uint hash (LoadableIconKey a) {
            return a.icon.hash () ^ a.size;
        }

        public static bool equal (LoadableIconKey a, LoadableIconKey b) {
            return (a.size == b.size && a.scale == b.scale && a.icon.equal (b.icon));
        }
    }

    [Compact]
    private class ThemedIconKey {
        public GLib.ThemedIcon icon;
        public int size;
        public int scale;

        public ThemedIconKey (GLib.ThemedIcon _icon, int _size, int _scale) {
            icon = _icon;
            size = _size;
            scale = _scale;
        }

        public uint hash () {
            return icon.hash () ^ (size * scale);
        }

        public bool equal (ThemedIconKey other) {
            if (this.size != other.size || this.scale != other.scale)
                return false;

            return this.icon.equal (other.icon);
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
            reap_cache_timeout = GLib.Timeout.add (reap_time, reap_cache);
        }
    }

    public static void set_reap_time (uint milliseconds) {
        if (milliseconds > 10 && milliseconds < 100000) {
            reap_time = milliseconds;
            if (end_reap_cache_timeout ()) {
                schedule_reap_cache ();
            }
        }
    }

    private static bool reap_cache () {
        bool reapable_icons_left = false;
        var time_now = GLib.get_monotonic_time ();
        var reap_time_extended = reap_time * 6;
        if (loadable_icon_cache != null) {
            // Only reap cached icons that are no longer referenced by any other object
            loadable_icon_cache.foreach_remove ((loadableicon, icon_info) => {
                if (icon_info.pixbuf != null && icon_info.pixbuf.ref_count == 1) {
                    if ((time_now - icon_info.last_use_time) > reap_time_extended) {
                        return true;
                    }
                }

                return false;
            });

            reapable_icons_left |= (loadable_icon_cache.size () > 0);
        }

        if (themed_icon_cache != null) {
            themed_icon_cache.foreach_remove ((themedicon, icon_info) => {
                if (icon_info.pixbuf != null && icon_info.pixbuf.ref_count == 1) {
                    if ((time_now - icon_info.last_use_time) > reap_time_extended) {
                        return true;
                    }
                }

                return false;
            });

            reapable_icons_left |= (themed_icon_cache.size () > 0);
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

        if (themed_icon_cache != null) {
            themed_icon_cache.remove_all ();
        }
    }

}
