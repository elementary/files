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

        public static Files.WindowState from_gdk_window_state (Gdk.WindowState state, bool start = true) {
            if (Gdk.WindowState.MAXIMIZED in state || Gdk.WindowState.FULLSCREEN in state) {
                return Files.WindowState.MAXIMIZED;
            } else if (Gdk.WindowState.TILED in state) {
                return start ? Files.WindowState.TILED_START : Files.WindowState.TILED_END;
            } else {
                return Files.WindowState.NORMAL;
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

    public enum SortBy {
        NAME,
        CREATED,
        MODIFIED,
        SIZE;

        public string to_string () {
            switch (this) {
                case SortBy.NAME:
                    return _("Name");

                case SortBy.CREATED:
                    return _("Creation Date");

                case SortBy.MODIFIED:
                    return _("Last modification date");

                case SortBy.SIZE:
                    return _("Size");

                default:
                    assert_not_reached ();
            }
        }
    }

    public enum RenameStatus {
        VALID,
        IGNORED,
        INVALID
    }

    public enum RenameMode {
        TEXT,
        NUMBER_SEQUENCE,
        DATETIME,
        INVALID;

        public string to_string () {
            switch (this) {
                case RenameMode.NUMBER_SEQUENCE:
                    return _("Number sequence");

                case RenameMode.TEXT:
                    return _("Text");

                case RenameMode.DATETIME:
                    return _("Date");

                default:
                    assert_not_reached ();
            }
        }
    }

    public enum RenamePosition {
        SUFFIX,
        PREFIX,
        INVALID;

        public string to_string () {
            switch (this) {
                case RenamePosition.SUFFIX:
                    return _("Suffix");

                case RenamePosition.PREFIX:
                    return _("Prefix");

                default:
                    assert_not_reached ();
            }
        }

        public string to_placeholder () {
            switch (this) {
                case RenamePosition.SUFFIX:
                    return _("Text to put at the end");

                case RenamePosition.PREFIX:
                    return _("Text to put at the start");

                default:
                    assert_not_reached ();
            }
        }
    }

    public enum RenameDateFormat {
        DEFAULT,
        DEFAULT_DATETIME,
        LOCALE,
        ISO_DATE,
        ISO_DATETIME,
        INVALID;

        public string to_string () {
            switch (this) {
                case RenameDateFormat.DEFAULT:
                    return _("Default Format - Date only");
                case RenameDateFormat.DEFAULT_DATETIME:
                    return _("Default Format - Date and Time");
                case RenameDateFormat.LOCALE:
                    return _("Locale Format - Date and Time");
                case RenameDateFormat.ISO_DATE:
                    return _("ISO 8601 Format - Date only");
                case RenameDateFormat.ISO_DATETIME:
                    return _("ISO 8601 Format - Date and Time");
                default:
                    assert_not_reached ();
            }
        }
    }

    public enum RenameDateSource {
        DEFAULT,
        MODIFIED,
        NOW,
        INVALID;

        public string to_string () {
            switch (this) {
                case RenameDateSource.DEFAULT:
                    return _("Date created");
                case RenameDateSource.MODIFIED:
                    return _("Date Modified");
                case RenameDateSource.NOW:
                    return _("Current Date");
                default:
                    assert_not_reached ();
            }
        }
    }
}
