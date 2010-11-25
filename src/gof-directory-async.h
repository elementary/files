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
//#include "fm-list-model.h"
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

/*
#define GIO_SUCKLESS_DEFAULT_ATTRIBUTES                                \
"standard::type,standard::is-hidden,standard::name,standard::display-name,standard::edit-name,standard::copy-name,standard::fast-content-type,standard::size,standard::allocated-size,access::*,mountable::*,time::*,unix::*,owner::*,selinux::*,thumbnail::*,id::filesystem,trash::orig-path,trash::deletion-date,metadata::*"
*/

#define GOF_GIO_DEFAULT_ATTRIBUTES "standard::is-hidden,standard::is-symlink,standard::type,standard::name,standard::fast-content-type,standard::size,access::*,time::*"
#define FILES_PER_QUERY 100

//typedef struct GOFDirectoryAsyncDetails GOFDirectoryAsyncDetails;
typedef struct GOFDirectoryAsyncPrivate GOFDirectoryAsyncPrivate;

typedef struct {
    //GtkWindow parent_instance;
    //ASyncGIOSamplePrivate * priv;
    //GOFDirectoryAsyncDetails *details;
    GObject parent;
    GOFDirectoryAsyncPrivate *priv;
} GOFDirectoryAsync;

typedef struct {
    GObjectClass parent_class;

    /* The files_added signal is emitted as the directory model 
     * discovers new files.
     */
    void     (* file_added)         (GOFDirectoryAsync *directory, GOFFile *file);
#if 0
    void     (* files_changed)       (NautilusDirectory         *directory,
                                      GList                     *changed_files);
    GList                      *added_files);
#endif
    void     (* done_loading)        (GOFDirectoryAsync         *directory);

} GOFDirectoryAsyncClass;

GType                   gof_directory_async_get_type (void);

//GOFDirectoryAsync       *gof_directory_async_new(gchar *);
GOFDirectoryAsync       *gof_directory_async_new(GFile *location);
GOFDirectoryAsync       *gof_directory_async_get_for_file(GOFFile *file);
//GOFDirectoryAsync       *gof_directory_async_get_parent(GOFDirectoryAsync *dir);
//GtkWidget               *get_tree_view(GOFDirectoryAsync *dir);
void                    load_dir_async (GOFDirectoryAsync *dir);
void                    gof_directory_async_cancel (GOFDirectoryAsync *dir);
char                    *gof_directory_async_get_uri (GOFDirectoryAsync *directory);
gboolean                gof_directory_async_has_parent(GOFDirectoryAsync *directory);
GFile                   *gof_directory_async_get_parent(GOFDirectoryAsync *directory);

/*GOFDirectoryAsync       *gof_directory_ref (GOFDirectoryAsync *directory);
  void                    gof_directory_unref (GOFDirectoryAsync *directory);*/

G_END_DECLS

#endif /* GOF_DIRECTORY_ASYNC_H */
