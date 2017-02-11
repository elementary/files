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

typedef void (* MarlinCopyCallback)      (GHashTable *debuting_uris,
                                          gpointer    callback_data);
typedef void (* MarlinCreateCallback)    (GFile      *new_file,
                                          gpointer    callback_data);
typedef void (* MarlinOpCallback)        (gpointer    callback_data);
typedef void (* MarlinDeleteCallback)    (gboolean    user_cancel,
                                          gpointer    callback_data);
typedef void (* MarlinMountCallback)     (GVolume    *volume,
                                          GObject    *callback_data_object);
typedef void (* MarlinUnmountCallback)   (gpointer    callback_data);

#if 0
void marlin_file_operations_copy_move   (const GList               *item_uris,
                                         GArray                    *relative_item_points,
                                         const char                *target_dir_uri,
                                         GdkDragAction              copy_action,
                                         GtkWidget                 *parent_view,
                                         MarlinCopyCallback       done_callback,
                                         gpointer                   done_callback_data);
#endif

void marlin_file_operations_empty_trash (GtkWidget                 *parent_view);
void marlin_file_operations_new_folder  (GtkWidget                 *parent_view,
                                         GdkPoint                  *target_point,
                                         GFile                     *parent_dir,
                                         MarlinCreateCallback     done_callback,
                                         gpointer                   done_callback_data);
void marlin_file_operations_new_folder_with_name (GtkWidget *parent_view,
                                             GdkPoint *target_point,
                                             GFile *parent_dir,
                                             gchar* folder_name,
                                             MarlinCreateCallback done_callback,
                                             gpointer done_callback_data);
void marlin_file_operations_new_folder_with_name_recursive (GtkWidget *parent_view,
                                             GdkPoint *target_point,
                                             GFile *parent_dir,
                                             gchar* folder_name,
                                             MarlinCreateCallback done_callback,
                                             gpointer done_callback_data);
void marlin_file_operations_new_file    (GtkWidget                 *parent_view,
                                         GdkPoint                  *target_point,
                                         const char                *parent_dir,
                                         const char                *target_filename,
                                         const char                *initial_contents,
                                         int                        length,
                                         MarlinCreateCallback     done_callback,
                                         gpointer                   data);

void marlin_file_operations_new_file_from_template (GtkWidget               *parent_view,
                                                    GdkPoint                *target_point,
                                                    GFile                   *parent_dir,
                                                    const char              *target_filename,
                                                    GFile                   *template,
                                                    MarlinCreateCallback     done_callback,
                                                    gpointer                 data);
void marlin_file_operations_delete          (GList                  *files,
                                             GtkWindow              *parent_window,
                                             MarlinDeleteCallback   done_callback,
                                             gpointer               done_callback_data);
void marlin_file_operations_trash_or_delete (GList                  *files,
                                             GtkWindow              *parent_window,
                                             MarlinDeleteCallback   done_callback,
                                             gpointer               done_callback_data);
#if 0
void marlin_file_set_permissions_recursive (const char                     *directory,
                                            guint32                         file_permissions,
                                            guint32                         file_mask,
                                            guint32                         folder_permissions,
                                            guint32                         folder_mask,
                                            MarlinOpCallback              callback,
                                            gpointer                        callback_data);

void marlin_file_operations_unmount_mount (GtkWindow                      *parent_window,
                                           GMount                         *mount,
                                           gboolean                        eject,
                                           gboolean                        check_trash);
#endif
void marlin_file_operations_unmount_mount_full (GtkWindow                 *parent_window,
                                                GMount                    *mount,
                                                gboolean                   eject,
                                                gboolean                   check_trash,
                                                MarlinUnmountCallback    callback,
                                                gpointer                   callback_data);
void marlin_file_operations_mount_volume  (GtkWindow                      *parent_window,
                                           GVolume                        *volume,
                                           gboolean                        allow_autorun);
void marlin_file_operations_mount_volume_full (GtkWindow                      *parent_window,
                                               GVolume                        *volume,
                                               gboolean                        allow_autorun,
                                               MarlinMountCallback           mount_callback,
                                               GObject                        *mount_callback_data_object);
void marlin_file_operations_copy      (GList                *files,
                                       GArray               *relative_item_points,
                                       GFile                *target_dir,
                                       GtkWindow            *parent_window,
                                       MarlinCopyCallback   done_callback,
                                       gpointer             done_callback_data);

void marlin_file_operations_copy_move   (GList                  *files,
                                         GArray                 *relative_item_points,
                                         GFile                  *target_dir,
                                         GdkDragAction          copy_action,
                                         GtkWidget              *parent_view,
                                         GCallback              done_callback,
                                         gpointer               done_callback_data);

void marlin_file_operations_move      (GList                *files,
                                       GArray               *relative_item_points,
                                       GFile                *target_dir,
                                       GtkWindow            *parent_window,
                                       MarlinCopyCallback  done_callback,
                                       gpointer              done_callback_data);
#if 0
void marlin_file_operations_duplicate (GList                *files,
                                       GArray               *relative_item_points,
                                       GtkWindow            *parent_window,
                                       MarlinCopyCallback  done_callback,
                                       gpointer              done_callback_data);
void marlin_file_operations_link      (GList                *files,
                                       GArray               *relative_item_points,
                                       GFile                *target_dir,
                                       GtkWindow            *parent_window,
                                       MarlinCopyCallback  done_callback,
                                       gpointer              done_callback_data);
void marlin_file_mark_desktop_file_trusted (GFile           *file,
                                            GtkWindow        *parent_window,
                                            gboolean          interactive,
                                            MarlinOpCallback done_callback,
                                            gpointer          done_callback_data);

gboolean marlin_file_operations_has_trash_files (GMount *mount);
gint marlin_file_operations_prompt_empty_trash (GtkWindow *parent_window);
GList *marlin_file_operations_get_trash_dirs_for_mount (GMount *mount);

#endif
#endif /* MARLIN_FILE_OPERATIONS_H */
