/* MarlinUndoManager - Manages undo of file operations (implementation)
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
 * Boston, MA 02110-1335 USA.
 */

#include "marlin-undostack-manager.h"
#include "marlin-file-operations.h"
#include <gio/gio.h>
#include <glib/gprintf.h>
#include <glib-object.h>
#include <glib/gi18n.h>
#include <locale.h>
#include <gdk/gdk.h>
#include "marlin-file-changes-queue.h"
#include "pantheon-files-core.h"

struct _MarlinUndoActionData
{
    /* Common stuff */
    MarlinUndoActionType type;
    gboolean is_valid;
    gboolean locked;              /* True if the action is being undone/redone */
    gboolean freed;               /* True if the action must be freed after undo/redo */
    guint count;                  /* Size of affected uris (count of items) */
    MarlinUndoManager *manager;    /* Pointer to the manager */

    /* Copy / Move stuff */
    GFile *src_dir;
    GFile *dest_dir;
    GList *sources;               /* Relative to src_dir */
    GList *destinations;          /* Relative to dest_dir */

    /* Cached labels/descriptions */
    char *undo_label;
    char *undo_description;
    char *redo_label;
    char *redo_description;

    /* Create new file/folder stuff/set permissions */
    char *template;
    char *target_uri;

    /* Rename stuff */
    char *old_uri;
    char *new_uri;

    /* Trash stuff */
    GHashTable *trashed;

    /* Recursive change permissions stuff */
    GHashTable *original_permissions;
    guint32 dir_mask;
    guint32 dir_permissions;
    guint32 file_mask;
    guint32 file_permissions;

    /* Single file change permissions stuff */
    guint32 current_permissions;
    guint32 new_permissions;

    /* Group */
    char *original_group_name_or_id;
    char *new_group_name_or_id;

    /* Owner */
    char *original_user_name_or_id;
    char *new_user_name_or_id;

};

struct _MarlinUndoManager
{
    GObject parent_instance;

    GQueue      *stack;
    guint       undo_levels;
    guint       index;
    GMutex      mutex;                /* Used to protect access to stack (because of async file ops) */
    gboolean    dispose_has_run;
    gboolean    undo_redo_flag;
    gboolean    confirm_delete;
};

G_DEFINE_TYPE (MarlinUndoManager, marlin_undo_manager, G_TYPE_OBJECT);

enum {
    REQUEST_MENU_UPDATE,
    LAST_SIGNAL
};

static guint signals[LAST_SIGNAL];

/* *****************************************************************
   Properties management prototypes
***************************************************************** */
enum
{
    PROP_UNDO_MANAGER_0,
    PROP_UNDO_LEVELS,
    PROP_CONFIRM_DELETE
};

static void marlin_undo_manager_set_property (GObject *object,
                                              guint prop_id, const GValue * value, GParamSpec * pspec);

static void marlin_undo_manager_get_property (GObject *object,
                                              guint prop_id, GValue * value, GParamSpec * pspec);

/* *****************************************************************
   Destructors prototypes
***************************************************************** */

static void marlin_undo_manager_dispose (GObject *object);

/* *****************************************************************
   Private methods prototypes
***************************************************************** */

static void stack_clear_n_oldest (GQueue *stack, guint n);

static void stack_fix_size (MarlinUndoManager *self);

static gboolean can_undo (MarlinUndoManager *self);

static gboolean can_redo (MarlinUndoManager *self);

static void stack_push_action (MarlinUndoManager *self,
                               MarlinUndoActionData *action);

static MarlinUndoActionData
* stack_scroll_left (MarlinUndoManager *self);

static MarlinUndoActionData
* stack_scroll_right (MarlinUndoManager *self);

static MarlinUndoActionData
* get_next_redo_action (MarlinUndoManager *self);

static MarlinUndoActionData
* get_next_undo_action (MarlinUndoManager *self);

static gchar *get_undo_label (MarlinUndoActionData *action);

static gchar *get_undo_description (MarlinUndoActionData *action);

static gchar *get_redo_label (MarlinUndoActionData *action);

static gchar *get_redo_description (MarlinUndoActionData *action);

static void do_menu_update (MarlinUndoManager *manager);

static void free_undo_action (gpointer data, gpointer user_data);

static void undostack_dispose_all (GQueue *queue);

static void undo_redo_done_transfer_callback (GHashTable *debuting_uris,
                                              gpointer data);

static void undo_redo_op_callback (gpointer callback_data);

static void undo_redo_done_rename_callback (GFile        *file,
                                            GAsyncResult *result,
                                            gpointer      user_data);

static void undo_redo_done_delete_callback (gboolean user_cancel, gpointer callback_data);

static void undo_redo_done_create_callback (GFile * new_file,
                                            gpointer callback_data);

static void clear_redo_actions (MarlinUndoManager *self);

static gchar *get_first_target_short_name (MarlinUndoActionData *action);

static GList *construct_gfile_list (GList *urilist, GFile *parent);

static GList *construct_gfile_list_from_uri (char *uri);

static GList *uri_list_to_gfile_list (GList *urilist);

static char *get_uri_basename (char *uri);

static char *get_uri_parent (char *uri);

static char *get_uri_parent_path (char *uri);

static GFile *get_file_parent_from_uri (char *uri);

static GHashTable *retrieve_files_to_restore (GHashTable *trashed);

/* *****************************************************************
   Base functions
***************************************************************** */
static void
marlin_undo_manager_class_init (MarlinUndoManagerClass *klass)
{
    GParamSpec *undo_levels;
    GParamSpec *confirm_delete;
    GObjectClass *g_object_class;

    /* Create properties */
    undo_levels = g_param_spec_uint ("undo-levels", "undo levels",
                                     "Number of undo levels to be stored",
                                     1, UINT_MAX, 30, G_PARAM_READWRITE | G_PARAM_CONSTRUCT);

    confirm_delete =
        g_param_spec_boolean ("confirm-delete", "confirm delete",
                              "Always confirm file deletion", FALSE,
                              G_PARAM_READWRITE | G_PARAM_CONSTRUCT);

    /* Set properties get/set methods */
    g_object_class = G_OBJECT_CLASS (klass);

    g_object_class->set_property = marlin_undo_manager_set_property;
    g_object_class->get_property = marlin_undo_manager_get_property;

    /* Install properties */
    g_object_class_install_property (g_object_class, PROP_UNDO_LEVELS,
                                     undo_levels);

    g_object_class_install_property (g_object_class, PROP_CONFIRM_DELETE,
                                     confirm_delete);

    /* The UI menu needs to update its status */
    signals[REQUEST_MENU_UPDATE] = g_signal_new ("request-menu-update",
                                                 G_TYPE_FROM_CLASS (klass),
                                                 G_SIGNAL_RUN_LAST | G_SIGNAL_NO_RECURSE | G_SIGNAL_NO_HOOKS,
                                                 0, NULL, NULL,
                                                 g_cclosure_marshal_VOID__POINTER,
                                                 G_TYPE_NONE, 1, G_TYPE_POINTER);

    /* Hook deconstructors */
    g_object_class->dispose = marlin_undo_manager_dispose;
}

