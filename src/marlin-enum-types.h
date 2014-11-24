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

#ifndef __MARLIN_ENUM_TYPES_H__
#define __MARLIN_ENUM_TYPES_H__

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtk.h>

G_BEGIN_DECLS;

#define APP_NAME "pantheon-files"

#define MARLIN_TYPE_ICON_SIZE (marlin_icon_size_get_type ())

typedef enum
{
    MARLIN_ICON_SIZE_SMALLEST = 16,
    MARLIN_ICON_SIZE_SMALLER  = 24,
    MARLIN_ICON_SIZE_SMALL    = 32,
    MARLIN_ICON_SIZE_NORMAL   = 48,
    MARLIN_ICON_SIZE_LARGE    = 64,
    MARLIN_ICON_SIZE_LARGER   = 96,
    MARLIN_ICON_SIZE_LARGEST  = 128,
} MarlinIconSize;

GType marlin_icon_size_get_type (void) G_GNUC_CONST;

#define MARLIN_TYPE_ZOOM_LEVEL (marlin_zoom_level_get_type ())
typedef enum
{
    MARLIN_ZOOM_LEVEL_SMALLEST,
    MARLIN_ZOOM_LEVEL_SMALLER,
    MARLIN_ZOOM_LEVEL_SMALL,
    MARLIN_ZOOM_LEVEL_NORMAL,
    MARLIN_ZOOM_LEVEL_LARGE,
    MARLIN_ZOOM_LEVEL_LARGER,
    MARLIN_ZOOM_LEVEL_LARGEST,
} MarlinZoomLevel;

GType           marlin_zoom_level_get_type     (void) G_GNUC_CONST;
MarlinIconSize  marlin_zoom_level_to_icon_size (MarlinZoomLevel zoom_level) G_GNUC_CONST;
GtkIconSize     marlin_zoom_level_to_stock_icon_size (MarlinZoomLevel zoom_level);
MarlinZoomLevel marlin_zoom_level_get_nearest_from_value (int size);

G_END_DECLS;

#endif /* !__MARLIN_ENUM_TYPES_H__ */
