/*
 * Copyright (C) 2010 ammonkey
 *
 * This library is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License
 * version 3.0 as published by the Free Software Foundation, Inc.,.
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

#ifndef GOF_FILE_H
#define GOF_FILE_H

#include <glib.h>
#include <glib-object.h>
#include <gdk/gdk.h>
#include <gdk-pixbuf/gdk-pixbuf.h>
#include <gio/gio.h>
#include "marlin-icon-info.h"

G_BEGIN_DECLS

#define GOF_TYPE_FILE (gof_file_get_type ())
#define GOF_FILE(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), GOF_TYPE_FILE, GOFFile))
#define GOF_FILE_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), GOF_TYPE_FILE, GOFFileClass))
#define GOF_IS_FILE(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GOF_TYPE_FILE))
#define GOF_IS_FILE_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), GOF_TYPE_FILE))
#define GOF_FILE_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), GOF_TYPE_FILE, GOFFileClass))

#define _g_object_unref0(var) ((var == NULL) ? NULL : (var = (g_object_unref (var), NULL)))
#define _g_free0(var) (var = (g_free (var), NULL))

/**
 * GOFFileThumbState:
 * @GOF_FILE_THUMB_STATE_MASK    : the mask to extract the thumbnail state.
 * @GOF_FILE_THUMB_STATE_UNKNOWN : unknown whether there's a thumbnail.
 * @GOF_FILE_THUMB_STATE_NONE    : no thumbnail is available.
 * @GOF_FILE_THUMB_STATE_READY   : a thumbnail is available.
 * @GOF_FILE_THUMB_STATE_LOADING : a thumbnail is being loaded.
 *
 * The state of the thumbnailing for a given #GOFFile.
 **/
typedef enum /*< flags >*/
{
  GOF_FILE_THUMB_STATE_MASK    = 0x03,
  GOF_FILE_THUMB_STATE_UNKNOWN = 0x00,
  GOF_FILE_THUMB_STATE_NONE    = 0x01,
  GOF_FILE_THUMB_STATE_READY   = 0x02,
  GOF_FILE_THUMB_STATE_LOADING = 0x03,
} GOFFileThumbState;


typedef struct _GOFFile GOFFile;
typedef struct _GOFFileClass GOFFileClass;

struct _GOFFile {
    GObject parent_instance;

    GFileInfo       *info;
    GFile           *location;
    GFile           *target_location;
    GOFFile         *target_gof;
    GFile           *directory;
    gchar           *custom_display_name;
    gchar           *uri;
    char            *basename;
    gchar           *tagstype;
    gchar           *formated_type;
    gchar           *utf8_collation_key;
    guint64         size;
    gchar           *format_size;
    GFileType       file_type;
    gboolean        is_directory;
    gboolean        is_hidden;
    gboolean        is_desktop;
    gboolean        is_expanded;
    GIcon           *icon;
    gchar           *custom_icon_name;
    GdkPixbuf       *pix;
    gint            pix_size;
    gint            width;
    gint            height;
    guint64         modified;
    gchar           *formated_modified;
    int             color;
    gboolean        is_mounted;
    gboolean        exists;
    gboolean        is_connected;

    gboolean        has_permissions;
    guint32         permissions;
    gchar           *owner;
    gchar           *group;
    int             uid;
    int             gid;
    gboolean        can_unmount;
    GMount          *mount;

    gchar           *thumbnail_path;
    gboolean        is_thumbnailing;

    time_t          trash_time; /* 0 is unknown */

    GList           *operations_in_progress;

    guint           flags;
    GList           *emblems_list;
    gboolean        is_gone;

    /* directory view settings */
    gint            sort_column_id;
    GtkSortType     sort_order;
};

struct _GOFFileClass {
    GObjectClass parent_class;

    /* Called when the file notices any change. */
    void            (* changed)             (GOFFile *file);
    void            (* destroy)             (GOFFile *file);
    void            (* info_available)      (GOFFile *file);
    void            (* icon_changed)        (GOFFile *file);

};

#define GOF_FILE_GIO_DEFAULT_ATTRIBUTES "standard::is-hidden,standard::is-backup,standard::is-symlink,standard::type,standard::name,standard::display-name,standard::content-type,standard::fast-content-type,standard::size,standard::symlink-target,standard::target-uri,access::*,time::*,owner::*,trash::*,unix::*,id::filesystem,thumbnail::*,mountable::*,metadata::marlin-sort-column-id,metadata::marlin-sort-reversed"

typedef enum {
    GOF_FILE_ICON_FLAGS_NONE = 0,
    GOF_FILE_ICON_FLAGS_USE_THUMBNAILS = (1<<0)
} GOFFileIconFlags;

typedef void (*GOFFileOperationCallback) (GOFFile  *file,
                                          GFile    *result_location,
                                          GError   *error,
                                          gpointer callback_data);

typedef struct {
    GOFFile *file;
    GCancellable *cancellable;
    GOFFileOperationCallback callback;
    gpointer callback_data;
    gboolean is_rename;

    gpointer data;
    GDestroyNotify free_data;
} GOFFileOperation;



GType gof_file_get_type (void);

