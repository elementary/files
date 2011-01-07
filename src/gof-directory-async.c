/*
 * Copyright (C) 2010 ammonkey
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * version 3.0 as published by the Free Software Foundation.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License version 3.0 for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library. If not, see
 * <http://www.gnu.org/licenses/>.
 *
 * Author: ammonkey <am.monkeyd@gmail.com>
 */

#include "gof-directory-async.h"
#include "nautilus-icon-info.h"
#include "gof-monitor.h"
#include "gof-file.h"
#include "nautilus-cell-renderer-text-ellipsized.h"
#include "marlin-global-preferences.h"
#include "marlin-vala.h"

struct GOFDirectoryAsyncPrivate {
    //GTimer          *timer;
    GFile           *parent;
    GOFMonitor      *monitor;
    //FMListModel     *model;
    GCancellable    *cancellable;
    GCancellable    *directory_info_cancellable;
};

enum {
    FILE_LOADED,
    FILE_ADDED,
    /*FILES_CHANGED,*/
    FILE_CHANGED,
    FILE_DELETED,
    DONE_LOADING,
    /*LOAD_ERROR,*/
    INFO_AVAILABLE,
    LAST_SIGNAL
};

G_LOCK_DEFINE_STATIC (directory_cache_mutex);

static GHashTable   *directory_cache;
static guint        signals[LAST_SIGNAL];


G_DEFINE_TYPE (GOFDirectoryAsync, gof_directory_async, G_TYPE_OBJECT)
    /*#define GOF_DIRECTORY_ASYNC_GET_PRIVATE(obj) \
      (G_TYPE_INSTANCE_GET_PRIVATE(obj, GOF_TYPE_DIRECTORY_ASYNC, GOFDirectoryAsyncPrivate))*/


static void
print_error(GError *error)
{
    if (error != NULL)
    {
        g_print ("%s\n", error->message);
        g_error_free (error);
    }
}

static void
directory_load_done (GOFDirectoryAsync *dir, GFileEnumerator *enumerator, GError *error)
{
    if (enumerator) {
        g_file_enumerator_close_async (enumerator,
                                       G_PRIORITY_DEFAULT,
                                       NULL, NULL, NULL);
        g_object_unref (enumerator);
    }

    log_printf (LOG_LEVEL_UNDEFINED, "%s ended\n", G_STRFUNC);
    if (error == NULL)
        dir->loaded = TRUE;
    else 
        g_cancellable_cancel (dir->priv->cancellable);
    
    g_signal_emit (dir, signals[DONE_LOADING], 0);
    dir->loading = FALSE;
    print_error(error);

    g_object_unref (dir);
}

static void
enumerator_files_callback (GObject *source_object, GAsyncResult *result, gpointer user_data)
{
    GError *error = NULL;
    GList *files, *f;
    GOFDirectoryAsync *dir = GOF_DIRECTORY_ASYNC (user_data);

    /*if (g_cancellable_is_cancelled (dir->priv->cancellable)) {
      return;
      }*/
    GFileEnumerator *enumerator = G_FILE_ENUMERATOR (source_object);
    /* Operation was cancelled */
    if (dir == NULL)
    {
        g_object_unref (enumerator);
        return;
    }

    files = g_file_enumerator_next_files_finish (enumerator, result, &error);
    //print_error(error);

    for (f=files; f; f=f->next)
    {
        //GFileInfo *info = f->data;
        GOFFile *goff = gof_file_new ((GFileInfo *) f->data, dir->location);
        //g_object_unref (goff);

        //if (!goff->is_hidden || g_settings_get_boolean(settings, "show-hiddenfiles"))
        if (!goff->is_hidden)
        {
            if (dir->file_hash != NULL)
                g_hash_table_insert (dir->file_hash, g_object_ref (goff->location), goff);
            //g_signal_emit (dir, signals[FILE_ADDED], 0, goff);
            g_signal_emit (dir, signals[FILE_LOADED], 0, goff);

            /* val = g_file_info_get_attribute_string (info, G_FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE);
               g_file_info_get_attribute_boolean (info, G_FILE_ATTRIBUTE_ACCESS_CAN_EXECUTE)
               g_file_info_get_file_type (info) == G_FILE_TYPE_DIRECTORY ? 'd' : '-',
               */
        } else {
            if (dir->hidden_file_hash != NULL)
                g_hash_table_insert (dir->hidden_file_hash, g_object_ref (goff->location), goff);
        }
    }

    if (files != NULL) {
        g_file_enumerator_next_files_async (enumerator, FILES_PER_QUERY,
                                            G_PRIORITY_DEFAULT,
                                            dir->priv->cancellable,
                                            enumerator_files_callback,
                                            dir);
    } else {
        directory_load_done (dir, enumerator, error);
    }

    //g_list_foreach (files, (GFunc)g_object_unref, NULL);
    g_list_free (files);
}