static void
marlin_undo_manager_init (MarlinUndoManager *self)
{
    /* Initialize private fields */
    self->stack = g_queue_new ();
    g_mutex_init (&self->mutex);
    self->index = 0;
    self->dispose_has_run = FALSE;
    self->undo_redo_flag = FALSE;
    self->confirm_delete = FALSE;
}

static void
marlin_undo_manager_dispose (GObject *object)
{
    MarlinUndoManager *self = MARLIN_UNDO_MANAGER (object);

    if (self->dispose_has_run)
        return;

    g_mutex_lock (&self->mutex);

    /* Free each undoable action in the stack and the stack itself */
    undostack_dispose_all (self->stack);
    g_queue_free (self->stack);
    g_mutex_unlock (&self->mutex);

    g_mutex_clear (&self->mutex);

    self->dispose_has_run = TRUE;

    G_OBJECT_CLASS (marlin_undo_manager_parent_class)->dispose (object);
}

/* *****************************************************************
   Property management
***************************************************************** */
static void
marlin_undo_manager_set_property (GObject *object, guint prop_id,
                                  const GValue *value, GParamSpec *pspec)
{
    MarlinUndoManager *self = MARLIN_UNDO_MANAGER (object);
    guint new_undo_levels;

    g_return_if_fail (MARLIN_IS_UNDO_MANAGER (object));

    switch (prop_id) {
    case PROP_UNDO_LEVELS:
        new_undo_levels = g_value_get_uint (value);
        if (new_undo_levels > 0 && (self->undo_levels != new_undo_levels)) {
            self->undo_levels = new_undo_levels;
            g_mutex_lock (&self->mutex);
            stack_fix_size (self);
            g_mutex_unlock (&self->mutex);
            do_menu_update (self);
        }
        break;
    case PROP_CONFIRM_DELETE:
        self->confirm_delete = g_value_get_boolean (value);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }
}

static void
marlin_undo_manager_get_property (GObject *object, guint prop_id,
                                  GValue *value, GParamSpec *pspec)
{
    MarlinUndoManager *self = MARLIN_UNDO_MANAGER (object);

    g_return_if_fail (MARLIN_IS_UNDO_MANAGER (object));

    switch (prop_id) {
    case PROP_UNDO_LEVELS:
        g_value_set_uint (value, self->undo_levels);
        break;

    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, prop_id, pspec);
        break;
    }
}

/* *****************************************************************
   Public methods
***************************************************************** */

/** ****************************************************************
 * Returns the undo stack manager instance (singleton pattern)
** ****************************************************************/
MarlinUndoManager *
marlin_undo_manager_instance (void)
{
    static MarlinUndoManager *manager = NULL;

    if (manager == NULL)
        manager = g_object_new (TYPE_MARLIN_UNDO_MANAGER, "undo-levels", 10, NULL);

    return manager;
}

/** ****************************************************************
 * True if undoing / redoing
** ****************************************************************/
gboolean
marlin_undo_manager_is_undo_redo (MarlinUndoManager *manager)
{
    g_return_val_if_fail (MARLIN_IS_UNDO_MANAGER (manager), FALSE);

    return manager->undo_redo_flag;
}

/*void
  marlin_undo_manager_request_menu_update (MarlinUndoManager *manager)
  {
  do_menu_update (manager);
  }*/

/** ****************************************************************
 * Redoes the last file operation
** ****************************************************************/
void
marlin_undo_manager_redo (MarlinUndoManager *self,
                          GtkWidget *parent_view,
                          MarlinUndoFinishCallback cb,
                          gpointer callback_data)
{
    GList *uris;
    GFile *file;
    char *new_name;
    char *puri;
    GFile *fparent;

    g_return_if_fail (MARLIN_IS_UNDO_MANAGER (self));

    g_mutex_lock (&self->mutex);

    MarlinUndoActionData *action = stack_scroll_left (self);

    /* Action will be NULL if redo is not possible */
    if (action != NULL) {
        action->locked = TRUE;
    }

    g_mutex_unlock (&self->mutex);

    do_menu_update (self);

    if (action != NULL) {
        action->locked = TRUE;      /* Remember to unlock when redo is finished */
        self->undo_redo_flag = TRUE;
        switch (action->type) {
        case MARLIN_UNDO_COPY:
            uris = construct_gfile_list (action->sources, action->src_dir);
            marlin_file_operations_copy_move_link (uris, NULL, action->dest_dir,
                                                   GDK_ACTION_COPY, NULL,
                                                   undo_redo_done_transfer_callback, action);

            g_list_free_full (uris, g_object_unref); /* marlin-file-operation takes deep copy */
            break;
        case MARLIN_UNDO_DUPLICATE:
            uris = construct_gfile_list (action->sources, action->src_dir);
            marlin_file_operations_copy_move_link (uris, NULL, NULL,
                                                   GDK_ACTION_COPY, NULL,
                                                   undo_redo_done_transfer_callback, action);

            g_list_free_full (uris, g_object_unref); /* marlin-file-operation takes deep copy */
            break;

        case MARLIN_UNDO_RESTOREFROMTRASH:
        case MARLIN_UNDO_MOVE:
            uris = construct_gfile_list (action->sources, action->src_dir);
            marlin_file_operations_copy_move_link (uris, NULL, action->dest_dir,
                                                   GDK_ACTION_MOVE, NULL,
                                                   undo_redo_done_transfer_callback, action);

            g_list_free_full (uris, g_object_unref); /* marlin-file-operation takes deep copy */
            break;

        case MARLIN_UNDO_RENAME:
            file = g_file_new_for_uri (action->old_uri);
            new_name = get_uri_basename (action->new_uri);
            pf_file_utils_set_file_display_name (file,
                                                 new_name,
                                                 NULL,
                                                 undo_redo_done_rename_callback,
                                                 action);
            g_free (new_name);
            g_object_unref (file);
            break;

        case MARLIN_UNDO_CREATEEMPTYFILE:
            puri = get_uri_parent (action->target_uri);
            new_name = get_uri_basename (action->target_uri);
            marlin_file_operations_new_file (NULL, NULL, puri,
                                             new_name,
                                             action->template,
                                             0, undo_redo_done_create_callback, action);
            g_free (puri);
            g_free (new_name);
            break;
        case MARLIN_UNDO_CREATEFOLDER:
            fparent = get_file_parent_from_uri (action->target_uri);
            marlin_file_operations_new_folder (NULL, NULL, fparent,
                                               undo_redo_done_create_callback, action);
            g_object_unref (fparent);
            break;
        case MARLIN_UNDO_MOVETOTRASH:
            if (g_hash_table_size (action->trashed) > 0) {
                GList *uri_to_trash = g_hash_table_get_keys (action->trashed);
                uris = uri_list_to_gfile_list (uri_to_trash);
                self->undo_redo_flag = TRUE;
                marlin_file_operations_trash_or_delete
                    (uris, NULL, undo_redo_done_delete_callback, action);
                g_list_free (uri_to_trash);
                g_list_free_full (uris, g_object_unref);
            }
            break;
        case MARLIN_UNDO_CREATELINK:
            uris = construct_gfile_list (action->sources, action->src_dir);
            marlin_file_operations_copy_move_link (uris, NULL, action->dest_dir,
                                                   GDK_ACTION_LINK, NULL,
                                                   undo_redo_done_transfer_callback, action);

            g_list_free_full (uris, g_object_unref); /* marlin-file-operation takes deep copy */
            break;
        case MARLIN_UNDO_DELETE:
        default:
            self->undo_redo_flag = FALSE;
            break;                  /* We shouldn't be here */
        }
    }

    if (cb != NULL)
        (*cb) ((gpointer) parent_view);
}

