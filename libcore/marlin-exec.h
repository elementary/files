/*-
 * Copyright (c) 2005-2007 Benedikt Meurer <benny@xfce.org>
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

#ifndef MARLIN_EXEC_H
#define MARLIN_EXEC_H

#include <gdk/gdk.h>

G_BEGIN_DECLS;

gchar *marlin_exec_parse     (const gchar  *exec,
                              GList        *path_list,
                              const gchar  *icon,
                              const gchar  *name,
                              const gchar  *path);
gchar *marlin_exec_auto_parse (gchar *exec, GList *file_list);

G_END_DECLS;

#endif /* !MARLIN_EXEC_H */