static void
load_dir_async_callback (GObject *source_object, GAsyncResult *res, gpointer user_data)
{
    GOFDirectoryAsync *dir = user_data;
    GFileEnumerator *enumerator;
    GError *error = NULL;

    if (g_cancellable_is_cancelled (dir->priv->cancellable)) {
        return;
    }

    g_object_ref (dir);
    enumerator = g_file_enumerate_children_finish (G_FILE (source_object), res, &error);

    if (enumerator != NULL) {
        g_file_enumerator_next_files_async (enumerator,
                                            FILES_PER_QUERY,
                                            G_PRIORITY_DEFAULT,
                                            dir->priv->cancellable,
                                            enumerator_files_callback,
                                            dir);
    } else {
        directory_load_done (dir, enumerator, error);
    }
}

static void load_dir_info_async_callback (GObject *source_object, GAsyncResult *res, gpointer user_data)
{
    GOFDirectoryAsync *dir = user_data;
    GError *error = NULL;

    if (g_cancellable_is_cancelled (dir->priv->cancellable)) {
        return;
    }

    dir->info = g_file_query_info_finish (G_FILE (source_object), res, &error);
    print_error(error);

    g_signal_emit (dir, signals[INFO_AVAILABLE], 0);
}


void
load_dir_async (GOFDirectoryAsync *dir)
{
    g_return_if_fail (GOF_IS_DIRECTORY_ASYNC (dir));
    g_return_if_fail (G_IS_FILE (dir->location));

    GOFDirectoryAsyncPrivate *p = dir->priv;
    p->cancellable = g_cancellable_new ();

    if (!dir->loaded)
    {
        printf ("%s LOADED FALSE\n", G_STRFUNC);
        dir->loading = TRUE;
        char *uri = g_file_get_uri(dir->location);
        log_printf( LOG_LEVEL_UNDEFINED, "Start loading directory %s \n", uri);
        g_free (uri);
        p->monitor = gof_monitor_directory (dir);

        g_file_enumerate_children_async (dir->location, GOF_GIO_DEFAULT_ATTRIBUTES,
                                         G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                                         G_PRIORITY_DEFAULT,
                                         p->cancellable,
                                         load_dir_async_callback,
                                         dir);

        g_file_query_info_async (dir->location,
                                 GOF_GIO_DEFAULT_ATTRIBUTES,
                                 G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS,
                                 G_PRIORITY_DEFAULT,
                                 p->cancellable,
                                 load_dir_info_async_callback,
                                 dir);
    } else {
        printf ("%s ALREADY LOADED\n", G_STRFUNC);
        g_signal_emit (dir, signals[INFO_AVAILABLE], 0);
    }
}

void
gof_directory_async_cancel (GOFDirectoryAsync *dir)
{
    g_cancellable_cancel (dir->priv->cancellable);
    g_cancellable_cancel (dir->priv->cancellable);
    //g_object_unref (dir);
}

