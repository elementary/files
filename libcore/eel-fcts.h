/*
 * Copyright (C) 1999, 2000, 2001 Eazel, Inc.
 *
 * The Gnome Library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of the
 * License, or (at your option) any later version.
 *
 * The Gnome Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with the Gnome Library; see the file COPYING.LIB.  If not,
 * write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
 *
 * Authors: John Sullivan <sullivan@eazel.com>
 *          Darin Adler <darin@bentspoon.com>
 */

#include <glib-object.h>

char        *eel_get_date_as_string (guint64 d, gchar *date_format);
GList       *eel_get_user_names (void);
GList       *eel_get_group_names_for_user (void);
GList       *eel_get_all_group_names (void);
gboolean    eel_get_group_id_from_group_name (const char *group_name, uid_t *gid);
gboolean    eel_get_user_id_from_user_name (const char *user_name, uid_t *uid);
gchar*      eel_get_user_name_from_user_uid (uid_t uid);
gboolean    eel_get_id_from_digit_string (const char *digit_string, uid_t *id);

gchar       *eel_format_size (guint64 size);

gboolean    eel_user_in_group (const char *group_name);
