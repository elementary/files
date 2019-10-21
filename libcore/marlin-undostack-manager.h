/* MarlinUndoManager - Manages undo of file operations (header)
 *
 * Copyright (C) 2007-2010 Amos Brocco
 *
 * Author: Amos Brocco <amos.brocco@unifr.ch>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public
 * License as published by the Free Software Foundation, Inc.,; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA..
 */

#ifndef MARLIN_UNDO_MANAGER_H
#define MARLIN_UNDO_MANAGER_H

#include <glib.h>
#include <glib-object.h>
#include <gtk/gtk.h>
#include <gio/gio.h>


typedef enum
{
    MARLIN_UNDO_COPY,
    MARLIN_UNDO_DUPLICATE,
    MARLIN_UNDO_MOVE,
    MARLIN_UNDO_RENAME,
    MARLIN_UNDO_CREATEEMPTYFILE,
    MARLIN_UNDO_CREATEFILEFROMTEMPLATE,
    MARLIN_UNDO_CREATEFOLDER,
    MARLIN_UNDO_MOVETOTRASH,
    MARLIN_UNDO_CREATELINK,
    MARLIN_UNDO_DELETE,
    MARLIN_UNDO_RESTOREFROMTRASH,
    MARLIN_UNDO_SETPERMISSIONS,
    MARLIN_UNDO_RECURSIVESETPERMISSIONS,
    MARLIN_UNDO_CHANGEOWNER,
    MARLIN_UNDO_CHANGEGROUP
} MarlinUndoActionType;

typedef struct _MarlinUndoActionData MarlinUndoActionData;

typedef struct _MarlinUndoMenuData MarlinUndoMenuData;

struct _MarlinUndoMenuData {
    char* undo_label;
    char* undo_description;
    char* redo_label;
    char* redo_description;
};

/* End action structures */

#define TYPE_MARLIN_UNDO_MANAGER (marlin_undo_manager_get_type())
G_DECLARE_FINAL_TYPE (MarlinUndoManager, marlin_undo_manager, MARLIN, UNDO_MANAGER, GObject)

void
marlin_undo_manager_add_action (MarlinUndoManager* manager,
                                MarlinUndoActionData* action);

void
marlin_undo_manager_add_rename_action (MarlinUndoManager* manager,
                                       GFile* file,
                                       const char* original_name);

void
marlin_undo_manager_undo (MarlinUndoManager   *manager,
                          GtkWidget           *parent_view,
                          GCancellable        *cancellable,
                          GAsyncReadyCallback  callback,
                          gpointer             user_data);
gboolean
marlin_undo_manager_undo_finish (MarlinUndoManager  *manager,
                                 GAsyncResult       *result,
                                 GError            **error);

void
marlin_undo_manager_redo (MarlinUndoManager   *manager,
                          GtkWidget           *parent_view,
                          GCancellable        *cancellable,
                          GAsyncReadyCallback  callback,
                          gpointer             user_data);
gboolean
marlin_undo_manager_redo_finish (MarlinUndoManager  *manager,
                                 GAsyncResult       *result,
                                 GError            **error);

MarlinUndoActionData*
marlin_undo_manager_data_new (MarlinUndoActionType type,
                              gint items_count);

gboolean
marlin_undo_manager_is_undo_redo (MarlinUndoManager* manager);

void
marlin_undo_manager_trash_has_emptied (MarlinUndoManager* manager);

MarlinUndoManager*
marlin_undo_manager_instance (void);

void
marlin_undo_manager_data_set_src_dir (MarlinUndoActionData* data,
                                      GFile* src);

void
marlin_undo_manager_data_set_dest_dir (MarlinUndoActionData* data,
                                       GFile* dest);

void
marlin_undo_manager_data_add_origin_target_pair (MarlinUndoActionData* data, GFile* origin, GFile* target);

void
marlin_undo_manager_data_set_create_data (MarlinUndoActionData* data, char* target_uri, char* template_uri);

void
marlin_undo_manager_data_set_rename_information (MarlinUndoActionData* data, GFile* old_file, GFile* new_file);

guint64
marlin_undo_manager_get_file_modification_time (GFile* file);

void
marlin_undo_manager_data_add_trashed_file (MarlinUndoActionData* data, GFile* file, guint64 mtime);

/* TODO remove */
/*void
marlin_undo_manager_request_menu_update (MarlinUndoManager* manager);*/

void
marlin_undo_manager_data_add_file_permissions (MarlinUndoActionData* data, GFile* file, guint32 permission);

void
marlin_undo_manager_data_set_recursive_permissions (MarlinUndoActionData* data, guint32 file_permissions, guint32 file_mask, guint32 dir_permissions, guint32 dir_mask);

void
marlin_undo_manager_data_set_file_permissions (MarlinUndoActionData* data, char* uri, guint32 current_permissions, guint32 new_permissions);

void
marlin_undo_manager_data_set_owner_change_information (MarlinUndoActionData* data, char* uri, const char* current_user, const char* new_user);

void
marlin_undo_manager_data_set_group_change_information (MarlinUndoActionData* data, char* uri, const char* current_group, const char* new_group);

#endif /* MARLIN_UNDO_MANAGER_H */