/** ****************************************************************
 * Undoes the last file operation
** ****************************************************************/
void
marlin_undo_manager_undo (MarlinUndoManager *self,
                          GtkWidget *parent_view,
                          MarlinUndoFinishCallback cb,
                          gpointer done_callback_data)
{
    GList *uris = NULL;
    GHashTable *files_to_restore;
    GFile *file;
    gchar *new_name;

    g_return_if_fail (MARLIN_IS_UNDO_MANAGER (self));

    g_mutex_lock (&self->mutex);

    MarlinUndoActionData *action = stack_scroll_right (self);

    if (action != NULL) {
        action->locked = TRUE;
    }

    g_mutex_unlock (&self->mutex);

    do_menu_update (self);

    if (action != NULL) {
        self->undo_redo_flag = TRUE;
        switch (action->type) {
        case MARLIN_UNDO_CREATEEMPTYFILE:
        /*case MARLIN_UNDO_CREATEFILEFROMTEMPLATE:*/
        case MARLIN_UNDO_CREATEFOLDER:
            uris = construct_gfile_list_from_uri (action->target_uri);
        case MARLIN_UNDO_COPY:
        case MARLIN_UNDO_DUPLICATE:
        case MARLIN_UNDO_CREATELINK:
            if (!uris) {
                uris = construct_gfile_list (action->destinations, action->dest_dir);
                uris = g_list_reverse (uris); // Deleting must be done in reverse
            }
            if (self->confirm_delete) {
                marlin_file_operations_delete (uris, NULL,
                                               undo_redo_done_delete_callback, action);
                g_list_free_full (uris, g_object_unref);
            } else {
                /* We skip the confirmation message
                */
                for (GList *f = uris; f != NULL; f = f->next) {
                    GFile *file = (GFile *)f->data;
                    g_file_delete (file, NULL, NULL);
                    marlin_file_changes_queue_file_removed (file);
                }

                g_list_free_full (uris, g_object_unref);
                marlin_file_changes_consume_changes (TRUE);

                /* Here we must do what's necessary for the callback */
                undo_redo_done_transfer_callback (NULL, action);
            }
            break;
        case MARLIN_UNDO_RESTOREFROMTRASH:
            uris = construct_gfile_list (action->destinations, action->dest_dir);
            marlin_file_operations_trash_or_delete (uris, NULL,
                                                    undo_redo_done_delete_callback, action);
            g_list_free_full (uris, g_object_unref);
            break;
        case MARLIN_UNDO_MOVETOTRASH:
            files_to_restore = retrieve_files_to_restore (action->trashed);
            if (g_hash_table_size (files_to_restore) > 0) {
                GList *gfiles_in_trash = g_hash_table_get_keys (files_to_restore);

                for (GList *l = gfiles_in_trash; l != NULL; l = l->next) {
                    GFile *item = (GFile *)l->data;
                    const char *value = g_hash_table_lookup (files_to_restore, item);
                    GFile *dest = g_file_new_for_uri (value);

                    g_file_move (item, dest,
                                 G_FILE_COPY_NOFOLLOW_SYMLINKS, NULL, NULL, NULL, NULL);
                    marlin_file_changes_queue_file_moved (item, dest);

                    g_object_unref (dest);
                }

                g_list_free (gfiles_in_trash);
                marlin_file_changes_consume_changes (TRUE);
            } else {
                pf_dialogs_show_error_dialog (_("Original location could not be determined"),
                                              _("Open trash folder and restore manually"),
                                              gtk_widget_get_toplevel (parent_view));
            }

            g_hash_table_destroy (files_to_restore);

            /* Here we must do what's necessary for the callback */
            undo_redo_done_transfer_callback (NULL, action);
            break;
        case MARLIN_UNDO_MOVE:
            uris = construct_gfile_list (action->destinations, action->dest_dir);
            marlin_file_operations_copy_move_link (uris, NULL, action->src_dir,
                                                  GDK_ACTION_MOVE, NULL,
                                                  undo_redo_done_transfer_callback, action);

            g_list_free_full (uris, g_object_unref); /* marlin-file-operation takes deep copy */
            break;

        case MARLIN_UNDO_RENAME:
            file = g_file_new_for_uri (action->new_uri);
            new_name = get_uri_basename (action->old_uri);
            pf_file_utils_set_file_display_name (file,
                                                 new_name,
                                                 NULL,
                                                 undo_redo_done_rename_callback,
                                                 action);
            g_free (new_name);
            g_object_unref (file);
            break;
        case MARLIN_UNDO_DELETE:
        default:
            self->undo_redo_flag = FALSE;
            break;                  /* We shouldn't be here */
        }
    }

    if (cb != NULL)
        (*cb) ((gpointer) parent_view);
}

/** ****************************************************************
 * Adds an operation to the stack
** ****************************************************************/
void
marlin_undo_manager_add_action (MarlinUndoManager *self,
                                MarlinUndoActionData *action)
{
    if (!action)
        return;

    if (!(action && action->is_valid)) {
        free_undo_action ((gpointer) action, NULL);
        return;
    }

    action->manager = self;

    g_mutex_lock (&self->mutex);
    stack_push_action (self, action);
    g_mutex_unlock (&self->mutex);

    do_menu_update (self);
}

void
marlin_undo_manager_add_rename_action (MarlinUndoManager* self,
                                       GFile* new_file,
                                       const char* original_name) {

    MarlinUndoActionData *data = marlin_undo_manager_data_new (MARLIN_UNDO_RENAME, 1);

    data->old_uri = g_strconcat (g_path_get_dirname (g_file_get_uri (new_file)),
                                 G_DIR_SEPARATOR_S,
                                 original_name,
                                 NULL);

    data->new_uri = g_file_get_uri (new_file);
    data->is_valid = TRUE;

    marlin_undo_manager_add_action (self, data);
}

static GList *
get_all_trashed_items (GQueue *stack)
{
    MarlinUndoActionData *action = NULL;
    GList *trash = NULL;
    GQueue *tmp_stack = g_queue_copy (stack);

    while ((action = (MarlinUndoActionData *) g_queue_pop_tail (tmp_stack)) != NULL) {
        if (action->trashed) {
            GList *keys = g_hash_table_get_keys (action->trashed);
            for (GList *l = keys; l != NULL; l = l->next) {
                trash = g_list_prepend (trash, l->data);
            }

            g_list_free (keys);
        }
    }

    g_queue_free (tmp_stack);
    return (trash);
}

