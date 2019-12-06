/* nautilus-file-operations: execute file operations.
 *
 * Copyright (C) 1999, 2000 Free Software Foundation, Inc.,
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
 * Authors: Ettore Perazzoli <ettore@gnu.org>,
 *          Pavel Cisler <pavel@eazel.com>
 */

#ifndef MARLIN_FILE_OPERATIONS_H
#define MARLIN_FILE_OPERATIONS_H

#include <gtk/gtk.h>
#include <gio/gio.h>

/* Sidebar uses Marlin.FileOperations to mount volumes but handles unmounting itself */
void marlin_file_operations_mount_volume  (GVolume   *volume,
                                           GtkWindow *parent_window);


void marlin_file_operations_mount_volume_full (GVolume                        *volume,
                                               GtkWindow                      *parent_window,
                                               GAsyncReadyCallback             callback,
                                               gpointer                        user_data);
gboolean marlin_file_operations_mount_volume_full_finish (GAsyncResult  *result,
                                                          GError       **error);

void marlin_file_operations_delete (GList               *files,
                                    GtkWindow           *parent_window,
                                    gboolean             try_trash,
                                    GCancellable        *cancellable,
                                    GAsyncReadyCallback  callback,
                                    gpointer             user_data);
gboolean marlin_file_operations_delete_finish (GAsyncResult  *result,
                                               GError       **error);


gboolean marlin_file_operations_has_trash_files (GMount *mount);

GList *marlin_file_operations_get_trash_dirs_for_mount (GMount *mount);

void marlin_file_operations_empty_trash (GtkWidget                 *parent_view);

void marlin_file_operations_copy_move_link (GList               *files,
                                            GArray              *relative_item_points,
                                            GFile               *target_dir,
                                            GdkDragAction        copy_action,
                                            GtkWidget           *parent_view,
                                            GCancellable        *cancellable,
                                            GAsyncReadyCallback  callback,
                                            gpointer             user_data);
gboolean marlin_file_operations_copy_move_link_finish (GAsyncResult  *result,
                                                       GError       **error);

void marlin_file_operations_new_file (GtkWidget           *parent_view,
                                      GdkPoint            *target_point,
                                      const char          *parent_dir,
                                      const char          *target_filename,
                                      const char          *initial_contents,
                                      int                  length,
                                      GCancellable        *cancellable,
                                      GAsyncReadyCallback  callback,
                                      gpointer             user_data);
GFile *marlin_file_operations_new_file_finish (GAsyncResult  *result,
                                               GError       **error);

/* TODO: Merge with marlin_file_operations_new_file */
void marlin_file_operations_new_folder (GtkWidget           *parent_view,
                                        GdkPoint            *target_point,
                                        GFile               *parent_dir,
                                        GCancellable        *cancellable,
                                        GAsyncReadyCallback  callback,
                                        gpointer             user_data);
GFile *marlin_file_operations_new_folder_finish (GAsyncResult  *result,
                                                 GError       **error);

void marlin_file_operations_new_file_from_template (GtkWidget           *parent_view,
                                                    GdkPoint            *target_point,
                                                    GFile               *parent_dir,
                                                    const char          *target_filename,
                                                    GFile               *template,
                                                    GCancellable        *cancellable,
                                                    GAsyncReadyCallback  callback,
                                                    gpointer             user_data);
GFile *marlin_file_operations_new_file_from_template_finish (GAsyncResult  *result,
                                                             GError       **error);

#endif /* MARLIN_FILE_OPERATIONS_H */
