/***
    Copyright (c) 2006-2007 Benedikt Meurer <benny@xfce.org>
    Copyright (c) 2009 Jannis Pohlmann <jannis@xfce.org>
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.

    This program is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
    more details.

    You should have received a copy of the GNU General Public License along with
    this program; if not, write to the Free Software Foundation, Inc., 51 Franklin Street,
    Fifth Floor, Boston, MA 02110-1335 USA.
 ***/

namespace Marlin {
    public enum WindowState {
        NORMAL,
        TILED_START,
        TILED_END,
        MAXIMIZED,
        INVALID;

        public string to_string () {
            switch (this) {
                case NORMAL:
                    return "Marlin.WindowState.NORMAL";
                case TILED_START:
                    return "Marlin.WindowState.TILED_START";
                case TILED_END:
                    return "Marlin.WindowState.TILED_END";
                case MAXIMIZED:
                    return "Marlin.WindowState.MAXIMIZED";
                default:
                    return "Marlin.WindowState.INVALID";
            }
        }

        public static Marlin.WindowState from_gdk_window_state (Gdk.WindowState state, bool start = true) {
            if (Gdk.WindowState.MAXIMIZED in state || Gdk.WindowState.FULLSCREEN in state) {
                return Marlin.WindowState.MAXIMIZED;
            } else if (Gdk.WindowState.TILED in state) {
                return start ? Marlin.WindowState.TILED_START : Marlin.WindowState.TILED_END;
            } else {
                return Marlin.WindowState.NORMAL;
            }
        }

        public bool is_tiled () {
            return this == TILED_START | this == TILED_END;
        }

        public bool is_maximized () {
            return this == MAXIMIZED;
        }
    }



    public enum ViewMode {
        /* First three modes must match the corresponding mode switch indices */
        ICON = 0,
        LIST = 1,
        MILLER_COLUMNS = 2,
        CURRENT,
        PREFERRED,
        INVALID
    }

    public enum OpenFlag {
        DEFAULT,
        NEW_ROOT,
        NEW_TAB,
        NEW_WINDOW,
        APP
    }

    public enum ZoomLevel {
        SMALLEST,
        SMALLER,
        SMALL,
        NORMAL,
        LARGE,
        LARGER,
        HUGE,
        HUGER,
        LARGEST,
        N_LEVELS,
        INVALID
    }

    public enum IconSize {
        EMBLEM = 16,
        SMALLEST = 16,
        LARGE_EMBLEM = 24,
        SMALLER = 24,
        SMALL = 32,
        NORMAL = 48,
        LARGE = 64,
        LARGER = 96,
        HUGE = 128,
        HUGER = 192,
        LARGEST = 256
    }

    public static IconSize zoom_level_to_icon_size (ZoomLevel zoom_level) {
        switch (zoom_level) {
            case ZoomLevel.SMALLEST:
                return IconSize.SMALLEST;

            case ZoomLevel.SMALLER:
                return IconSize.SMALLER;

            case ZoomLevel.SMALL:
                return IconSize.SMALL;

            case ZoomLevel.NORMAL:
                return IconSize.NORMAL;

            case ZoomLevel.LARGE:
                return IconSize.LARGE;

            case ZoomLevel.LARGER:
                return IconSize.LARGER;

            case ZoomLevel.HUGE:
                return IconSize.HUGE;

            case ZoomLevel.HUGER:
                return IconSize.HUGER;

            default:
                 return IconSize.LARGEST;
        }
    }

    public static ZoomLevel zoom_level_get_nearest_from_value (int size) {
        if (size <= IconSize.SMALLEST) {
            return ZoomLevel.SMALLEST;
        }

        if (size <= IconSize.SMALLER) {
            return ZoomLevel.SMALLER;
        }

        if (size <= IconSize.SMALL) {
            return ZoomLevel.SMALL;
        }

        if (size <= IconSize.NORMAL) {
            return ZoomLevel.NORMAL;
        }

        if (size <= IconSize.LARGE) {
            return ZoomLevel.LARGE;
        }

        if (size <= IconSize.LARGER) {
            return ZoomLevel.LARGER;
        }

        if (size <= IconSize.HUGE) {
            return ZoomLevel.HUGE;
        }

        if (size <= IconSize.HUGER) {
            return ZoomLevel.HUGER;
        }

        return ZoomLevel.LARGEST;
    }

    public static Gtk.IconSize zoom_level_to_stock_icon_size (ZoomLevel zoom_level) {
        switch (zoom_level) {
            case ZoomLevel.SMALLEST:
                return Gtk.IconSize.MENU;

            case ZoomLevel.SMALLER:
                return Gtk.IconSize.SMALL_TOOLBAR;

            case ZoomLevel.SMALL:
                return Gtk.IconSize.LARGE_TOOLBAR;

            case ZoomLevel.NORMAL:
            case ZoomLevel.LARGE:
            case ZoomLevel.LARGER:
            case ZoomLevel.HUGE:
            case ZoomLevel.HUGER:
            case ZoomLevel.LARGEST:
                return Gtk.IconSize.DIALOG;

            default:
                assert_not_reached ();
        }
    }

    public enum TargetType {
        STRING,
        TEXT_URI_LIST,
        XDND_DIRECT_SAVE0,
        NETSCAPE_URL,
        BOOKMARK_ROW
    }
}