static gboolean
is_destination_uri_action_partof_trashed (GList *trash, GList *g)
{
    for (GList *l = trash; l != NULL; l = l->next) {
        for (; g != NULL; g = g->next) {
            gchar *uri = g_file_get_uri (g->data);
            if (!strcmp (uri, l->data)) {
                g_free (uri);
                return TRUE;
            }

            g_free (uri);
        }
    }

    return FALSE;
}
/** ****************************************************************
 * Callback after emptying the trash
** ****************************************************************/
void
marlin_undo_manager_trash_has_emptied (MarlinUndoManager *self)
{
    /* Clear actions from the oldest to the newest move to trash */
    g_mutex_lock (&self->mutex);
    clear_redo_actions (self);
    MarlinUndoActionData *action = NULL;

    GList *g;
    GQueue *tmp_stack = g_queue_copy(self->stack);
    GList *trash = get_all_trashed_items (tmp_stack);
    while ((action = (MarlinUndoActionData *) g_queue_pop_tail (tmp_stack)) != NULL)
    {
        if (action->destinations && action->dest_dir) {
            /* what a pain rebuild again and again an uri
            ** TODO change the struct add uri elements */
            g = construct_gfile_list (action->destinations, action->dest_dir);
            /* remove action for trashed item uris == destination action */
            if (is_destination_uri_action_partof_trashed(trash, g)) {
                g_queue_remove (self->stack, action);
                continue;
            }
        }
        if (action->type == MARLIN_UNDO_MOVETOTRASH) {
            //printf ("detected MARLIN_UNDO_MOVETOTRASH\n");
            g_queue_remove (self->stack, action);
        }
    }

    g_queue_free (tmp_stack);
    g_mutex_unlock (&self->mutex);
    do_menu_update (self);
}

/** ****************************************************************
 * Returns the modification time for the given file (used for undo trash)
** ****************************************************************/
//amtest
/* TODO use GOFFile we shouldn't have to query_info we already know all of this */
guint64
marlin_undo_manager_get_file_modification_time (GFile *file)
{
    GFileInfo *info;
    guint64 mtime;
    info = g_file_query_info (file, G_FILE_ATTRIBUTE_TIME_MODIFIED,
                              G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, FALSE, NULL);
    if (info == NULL) {
        return -1;
    }

    mtime = g_file_info_get_attribute_uint64 (info,
                                              G_FILE_ATTRIBUTE_TIME_MODIFIED);

    g_object_unref (info);

    return mtime;
}

/** ****************************************************************
 * Returns a new undo data container
** ****************************************************************/
MarlinUndoActionData *
marlin_undo_manager_data_new (MarlinUndoActionType type, gint items_count)
{
    //amtest
    //printf("%s\n", G_STRFUNC);
    MarlinUndoActionData *data = g_slice_new0 (MarlinUndoActionData);
    data->type = type;
    data->count = items_count;

    if (type == MARLIN_UNDO_MOVETOTRASH) {
        data->trashed = g_hash_table_new_full (g_str_hash, g_str_equal, g_free, g_free);
    }
    //undotest
    /*else if (type == MARLIN_UNDO_RECURSIVESETPERMISSIONS) {
      data->original_permissions =
      g_hash_table_new_full (g_str_hash, g_str_equal, g_free, g_free);
      }*/

    return data;
}

/** ****************************************************************
 * Sets the source directory
** ****************************************************************/
void
marlin_undo_manager_data_set_src_dir (MarlinUndoActionData *data, GFile *src)
{
    if (!data)
        return;

    data->src_dir = src;
}

/** ****************************************************************
 * Sets the destination directory
** ****************************************************************/
void
marlin_undo_manager_data_set_dest_dir (MarlinUndoActionData *data, GFile *dest)
{
    if (!data)
        return;

    data->dest_dir = dest;
}

/** ****************************************************************
 * Pushes an origin, target pair in an existing undo data container
** ****************************************************************/
void
marlin_undo_manager_data_add_origin_target_pair (MarlinUndoActionData *data,
                                                 GFile *origin,
                                                 GFile *target)
{

    if (!data)
        return;

    char *src_relative = g_file_get_relative_path (data->src_dir, origin);
    data->sources = g_list_prepend (data->sources, src_relative);
    char *dest_relative = g_file_get_relative_path (data->dest_dir, target);
    data->destinations = g_list_prepend (data->destinations, dest_relative);

    data->is_valid = TRUE;
}

/** ****************************************************************
 * Pushes an trashed file with modification time in an existing undo data container
** ****************************************************************/
void
marlin_undo_manager_data_add_trashed_file (MarlinUndoActionData *data,
                                           GFile *file,
                                           guint64 mtime)
{
    if (!data)
        return;

    guint64 *modification_time = g_new (guint64, 1);
    *modification_time = mtime;

    char *original_uri = g_file_get_uri (file);
    //amtest
    //printf ("[trash] orig uri %s\n", originalURI);

    g_hash_table_insert (data->trashed, original_uri, modification_time);

    data->is_valid = TRUE;
}

/** ****************************************************************
 * Pushes a recursive permission change data in an existing undo data container
** ****************************************************************/
void
marlin_undo_manager_data_add_file_permissions (MarlinUndoActionData *data,
                                               GFile *file,
                                               guint32 permission)
{
    if (!data)
        return;

    guint32 *currentPermission = g_new (guint32, 1);
    *currentPermission = permission;

    char *originalURI = g_file_get_uri (file);

    g_hash_table_insert (data->original_permissions, originalURI,
                         currentPermission);

    data->is_valid = TRUE;
}

/** ****************************************************************
 * Sets the original file permission in an existing undo data container
** ****************************************************************/
void
marlin_undo_manager_data_set_file_permissions (MarlinUndoActionData *data,
                                               char *uri,
                                               guint32 current_permissions,
                                               guint32 new_permissions)
{
    if (!data)
        return;

    data->target_uri = uri;

    data->current_permissions = current_permissions;
    data->new_permissions = new_permissions;

    data->is_valid = TRUE;
}

/** ****************************************************************
 * Sets the change owner information in an existing undo data container
** ****************************************************************/
void
marlin_undo_manager_data_set_owner_change_information (MarlinUndoActionData *data,
                                                       char *uri,
                                                       const char *current_user,
                                                       const char *new_user)
{
    if (!data)
        return;

    data->target_uri = uri;

    data->original_user_name_or_id = g_strdup (current_user);
    data->new_user_name_or_id = g_strdup (new_user);

    data->is_valid = TRUE;
}

/** ****************************************************************
 * Sets the change group information in an existing undo data container
** ****************************************************************/
void
marlin_undo_manager_data_set_group_change_information (MarlinUndoActionData *data,
                                                       char *uri,
                                                       const char *current_group,
                                                       const char *new_group)
{
    if (!data)
        return;

    data->target_uri = uri;

    data->original_group_name_or_id = g_strdup (current_group);
    data->new_group_name_or_id = g_strdup (new_group);

    data->is_valid = TRUE;
}

/** ****************************************************************
 * Sets the permission change mask
** ****************************************************************/
void
marlin_undo_manager_data_set_recursive_permissions (MarlinUndoActionData *data,
                                                    guint32 file_permissions,
                                                    guint32 file_mask,
                                                    guint32 dir_permissions,
                                                    guint32 dir_mask)
{
    if (!data)
        return;

    data->file_permissions = file_permissions;
    data->file_mask = file_mask;
    data->dir_permissions = dir_permissions;
    data->dir_mask = dir_mask;

    data->is_valid = TRUE;
}

