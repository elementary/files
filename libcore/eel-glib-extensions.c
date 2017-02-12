/* eel-glib-extensions.c - implementation of new functions that conceptually
 * belong in glib. Perhaps some of these will be
 * actually rolled into glib someday.
 *
 * Copyright (C) 2000 Eazel, Inc.
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
 *          ammonkey <am.monkeyd@gmail.com>
 */

#include "eel-glib-extensions.h"
#include <sys/time.h>
#include <math.h>

static void
update_auto_boolean (GSettings   *settings,
                     const gchar *key,
                     gpointer     user_data)
{
    int *storage = user_data;

    *storage = g_settings_get_boolean (settings, key);
}

void
eel_g_settings_add_auto_boolean (GSettings *settings,
                                 const char *key,
                                 gboolean *storage)
{
    char *signal;

    *storage = g_settings_get_boolean (settings, key);
    signal = g_strconcat ("changed::", key, NULL);
    g_signal_connect (settings, signal,
                      G_CALLBACK(update_auto_boolean),
                      storage);
}

/**
 * eel_add_weak_pointer
 *
 * Nulls out a saved reference to an object when the object gets destroyed.
 *
 * @pointer_location: Address of the saved pointer.
**/
void
eel_add_weak_pointer (gpointer pointer_location)
{
    gpointer *object_location;

    g_return_if_fail (pointer_location != NULL);

    object_location = (gpointer *) pointer_location;
    if (*object_location == NULL) {
        /* The reference is NULL, nothing to do. */
        return;
    }

    g_return_if_fail (G_IS_OBJECT (*object_location));

    g_object_add_weak_pointer (G_OBJECT (*object_location),
                               object_location);
}

/**
 * eel_remove_weak_pointer
 *
 * Removes the weak pointer that was added by eel_add_weak_pointer.
 * Also nulls out the pointer.
 *
 * @pointer_location: Pointer that was passed to eel_add_weak_pointer.
**/
void
eel_remove_weak_pointer (gpointer pointer_location)
{
    gpointer *object_location;

    g_return_if_fail (pointer_location != NULL);

    object_location = (gpointer *) pointer_location;
    if (*object_location == NULL) {
        /* The object was already destroyed and the reference
         * nulled out, nothing to do.
         */
        return;
    }

    g_return_if_fail (G_IS_OBJECT (*object_location));

    g_object_remove_weak_pointer (G_OBJECT (*object_location),
                                  object_location);

    *object_location = NULL;
}

/**
 * eel_g_object_list_ref
 *
 * Ref all the objects in a list.
 * @list: GList of objects.
**/
GList *
eel_g_object_list_ref (GList *list)
{
    g_list_foreach (list, (GFunc) g_object_ref, NULL);
    return list;
}

/**
 * eel_g_object_list_copy
 *
 * Copy the list of objects, ref'ing each one.
 * @list: GList of objects.
**/
GList *
eel_g_object_list_copy (GList *list)
{
    return g_list_copy (eel_g_object_list_ref (list));
}

/**
 * eel_g_str_list_alphabetize
 *
 * Sort a list of strings using locale-sensitive rules.
 *
 * @list: List of strings and/or NULLs.
 *
 * Return value: @list, sorted.
 **/
GList *
eel_g_str_list_alphabetize (GList *list)
{
    return g_list_sort (list, (GCompareFunc) g_utf8_collate);
}