GOFFile         *gof_file_new (GFile *location, GFile *dir);

void            gof_file_update (GOFFile *file);
void            gof_file_query_update (GOFFile *file);
gboolean        gof_file_ensure_query_info (GOFFile *file);
void            gof_file_update_type (GOFFile *file);
void            gof_file_update_icon (GOFFile *file, gint size);
void            gof_file_update_desktop_file (GOFFile *file);
void            gof_file_update_trash_info (GOFFile *file);
void            gof_file_update_emblem (GOFFile *file);
void            gof_file_get_folder_icon_from_uri_or_path (GOFFile *file);

GOFFile*        gof_file_get (GFile *location);
GOFFile*        gof_file_get_by_uri (const char *uri);
GOFFile*        gof_file_get_by_commandline_arg (const char *arg);

int             gof_file_compare_for_sort (GOFFile *file_1,
                                           GOFFile *file_2,
                                           gint sort_type,
                                           gboolean directories_first,
                                           gboolean reversed);
GOFFile*        gof_file_ref (GOFFile *file);
void            gof_file_unref (GOFFile *file);
GList           *gof_file_get_location_list (GList *files);

void            gof_file_list_free (GList *list);
GList           *gof_file_list_ref (GList *list);
GList           *gof_file_list_copy (GList *list);
GdkPixbuf       *gof_file_get_icon_pixbuf (GOFFile *file, gint size, gboolean force_size, GOFFileIconFlags flags);
MarlinIconInfo  *gof_file_get_icon (GOFFile *file, int size, GOFFileIconFlags flags);
gboolean        gof_file_is_writable (GOFFile *file);
gboolean        gof_file_is_trashed (GOFFile *file);
const gchar     *gof_file_get_symlink_target (GOFFile *file);
gchar           *gof_file_get_formated_time (GOFFile *file, const char *attr);
gboolean        gof_file_is_symlink (GOFFile *file);
gboolean        gof_file_is_desktop_file (GOFFile *file);
void            gof_file_set_expanded (GOFFile *file, gboolean expanded);
gchar           *gof_file_list_to_string (GList *list, gsize *len);

void            gof_file_open_single (GOFFile *file, GdkScreen *screen, GAppInfo *app_info);
gboolean        gof_file_launch_files (GList *files, GdkScreen *screen, GAppInfo* app_info);
gboolean        gof_file_launch (GOFFile  *file, GdkScreen *screen, GAppInfo *app_info);
gboolean        gof_file_execute (GOFFile *file, GdkScreen *screen, GList *file_list, GError **error);
GAppInfo        *gof_file_get_default_handler (GOFFile *file);

void            gof_file_icon_changed (GOFFile *file);
void            gof_file_rename (GOFFile *file,
                                 const char *new_name,
                                 GOFFileOperationCallback callback,
                                 gpointer callback_data);
void            gof_file_set_thumb_state (GOFFile *file, GOFFileThumbState state);
void            gof_file_add_emblem(GOFFile* file, const gchar* emblem);
GMount*         gof_file_get_mount_at (GFile* target);

/* To provide a wrapper around g_file_get_uri (not sure it is really useful tough) */
#define gof_file_get_uri(obj) g_file_get_uri(obj->location)
/**
 * gof_file_get_thumb_state:
 * @file : a #GOFFile.
 *
 * Returns the current #GOFFileThumbState for @file.
 *
 * Return value: the #GOFFileThumbState for @file.
 **/
#define gof_file_get_thumb_state(file) (GOF_FILE ((file))->flags & GOF_FILE_THUMB_STATE_MASK)
const gchar* gof_file_get_thumbnail_path (GOFFile *file);
const gchar* gof_file_get_preview_path (GOFFile *file);
gboolean        gof_file_can_set_owner (GOFFile *file);
gboolean        gof_file_can_set_group (GOFFile *file);
GList           *gof_file_get_settable_group_names (GOFFile *file);
gboolean        gof_file_can_set_permissions (GOFFile *file);
char            *gof_file_get_permissions_as_string (GOFFile *file);

gint            gof_file_compare_by_display_name (gconstpointer a, gconstpointer b);

GFile           *gof_file_get_target_location (GOFFile *file);
const gchar     *gof_file_get_display_name (GOFFile *file);
gboolean        gof_file_is_folder (GOFFile *file);
const gchar     *gof_file_get_ftype (GOFFile *file);

void            gof_file_query_thumbnail_update (GOFFile *file);
gboolean        gof_file_can_unmount (GOFFile *file);

gboolean        gof_file_is_remote_uri_scheme (GOFFile *file);
gboolean        gof_file_is_root_network_folder (GOFFile *file);
gboolean        gof_file_is_network_uri_scheme (GOFFile *file);
gboolean        gof_file_is_smb_uri_scheme (GOFFile *file);
gboolean        gof_file_is_recent_uri_scheme (GOFFile *file);
gboolean        gof_file_is_smb_share (GOFFile *file);
gboolean        gof_file_is_smb_server (GOFFile *file);
gboolean        gof_file_is_mountable (GOFFile *file);

char            *gof_file_get_display_target_uri (GOFFile *file);
G_END_DECLS

#endif /* GOF_FILE_H */