/** ****************************************************************
 * Sets create file information
** ****************************************************************/
void
marlin_undo_manager_data_set_create_data (MarlinUndoActionData *data,
                                          char *target_uri,
                                          char *template)
{
    if (!data)
        return;

    data->template = g_strdup (template);
    data->target_uri = g_strdup (target_uri);

    data->is_valid = TRUE;
}

/** ****************************************************************
 * Sets rename information
** ****************************************************************/
void
marlin_undo_manager_data_set_rename_information (MarlinUndoActionData *data,
                                                 GFile *old_file,
                                                 GFile *new_file)
{
    if (!data)
        return;

    data->old_uri = g_file_get_uri (old_file);
    data->new_uri = g_file_get_uri (new_file);

    data->is_valid = TRUE;
}

/* *****************************************************************
   Private methods (nothing to see here, move along)
***************************************************************** */

static MarlinUndoActionData *
stack_scroll_right (MarlinUndoManager *self)
{
    gpointer data = NULL;

    if (!can_undo (self))
        return NULL;

    data = g_queue_peek_nth (self->stack, self->index);
    if (self->index < g_queue_get_length (self->stack)) {
        self->index++;
    }

    return data;
}

/** ---------------------------------------------------------------- */
static MarlinUndoActionData *
stack_scroll_left (MarlinUndoManager *self)
{
    gpointer data = NULL;

    if (!can_redo (self))
        return NULL;

    self->index--;
    data = g_queue_peek_nth (self->stack, self->index);

    return data;
}

/** ---------------------------------------------------------------- */
static void
stack_clear_n_oldest (GQueue *stack, guint n)
{
    MarlinUndoActionData *action;

    for (guint i = 0; i < n; i++) {
        if ((action = (MarlinUndoActionData *) g_queue_pop_tail (stack)) == NULL)
            break;
        if (action->locked) {
            action->freed = TRUE;
        } else {
            free_undo_action (action, NULL);
        }
    }
}

/** ---------------------------------------------------------------- */
static void
stack_fix_size (MarlinUndoManager *self)
{
    guint length = g_queue_get_length (self->stack);

    if (length > self->undo_levels) {
        if (self->index > (self->undo_levels + 1)) {
            /* If the index will fall off the stack
             * move it back to the maximum position */
            self->index = self->undo_levels + 1;
        }
        stack_clear_n_oldest (self->stack, length - (self->undo_levels));
    }
}

/** ---------------------------------------------------------------- */
static void
clear_redo_actions (MarlinUndoManager *self)
{
    while (self->index > 0) {
        MarlinUndoActionData *head = (MarlinUndoActionData *)
            g_queue_pop_head (self->stack);
        free_undo_action (head, NULL);
        self->index--;
    }
}

/** ---------------------------------------------------------------- */
static void
stack_push_action (MarlinUndoManager *self,
                   MarlinUndoActionData *action)
{
    guint length;

    clear_redo_actions (self);

    g_queue_push_head (self->stack, (gpointer) action);
    length = g_queue_get_length (self->stack);

    if (length > self->undo_levels) {
        stack_fix_size (self);
    }
}

/** ---------------------------------------------------------------- */
static gchar *
get_first_target_short_name (MarlinUndoActionData *action)
{
    GList *targets_first;
    gchar *file_name;

    targets_first = g_list_first (action->destinations);
    file_name = (gchar *) g_strdup (targets_first->data);

    return file_name;
}

