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

namespace Files {
    public enum WindowState {
        NORMAL,
        TILED_LEFT,
        TILED_RIGHT,
        TILED_BOTTOM,
        TILED_TOP,
        MAXIMIZED,
        INVALID;

        public static Files.WindowState from_gdk_toplevel_state (
            Gdk.ToplevelState state
        ) {

            if (Gdk.ToplevelState.MAXIMIZED in state) {
                return Files.WindowState.MAXIMIZED;
            } else if (Gdk.ToplevelState.LEFT_TILED in state) {
                return Files.WindowState.TILED_LEFT;
            } else if (Gdk.ToplevelState.RIGHT_TILED in state) {
                return Files.WindowState.TILED_RIGHT;
            } else if (Gdk.ToplevelState.BOTTOM_TILED in state) {
                return Files.WindowState.TILED_BOTTOM;
            } else if (Gdk.ToplevelState.TOP_TILED in state) {
                return Files.WindowState.TILED_TOP;
            } else {
                return Files.WindowState.NORMAL;
            }
        }

        public bool is_tiled () {
            return this == TILED_LEFT ||
                   this == TILED_RIGHT ||
                   this == TILED_BOTTOM ||
                   this == TILED_TOP;
        }

        public bool is_maximized () {
            return this == MAXIMIZED;
        }
    }

    public enum SortType {
        FILE_COLUMN,
        COLOR,
        PIXBUF,
        FILENAME,
        SIZE,
        TYPE,
        MODIFIED,
        CUSTOM;

        public static SortType from_string (string sort_name) {
            switch (sort_name) {
                case "name":
                    return SortType.FILENAME;
                case "size":
                    return SortType.SIZE;
                case "type":
                    return SortType.TYPE;
                case "modified":
                    return SortType.MODIFIED;
                default:
                    return SortType.FILENAME;
            }
        }

        public unowned string to_string () {
            switch (this) {
                case SortType.FILENAME:
                    return "name";
                case SortType.SIZE:
                    return "size";
                case SortType.TYPE:
                    return "type";
                case SortType.MODIFIED:
                    return "modified";
                default:
                    critical ("COLUMN id %u unsupported", this);
                    return "";
            }
        }
    }

    public enum ViewMode {
        /* First three modes must match the corresponding mode switch indices */
        ICON = 0,
        LIST,
        MULTICOLUMN,
        CURRENT,
        PREFERRED,
        INVALID
    }

    public enum OpenFlag {
        DEFAULT,
        APPEND,
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
        INVALID;

        public IconSize to_icon_size () {
            switch (this) {
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

    public enum TargetType {
        STRING,
        TEXT_URI_LIST,
        XDND_DIRECT_SAVE0,
        NETSCAPE_URL,
        BOOKMARK_ROW
    }

    public enum Permissions.Type {
        USER,
        GROUP,
        OTHER
    }

    public enum Permissions.Value {
        READ,
        WRITE,
        EXE
    }

    public static bool is_chmod_code (string str) {
        try {
            var regex = new Regex ("^[0-7]{3}$");
            if (regex.match (str)) {
                return true;
            }
        } catch (RegexError e) {
            assert_not_reached ();
        }

        return false;
    }

    public enum PathBarMode {
        CRUMBS,
        ENTRY,
        SEARCH
    }
}
