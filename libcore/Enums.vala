/***
    Copyright (c) 2006-2007 Benedikt Meurer <benny@xfce.org>
    Copyright (c) 2009 Jannis Pohlmann <jannis@xfce.org>
    Copyright (c) 2015-2017 elementary LLC (http://launchpad.net/elementary)

    This program is free software; you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the Free
    Software Foundation; either version 2 of the License, or (at your option)
    any later version.

    This program is distributed in the hope that it will be useful, but WITHOUT
    ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
    FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
    more details.

    You should have received a copy of the GNU General Public License along with
    this program; if not, write to the Free Software Foundation, Inc., 59 Temple
    Place, Suite 330, Boston, MA  02111-1307  USA
 ***/

namespace Marlin {
    public enum ViewMode {
        ICON,
        LIST,
        MILLER_COLUMNS,
        CURRENT,
        PREFERRED,
        INVALID
    }

    public enum OpenFlag {
        DEFAULT,
        NEW_ROOT,
        NEW_TAB,
        NEW_WINDOW
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
        N_LEVELS
    }

    public enum IconSize {
        SMALLEST = 16,
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
        if (size <= IconSize.SMALLEST)
            return ZoomLevel.SMALLEST;

        if (size <= IconSize.SMALLER)
            return ZoomLevel.SMALLER;

        if (size <= IconSize.SMALL)
            return ZoomLevel.SMALL;

        if (size <= IconSize.NORMAL)
            return ZoomLevel.NORMAL;

        if (size <= IconSize.LARGE)
            return ZoomLevel.LARGE;

        if (size <= IconSize.LARGER)
            return ZoomLevel.LARGER;

        if (size <= IconSize.HUGE)
            return ZoomLevel.HUGE;

        if (size <= IconSize.HUGER)
            return ZoomLevel.HUGER;

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
        NETSCAPE_URL
    }
}