/** ---------------------------------------------------------------- */
static gchar *
get_undo_description (MarlinUndoActionData *action)
{
    gchar *description = NULL;
    gchar *source = NULL;
    guint count;

    if (action != NULL) {
        if (action->undo_description == NULL) {
            if (action->src_dir) {
                source = g_file_get_path (action->src_dir);
            }
            count = action->count;
            switch (action->type) {
            case MARLIN_UNDO_COPY:
                if (count != 1) {
                    description = g_strdup_printf (_("Delete %d copied items"), count);
                } else {
                    gchar *name = get_first_target_short_name (action);
                    description = g_strdup_printf (_("Delete '%s'"), name);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_DUPLICATE:
                if (count != 1) {
                    description =
                        g_strdup_printf (_("Delete %d duplicated items"), count);
                } else {
                    gchar *name = get_first_target_short_name (action);
                    description = g_strdup_printf (_("Delete '%s'"), name);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_MOVE:
                if (count != 1) {
                    description =
                        g_strdup_printf (_
                                         ("Move %d items back to '%s'"), count, source);
                } else {
                    gchar *name = get_first_target_short_name (action);
                    description =
                        g_strdup_printf (_("Move '%s' back to '%s'"), name, source);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_RENAME:
                {
                    char *from_name = get_uri_basename (action->new_uri);
                    char *to_name = get_uri_basename (action->old_uri);
                    description =
                        g_strdup_printf (_("Rename '%s' as '%s'"), from_name, to_name);
                    g_free (from_name);
                    g_free (to_name);
                }
                break;
            /*case MARLIN_UNDO_CREATEFILEFROMTEMPLATE:*/
            case MARLIN_UNDO_CREATEEMPTYFILE:
            case MARLIN_UNDO_CREATEFOLDER:
                {
                    char *name = get_uri_basename (action->target_uri);
                    description = g_strdup_printf (_("Delete '%s'"), name);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_MOVETOTRASH:
                {
                    count = g_hash_table_size (action->trashed);
                    if (count != 1) {
                        description =
                            g_strdup_printf (_("Restore %d items from trash"), count);
                    } else {
                        GList *keys = g_hash_table_get_keys (action->trashed);
                        GList *first = g_list_first (keys);
                        char *item = (char *) first->data;
                        char *name = get_uri_basename (item);
                        char *orig_path = get_uri_parent_path (item);
                        description =
                            g_strdup_printf (_("Restore '%s' to '%s'"), name, orig_path);
                        g_free (name);
                        g_free (orig_path);
                        g_list_free (keys);
                    }
                }
                break;
            case MARLIN_UNDO_RESTOREFROMTRASH:
                {
                    if (count != 1) {
                        description =
                            g_strdup_printf (_("Move %d items back to trash"), count);
                    } else {
                        gchar *name = get_first_target_short_name (action);
                        description = g_strdup_printf (_("Move '%s' back to trash"), name);
                        g_free (name);
                    }
                }
                break;
            case MARLIN_UNDO_CREATELINK:
                {
                    if (count != 1) {
                        description =
                            g_strdup_printf (_("Delete links to %d items"), count);
                    } else {
                        gchar *name = get_first_target_short_name (action);
                        description = g_strdup_printf (_("Delete link to '%s'"), name);
                        g_free (name);
                    }
                }
                break;
            case MARLIN_UNDO_RECURSIVESETPERMISSIONS:
                {
                    char *name = g_file_get_path (action->dest_dir);
                    description =
                        g_strdup_printf (_
                                         ("Restore original permissions of items enclosed in '%s'"), name);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_SETPERMISSIONS:
                {
                    char *name = get_uri_basename (action->target_uri);
                    description =
                        g_strdup_printf (_("Restore original permissions of '%s'"), name);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_CHANGEGROUP:
                {
                    char *name = get_uri_basename (action->target_uri);
                    description =
                        g_strdup_printf (_
                                         ("Restore group of '%s' to '%s'"),
                                         name, action->original_group_name_or_id);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_CHANGEOWNER:
                {
                    char *name = get_uri_basename (action->target_uri);
                    description =
                        g_strdup_printf (_
                                         ("Restore owner of '%s' to '%s'"),
                                         name, action->original_user_name_or_id);
                    g_free (name);
                }
                break;
            default:
                break;
            }
            if (source) {
                g_free (source);
            }
            action->undo_description = description;
        } else {
            return action->undo_description;
        }
    }

    return description;
}

/** ---------------------------------------------------------------- */
static gchar *
get_redo_description (MarlinUndoActionData * action)
{
    gchar *description = NULL;
    gchar *destination = NULL;
    guint count;

    if (action != NULL) {
        if (action->redo_description == NULL) {
            if (action->dest_dir) {
                destination = g_file_get_path (action->dest_dir);
            }
            count = action->count;
            switch (action->type) {
            case MARLIN_UNDO_COPY:
                if (count != 1) {
                    description =
                        g_strdup_printf (_
                                         ("Copy %d items to '%s'"), count, destination);
                } else {
                    gchar *name = get_first_target_short_name (action);
                    description =
                        g_strdup_printf (_("Copy '%s' to '%s'"), name, destination);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_DUPLICATE:
                if (count != 1) {
                    description =
                        g_strdup_printf (_
                                         ("Duplicate of %d items in '%s'"), count, destination);
                } else {
                    gchar *name = get_first_target_short_name (action);
                    description =
                        g_strdup_printf (_
                                         ("Duplicate '%s' in '%s'"), name, destination);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_MOVE:
                if (count != 1) {
                    description =
                        g_strdup_printf (_
                                         ("Move %d items to '%s'"), count, destination);
                } else {
                    gchar *name = get_first_target_short_name (action);
                    description =
                        g_strdup_printf (_("Move '%s' to '%s'"), name, destination);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_RENAME:
                {
                    char *from_name = get_uri_basename (action->old_uri);
                    char *to_name = get_uri_basename (action->new_uri);
                    description =
                        g_strdup_printf (_("Rename '%s' as '%s'"), from_name, to_name);
                    g_free (from_name);
                    g_free (to_name);
                }
                break;
            case MARLIN_UNDO_CREATEFILEFROMTEMPLATE:
                {
                    char *name = get_uri_basename (action->target_uri);
                    description =
                        g_strdup_printf (_("Create new file '%s' from template "), name);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_CREATEEMPTYFILE:
                {
                    char *name = get_uri_basename (action->target_uri);
                    description = g_strdup_printf (_("Create an empty file '%s'"), name);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_CREATEFOLDER:
                {
                    char *name = get_uri_basename (action->target_uri);
                    description = g_strdup_printf (_("Create a new folder '%s'"), name);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_MOVETOTRASH:
                {
                    count = g_hash_table_size (action->trashed);
                    if (count != 1) {
                        description = g_strdup_printf (_("Move %d items to trash"), count);
                    } else {
                        GList *keys = g_hash_table_get_keys (action->trashed);
                        GList *first = g_list_first (keys);
                        char *item = (char *) first->data;
                        char *name = get_uri_basename (item);
                        description = g_strdup_printf (_("Move '%s' to trash"), name);
                        g_free (name);
                        g_list_free (keys);
                    }
                }
                break;
            case MARLIN_UNDO_RESTOREFROMTRASH:
                {
                    if (count != 1) {
                        description =
                            g_strdup_printf (_("Restore %d items from trash"), count);
                    } else {
                        gchar *name = get_first_target_short_name (action);
                        description = g_strdup_printf (_("Restore '%s' from trash"), name);
                        g_free (name);
                    }
                }
                break;
            case MARLIN_UNDO_CREATELINK:
                {
                    if (count != 1) {
                        description =
                            g_strdup_printf (_("Create links to %d items"), count);
                    } else {
                        gchar *name = get_first_target_short_name (action);
                        description = g_strdup_printf (_("Create link to '%s'"), name);
                        g_free (name);
                    }
                }
                break;
            case MARLIN_UNDO_RECURSIVESETPERMISSIONS:
                {
                    char *name = g_file_get_path (action->dest_dir);
                    description =
                        g_strdup_printf (_("Set permissions of items enclosed in '%s'"),
                                         name);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_SETPERMISSIONS:
                {
                    char *name = get_uri_basename (action->target_uri);
                    description = g_strdup_printf (_("Set permissions of '%s'"), name);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_CHANGEGROUP:
                {
                    char *name = get_uri_basename (action->target_uri);
                    description =
                        g_strdup_printf (_
                                         ("Set group of '%s' to '%s'"),
                                         name, action->new_group_name_or_id);
                    g_free (name);
                }
                break;
            case MARLIN_UNDO_CHANGEOWNER:
                {
                    char *name = get_uri_basename (action->target_uri);
                    description =
                        g_strdup_printf (_
                                         ("Set owner of '%s' to '%s'"), name, action->new_user_name_or_id);
                    g_free (name);
                }
                break;
            default:
                break;
            }
            if (destination) {
                g_free (destination);
            }
            action->redo_description = description;
        } else {
            return action->redo_description;
        }
    }

    return description;
}

/** ---------------------------------------------------------------- */
static gchar *
get_undo_label (MarlinUndoActionData * action)
{
    gchar *label = NULL;
    guint count;

    if (action != NULL) {
        if (action->undo_label == NULL) {
            count = action->count;
            switch (action->type) {
            case MARLIN_UNDO_COPY:
                label = g_strdup_printf (ngettext
                                         ("_Undo copy of %d item",
                                          "_Undo copy of %d items", count), count);
                break;
            case MARLIN_UNDO_DUPLICATE:
                label = g_strdup_printf (ngettext
                                         ("_Undo duplicate of %d item",
                                          "_Undo duplicate of %d items", count), count);
                break;
            case MARLIN_UNDO_MOVE:
                label = g_strdup_printf (ngettext
                                         ("_Undo move of %d item",
                                          "_Undo move of %d items", count), count);
                break;
            case MARLIN_UNDO_RENAME:
                label = g_strdup_printf (ngettext
                                         ("_Undo rename of %d item",
                                          "_Undo rename of %d items", count), count);
                break;
            case MARLIN_UNDO_CREATEEMPTYFILE:
                label = g_strdup_printf (_("_Undo creation of an empty file"));
                break;
            case MARLIN_UNDO_CREATEFILEFROMTEMPLATE:
                label = g_strdup_printf (_("_Undo creation of a file from template"));
                break;
            case MARLIN_UNDO_CREATEFOLDER:
                label = g_strdup_printf (ngettext
                                         ("_Undo creation of %d folder",
                                          "_Undo creation of %d folders", count), count);
                break;
            case MARLIN_UNDO_MOVETOTRASH:
                label = g_strdup_printf (ngettext
                                         ("_Undo move to trash of %d item",
                                          "_Undo move to trash of %d items", count), count);
                break;
            case MARLIN_UNDO_RESTOREFROMTRASH:
                label = g_strdup_printf (ngettext
                                         ("_Undo restore from trash of %d item",
                                          "_Undo restore from trash of %d items", count), count);
                break;
            case MARLIN_UNDO_CREATELINK:
                label = g_strdup_printf (ngettext
                                         ("_Undo create link to %d item",
                                          "_Undo create link to %d items", count), count);
                break;
            case MARLIN_UNDO_DELETE:
                label = g_strdup_printf (ngettext
                                         ("_Undo delete of %d item",
                                          "_Undo delete of %d items", count), count);
                break;
            case MARLIN_UNDO_RECURSIVESETPERMISSIONS:
                label = g_strdup_printf (ngettext
                                         ("Undo recursive change permissions of %d item",
                                          "Undo recursive change permissions of %d items",
                                          count), count);
                break;
            case MARLIN_UNDO_SETPERMISSIONS:
                label = g_strdup_printf (ngettext
                                         ("Undo change permissions of %d item",
                                          "Undo change permissions of %d items", count), count);
                break;
            case MARLIN_UNDO_CHANGEGROUP:
                label = g_strdup_printf (ngettext
                                         ("Undo change group of %d item",
                                          "Undo change group of %d items", count), count);
                break;
            case MARLIN_UNDO_CHANGEOWNER:
                label = g_strdup_printf (ngettext
                                         ("Undo change owner of %d item",
                                          "Undo change owner of %d items", count), count);
                break;
            default:
                break;
            }
            action->undo_label = label;
        } else {
            return action->undo_label;
        }
    }

    return label;
}

/** ---------------------------------------------------------------- */
static gchar *
get_redo_label (MarlinUndoActionData * action)
{
    gchar *label = NULL;
    guint count;

    if (action != NULL) {
        if (action->redo_label == NULL) {
            count = action->count;
            switch (action->type) {
            case MARLIN_UNDO_COPY:
                label = g_strdup_printf (ngettext
                                         ("_Redo copy of %d item",
                                          "_Redo copy of %d items", count), count);
                break;
            case MARLIN_UNDO_DUPLICATE:
                label = g_strdup_printf (ngettext
                                         ("_Redo duplicate of %d item",
                                          "_Redo duplicate of %d items", count), count);
                break;
            case MARLIN_UNDO_MOVE:
                label = g_strdup_printf (ngettext
                                         ("_Redo move of %d item",
                                          "_Redo move of %d items", count), count);
                break;
            case MARLIN_UNDO_RENAME:
                label = g_strdup_printf (ngettext
                                         ("_Redo rename of %d item",
                                          "_Redo rename of %d items", count), count);
                break;
            case MARLIN_UNDO_CREATEEMPTYFILE:
                label = g_strdup_printf (_("_Redo creation of an empty file"));
                break;
            case MARLIN_UNDO_CREATEFILEFROMTEMPLATE:
                label = g_strdup_printf (_("_Redo creation of a file from template"));
                break;
            case MARLIN_UNDO_CREATEFOLDER:
                label = g_strdup_printf (ngettext
                                         ("_Redo creation of %d folder",
                                          "_Redo creation of %d folders", count), count);
                break;
            case MARLIN_UNDO_MOVETOTRASH:
                label = g_strdup_printf (ngettext
                                         ("_Redo move to trash of %d item",
                                          "_Redo move to trash of %d items", count), count);
                break;
            case MARLIN_UNDO_RESTOREFROMTRASH:
                label = g_strdup_printf (ngettext
                                         ("_Redo restore from trash of %d item",
                                          "_Redo restore from trash of %d items", count), count);
                break;
            case MARLIN_UNDO_CREATELINK:
                label = g_strdup_printf (ngettext
                                         ("_Redo create link to %d item",
                                          "_Redo create link to %d items", count), count);
                break;
            case MARLIN_UNDO_DELETE:
                label = g_strdup_printf (ngettext
                                         ("_Redo delete of %d item",
                                          "_Redo delete of %d items", count), count);
                break;
            case MARLIN_UNDO_RECURSIVESETPERMISSIONS:
                label = g_strdup_printf (ngettext
                                         ("Redo recursive change permissions of %d item",
                                          "Redo recursive change permissions of %d items",
                                          count), count);
                break;
            case MARLIN_UNDO_SETPERMISSIONS:
                label = g_strdup_printf (ngettext
                                         ("Redo change permissions of %d item",
                                          "Redo change permissions of %d items", count), count);
                break;
            case MARLIN_UNDO_CHANGEGROUP:
                label = g_strdup_printf (ngettext
                                         ("Redo change group of %d item",
                                          "Redo change group of %d items", count), count);
                break;
            case MARLIN_UNDO_CHANGEOWNER:
                label = g_strdup_printf (ngettext
                                         ("Redo change owner of %d item",
                                          "Redo change owner of %d items", count), count);
                break;
            default:
                break;
            }
            action->redo_label = label;
        } else {
            return action->redo_label;
        }
    }

    return label;
}

/** ---------------------------------------------------------------- */
static void
undo_redo_done_transfer_callback (GHashTable * debuting_uris, gpointer data)
{
    MarlinUndoActionData *action;

    action = (MarlinUndoActionData *) data;

    /* If the action needed to be freed but was locked, free now */
    if (action->freed) {
        free_undo_action (action, NULL);
    } else {
        action->locked = FALSE;
    }

    MarlinUndoManager *manager = action->manager;
    manager->undo_redo_flag = FALSE;

    /* Update menus */
    do_menu_update (action->manager);
}

/** ---------------------------------------------------------------- */
static void
undo_redo_done_delete_callback (gboolean user_cancel, gpointer callback_data)
{
    undo_redo_done_transfer_callback (NULL, callback_data);
}

/** ---------------------------------------------------------------- */
static void
undo_redo_done_create_callback (GFile * new_file, gpointer callback_data)
{
    undo_redo_done_transfer_callback (NULL, callback_data);
}

/** ---------------------------------------------------------------- */
static void
undo_redo_op_callback (gpointer callback_data)
{
    undo_redo_done_transfer_callback (NULL, callback_data);
}

/** ---------------------------------------------------------------- */
static void
undo_redo_done_rename_callback (GFile        *file,
                                GAsyncResult *result,
                                gpointer      user_data)
{
    GError *e = NULL;
    GFile* res_file = pf_file_utils_set_file_display_name_finish (result, &e);
    if (e != NULL) {
        g_error_free (e);
    }

    g_object_unref (res_file);
    undo_redo_done_transfer_callback (NULL, user_data);
}

/** ---------------------------------------------------------------- */
static void
free_undo_action (gpointer data, gpointer user_data)
{
    MarlinUndoActionData *action = (MarlinUndoActionData *) data;

    if (!action)
        return;

    g_free (action->template);
    g_free (action->target_uri);
    g_free (action->old_uri);
    g_free (action->new_uri);

    g_free (action->undo_label);
    g_free (action->undo_description);
    g_free (action->redo_label);
    g_free (action->redo_description);

    g_free (action->original_group_name_or_id);
    g_free (action->original_user_name_or_id);
    g_free (action->new_group_name_or_id);
    g_free (action->new_user_name_or_id);

    if (action->sources) {
        g_list_free_full (action->sources, g_free);
    }
    if (action->destinations) {
        g_list_free_full (action->destinations, g_free);
    }

    if (action->trashed) {
        g_hash_table_destroy (action->trashed);
    }

    if (action->original_permissions) {
        g_hash_table_destroy (action->original_permissions);
    }

    if (action->src_dir)
        g_object_unref (action->src_dir);
    if (action->dest_dir)
        g_object_unref (action->dest_dir);

    if (action)
        g_slice_free (MarlinUndoActionData, action);
}

/** ---------------------------------------------------------------- */
static void
undostack_dispose_all (GQueue * queue)
{
    g_queue_foreach (queue, free_undo_action, NULL);
}

/** ---------------------------------------------------------------- */
static gboolean
can_undo (MarlinUndoManager * self)
{
    return (get_next_undo_action (self) != NULL);
}

/** ---------------------------------------------------------------- */
static gboolean
can_redo (MarlinUndoManager * self)
{
    return (get_next_redo_action (self) != NULL);
}

/** ---------------------------------------------------------------- */
static MarlinUndoActionData *
get_next_redo_action (MarlinUndoManager * self)
{
    if (g_queue_is_empty (self->stack)) {
        return NULL;
    }

    if (self->index == 0) {
        /* ... no redo actions */
        return NULL;
    }

    MarlinUndoActionData *action = g_queue_peek_nth (self->stack,
                                                     self->index - 1);

    if (action->locked) {
        return NULL;
    } else {
        return action;
    }
}

/** ---------------------------------------------------------------- */
static MarlinUndoActionData *
get_next_undo_action (MarlinUndoManager *self)
{
    if (g_queue_is_empty (self->stack)) {
        return NULL;
    }

    guint stack_size = g_queue_get_length (self->stack);

    if (self->index == stack_size) {
        return NULL;
    }

    MarlinUndoActionData *action = g_queue_peek_nth (self->stack,
                                                     self->index);

    if (action->locked) {
        return NULL;
    } else {
        return action;
    }
}

/** ---------------------------------------------------------------- */
static void
do_menu_update (MarlinUndoManager *self)
{
    g_return_if_fail (self);

    MarlinUndoActionData *action;
    MarlinUndoMenuData *data = g_slice_new0 (MarlinUndoMenuData);

    g_mutex_lock (&self->mutex);

    action = get_next_undo_action (self);
    if (action != NULL) {
        data->undo_label = get_undo_label (action);
        data->undo_description = get_undo_description (action);
    }

    action = get_next_redo_action (self);
    if (action != NULL) {
        data->redo_label = get_redo_label (action);
        data->redo_description = get_redo_description (action);
    }

    g_mutex_unlock (&self->mutex);

    /* Update menus */
    g_signal_emit (self, signals[REQUEST_MENU_UPDATE], 0, data);

    /* Free the signal data */
    // Note: we do not own labels and descriptions, they are part of the action.
    g_slice_free (MarlinUndoMenuData, data);
}

/** ---------------------------------------------------------------- */
static GList *
construct_gfile_list (GList *urilist, GFile *parent)
{
    GList *file_list = NULL;

    for (GList *l = urilist; l != NULL; l = l->next) {
        GFile *file = g_file_get_child (parent, l->data);
        file_list = g_list_prepend (file_list, file);
    }

    return file_list;
}

/** ---------------------------------------------------------------- */
static GList *
construct_gfile_list_from_uri (char *uri)
{
    GFile *file = g_file_new_for_uri (uri);

    return g_list_prepend (NULL, file);
}

/** ---------------------------------------------------------------- */
static GList *
uri_list_to_gfile_list (GList * urilist)
{
    GList *file_list = NULL;

    for (GList *l = urilist; l != NULL; l = l->next) {
        GFile *file = g_file_new_for_uri (l->data);
        file_list = g_list_prepend (file_list, file);
    }

    return file_list;
}

/** ---------------------------------------------------------------- */
static char *
get_uri_basename (char *uri)
{
    GFile *f = g_file_new_for_uri (uri);
    char *basename = g_file_get_basename (f);
    g_object_unref (f);
    return basename;
}

/** ---------------------------------------------------------------- */
static char *
get_uri_parent (char *uri)
{
    GFile *f = g_file_new_for_uri (uri);
    GFile *p = g_file_get_parent (f);
    char *parent = g_file_get_uri (p);
    g_object_unref (f);
    g_object_unref (p);
    return parent;
}

/** ---------------------------------------------------------------- */
static char *
get_uri_parent_path (char *uri)
{
    GFile *f = g_file_new_for_uri (uri);
    GFile *p = g_file_get_parent (f);
    char *parent = g_file_get_path (p);
    g_object_unref (f);
    g_object_unref (p);
    return parent;
}

/** ---------------------------------------------------------------- */
static GFile *
get_file_parent_from_uri (char *uri)
{
    GFile *f = g_file_new_for_uri (uri);
    GFile *p = g_file_get_parent (f);
    g_object_unref (f);
    return p;
}

/** ---------------------------------------------------------------- */
static GHashTable *
retrieve_files_to_restore (GHashTable * trashed)
{
    GFileEnumerator *enumerator;
    GFileInfo *info;
    GFile *trash;
    GHashTable *to_restore;

    to_restore =
        g_hash_table_new_full (g_direct_hash,
                               g_direct_equal, g_object_unref, g_free);

    trash = g_file_new_for_uri ("trash:");

    enumerator = g_file_enumerate_children (trash,
                                            G_FILE_ATTRIBUTE_STANDARD_NAME
                                            ","
                                            G_FILE_ATTRIBUTE_TIME_MODIFIED
                                            ",trash::orig-path", G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, FALSE, NULL);
    //amtest
    /*guint nb;
      GList *l;*/
    if (!(g_hash_table_size (trashed)) > 0)
        return NULL;

    if (enumerator) {
        while ((info =
                g_file_enumerator_next_file (enumerator, NULL, NULL)) != NULL) {
            /* Retrieve the original file uri */
            const char *origpath = g_file_info_get_attribute_byte_string (info, "trash::orig-path");
            if (origpath) {
                GFile *origfile = g_file_new_for_path (origpath);
                char *origuri = g_file_get_uri (origfile);
                gpointer lookupvalue;

                g_object_unref (origfile);

                lookupvalue = g_hash_table_lookup (trashed, origuri);

                if (lookupvalue) {
                    //printf ("we got a MATCH\n");
                    guint64 *mtime = (guint64 *) lookupvalue;
                    guint64 mtime_item = g_file_info_get_attribute_uint64 (info, G_FILE_ATTRIBUTE_TIME_MODIFIED);
                    if (*mtime == mtime_item) {
                        GFile *item = g_file_get_child (trash, g_file_info_get_name (info)); /* File in the trash */
                        g_hash_table_insert (to_restore, item, origuri);
                    }
                } else {
                    g_free (origuri);
                }
            }
        }

        g_file_enumerator_close (enumerator, FALSE, NULL);
        g_object_unref (enumerator);
    }

    g_object_unref (trash);

    return to_restore;
}

/** ---------------------------------------------------------------- */
