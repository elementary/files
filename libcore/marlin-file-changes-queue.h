/*
 * Copyright (C) 1999, 2000, 2001 Eazel, Inc.
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

#ifndef MARLIN_FILE_CHANGES_QUEUE_H
#define MARLIN_FILE_CHANGES_QUEUE_H

#include <gdk/gdk.h>
#include <gio/gio.h>

void marlin_file_changes_queue_file_added                      (GFile      *location);
void marlin_file_changes_queue_file_changed                    (GFile      *location);
void marlin_file_changes_queue_file_removed                    (GFile      *location);
void marlin_file_changes_queue_file_moved                      (GFile      *from,
                                                                GFile      *to);

void marlin_file_changes_consume_changes                       (gboolean    consume_all);


#endif /* MARLIN_FILE_CHANGES_QUEUE_H */