GOFDirectoryAsync *gof_directory_async_new (GFile *location)
{
    GOFDirectoryAsync *self;

    self = g_object_new (GOF_TYPE_DIRECTORY_ASYNC, NULL);
    //self->priv->model = model;
    self->location = g_object_ref (location);
    self->priv->parent = g_file_get_parent(self->location);

    return (self);
}

GOFDirectoryAsync *gof_directory_async_get_for_file (GOFFile *file)
{
    GOFDirectoryAsync *dir;

    dir = gof_directory_cache_lookup (file->location);
    if (G_UNLIKELY (dir != NULL)) {
        /* take a reference for the caller */
        g_object_ref (dir);
        printf (">>>>>>>> %s reuse cached dir %s\n", G_STRFUNC, g_file_get_uri (dir->location));
    } else {
        printf (">>>>>>>> %s create dir %s\n", G_STRFUNC, g_file_get_uri (file->location));
        dir = g_object_new (GOF_TYPE_DIRECTORY_ASYNC, NULL);
        //log_printf (LOG_LEVEL_UNDEFINED, "test %s %s\n", file->name, g_file_get_uri(file->directory));
        dir->location = g_object_ref (file->location);
        dir->priv->parent = g_object_ref (file->directory);
    }

    return (dir);
}

GOFDirectoryAsync *gof_directory_cache_lookup (GFile *file)
{
    GOFDirectoryAsync *cached_dir;

    g_return_val_if_fail (G_IS_FILE (file), NULL);

    /* allocate the GOFDirectoryAsync cache on-demand */
    if (G_UNLIKELY (directory_cache == NULL))
    {
        G_LOCK (directory_cache_mutex);
        directory_cache = g_hash_table_new_full (g_file_hash, 
                                                 (GEqualFunc) g_file_equal, 
                                                 (GDestroyNotify) g_object_unref, 
                                                 NULL);
        G_UNLOCK (directory_cache_mutex);
    }
    cached_dir = g_hash_table_lookup (directory_cache, file);

    return cached_dir;
}

GOFDirectoryAsync *gof_directory_get (GFile *location)
{
    GOFDirectoryAsync *dir;

    dir = gof_directory_cache_lookup (location);
    if (G_UNLIKELY (dir != NULL)) {
        /* take a reference for the caller */
        g_object_ref (dir);
        printf (">>>>>>>> %s reuse cached dir %s\n", G_STRFUNC, g_file_get_uri (dir->location));
    } else {
        printf (">>>>>>>> %s create dir %s\n", G_STRFUNC, g_file_get_uri (location));
        dir = gof_directory_async_new (location);
        G_LOCK (directory_cache_mutex);
        g_hash_table_insert (directory_cache, g_object_ref (dir->location), dir);
        G_UNLOCK (directory_cache_mutex);
        dir->file_hash = g_hash_table_new_full (g_file_hash, 
                                                (GEqualFunc) g_file_equal, 
                                                (GDestroyNotify) g_object_unref,          
                                                (GDestroyNotify) g_object_unref);
        dir->hidden_file_hash = g_hash_table_new_full (g_file_hash, 
                                                       (GEqualFunc) g_file_equal, 
                                                       (GDestroyNotify) g_object_unref,          
                                                       (GDestroyNotify) g_object_unref);
    }

    return (dir);
}

static void
gof_directory_async_init (GOFDirectoryAsync *self)
{
    self->priv = g_new0(GOFDirectoryAsyncPrivate, 1);
    self->loading = FALSE;
    self->loaded = FALSE;
    self->info = NULL;
}

