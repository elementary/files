/*-
 * Copyright (c) 2009 Jannis Pohlmann <jannis@xfce.org>
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

#ifndef __EEL_GIO_EXTENSIONS_H__
#define __EEL_GIO_EXTENSIONS_H__

#include <gio/gio.h>

GList       *eel_g_file_list_new_from_string (const gchar *string);
gchar       *eel_g_file_get_location (GFile *file);
GFile       *eel_g_file_get_trash_original_file (const gchar *string);
GKeyFile    *eel_g_file_query_key_file (GFile *file, GCancellable *cancellable, GError **error);
GFile       *eel_g_file_ref (GFile *file);
void        eel_g_file_unref (GFile *file);

#endif /* !__EEL_GIO_EXTENSIONS_H__ */
