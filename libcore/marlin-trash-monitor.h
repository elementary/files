/*
 * Copyright (C) 2000 Eazel, Inc.
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

#ifndef MARLIN_TRASH_MONITOR_H
#define MARLIN_TRASH_MONITOR_H

#include <gtk/gtk.h>
#include <gio/gio.h>

typedef struct MarlinTrashMonitor MarlinTrashMonitor;
typedef struct MarlinTrashMonitorClass MarlinTrashMonitorClass;
typedef struct MarlinTrashMonitorDetails MarlinTrashMonitorDetails;

#define MARLIN_TYPE_TRASH_MONITOR marlin_trash_monitor_get_type()
#define MARLIN_TRASH_MONITOR(obj) \
    (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_TRASH_MONITOR, MarlinTrashMonitor))
#define MARLIN_TRASH_MONITOR_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_TRASH_MONITOR, MarlinTrashMonitorClass))
#define MARLIN_IS_TRASH_MONITOR(obj) \
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_TRASH_MONITOR))
#define MARLIN_IS_TRASH_MONITOR_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_TRASH_MONITOR))
#define MARLIN_TRASH_MONITOR_GET_CLASS(obj) \
    (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_TRASH_MONITOR, MarlinTrashMonitorClass))

struct MarlinTrashMonitor {
    GObject object;
    MarlinTrashMonitorDetails *details;
};

struct MarlinTrashMonitorClass {
    GObjectClass parent_class;

    void (* trash_state_changed)    (MarlinTrashMonitor     *trash_monitor,
                                     gboolean        new_state);
};

GType               marlin_trash_monitor_get_type                   (void);

MarlinTrashMonitor  *marlin_trash_monitor_get                       (void);
gboolean            marlin_trash_monitor_is_empty                   (void);
GIcon               *marlin_trash_monitor_get_icon                  (void);

void                marlin_trash_monitor_add_new_trash_directories  (void);

#endif
