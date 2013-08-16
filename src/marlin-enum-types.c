/*-
 * Copyright (c) 2006-2007 Benedikt Meurer <benny@xfce.org>
 * Copyright (c) 2009 Jannis Pohlmann <jannis@xfce.org>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc., 59 Temple
 * Place, Suite 330, Boston, MA  02111-1307  USA
 */

#include "marlin-enum-types.h"

#define I_(string) (g_intern_static_string ((string)))

GType
marlin_icon_size_get_type (void)
{
    static GType type = G_TYPE_INVALID;

    if (G_UNLIKELY (type == G_TYPE_INVALID))
    {
        static const GEnumValue values[] =
        {
            { MARLIN_ICON_SIZE_SMALLEST, "MARLIN_ICON_SIZE_SMALLEST", "smallest", },
            { MARLIN_ICON_SIZE_SMALLER,  "MARLIN_ICON_SIZE_SMALLER",  "smaller",  },
            { MARLIN_ICON_SIZE_SMALL,    "MARLIN_ICON_SIZE_SMALL",    "small",    },
            { MARLIN_ICON_SIZE_NORMAL,   "MARLIN_ICON_SIZE_NORMAL",   "normal",   },
            { MARLIN_ICON_SIZE_LARGE,    "MARLIN_ICON_SIZE_LARGE",    "large",    },
            { MARLIN_ICON_SIZE_LARGER,   "MARLIN_ICON_SIZE_LARGER",   "larger",   },
            { MARLIN_ICON_SIZE_LARGEST,  "MARLIN_ICON_SIZE_LARGEST",  "largest",  },
            { 0,                         NULL,                        NULL,       },
        };

        type = g_enum_register_static (I_("MarlinIconSize"), values);
    }

    return type;
}

static void
marlin_icon_size_from_zoom_level (const GValue *src_value,
                                  GValue       *dst_value)
{
    g_value_set_enum (dst_value, marlin_zoom_level_to_icon_size (g_value_get_enum (src_value)));
}

GType
marlin_zoom_level_get_type (void)
{
    static GType type = G_TYPE_INVALID;

    if (G_UNLIKELY (type == G_TYPE_INVALID))
    {
        static const GEnumValue values[] =
        {
            { MARLIN_ZOOM_LEVEL_SMALLEST, "MARLIN_ZOOM_LEVEL_SMALLEST", "smallest", },
            { MARLIN_ZOOM_LEVEL_SMALLER,  "MARLIN_ZOOM_LEVEL_SMALLER",  "smaller",  },
            { MARLIN_ZOOM_LEVEL_SMALL,    "MARLIN_ZOOM_LEVEL_SMALL",    "small",    },
            { MARLIN_ZOOM_LEVEL_NORMAL,   "MARLIN_ZOOM_LEVEL_NORMAL",   "normal",   },
            { MARLIN_ZOOM_LEVEL_LARGE,    "MARLIN_ZOOM_LEVEL_LARGE",    "large",    },
            { MARLIN_ZOOM_LEVEL_LARGER,   "MARLIN_ZOOM_LEVEL_LARGER",   "larger",   },
            { MARLIN_ZOOM_LEVEL_LARGEST,  "MARLIN_ZOOM_LEVEL_LARGEST",  "largest",  },
            { 0,                          NULL,                         NULL,       },
        };

        type = g_enum_register_static (I_("MarlinZoomLevel"), values);

        /* register transformation function for MarlinZoomLevel->MarlinIconSize */
        g_value_register_transform_func (type, MARLIN_TYPE_ICON_SIZE, marlin_icon_size_from_zoom_level);
    }

    return type;
}


/**
 * marlin_zoom_level_to_icon_size:
 * @zoom_level : a #MarlinZoomLevel.
 *
 * Returns the #MarlinIconSize corresponding to the @zoom_level.
 *
 * Return value: the #MarlinIconSize for @zoom_level.
**/
MarlinIconSize
marlin_zoom_level_to_icon_size (MarlinZoomLevel zoom_level)
{
    switch (zoom_level)
    {
    case MARLIN_ZOOM_LEVEL_SMALLEST: return MARLIN_ICON_SIZE_SMALLEST;
    case MARLIN_ZOOM_LEVEL_SMALLER:  return MARLIN_ICON_SIZE_SMALLER;
    case MARLIN_ZOOM_LEVEL_SMALL:    return MARLIN_ICON_SIZE_SMALL;
    case MARLIN_ZOOM_LEVEL_NORMAL:   return MARLIN_ICON_SIZE_NORMAL;
    case MARLIN_ZOOM_LEVEL_LARGE:    return MARLIN_ICON_SIZE_LARGE;
    case MARLIN_ZOOM_LEVEL_LARGER:   return MARLIN_ICON_SIZE_LARGER;
    default:                         return MARLIN_ICON_SIZE_LARGEST;
    }
}

/**
 * marlin_zoom_level_to_stock_icon_size:
 * @zoom_level : a #MarlinZoomLevel.
 *
 * Returns: the #GtkIconSize for @zoom_level.
**/
GtkIconSize
marlin_zoom_level_to_stock_icon_size (MarlinZoomLevel zoom_level)
{
    switch (zoom_level)
    {
    case MARLIN_ZOOM_LEVEL_SMALLEST:
        return GTK_ICON_SIZE_MENU;

    case MARLIN_ZOOM_LEVEL_SMALLER:
        return GTK_ICON_SIZE_SMALL_TOOLBAR;

    case MARLIN_ZOOM_LEVEL_SMALL:
        return GTK_ICON_SIZE_LARGE_TOOLBAR;

    case MARLIN_ZOOM_LEVEL_NORMAL:
    case MARLIN_ZOOM_LEVEL_LARGE:
    case MARLIN_ZOOM_LEVEL_LARGER:
    case MARLIN_ZOOM_LEVEL_LARGEST:
        return GTK_ICON_SIZE_DIALOG;

    default:
        g_assert_not_reached ();
    }
}

MarlinZoomLevel
marlin_zoom_level_get_nearest_from_value (int size)
{
    if (size <= MARLIN_ICON_SIZE_SMALLEST)
        return MARLIN_ZOOM_LEVEL_SMALLEST;
    if (size <= MARLIN_ICON_SIZE_SMALLER)
        return MARLIN_ZOOM_LEVEL_SMALLER;
    if (size <= MARLIN_ICON_SIZE_SMALL)
        return MARLIN_ZOOM_LEVEL_SMALL;
    if (size <= MARLIN_ICON_SIZE_NORMAL)
        return MARLIN_ZOOM_LEVEL_NORMAL;
    if (size <= MARLIN_ICON_SIZE_LARGE)
        return MARLIN_ZOOM_LEVEL_LARGE;
    if (size <= MARLIN_ICON_SIZE_LARGER)
        return MARLIN_ZOOM_LEVEL_LARGER;
    if (size <= MARLIN_ICON_SIZE_LARGEST)
        return MARLIN_ZOOM_LEVEL_LARGEST;
}