static void
gof_directory_async_finalize (GObject *object)
{
    GOFDirectoryAsync *dir = GOF_DIRECTORY_ASYNC (object);

    /*
       if (priv->monitors)
       {
       g_slist_foreach (priv->monitors, (GFunc)g_object_unref, NULL);
       g_slist_free (priv->monitors);
       }*/
    //load_dir_async_cancel (dir);
    //gof_directory_async_cancel (dir);
    char *uri = g_file_get_uri(dir->location);
    log_printf (LOG_LEVEL_UNDEFINED, ">> %s %s\n", G_STRFUNC, uri);
    g_free (uri);

    if (dir->priv->monitor)
        gof_monitor_cancel (dir->priv->monitor);
    g_object_unref (dir->priv->cancellable);

    /* drop the entry from the cache */
    G_LOCK (directory_cache_mutex);
    g_hash_table_remove (directory_cache, dir->location);
    G_UNLOCK (directory_cache_mutex);

    if (dir->file_hash != NULL)
        g_hash_table_destroy (dir->file_hash);
    if (dir->hidden_file_hash != NULL)
        g_hash_table_destroy (dir->hidden_file_hash);

    /* release directory info */
    if (dir->info != NULL)
        g_object_unref (dir->info);

    g_object_unref (dir->location);
    /*if (dir->priv->_parent != NULL)
      g_object_unref (dir->priv->_parent);*/
    g_free (dir->priv);
    G_OBJECT_CLASS (gof_directory_async_parent_class)->finalize (object);
    printf ("%s EOF\n", G_STRFUNC);
}

static void
gof_directory_async_class_init (GOFDirectoryAsyncClass *klass)
{
    GObjectClass *object_class = G_OBJECT_CLASS (klass);
    //GParamSpec   *pspec;

    object_class->finalize     = gof_directory_async_finalize;
    /*object_class->get_property = _get_property;
      object_class->set_property = _set_property;*/

    //g_type_class_add_private (object_class, sizeof (GOFDirectoryAsyncPrivate));

    signals[FILE_LOADED] =
        g_signal_new ("file_loaded",
                      G_TYPE_FROM_CLASS (object_class),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (GOFDirectoryAsyncClass, file_loaded),
                      NULL, NULL,
                      g_cclosure_marshal_VOID__POINTER,
                      G_TYPE_NONE, 1, G_TYPE_POINTER);
    signals[FILE_ADDED] =
        g_signal_new ("file_added",
                      G_TYPE_FROM_CLASS (object_class),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (GOFDirectoryAsyncClass, file_added),
                      NULL, NULL,
                      g_cclosure_marshal_VOID__POINTER,
                      G_TYPE_NONE, 1, G_TYPE_POINTER);
    signals[FILE_CHANGED] =
        g_signal_new ("file_changed",
                      G_TYPE_FROM_CLASS (object_class),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (GOFDirectoryAsyncClass, file_changed),
                      NULL, NULL,
                      g_cclosure_marshal_VOID__POINTER,
                      G_TYPE_NONE, 1, G_TYPE_POINTER);
    signals[FILE_DELETED] =
        g_signal_new ("file_deleted",
                      G_TYPE_FROM_CLASS (object_class),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (GOFDirectoryAsyncClass, file_deleted),
                      NULL, NULL,
                      g_cclosure_marshal_VOID__POINTER,
                      G_TYPE_NONE, 1, G_TYPE_POINTER);
    signals[DONE_LOADING] =
        g_signal_new ("done_loading",
                      G_TYPE_FROM_CLASS (object_class),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (GOFDirectoryAsyncClass, done_loading),
                      NULL, NULL,
                      g_cclosure_marshal_VOID__VOID,
                      G_TYPE_NONE, 0);

    signals[INFO_AVAILABLE] =
        g_signal_new ("info_available",
                      G_TYPE_FROM_CLASS (object_class),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (GOFDirectoryAsyncClass, info_available),
                      NULL, NULL,
                      g_cclosure_marshal_VOID__VOID,
                      G_TYPE_NONE, 0);

}

char *
gof_directory_async_get_uri (GOFDirectoryAsync *directory)
{
    return g_file_get_uri(directory->location);
}

gboolean
gof_directory_async_has_parent(GOFDirectoryAsync *directory)
{
    return (directory->priv->parent != NULL);
}

GFile *
gof_directory_async_get_parent(GOFDirectoryAsync *directory)
{
    return (g_object_ref (directory->priv->parent));
}

