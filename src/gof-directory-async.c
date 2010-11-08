/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 8; tab-width: 8 -*- */
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
//#include "fm-list-model.h"
#include "nautilus-cell-renderer-text-ellipsized.h"

struct GOFDirectoryAsyncPrivate {
        //GTimer          *timer;
        GFile           *_dir;
        //GFile           *_parent;
        //GAsyncResult    *_res;
        GOFMonitor      *monitor;
        //FMListModel     *model;
	GCancellable    *cancellable;
        //GHashTable      *file_hash;
       	//GHashTable      *hidden_file_hash;
};

enum {
	FILE_ADDED,
	/*FILES_CHANGED,*/
	DONE_LOADING,
	/*LOAD_ERROR,*/
	LAST_SIGNAL
};

static guint signals[LAST_SIGNAL];

#if 0
struct DirectoryLoadState {
	GOFDirectoryAsync       *directory;
	GCancellable            *cancellable;
	GFileEnumerator         *enumerator;
	GHashTable              *load_mime_list_hash;
	GOFFile                 *load_directory_file;
	int                     load_file_count;
};
#endif

G_DEFINE_TYPE (GOFDirectoryAsync, gof_directory_async, G_TYPE_OBJECT)
        /*#define GOF_DIRECTORY_ASYNC_GET_PRIVATE(obj) \
          (G_TYPE_INSTANCE_GET_PRIVATE(obj, GOF_TYPE_DIRECTORY_ASYNC, GOFDirectoryAsyncPrivate))*/

static void
print_error(GError *error)
{
        if (error)
        {
                g_print ("%s", error->message);
                g_error_free (error);
        }
}

static void
enumerator_files_callback (GObject *source_object, GAsyncResult *result, gpointer user_data)
{
        GFileEnumerator *enumerator;
        GError *error = NULL;
        GList *files, *f;
        GOFDirectoryAsync *dir = user_data;

        /*if (g_cancellable_is_cancelled (dir->priv->cancellable)) {
                return;
        }*/
        enumerator = G_FILE_ENUMERATOR (source_object);
        /* Operation was cancelled */
        if (dir == NULL)
        {
                g_object_unref (enumerator);
                return;
        }

        files = g_file_enumerator_next_files_finish (enumerator, result, &error);
        print_error(error);

        if (!files)
        {
                /* There's no way to spread the error up to the filechooser, if any */
                g_file_enumerator_close_async (enumerator,
                                               G_PRIORITY_DEFAULT,
                                               NULL, NULL, NULL);

                printf ("%s ended\n", G_STRFUNC);
                g_signal_emit (dir, signals[DONE_LOADING], 0);
                /*folder->finished_loading = TRUE;
                  g_signal_emit_by_name (dir, "finished-loading", 0);*/
                g_object_unref (dir);
                return;
        }
        //GtkTreeIter iter;
        for (f = files; f; f = f->next)
        {
                //GFileInfo *info = f->data;
                GOFFile *goff = gof_file_new ((GFileInfo *) f->data, dir->priv->_dir);
#if 0
                const gchar *name = g_file_info_get_name (info);
                //gchar *size = g_strconcat (g_strdup_printf ("%i", ((gint) g_file_info_get_size (info)) / 1024), "KiB", NULL);
                gchar *size = g_format_size_for_display(g_file_info_get_size(info));
                if (g_file_info_get_file_type(info) == G_FILE_TYPE_DIRECTORY)
                        size = "<dir>";
                const gchar *ftype = g_file_info_get_attribute_string (info, G_FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE);
                GIcon *icon = g_content_type_get_icon (ftype);
                //gchar *picon = g_icon_to_string (icon);
                //printf ("%s %s\n", name, picon);
#endif
#if 0
                GtkIconTheme *icon_theme = gtk_icon_theme_get_default ();
                /*GdkPixbuf *pix = gtk_icon_theme_load_icon (icon_theme, picon, 16,
                  GTK_ICON_LOOKUP_USE_BUILTIN | GTK_ICON_LOOKUP_GENERIC_FALLBACK | GTK_ICON_LOOKUP_FORCE_SIZE, NULL);*/
                GtkIconInfo *icon_info = gtk_icon_theme_lookup_by_gicon (icon_theme, icon, 16,
                                                                         //GTK_ICON_LOOKUP_USE_BUILTIN | GTK_ICON_LOOKUP_GENERIC_FALLBACK | GTK_ICON_LOOKUP_FORCE_SIZE);
                            GTK_ICON_LOOKUP_GENERIC_FALLBACK);
                GdkPixbuf *pix = gtk_icon_info_load_icon(icon_info, NULL);
                // application-octet-stream gnome-mime-application-octet-stream application-x-generic
#endif 
                /*NautilusIconInfo *nicon;
                nicon = nautilus_icon_info_lookup (goff->icon, 16);
                GdkPixbuf *pix = nautilus_icon_info_get_pixbuf_nodefault (nicon);*/


                if (!goff->is_hidden)
                {
                        //printf ("%s\n", goff->name);
                        //fm_list_model_add_file (dir->priv->model, goff, dir);

		        g_signal_emit (dir, signals[FILE_ADDED], 0, goff);
                        //custom_list_append_record (customlist,);

                        /*gtk_list_store_append (dir->priv->m_store, &iter);
                        gtk_list_store_set (dir->priv->m_store, &iter, 
                                            //GOF_DIR_COL_ICON, NULL,
                                            GOF_DIR_COL_ICON, pix,
                                            GOF_DIR_COL_FILENAME, goff->name,
                                            GOF_DIR_COL_SIZE, goff->format_size,
                                            -1);*/
                        /* val = g_file_info_get_attribute_string (info, G_FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE);
                           g_file_info_get_attribute_boolean (info, G_FILE_ATTRIBUTE_ACCESS_CAN_EXECUTE) 
                           g_file_info_get_file_type (info) == G_FILE_TYPE_DIRECTORY ? 'd' : '-',
                           */
                }
        }

        g_file_enumerator_next_files_async (enumerator, FILES_PER_QUERY,
                                            G_PRIORITY_DEFAULT,
                                            dir->priv->cancellable,
                                            //NULL,
                                            enumerator_files_callback,
                                            dir);

        g_list_free (files);
}

