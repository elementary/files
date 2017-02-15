/*
 * Copyright (C) 2000, 2001 Eazel, Inc.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
 *
 * Author: Pavel Cisler <pavel@eazel.com>
 */

#include "marlin-trash-monitor.h"

#include "marlin-icons.h"
#include <string.h>

struct MarlinTrashMonitorDetails {
    gboolean empty;
    GIcon *icon;
    GFileMonitor *file_monitor;
};

enum {
    TRASH_STATE_CHANGED,
    LAST_SIGNAL
};

static guint signals[LAST_SIGNAL];
static MarlinTrashMonitor *marlin_trash_monitor = NULL;

G_DEFINE_TYPE(MarlinTrashMonitor, marlin_trash_monitor, G_TYPE_OBJECT)

static void
marlin_trash_monitor_finalize (GObject *object)
{
    MarlinTrashMonitor *trash_monitor;

    trash_monitor = MARLIN_TRASH_MONITOR (object);

    if (trash_monitor->details->icon) {
        g_object_unref (trash_monitor->details->icon);
    }
    if (trash_monitor->details->file_monitor) {
        g_object_unref (trash_monitor->details->file_monitor);
    }

    G_OBJECT_CLASS (marlin_trash_monitor_parent_class)->finalize (object);
}

static void
marlin_trash_monitor_class_init (MarlinTrashMonitorClass *klass)
{
    GObjectClass *object_class;

    object_class = G_OBJECT_CLASS (klass);

    object_class->finalize = marlin_trash_monitor_finalize;

    signals[TRASH_STATE_CHANGED] = g_signal_new
        ("trash_state_changed",
         G_TYPE_FROM_CLASS (object_class),
         G_SIGNAL_RUN_LAST,
         G_STRUCT_OFFSET (MarlinTrashMonitorClass, trash_state_changed),
         NULL, NULL,
         g_cclosure_marshal_VOID__BOOLEAN,
         G_TYPE_NONE, 1,
         G_TYPE_BOOLEAN);

    g_type_class_add_private (object_class, sizeof(MarlinTrashMonitorDetails));
}

static void
update_info_cb (GObject *source_object,
                GAsyncResult *res,
                gpointer user_data)
{
    MarlinTrashMonitor *trash_monitor;
    GFileInfo *info;
    GIcon *icon;
    const char * const *names;
    gboolean empty;
    int i;

    trash_monitor = MARLIN_TRASH_MONITOR (user_data);

    info = g_file_query_info_finish (G_FILE (source_object),
                                     res, NULL);

    if (info != NULL) {
        icon = g_file_info_get_icon (info);

        if (icon) {
            g_object_unref (trash_monitor->details->icon);
            trash_monitor->details->icon = g_object_ref (icon);
            empty = TRUE;
            if (G_IS_THEMED_ICON (icon)) {
                names = g_themed_icon_get_names (G_THEMED_ICON (icon));
                for (i = 0; names[i] != NULL; i++) {
                    if (strcmp (names[i], MARLIN_ICON_TRASH_FULL) == 0) {
                        empty = FALSE;
                        break;
                    }
                }
            }
            if (trash_monitor->details->empty != empty) {
                trash_monitor->details->empty = empty;

                /* trash got empty or full, notify everyone who cares */
                g_signal_emit (trash_monitor,
                               signals[TRASH_STATE_CHANGED], 0,
                               trash_monitor->details->empty);
            }
        }
        g_object_unref (info);
    }

    g_object_unref (trash_monitor);
}

static void
schedule_update_info (MarlinTrashMonitor *trash_monitor)
{
    GFile *location;
    location = g_file_new_for_uri (MARLIN_TRASH_URI);

    g_file_query_info_async (location,
                             G_FILE_ATTRIBUTE_STANDARD_ICON,
                             0, 0, NULL,
                             update_info_cb, g_object_ref (trash_monitor));

    g_object_unref (location);
}

static void
file_changed (GFileMonitor* monitor,
              GFile *child,
              GFile *other_file,
              GFileMonitorEvent event_type,
              gpointer user_data)
{
    MarlinTrashMonitor *trash_monitor;
    trash_monitor = MARLIN_TRASH_MONITOR (user_data);

    schedule_update_info (trash_monitor);
}

static void
marlin_trash_monitor_init (MarlinTrashMonitor *trash_monitor)
{
    GFile *location;

    trash_monitor->details = G_TYPE_INSTANCE_GET_PRIVATE (trash_monitor,
                                                          MARLIN_TYPE_TRASH_MONITOR,
                                                          MarlinTrashMonitorDetails);

    trash_monitor->details->empty = TRUE;
    trash_monitor->details->icon = g_themed_icon_new (MARLIN_ICON_TRASH);

    location = g_file_new_for_uri (MARLIN_TRASH_URI);

    trash_monitor->details->file_monitor = g_file_monitor_file (location, 0, NULL, NULL);

    g_signal_connect (trash_monitor->details->file_monitor, "changed",
                      (GCallback)file_changed, trash_monitor);

    g_object_unref (location);

    schedule_update_info (trash_monitor);
}

//TODO unref marlin_trash_monitor global var
/*static void
unref_trash_monitor (void)
{
    g_object_unref (marlin_trash_monitor);
}*/

MarlinTrashMonitor *
marlin_trash_monitor_get (void)
{
    if (marlin_trash_monitor == NULL) {
        /* not running yet, start it up */

        marlin_trash_monitor = MARLIN_TRASH_MONITOR
            (g_object_new (MARLIN_TYPE_TRASH_MONITOR, NULL));
    }

    return marlin_trash_monitor;
}

gboolean
marlin_trash_monitor_is_empty (void)
{
    MarlinTrashMonitor *monitor;

    monitor = marlin_trash_monitor_get ();
    return monitor->details->empty;
}

GIcon *
marlin_trash_monitor_get_icon (void)
{
    MarlinTrashMonitor *monitor;

    monitor = marlin_trash_monitor_get ();
    if (monitor->details->icon) {
        return g_object_ref (monitor->details->icon);
    }
    return NULL;
}

void
marlin_trash_monitor_add_new_trash_directories (void)
{
    /* We trashed something... */
}
