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
    public enum ColumnID {
        FILE_COLUMN,
        COLOR,
        PIXBUF,
        FILENAME,
        SIZE,
        TYPE,
        MODIFIED,
        NUM_COLUMNS;

        public static ColumnID from_string (string column_id) {
            switch (column_id) {
                case "name":
                    return ColumnID.FILENAME;
                case "size":
                    return ColumnID.SIZE;
                case "type":
                    return ColumnID.TYPE;
                case "modified":
                    return ColumnID.MODIFIED;
                default:
                    critical ("invalid sort name %s", column_id);
                    return ColumnID.FILENAME;
            }
        }

        public unowned string to_string () {
            switch (this) {
                case ColumnID.FILENAME:
                    return "name";
                case ColumnID.SIZE:
                    return "size";
                case ColumnID.TYPE:
                    return "type";
                case ColumnID.MODIFIED:
                    return "modified";
                default:
                    critical ("COLUMN id %u unsupported", this);
                    return "";
            }
        }
    }

    // Indicates where on a view a click occurred
    protected enum ClickZone {
        EXPANDER,
        HELPER,
        ICON,
        NAME,
        BLANK_PATH,
        BLANK_NO_PATH,
        INVALID
    }

    public enum WindowState {
        NORMAL,
        TILED_LEFT,
        TILED_RIGHT,
        TILED_BOTTOM,
        TILED_TOP,
        MAXIMIZED,
        INVALID;

        // public string to_string () {
        //     switch (this) {
        //         case NORMAL:
        //             return "Marlin.WindowState.NORMAL";
        //         case TILED_LEFT:
        //             return "Marlin.WindowState.TILED_LEFT";
        //         case TILED_RIGHT:
        //             return "Marlin.WindowState.TILED_RIGHT";
        //         case MAXIMIZED:
        //             return "Marlin.WindowState.MAXIMIZED";
        //         default:
        //             return "Marlin.WindowState.INVALID";
        //     }
        // }

        public static Files.WindowState from_gdk_toplevel_state (Gdk.ToplevelState state) {

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
            return this == TILED_LEFT | this == TILED_RIGHT || this == TILED_BOTTOM || this == TILED_TOP;
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
}
