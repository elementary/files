/* nautilus-file-utilities.h - interface for file manipulation routines.
 *
 *  Copyright (C) 1999, 2000, 2001 Eazel, Inc.
 *
 * The Gnome Library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * The Gnome Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with the Gnome Library; see the file COPYING.LIB.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authors: John Sullivan <sullivan@eazel.com>
 */

#include "marlin-file-utilities.h"

#include "gof-file.h"
#include "eel-gio-extensions.h"
#include "eel-stock-dialogs.h"
#include <glib.h>
#include <glib/gprintf.h>
#include <glib/gi18n.h>

#include "marlin-file-operations.h"


/**
 * marlin_get_accel_map_file:
 *
 * Get the path for the filename containing nautilus accelerator map.
 * The filename need not exist. (according to gnome standard))
 *
 * Return value: the filename path, or NULL if the home directory could not be found
**/
char *
marlin_get_accel_map_file (void)
{
    return g_build_filename (g_get_home_dir (), ".gnome2/accels/marlin", NULL);
}

static void
my_list_free_full (GList *list)
{
    g_list_free_full (list, g_object_unref);
}

void
marlin_get_rename_region (const char *filename, int *start_offset, int *end_offset, gboolean select_all)
{
    if (select_all) {
        *start_offset = 0;
        *end_offset = g_utf8_strlen (filename, -1);
    } else
        eel_filename_get_rename_region (filename, start_offset, end_offset);
}
