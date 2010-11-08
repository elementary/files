/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 8; tab-width: 8 -*- */
/*
 * Copyright (C) 2010 ammonkey
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * version 3.0 as published by the Free Software Foundation.
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

#include "eel-glib-extensions.h"
#include <sys/time.h>

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

gint64
eel_get_system_time (void)
{
	struct timeval tmp;

	gettimeofday (&tmp, NULL);
	return (gint64)tmp.tv_usec + (gint64)tmp.tv_sec * G_GINT64_CONSTANT (1000000);
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

