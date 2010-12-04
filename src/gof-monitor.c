/*
   nautilus-monitor.c: file and directory change monitoring for nautilus

   Copyright (C) 2000, 2001 Eazel, Inc.

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License as
   published by the Free Software Foundation; either version 2 of the
   License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this program; if not, write to the
   Free Software Foundation, Inc., 59 Temple Place - Suite 330,
   Boston, MA 02111-1307, USA.

   Authors: Seth Nickell <seth@eazel.com>
   Darin Adler <darin@bentspoon.com>
   Alex Graveley <alex@ximian.com>
*/

#include <config.h>
#include "gof-monitor.h"
//#include "nautilus-file-changes-queue.h"
//#include "nautilus-file-utilities.h"

#include <gio/gio.h>
#include <stdio.h>
#include "marlin-vala.h"

struct GOFMonitor {
    GFileMonitor *monitor;
};

static void
dir_changed (GFileMonitor* monitor,
             GFile *child,
             GFile *other_file,
             GFileMonitorEvent event_type,
             gpointer user_data)
{
    char *uri, *to_uri;

    uri = g_file_get_uri (child);
    to_uri = NULL;
    if (other_file) {
        to_uri = g_file_get_uri (other_file);
    }

    switch (event_type) {
    default:
    case G_FILE_MONITOR_EVENT_CHANGED:
        /* ignore */
        break;
    case G_FILE_MONITOR_EVENT_ATTRIBUTE_CHANGED:
    case G_FILE_MONITOR_EVENT_CHANGES_DONE_HINT:
        //nautilus_file_changes_queue_file_changed (child);
        log_printf (LOG_LEVEL_UNDEFINED, "file changed %s\n", uri);
        break;
    case G_FILE_MONITOR_EVENT_DELETED:
        //nautilus_file_changes_queue_file_removed (child);
        log_printf (LOG_LEVEL_UNDEFINED, "file deleted %s\n", uri);
        break;
    case G_FILE_MONITOR_EVENT_CREATED:
        //nautilus_file_changes_queue_file_added (child);
        log_printf (LOG_LEVEL_UNDEFINED, "file added %s\n", uri);
        break;

    case G_FILE_MONITOR_EVENT_PRE_UNMOUNT:
        /* TODO: Do something */
        break;
    case G_FILE_MONITOR_EVENT_UNMOUNTED:
        /* TODO: Do something */
        break;
    }

    g_free (uri);
    g_free (to_uri);
}

GOFMonitor *
gof_monitor_directory (GFile *location)
{
    GFileMonitor *dir_monitor;
    GOFMonitor *ret;

    dir_monitor = g_file_monitor_directory (location, G_FILE_MONITOR_WATCH_MOUNTS, NULL, NULL);
    /* TODO: implement GCancellable * */
    //dir_monitor = g_file_monitor_directory (location, G_FILE_MONITOR_SEND_MOVED, NULL, NULL);
    ret = g_new0 (GOFMonitor, 1);
    ret->monitor = dir_monitor;

    if (ret->monitor) {
        g_signal_connect (ret->monitor, "changed", (GCallback)dir_changed, ret);
    }

    return ret;
}

void 
gof_monitor_cancel (GOFMonitor *monitor)
{
    if (monitor->monitor != NULL) {
        g_signal_handlers_disconnect_by_func (monitor->monitor, dir_changed, monitor);
        g_file_monitor_cancel (monitor->monitor);
        g_object_unref (monitor->monitor);
    }

    g_free (monitor);
}
