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

#ifndef GOF_DIRECTORY_ASYNC_H
#define GOF_DIRECTORY_ASYNC_H

#include <gtk/gtk.h>
#include "gof-file.h"

G_BEGIN_DECLS

#define GOF_TYPE_DIRECTORY_ASYNC gof_directory_async_get_type()
#define GOF_DIRECTORY_ASYNC(obj) \
    (G_TYPE_CHECK_INSTANCE_CAST ((obj), GOF_TYPE_DIRECTORY_ASYNC, GOFDirectoryAsync))
#define GOF_DIRECTORY_ASYNC_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_CAST ((klass), GOF_TYPE_DIRECTORY_ASYNC, GOFDirectoryAsyncClass))
#define GOF_IS_DIRECTORY_ASYNC(obj) \
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GOF_TYPE_DIRECTORY_ASYNC))
#define GOF_IS_DIRECTORY_ASYNC_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_TYPE ((klass), GOF_TYPE_DIRECTORY_ASYNC))
#define GOF_DIRECTORY_ASYNC_GET_CLASS(obj) \
    (G_TYPE_INSTANCE_GET_CLASS ((obj), GOF_TYPE_DIRECTORY_ASYNC, GOFDirectoryAsyncClass))

#define _g_object_unref0(var) ((var == NULL) ? NULL : (var = (g_object_unref (var), NULL)))

#define FILES_PER_QUERY 100

typedef struct GOFDirectoryAsyncPrivate GOFDirectoryAsyncPrivate;

typedef struct {
    GObject                     parent;
    GFile                       *location;
    GOFFile                     *file;
    gboolean                    loading;
    gboolean                    loaded;
    GHashTable                  *file_hash;
    GHashTable                  *hidden_file_hash;
    GOFDirectoryAsyncPrivate    *priv;
} GOFDirectoryAsync;

typedef struct {
    GObjectClass parent_class;

    /* The files_added signal is emitted as the directory model
     * discovers new files.
     */
    void     (* file_loaded)        (GOFDirectoryAsync *directory, GOFFile *file);
    void     (* file_added)         (GOFDirectoryAsync *directory, GOFFile *file);
    void     (* file_changed)       (GOFDirectoryAsync *directory, GOFFile *file);
    void     (* file_deleted)       (GOFDirectoryAsync *directory, GOFFile *file);
#if 0
    void     (* files_changed)       (NautilusDirectory         *directory,
                                      GList                     *changed_files);
    GList                      *added_files);
#endif
    void     (* done_loading)        (GOFDirectoryAsync         *directory);
    void     (* info_available)      (GOFDirectoryAsync         *directory);

} GOFDirectoryAsyncClass;

GType                   gof_directory_async_get_type (void);

GOFDirectoryAsync       *gof_directory_async_new(GFile *location);
GOFDirectoryAsync       *gof_directory_async_new_from_file (GOFFile *file);
GOFDirectoryAsync       *gof_directory_async_new_from_gfile (GFile *location);
GOFDirectoryAsync       *gof_directory_cache_lookup (GFile *file);
gboolean                gof_directory_async_load (GOFDirectoryAsync *dir);
void                    gof_directory_async_cancel (GOFDirectoryAsync *dir);
char                    *gof_directory_async_get_uri (GOFDirectoryAsync *directory);
gboolean                gof_directory_async_has_parent(GOFDirectoryAsync *directory);
GFile                   *gof_directory_async_get_parent(GOFDirectoryAsync *directory);
//void                    gof_directory_async_load_file_hash (GOFDirectoryAsync *dir);

/*GOFDirectoryAsync       *gof_directory_ref (GOFDirectoryAsync *directory);
  void                    gof_directory_unref (GOFDirectoryAsync *directory);*/

gboolean                gof_directory_is_empty (GOFDirectoryAsync *directory);

G_END_DECLS

#endif /* GOF_DIRECTORY_ASYNC_H */

