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

#ifndef MARLIN_FILE_UTILITIES_H
#define MARLIN_FILE_UTILITIES_H

#include <gio/gio.h>
#include <gtk/gtk.h>

//char *  marlin_get_xdg_dir                      (const char *type);
char    *marlin_get_accel_map_file      (void);

void    marlin_get_rename_region (const char *filename, int *start_offset, int *end_offset, gboolean select_all);

#endif /* MARLIN_FILE_UTILITIES_H */
