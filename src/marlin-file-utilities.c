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

#include <config.h>
#include "marlin-file-utilities.h"

/*#include "nautilus-global-preferences.h"
#include "nautilus-lib-self-check-functions.h"
#include "nautilus-metadata.h"
#include "nautilus-file.h"
#include "nautilus-file-operations.h"
#include "nautilus-search-directory.h"
#include "nautilus-signaller.h"
#include <eel/eel-glib-extensions.h>
#include <eel/eel-stock-dialogs.h>
#include <eel/eel-string.h>
#include <eel/eel-debug.h>*/

/*#include <glib.h>
#include <glib/gi18n.h>
#include <glib/gstdio.h>
#include <unistd.h>
#include <stdlib.h>*/

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


#define GSM_NAME  "org.gnome.SessionManager"
#define GSM_PATH "/org/gnome/SessionManager"
#define GSM_INTERFACE "org.gnome.SessionManager"

/* The following values come from
 * http://www.gnome.org/~mccann/gnome-session/docs/gnome-session.html#org.gnome.SessionManager.Inhibit 
 */
#define INHIBIT_LOGOUT (1U)
#define INHIBIT_SUSPEND (4U)

static GDBusConnection *
get_dbus_connection (void)
{
    static GDBusConnection *conn = NULL;

    if (conn == NULL) {
	GError *error = NULL;

	conn = g_bus_get_sync (G_BUS_TYPE_SESSION, NULL, &error);

	if (conn == NULL) {
	    g_warning ("Could not connect to session bus: %s", error->message);
	    g_error_free (error);
	}
    }

    return conn;
}

/**
 * marlin_inhibit_power_manager:
 * @message: a human readable message for the reason why power management
 *       is being suspended.
 *
 * Inhibits the power manager from logging out or suspending the machine
 * (e.g. whenever Marlin is doing file operations).
 *
 * Returns: an integer cookie, which must be passed to
 *    marlin_uninhibit_power_manager() to resume
 *    normal power management.
 */
int
marlin_inhibit_power_manager (const char *message)
{
    GDBusConnection *connection;
    GVariant *result;
    GError *error = NULL;
    guint cookie = 0;

    g_return_val_if_fail (message != NULL, -1);

    connection = get_dbus_connection ();

    if (connection == NULL) {
	return -1;
    }

    result = g_dbus_connection_call_sync (connection,
					  GSM_NAME,
					  GSM_PATH,
					  GSM_INTERFACE,
					  "Inhibit",
					  g_variant_new ("(susu)",
							 "Marlin",
							 (guint) 0,
							 message,
							 (guint) (INHIBIT_LOGOUT | INHIBIT_SUSPEND)),
					  G_VARIANT_TYPE ("(u)"),
					  G_DBUS_CALL_FLAGS_NO_AUTO_START,
					  -1,
					  NULL,
					  &error);

    if (error != NULL) {
	g_warning ("Could not inhibit power management: %s", error->message);
	g_error_free (error);
	return -1;
    }

    g_variant_get (result, "(u)", &cookie);
    g_variant_unref (result);

    return (int) cookie;
}

/**
 * marlin_uninhibit_power_manager:
 * @cookie: the cookie value returned by marlin_inhibit_power_manager()
 *
 * Uninhibits power management. This function must be called after the task
 * which inhibited power management has finished, or the system will not
 * return to normal power management.
 */
void
marlin_uninhibit_power_manager (gint cookie)
{
    GDBusConnection *connection;
    GVariant *result;
    GError *error = NULL;

    g_return_if_fail (cookie > 0);

    connection = get_dbus_connection ();

    if (connection == NULL) {
	return;
    }

    result = g_dbus_connection_call_sync (connection,
					  GSM_NAME,
					  GSM_PATH,
					  GSM_INTERFACE,
					  "Uninhibit",
					  g_variant_new ("(u)", (guint) cookie),
					  NULL,
					  G_DBUS_CALL_FLAGS_NO_AUTO_START,
					  -1,
					  NULL,
					  &error);

    if (result == NULL) {
	g_warning ("Could not uninhibit power management: %s", error->message);
	g_error_free (error);
	return;
    }

    g_variant_unref (result);
}

