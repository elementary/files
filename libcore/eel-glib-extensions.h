/*
 * Copyright (C) 2010 ammonkey
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * version 3.0 as published by the Free Software Foundation, Inc.,.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License version 3.0 for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library. If not, see
 * <http://www.gnu.org/licenses/>.
 *
 * Author: ammonkey <am.monkeyd@gmail.com>
 */

#ifndef EEL_GLIB_EXTENSIONS_H
#define EEL_GLIB_EXTENSIONS_H

#include <glib.h>
#include <gio/gio.h>

void    eel_g_settings_add_auto_boolean (GSettings *settings, const char *key,
                                         gboolean *storage);
void    eel_add_weak_pointer (gpointer pointer_location);
void    eel_remove_weak_pointer (gpointer pointer_location);

GList   *eel_g_object_list_ref (GList *list);
GList   *eel_g_object_list_copy (GList *list);
GList   *eel_g_str_list_alphabetize (GList *list);

#endif /* EEL_GLIB_EXTENSIONS_H */