static void load_dir_async_callback (GObject *source_object, GAsyncResult *res, gpointer user_data) 
{
        GOFDirectoryAsync *dir = user_data;
        GFileEnumerator *enumerator;
        GError *error = NULL;

        if (g_cancellable_is_cancelled (dir->priv->cancellable)) {
                return;
        }

        enumerator = g_file_enumerate_children_finish (G_FILE (source_object), res, &error);
        print_error(error);

        if (enumerator) {
                g_file_enumerator_next_files_async (enumerator,
                                                    FILES_PER_QUERY,
                                                    //G_PRIORITY_LOW,
                                                    G_PRIORITY_DEFAULT,
                                                    dir->priv->cancellable,
                                                    //NULL,
                                                    enumerator_files_callback,
                                                    g_object_ref (dir));
                g_object_unref (enumerator);
        }

}


//static void
void
load_dir_async (GOFDirectoryAsync *dir)
{
        GOFDirectoryAsyncPrivate *p = dir->priv;
	p->cancellable = g_cancellable_new ();

        if (p->_dir)
        {
                char *uri = g_file_get_uri(p->_dir);
                g_message ("Start loading directory %s", uri);
                g_free (uri);
                p->monitor = gof_monitor_directory (p->_dir);

                g_file_enumerate_children_async (p->_dir, GOF_GIO_DEFAULT_ATTRIBUTES, G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, 
                                                 G_PRIORITY_DEFAULT, p->cancellable, load_dir_async_callback, dir);
                                                 //G_FILE_QUERY_INFO_NOFOLLOW_SYMLINKS, G_PRIORITY_DEFAULT, NULL, NULL, dir);

                //GtkTreeIter iter;
        }
}

void
load_dir_async_cancel (GOFDirectoryAsync *dir)
{
        g_cancellable_cancel (dir->priv->cancellable);
        g_cancellable_cancel (dir->priv->cancellable);
        //g_object_unref (dir);
}

/*
static void
done_loading (GOFDirectoryAsync *dir)
{
        printf ("%s\n", G_STRFUNC);
        //gtk_tree_view_set_model (GTK_TREE_VIEW (dir->priv->tree), GTK_TREE_MODEL (dir->priv->m_store));
}*/

GOFDirectoryAsync *gof_directory_async_new(GFile *location)
{
        GOFDirectoryAsync *self;

        self = g_object_new (GOF_TYPE_DIRECTORY_ASYNC, NULL);
        //self->priv->model = model;
        //self->priv->_dir = g_file_dup(location);
        self->priv->_dir = location;
        g_object_ref (location);
        //self->priv->_parent = g_file_get_parent(self->priv->_dir);

        //load_dir_async (self);

        return (self);
}

GOFDirectoryAsync *gof_directory_async_get_for_file(GOFFile *file)
{
        GOFDirectoryAsync *self;
        
        self = g_object_new (GOF_TYPE_DIRECTORY_ASYNC, NULL);
        //self->priv->_parent = g_file_dup (file->directory);
        //self->priv->model = model;
        //printf ("test %s %s\n", file->name, g_file_get_uri(file->directory));
        //self->priv->_dir = g_file_get_child(file->directory, file->name);
        self->priv->_dir = file->location;
        g_object_ref (file->location);
        //printf ("test %s\n", g_file_get_uri(self->priv->_dir));
        //load_dir_async (self);

        return (self);
}

/*
GOFDirectoryAsync *gof_directory_async_get_parent(GOFDirectoryAsync *dir)
{
        GOFDirectoryAsync *parent;
        
        parent = g_object_new (GOF_TYPE_DIRECTORY_ASYNC, NULL);
        parent->priv->_parent = g_file_get_parent(dir->priv->_dir);
        parent->priv->model = model;
        parent->priv->_dir = g_file_dup(dir->priv->_parent);

        return (parent);
}*/

static void
gof_directory_async_init (GOFDirectoryAsync *self)
{
        /*GOFDirectoryAsyncPrivate *priv;

          priv = GOF_DIRECTORY_ASYNC_GET_PRIVATE (self);*/
        self->priv = g_new0(GOFDirectoryAsyncPrivate, 1);
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
        char *uri = g_file_get_uri(dir->priv->_dir);
        printf (">> %s %s\n", G_STRFUNC, uri);
        g_free (uri);
        g_object_unref (dir->priv->_dir);
        /*if (dir->priv->_parent != NULL)
                g_object_unref (dir->priv->_parent);*/
        gof_monitor_cancel (dir->priv->monitor);
        g_object_unref (dir->priv->cancellable);
        g_free (dir->priv);
        G_OBJECT_CLASS (gof_directory_async_parent_class)->finalize (object);
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
       
        signals[FILE_ADDED] =
		g_signal_new ("file_added",
		              G_TYPE_FROM_CLASS (object_class),
		              G_SIGNAL_RUN_LAST,
		              G_STRUCT_OFFSET (GOFDirectoryAsyncClass, file_added),
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

}

char *
gof_directory_async_get_uri (GOFDirectoryAsync *directory)
{
        return g_file_get_uri(directory->priv->_dir);
}

