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

#include "gof-file.h"
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include "marlin-global-preferences.h" 
#include "eel-i18n.h"
#include "eel-fcts.h"
#include "eel-string.h"
#include "eel-gio-extensions.h"
#include "eel-string.h"
#include "marlin-exec.h"
#include "marlin-icons.h"
#include "marlincore.h"

enum {
    FM_LIST_MODEL_FILE_COLUMN,
    FM_LIST_MODEL_ICON,
    FM_LIST_MODEL_COLOR,
    FM_LIST_MODEL_FILENAME,
    FM_LIST_MODEL_SIZE,
    FM_LIST_MODEL_TYPE,
    FM_LIST_MODEL_MODIFIED,
    FM_LIST_MODEL_NUM_COLUMNS
};

G_LOCK_DEFINE_STATIC (file_cache_mutex);

static GHashTable   *file_cache;

//static void gof_file_get_property (GObject * object, guint property_id, GValue * value, GParamSpec * pspec);
//static void gof_file_set_property (GObject * object, guint property_id, const GValue * value, GParamSpec * pspec);

G_DEFINE_TYPE (GOFFile, gof_file, G_TYPE_OBJECT)

#define SORT_LAST_CHAR1 '.'
#define SORT_LAST_CHAR2 '#'

#define ICON_NAME_THUMBNAIL_LOADING   "image-loading"

    enum {
        CHANGED,
        //UPDATED_DEEP_COUNT_IN_PROGRESS,
        INFO_AVAILABLE,
        ICON_CHANGED,
        DESTROY,
        LAST_SIGNAL
    };

static guint    signals[LAST_SIGNAL];
static guint32  effective_user_id;

static gpointer _g_object_ref0 (gpointer self) {
	return self ? g_object_ref (self) : NULL;
}

static GIcon *
get_icon_user_special_dirs(char *path)
{
    GIcon *icon = NULL;

    if (!path)
        return NULL;
    if (g_strcmp0 (path, g_get_home_dir ()) == 0)
        icon = g_themed_icon_new ("user-home");
    else if (g_strcmp0 (path, g_get_user_special_dir (G_USER_DIRECTORY_DESKTOP)) == 0)
        icon = g_themed_icon_new ("user-desktop");
    else if (g_strcmp0 (path, g_get_user_special_dir (G_USER_DIRECTORY_DOCUMENTS)) == 0)
        icon = g_themed_icon_new_with_default_fallbacks ("folder-documents");
    else if (g_strcmp0 (path, g_get_user_special_dir (G_USER_DIRECTORY_DOWNLOAD)) == 0)
        icon = g_themed_icon_new_with_default_fallbacks ("folder-download");
    else if (g_strcmp0 (path, g_get_user_special_dir (G_USER_DIRECTORY_MUSIC)) == 0)
        icon = g_themed_icon_new_with_default_fallbacks ("folder-music");
    else if (g_strcmp0 (path, g_get_user_special_dir (G_USER_DIRECTORY_PICTURES)) == 0)
        icon = g_themed_icon_new_with_default_fallbacks ("folder-pictures");
    else if (g_strcmp0 (path, g_get_user_special_dir (G_USER_DIRECTORY_PUBLIC_SHARE)) == 0)
        icon = g_themed_icon_new_with_default_fallbacks ("folder-publicshare");
    else if (g_strcmp0 (path, g_get_user_special_dir (G_USER_DIRECTORY_TEMPLATES)) == 0)
        icon = g_themed_icon_new_with_default_fallbacks ("folder-templates");
    else if (g_strcmp0 (path, g_get_user_special_dir (G_USER_DIRECTORY_VIDEOS)) == 0)
        icon = g_themed_icon_new_with_default_fallbacks ("folder-videos");

    return (icon);
}

static void
gof_set_custom_display_name (GOFFile *file, gchar *name)
{
    _g_free0 (file->custom_display_name);
    file->custom_display_name = g_strdup (name);
    file->name = file->custom_display_name;
}

GOFFile    *gof_file_new (GFile *location, GFile *dir)
{
    GOFFile *file;

    file = (GOFFile*) g_object_new (GOF_TYPE_FILE, NULL);
    file->location = g_object_ref (location);
    file->uri = g_file_get_uri (location);
    if (dir != NULL)
        file->directory = g_object_ref (dir);
    else
        file->directory = NULL;
    file->basename = g_file_get_basename (file->location);
    //file->parent_dir = g_file_enumerator_get_container (enumerator);
    file->color = NULL;

    return (file);
}

static void
gof_file_icon_changed (GOFFile *file)
{
    GOFDirectoryAsync *dir;

    /* get the DirectoryAsync associated to the file */
    dir = gof_directory_async_cache_lookup (file->directory);
    if (dir != NULL) {
        if (!file->is_hidden || dir->show_hidden_files)
            g_signal_emit_by_name (dir, "icon_changed", file);
        
        g_object_unref (dir);
    }
    g_signal_emit_by_name (file, "icon_changed");
}

static void 
gof_file_clear_info (GOFFile *file)
{
    g_return_if_fail (file != NULL);

    _g_free0(file->utf8_collation_key);
    _g_free0(file->formated_type);
    _g_free0(file->format_size);
    _g_free0(file->formated_modified);
    _g_object_unref0 (file->icon);
    _g_object_unref0 (file->pix);
    _g_free0 (file->custom_display_name);
    _g_free0 (file->custom_icon_name);
    file->custom_display_name = NULL;

    file->uid = -1;
    file->gid = -1;
    file->has_permissions = FALSE;
    file->permissions = 0;
    _g_free0(file->owner);
    _g_free0(file->group);
}

static gboolean
gof_file_is_remote_uri_scheme (GOFFile *file)
{
    /* try to determinate what appear to be remote. This is quite hazardous but gio doesn't offer any better option */
    char *scheme = g_file_get_uri_scheme (file->location);

    //g_message ("%s %s", G_STRFUNC, scheme);
    if (!strcmp (scheme, "trash")) {
        g_free (scheme);
        return FALSE;
    }
    if (!strcmp (scheme, "archive")) {
        g_free (scheme);
        return FALSE;
    }

    g_free (scheme);
    return TRUE;
}

void    gof_file_get_folder_icon_from_uri_or_path (GOFFile *file) 
{
    if (!file->is_hidden && file->uri != NULL) {
        char *path = g_filename_from_uri (file->uri, NULL, NULL);
        file->icon = get_icon_user_special_dirs(path);
        _g_free0 (path);
    }

    if (file->icon == NULL && !g_file_is_native (file->location)
        && gof_file_is_remote_uri_scheme (file))
        file->icon = g_themed_icon_new (MARLIN_ICON_FOLDER_REMOTE);
    if (file->icon == NULL)
        file->icon = g_themed_icon_new (MARLIN_ICON_FOLDER);
}

void    gof_file_update (GOFFile *file)
{
    GKeyFile *key_file;
    gchar *p;

    g_return_if_fail (file->info != NULL);

    /* free previously allocated */
    gof_file_clear_info (file);

    file->name = g_file_info_get_name (file->info);

    //TODO ???
    /*if (file->info == NULL && file->location != NULL)
      gof_set_custom_display_name (file, file->basename);*/

    //g_message ("test parent_dir %s\n", g_file_get_uri(file->location));

    file->display_name = g_file_info_get_display_name (file->info);
    file->is_hidden = g_file_info_get_is_hidden (file->info) || g_file_info_get_is_backup (file->info);
    file->ftype = g_file_info_get_attribute_string (file->info, G_FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE);
    file->size = (guint64) g_file_info_get_size (file->info);
    file->file_type = g_file_info_get_file_type (file->info);
    file->is_directory = (file->file_type == G_FILE_TYPE_DIRECTORY);
    file->modified = g_file_info_get_attribute_uint64 (file->info, G_FILE_ATTRIBUTE_TIME_MODIFIED);

    if (file->is_directory)
        file->format_size = g_strdup ("--");
    else
        file->format_size = g_format_size_for_display(file->size);
    /* TODO prefs: create an object to store all the preferences */
    gchar *date_format_pref = g_settings_get_string(settings, MARLIN_PREFERENCES_DATE_FORMAT);
    file->formated_modified = eel_get_date_as_string (file->modified, date_format_pref);
    _g_free0 (date_format_pref);

    /* TODO the key-files could be loaded async. 
    <lazy>The performance gain would not be that great</lazy>*/
    if ((file->is_desktop = gof_file_is_desktop_file (file)))
    {
        /* The following code snippet about desktop files come from Thunar thunar-file.c,
         * Copyright (c) 2005-2007 Benedikt Meurer <benny@xfce.org>
         * Copyright (c) 2009-2011 Jannis Pohlmann <jannis@xfce.org> 
         */

        /* determine the custom icon and display name for .desktop files */

        /* query a key file for the .desktop file */
        //TODO make cancellable & error
        key_file = eel_g_file_query_key_file (file->location, NULL, NULL);
        if (key_file != NULL)
        {
            /* read the icon name from the .desktop file */
            file->custom_icon_name = g_key_file_get_string (key_file, 
                                                            G_KEY_FILE_DESKTOP_GROUP,
                                                            G_KEY_FILE_DESKTOP_KEY_ICON,
                                                            NULL);

            if (G_UNLIKELY (eel_str_is_empty (file->custom_icon_name)))
            {
                /* make sure we set null if the string is empty else the assertion in 
                 * thunar_icon_factory_lookup_icon() will fail */
                _g_free0 (file->custom_icon_name);
                file->custom_icon_name = NULL;
            }
            else
            {
                /* drop any suffix (e.g. '.png') from themed icons */
                if (!g_path_is_absolute (file->custom_icon_name))
                {
                    p = strrchr (file->custom_icon_name, '.');
                    if (p != NULL)
                        *p = '\0';
                }
            }

            /* read the display name from the .desktop file (will be overwritten later
             * if it's undefined here) */
            char *custom_display_name = g_key_file_get_string (key_file,
                                                               G_KEY_FILE_DESKTOP_GROUP,
                                                               G_KEY_FILE_DESKTOP_KEY_NAME,
                                                               NULL);

            /* check if we have a display name now */
            if (custom_display_name != NULL)
            {
                /* drop the name if it's empty or has invalid encoding */
                if (*custom_display_name == '\0' 
                    || !g_utf8_validate (custom_display_name, -1, NULL))
                {
                    _g_free0 (custom_display_name);
                    custom_display_name = NULL;
                } else {
                    gof_set_custom_display_name (file, custom_display_name);
                    _g_free0 (custom_display_name);
                }
            }

            /* free the key file */
            g_key_file_free (key_file);
        }
    }

    if (file->is_directory) {
        gof_file_get_folder_icon_from_uri_or_path (file);
    } else {
        if (file->ftype != NULL)
            file->icon = g_content_type_get_icon (file->ftype);
    }

    file->thumbnail_path =  g_file_info_get_attribute_byte_string (file->info, G_FILE_ATTRIBUTE_THUMBNAIL_PATH);

    /* SPOTTED! is that really usefull? */
    file->utf8_collation_key = g_utf8_collate_key (file->name, -1);

    //trash doesn't have a ftype
    if (file->ftype != NULL) {
        gchar *formated_type = g_content_type_get_description (file->ftype);
        if (G_UNLIKELY (gof_file_is_symlink (file))) {
            file->formated_type = g_strdup_printf (_("link to %s"), formated_type);
        } else {
            file->formated_type = g_strdup (formated_type);
        }
        g_free (formated_type);
    }

    /* permissions */
    file->has_permissions = g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_UNIX_MODE);
    file->permissions = g_file_info_get_attribute_uint32 (file->info, G_FILE_ATTRIBUTE_UNIX_MODE);
    const char *owner = g_file_info_get_attribute_string (file->info, G_FILE_ATTRIBUTE_OWNER_USER);
    const char *group = g_file_info_get_attribute_string (file->info, G_FILE_ATTRIBUTE_OWNER_GROUP);
    if (owner != NULL)
        file->owner = strdup (owner);
    if (group != NULL)
        file->group = strdup (group);
    if (g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_UNIX_UID)) {
        file->uid = g_file_info_get_attribute_uint32 (file->info, G_FILE_ATTRIBUTE_UNIX_UID);
        if (file->owner == NULL)
            file->owner = g_strdup_printf ("%d", file->uid);
    }
    if (g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_UNIX_GID)) {
        file->gid = g_file_info_get_attribute_uint32 (file->info, G_FILE_ATTRIBUTE_UNIX_GID);
        if (file->group == NULL)
            file->group = g_strdup_printf ("%d", file->gid);
    }

    gof_file_update_trash_info (file);
    gof_file_update_emblem (file);
}

static NautilusIconInfo *
gof_file_get_icon (GOFFile *file, int size, GOFFileIconFlags flags)
{
    NautilusIconInfo *icon;
    GIcon *gicon;

    if (file == NULL) 
        return NULL;

    //printf ("%s %s %s\n", G_STRFUNC, file->name, file->thumbnail_path);
    if (flags & GOF_FILE_ICON_FLAGS_USE_THUMBNAILS) {
        if (file->thumbnail_path != NULL) {
            //printf("show thumb %d\n", size);
            icon = nautilus_icon_info_lookup_from_path (file->thumbnail_path, size);
            return icon;
        }
    }

    if (flags & GOF_FILE_ICON_FLAGS_USE_THUMBNAILS
        && file->flags == GOF_FILE_THUMB_STATE_LOADING) {
        gicon = g_themed_icon_new (ICON_NAME_THUMBNAIL_LOADING);
        //printf ("thumbnail loading\n");
    } else { 
        gicon = g_object_ref (file->icon);
    }

    if (gicon) {
        icon = nautilus_icon_info_lookup (gicon, size);
        if (nautilus_icon_info_is_fallback(icon)) {
            g_object_unref (icon);
            icon = nautilus_icon_info_lookup (g_themed_icon_new ("text-x-generic"), size);
        }
        g_object_unref (gicon);
        return icon;
    } else {
        return nautilus_icon_info_lookup (g_themed_icon_new ("text-x-generic"), size);
    }
}

static GdkPixbuf 
*ensure_pixbuf_from_nicon (GOFFile *file, gint size, NautilusIconInfo *nicon)
{
    GdkPixbuf *pix;
    NautilusIconInfo *temp_nicon;

    pix = nautilus_icon_info_get_pixbuf_nodefault (nicon);
    if (pix == NULL) {
        temp_nicon = gof_file_get_icon (file, size, GOF_FILE_ICON_FLAGS_USE_THUMBNAILS);
        pix = nautilus_icon_info_get_pixbuf_nodefault (temp_nicon);
        _g_object_unref0 (temp_nicon);
    }

    return pix;
}

/* TODO check this fct we shouldn't store the pixbuf in GOF */
void gof_file_update_icon (GOFFile *file, gint size)
{
    NautilusIconInfo *nicon = NULL;

    if (file->custom_icon_name != NULL) {
        if (g_path_is_absolute (file->custom_icon_name)) 
            nicon = nautilus_icon_info_lookup_from_path (file->custom_icon_name, size);
        else
            nicon = nautilus_icon_info_lookup_from_name (file->custom_icon_name, size);
    } else {
        nicon = gof_file_get_icon (file, size, GOF_FILE_ICON_FLAGS_USE_THUMBNAILS);
    }

    /* destroy pixbuff if already present */
    _g_object_unref0 (file->pix);
    /* make sure we always got a non null pixbuf */
    file->pix = ensure_pixbuf_from_nicon (file, size, nicon);
    _g_object_unref0 (nicon);
}

void gof_file_update_emblem (GOFFile *file)
{
    /* erase previous stored emblems */
    if (file->emblems_list != NULL) {
        g_list_free (file->emblems_list);
        file->emblems_list = NULL;
    }
    if(plugins != NULL) 
        marlin_plugin_manager_update_file_info (plugins, file);
    if(gof_file_is_symlink(file))
    {
        gof_file_add_emblem(file, "emblem-symbolic-link");

        /* testing up to 4 emblems */
        /*gof_file_add_emblem(file, "emblem-generic");
          gof_file_add_emblem(file, "emblem-important");
          gof_file_add_emblem(file, "emblem-favorite");*/
    }

    /* TODO update signal on real change */
    //g_warning ("update emblem %s", file.uri);
    if (file->emblems_list != NULL)
        gof_file_icon_changed (file); 
}

void gof_file_add_emblem (GOFFile* file, const gchar* emblem)
{
    GList* emblems = g_list_first(file->emblems_list);
    while(emblems != NULL)
    {
        if(!g_strcmp0(emblems->data, emblem))
            return;
        emblems = g_list_next(emblems);
    }
    file->emblems_list = g_list_append(file->emblems_list, (void*)emblem);
    gof_file_icon_changed (file);
}

static void
print_error (GError *error)
{
    if (error != NULL)
    {
        g_warning ("%s [code %d]\n", error->message, error->code);
        g_clear_error (&error);
    }
}

static
gboolean gof_file_query_info (GOFFile *file)
{
    GError *err = NULL;

    //printf ("!!!!!!!!!!!!file_query_info %s\n", g_file_get_uri (file->location));
    file->info = g_file_query_info (file->location, GOF_GIO_DEFAULT_ATTRIBUTES,
                                    0, NULL, &err);
    if (err != NULL) {
        if (err->domain == G_IO_ERROR && err->code == G_IO_ERROR_NOT_MOUNTED) {
            file->is_mounted = FALSE;
        }
        if (err->code == G_IO_ERROR_NOT_FOUND
            || err->code == G_IO_ERROR_NOT_DIRECTORY) {
            file->exists = FALSE;
        }
        print_error (err);
    } else {
        return TRUE;
    }

    return FALSE;
}

/* query info and update. This call is synchronous */
void gof_file_query_update (GOFFile *file)
{
    if (gof_file_query_info (file))
        gof_file_update (file);
}

/* ensure we got the file info */
gboolean gof_file_ensure_query_info (GOFFile *file)
{
    if (file->info == NULL) {
        g_warning ("info null need to query_update %s", file->uri);
        gof_file_query_update (file);
    }

    return (file->info != NULL);
}

static
void gof_file_query_thumbnail_update (GOFFile *file)
{
    if (gof_file_query_info (file))
        file->thumbnail_path =  g_file_info_get_attribute_byte_string (file->info, G_FILE_ATTRIBUTE_THUMBNAIL_PATH);
}

void gof_file_update_trash_info (GOFFile *file)
{
    GTimeVal g_trash_time;
    const char * time_string;

    g_return_if_fail (file->info != NULL);

    file->trash_time = 0;
    time_string = g_file_info_get_attribute_string (file->info, "trash::deletion-date");
    if (time_string != NULL) {
        g_time_val_from_iso8601 (time_string, &g_trash_time);
        file->trash_time = g_trash_time.tv_sec;
    }

    file->trash_orig_path = g_file_info_get_attribute_byte_string (file->info, "trash::orig-path");
}

void gof_file_remove_from_caches (GOFFile *file)
{
    /* remove from file_cache */
    if (g_hash_table_remove (file_cache, file->location))
        g_debug ("remove from file_cache %s", file->uri);
    
    /* remove from directory_cache */
    GOFDirectoryAsync *dir = NULL;
    //g_warning ("zz0 %s", g_file_get_uri (file->location));
    if (file->directory != NULL && G_OBJECT (file->directory)->ref_count > 0) {
        dir = gof_directory_async_cache_lookup (file->directory);
        //g_warning ("zz1 %s", g_file_get_uri (file->directory));
        if (dir != NULL) {
            if (gof_directory_async_remove_from_cache (dir, file))
                g_debug ("remove from directory_cache %s", file->uri);
            g_object_unref (dir);
        }
    }
    g_warning ("end %s", G_STRFUNC);
}

static void gof_file_init (GOFFile *file) {
    file->info = NULL;
    file->location = NULL;
    file->icon = NULL;
    file->pix = NULL;

    file->utf8_collation_key = NULL;
    file->formated_type = NULL;
    file->format_size = NULL;
    file->formated_modified = NULL;
    file->custom_display_name = NULL;
    file->custom_icon_name = NULL;
    file->owner = NULL;
    file->group = NULL;

    /* assume the file is mounted by default */
    file->is_mounted = TRUE;
    file->exists = TRUE;
    
    file->flags = 0;
}

static void gof_file_finalize (GObject* obj) {
    GOFFile *file;

    file = GOF_FILE (obj);
    g_warning ("%s %s", G_STRFUNC, file->basename);

    _g_object_unref0 (file->info);
    _g_object_unref0 (file->location);
    _g_object_unref0 (file->directory);
    _g_free0 (file->uri);
    _g_free0(file->basename);
    _g_free0(file->utf8_collation_key);
    _g_free0(file->formated_type);
    _g_free0(file->format_size);
    _g_free0(file->formated_modified);
    _g_object_unref0 (file->icon);
    _g_object_unref0 (file->pix);

    _g_free0 (file->custom_display_name);
    _g_free0 (file->custom_icon_name);

    G_OBJECT_CLASS (gof_file_parent_class)->finalize (obj);
}

static void gof_file_class_init (GOFFileClass * klass) {

    /* determine the effective user id of the process */
    effective_user_id = geteuid ();

    gof_file_parent_class = g_type_class_peek_parent (klass);
    //g_type_class_add_private (klass, sizeof (GOFFilePrivate));
    /*G_OBJECT_CLASS (klass)->get_property = gof_file_get_property;
      G_OBJECT_CLASS (klass)->set_property = gof_file_set_property;*/
    G_OBJECT_CLASS (klass)->finalize = gof_file_finalize;

    signals[CHANGED] = g_signal_new ("changed",
                                    G_TYPE_FROM_CLASS (klass),
                                    G_SIGNAL_RUN_LAST,
                                    G_STRUCT_OFFSET (GOFFileClass, changed),
                                    NULL, NULL,
                                    g_cclosure_marshal_VOID__VOID,
                                    G_TYPE_NONE, 0);

    signals[DESTROY] = g_signal_new ("destroy",
                                    G_TYPE_FROM_CLASS (klass),
                                    G_SIGNAL_RUN_LAST,
                                    G_STRUCT_OFFSET (GOFFileClass, destroy),
                                    NULL, NULL,
                                    g_cclosure_marshal_VOID__VOID,
                                    G_TYPE_NONE, 0);


    signals[INFO_AVAILABLE] = g_signal_new ("info_available",
                                    G_TYPE_FROM_CLASS (klass),
                                    G_SIGNAL_RUN_LAST,
                                    G_STRUCT_OFFSET (GOFFileClass, info_available),
                                    NULL, NULL,
                                    g_cclosure_marshal_VOID__VOID,
                                    G_TYPE_NONE, 0);

    signals[ICON_CHANGED] = g_signal_new ("icon_changed",
                                    G_TYPE_FROM_CLASS (klass),
                                    G_SIGNAL_RUN_LAST,
                                    G_STRUCT_OFFSET (GOFFileClass, icon_changed),
                                    NULL, NULL,
                                    g_cclosure_marshal_VOID__VOID,
                                    G_TYPE_NONE, 0);

    /*g_object_class_install_property (G_OBJECT_CLASS (klass), gof_FILE_NAME, g_param_spec_string ("name", "name", "name", NULL, G_PARAM_STATIC_NAME | G_PARAM_STATIC_NICK | G_PARAM_STATIC_BLURB | G_PARAM_READABLE));
      g_object_class_install_property (G_OBJECT_CLASS (klass), gof_FILE_SIZE, g_param_spec_uint64 ("size", "size", "size", 0, G_MAXUINT64, 0U, G_PARAM_STATIC_NAME | G_PARAM_STATIC_NICK | G_PARAM_STATIC_BLURB | G_PARAM_READABLE));
      g_object_class_install_property (G_OBJECT_CLASS (klass), gof_FILE_DIRECTORY, g_param_spec_boolean ("directory", "directory", "directory", FALSE, G_PARAM_STATIC_NAME | G_PARAM_STATIC_NICK | G_PARAM_STATIC_BLURB | G_PARAM_READABLE));*/
}

/*
   static void gof_file_instance_init (GOFFile * self) {
   self->priv = gof_FILE_GET_PRIVATE (self);
   }*/

#if 0
GType gof_file_get_type (void) {
    static volatile gsize gof_file_type_id__volatile = 0;
    if (g_once_init_enter (&gof_file_type_id__volatile)) {
        static const GTypeInfo g_define_type_info = { sizeof (GOFFileClass), (GBaseInitFunc) NULL, (GBaseFinalizeFunc) NULL, (GClassInitFunc) gof_file_class_init, (GClassFinalizeFunc) NULL, NULL, sizeof (GOFFile), 0, (GInstanceInitFunc) gof_file_instance_init, NULL };
        GType gof_file_type_id;
        gof_file_type_id = g_type_register_static (G_TYPE_OBJECT, "GOFFile", &g_define_type_info, 0);
        g_once_init_leave (&gof_file_type_id__volatile, gof_file_type_id);
    }
    return gof_file_type_id__volatile;
}
#endif

#if 0
static void gof_file_get_property (GObject * object, guint property_id, GValue * value, GParamSpec * pspec) {
    GOFFile * self;
    self = GOF_FILE (object);
    switch (property_id) {
    case gof_FILE_NAME:
        g_value_set_string (value, gof_file_get_name (self));
        break;
    case gof_FILE_SIZE:
        g_value_set_uint64 (value, gof_file_get_size (self));
        break;
    case gof_FILE_DIRECTORY:
        g_value_set_boolean (value, gof_file_get_directory (self));
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}


static void gof_file_set_property (GObject * object, guint property_id, const GValue * value, GParamSpec * pspec) {
    GOFFile * self;
    self = GOF_FILE (object);
    switch (property_id) {
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}
#endif

static int
compare_files_by_time (GOFFile *file1, GOFFile *file2)
{
    if (file1->modified < file2->modified)
        return -1;
    else if (file1->modified > file2->modified)
        return 1;

    return 0;
}

static int
compare_by_time (GOFFile *file1, GOFFile *file2)
{
    if (file1->is_directory && !file2->is_directory)
        return -1;
    if (file2->is_directory && !file1->is_directory)
        return 1;

    return compare_files_by_time (file1, file2);
}

static int
compare_by_type (GOFFile *file1, GOFFile *file2)
{
    /* Directories go first. Then, if mime types are identical,
     * don't bother getting strings (for speed). This assumes
     * that the string is dependent entirely on the mime type,
     * which is true now but might not be later.
     */
    if (file1->is_directory && file2->is_directory)
        return 0;
    if (file1->is_directory)
        return -1;
    if (file2->is_directory)
        return +1;
    return (g_strcmp0 (file1->utf8_collation_key, file2->utf8_collation_key));
}

static int
compare_by_display_name (GOFFile *file1, GOFFile *file2)
{
    const char *name_1, *name_2;
    gboolean sort_last_1, sort_last_2;
    int compare;

    name_1 = file1->name;
    name_2 = file2->name;

    sort_last_1 = name_1[0] == SORT_LAST_CHAR1 || name_1[0] == SORT_LAST_CHAR2;
    sort_last_2 = name_2[0] == SORT_LAST_CHAR1 || name_2[0] == SORT_LAST_CHAR2;

    if (sort_last_1 && !sort_last_2) {
        compare = +1;
    } else if (!sort_last_1 && sort_last_2) {
        compare = -1;
    } else {
        compare = g_strcmp0 (file1->utf8_collation_key, file2->utf8_collation_key);
    }

    return compare;
}

static int
compare_files_by_size (GOFFile *file1, GOFFile *file2)
{
    if (file1->size < file2->size) {
        return -1;
    }
    else if (file1->size > file2->size) {
        return 1;
    }

    return 0;
}

static int
compare_by_size (GOFFile *file1, GOFFile *file2)
{
    if (file1->is_directory && !file2->is_directory)
        return -1;
    if (file2->is_directory && !file1->is_directory)
        return 1;

    return compare_files_by_size (file1, file2);
}

static int
gof_file_compare_for_sort_internal (GOFFile *file1,
                                    GOFFile *file2,
                                    gboolean directories_first,
                                    gboolean reversed)
{
    if (directories_first) {
        if (file1->is_directory && !file2->is_directory) {
            return -1;
        }
        if (file2->is_directory && !file1->is_directory) {
            return 1;
        }
    }

    /*if (file1->details->sort_order < file2->details->sort_order) {
      return reversed ? 1 : -1;
      } else if (file_1->details->sort_order > file_2->details->sort_order) {
      return reversed ? -1 : 1;
      }*/

    return 0;
}

int
gof_file_compare_for_sort (GOFFile *file1,
                           GOFFile *file2,
                           gint sort_type,
                           gboolean directories_first,
                           gboolean reversed)
{
    int result;

    if (file1 == file2) {
        return 0;
    }

    result = gof_file_compare_for_sort_internal (file1, file2, directories_first, reversed);
    //g_message ("res %d %s %s\n", result, file1->name, file2->name);

    if (result == 0) {
        switch (sort_type) {
        case FM_LIST_MODEL_FILENAME:
            result = compare_by_display_name (file1, file2);
            /*if (result == 0) {
              result = compare_by_directory_name (file_1, file_2);
              }*/
            break;
        case FM_LIST_MODEL_SIZE:
            result = compare_by_size (file1, file2);
            break;
        case FM_LIST_MODEL_TYPE:
            result = compare_by_type (file1, file2);
            break;
        case FM_LIST_MODEL_MODIFIED:
            result = compare_by_time (file1, file2);
            break;
        }

        if (reversed) {
            result = -result;
        }
    }
#if 0
    if (result == 0) {
        switch (sort_type) {
        case NAUTILUS_FILE_SORT_BY_DISPLAY_NAME:
            result = compare_by_display_name (file_1, file_2);
            if (result == 0) {
                result = compare_by_directory_name (file_1, file_2);
            }
            break;
        case NAUTILUS_FILE_SORT_BY_DIRECTORY:
            result = compare_by_full_path (file_1, file_2);
            break;
        case NAUTILUS_FILE_SORT_BY_SIZE:
            /* Compare directory sizes ourselves, then if necessary
             * use GnomeVFS to compare file sizes.
             */
            result = compare_by_size (file_1, file_2);
            if (result == 0) {
                result = compare_by_full_path (file_1, file_2);
            }
            break;
        case NAUTILUS_FILE_SORT_BY_TYPE:
            /* GnomeVFS doesn't know about our special text for certain
             * mime types, so we handle the mime-type sorting ourselves.
             */
            result = compare_by_type (file_1, file_2);
            if (result == 0) {
                result = compare_by_full_path (file_1, file_2);
            }
            break;
        case NAUTILUS_FILE_SORT_BY_MTIME:
            result = compare_by_time (file_1, file_2, NAUTILUS_DATE_TYPE_MODIFIED);
            if (result == 0) {
                result = compare_by_full_path (file_1, file_2);
            }
            break;
        case NAUTILUS_FILE_SORT_BY_ATIME:
            result = compare_by_time (file_1, file_2, NAUTILUS_DATE_TYPE_ACCESSED);
            if (result == 0) {
                result = compare_by_full_path (file_1, file_2);
            }
            break;
        case NAUTILUS_FILE_SORT_BY_TRASHED_TIME:
            result = compare_by_time (file_1, file_2, NAUTILUS_DATE_TYPE_TRASHED);
            if (result == 0) {
                result = compare_by_full_path (file_1, file_2);
            }
            break;
        case NAUTILUS_FILE_SORT_BY_EMBLEMS:
            /* GnomeVFS doesn't know squat about our emblems, so
             * we handle comparing them here, before falling back
             * to tie-breakers.
             */
            result = compare_by_emblems (file_1, file_2);
            if (result == 0) {
                result = compare_by_full_path (file_1, file_2);
            }
            break;
        default:
            g_return_val_if_reached (0);
        }

        if (reversed) {
            result = -result;
        }
    }
#endif
    return result;
}

GOFFile *
gof_file_ref (GOFFile *file)
{
    if (file == NULL) {
        return NULL;
    }
    g_return_val_if_fail (GOF_IS_FILE (file), NULL);

    return g_object_ref (file);
}

void
gof_file_unref (GOFFile *file)
{
    if (file == NULL) {
        return;
    }

    g_return_if_fail (GOF_IS_FILE (file));

    g_object_unref (file);
}

GList *
gof_files_get_location_list (GList *files)
{
    GList *gfile_list = NULL;
    GList *l;
    GOFFile *file;

    for (l=files; l != NULL; l=l->next) {
        file = (GOFFile *) l->data;
        if (file != NULL && file->location != NULL) {
            gfile_list = g_list_prepend (gfile_list, eel_g_file_ref (file->location));
        }
    } 
    //gfile_list = g_list_reverse (gfile_list);

    return (gfile_list);
}



GdkPixbuf *
gof_file_get_icon_pixbuf (GOFFile *file, int size, gboolean force_size, GOFFileIconFlags flags)
{
    NautilusIconInfo *nicon;
    GdkPixbuf *pix;

    nicon = gof_file_get_icon (file, size, flags);
    if (force_size) {
        pix =  nautilus_icon_info_get_pixbuf_at_size (nicon, size);
    } else {
        pix = nautilus_icon_info_get_pixbuf_nodefault (nicon);
    }
    g_object_unref (nicon);

    return pix;
}

/**
 * gof_file_is_writable: impoted from thunar
 * @file : a #GOFFile instance.
 *
 * Determines whether the owner of the current process is allowed
 * to write the @file.
 *
 * Return value: %TRUE if @file can be read.
**/
gboolean
gof_file_is_writable (GOFFile *file)
{
    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);

    if (file->info == NULL)
        return FALSE;
    if (!g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_ACCESS_CAN_WRITE))
        return TRUE;

    return g_file_info_get_attribute_boolean (file->info, G_FILE_ATTRIBUTE_ACCESS_CAN_WRITE);
}

gboolean
gof_file_is_trashed (GOFFile *file)
{
    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);
    return eel_g_file_is_trashed (file->location);
}

const gchar *
gof_file_get_symlink_target (GOFFile *file)
{
    g_return_val_if_fail (GOF_IS_FILE (file), NULL);

    if (file->info == NULL)
        return NULL;

    return g_file_info_get_symlink_target (file->info);
}

gboolean 
gof_file_is_symlink (GOFFile *file) 
{
    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);

    if (file->info == NULL)
        return FALSE;

    return g_file_info_get_is_symlink (file->info);
}

gchar * 
gof_file_get_formated_time (GOFFile *file, const char *attr)
{
    g_return_val_if_fail (file != NULL, NULL);
    g_return_val_if_fail (file->info != NULL, NULL);

    guint64 date = g_file_info_get_attribute_uint64 (file->info, attr);
    //TODO prefs
    return eel_get_date_as_string (date, "iso");
}


/**
 * gof_file_is_desktop_file: imported from thunar
 * @file : a #GOFFile.
 *
 * Returns %TRUE if @file is a .desktop file, but not a .directory file.
 *
 * Return value: %TRUE if @file is a .desktop file.
**/
gboolean
gof_file_is_desktop_file (GOFFile *file)
{
    const gchar *content_type;
    gboolean     is_desktop_file = FALSE;

    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);

    if (file->info == NULL)
        return FALSE;

    content_type = file->ftype;
    if (content_type != NULL)
        is_desktop_file = g_content_type_equals (content_type, "application/x-desktop");

    return is_desktop_file 
        && !g_str_has_suffix (file->basename, ".directory");
}

/**
 * gof_file_is_executable: imported from thunar
 * @file : a #GOFFile instance.
 *
 * Determines whether the owner of the current process is allowed
 * to execute the @file (or enter the directory refered to by
 * @file). On UNIX it also returns %TRUE if @file refers to a 
 * desktop entry.
 *
 * Return value: %TRUE if @file can be executed.
**/
gboolean
gof_file_is_executable (GOFFile *file)
{
    gboolean     can_execute = FALSE;
    const gchar *content_type;

    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);

    if (file->info == NULL)
        return FALSE;

    if (g_file_info_get_attribute_boolean (file->info, G_FILE_ATTRIBUTE_ACCESS_CAN_EXECUTE))
    {
        /* get the content type of the file */
        //TODO
        //content_type = g_file_info_get_content_type (file->info);
        content_type = file->ftype;
        if (G_LIKELY (content_type != NULL))
        {
#ifdef G_OS_WIN32
            /* check for .exe, .bar or .com */
            can_execute = g_content_type_can_be_executable (content_type);
#else
            /* check if the content type is save to execute, we don't use
             * g_content_type_can_be_executable() for unix because it also returns
             * true for "text/plain" and we don't want that */
            if (g_content_type_is_a (content_type, "application/x-executable")
                || g_content_type_is_a (content_type, "application/x-shellscript"))
            {
                can_execute = TRUE;
            }
#endif
        }
    }

    return can_execute || gof_file_is_desktop_file (file);
}

/**
 * gof_file_set_thumb_state: imported from thunar
 * @file        : a #GOFFile.
 * @thumb_state : the new #GOFFileThumbState.
 *
 * Sets the #GOFFileThumbState for @file to @thumb_state. 
 * This will cause a "file-changed" signal to be emitted from
 * #GOFMonitor. 
**/ 
void
gof_file_set_thumb_state (GOFFile *file, GOFFileThumbState state)
{
    g_return_if_fail (GOF_IS_FILE (file));

    /* set the new thumbnail state */
    file->flags = (file->flags & ~GOF_FILE_THUMB_STATE_MASK) | (state);
    if (file->flags == GOF_FILE_THUMB_STATE_READY) 
        gof_file_query_thumbnail_update (file);

    /* notify others of this change, so that all components can update
     * their file information */
    gof_file_icon_changed (file);
}

GOFFile* gof_file_cache_lookup (GFile *location)
{
    GOFFile *cached_file = NULL;

    g_return_val_if_fail (G_IS_FILE (location), NULL);

    /* allocate the GOFFile cache on-demand */
    if (G_UNLIKELY (file_cache == NULL))
    {
        G_LOCK (file_cache_mutex);
        file_cache = g_hash_table_new_full (g_file_hash, 
                                            (GEqualFunc) g_file_equal, 
                                            (GDestroyNotify) g_object_unref, 
                                            (GDestroyNotify) g_object_unref);
        G_UNLOCK (file_cache_mutex);
    }
    if (file_cache != NULL)
        cached_file = g_hash_table_lookup (file_cache, location);

    return _g_object_ref0 (cached_file);
}

GOFFile* gof_file_get (GFile *location)
{
    GFile *parent;
    GOFFile *file = NULL;
    GOFDirectoryAsync *dir = NULL;

    //parent = g_file_get_parent (location);
    if ((parent = g_file_get_parent (location)) != NULL)
        dir = gof_directory_async_cache_lookup (parent);
    if (dir != NULL) {
        /*gchar *uri = g_file_get_uri (parent);
        g_warning (">>>>>>>>>>>>>>> dir already cached %s", uri);
        g_free (uri);*/
        if ((file = g_hash_table_lookup (dir->file_hash, location)) == NULL)
            file = g_hash_table_lookup (dir->hidden_file_hash, location);
        _g_object_ref0 (file);
        g_object_unref (dir);
    }

    if (file == NULL) {
        //g_debug ("gof_file_cache_lookup");
        file = gof_file_cache_lookup (location);
    } 
    
    if (file != NULL) {
        g_debug (">>>>reuse file %s", file->uri);
    } else {
        file = gof_file_new (location, parent);
        g_debug (">>>>create file %s", file->uri);
        G_LOCK (file_cache_mutex);
        if (file_cache != NULL)
            g_hash_table_insert (file_cache, g_object_ref (location), g_object_ref (file));
        G_UNLOCK (file_cache_mutex);

        /*g_critical ("%s INFO null %s file_cache items %d", G_STRFUNC, file->uri, 
                    g_hash_table_size (file_cache));*/
    }

    _g_object_unref0 (parent);

    return (file);
}

GOFFile* gof_file_get_by_uri (const char *uri)
{
    GFile *location;
    GOFFile *file;

    location = g_file_new_for_uri (uri);
    if(location == NULL)
        return NULL;

    file = gof_file_get (location);
#ifdef ENABLE_DEBUG
    g_debug ("%s %s", G_STRFUNC, file->uri);
#endif
    g_object_unref (location);

    return file;
}

GOFFile* gof_file_get_by_commandline_arg (const char *arg)
{
    GFile *location;
    GOFFile *file;

    location = g_file_new_for_commandline_arg (arg);
    file = gof_file_get (location);
    g_object_unref (location);

    return file;
}

gchar* gof_file_list_to_string (GList *list, gsize *len)
{
    GString *string;
    GList   *lp;

    /* allocate initial string */
    string = g_string_new (NULL);

    for (lp = list; lp != NULL; lp = lp->next)
    {
        string = g_string_append (string, GOF_FILE(lp->data)->uri);
        string = g_string_append (string, "\r\n");
    }

    *len = string->len;
    return g_string_free (string, FALSE); 
}

gboolean gof_file_same_filesystem (GOFFile *file_a, GOFFile *file_b)
{
    const gchar *filesystem_id_a;
    const gchar *filesystem_id_b;

    g_return_val_if_fail (GOF_IS_FILE (file_a), FALSE);
    g_return_val_if_fail (GOF_IS_FILE (file_b), FALSE);

    /* return false if we have no information about one of the files */
    if (file_a->info == NULL || file_b->info == NULL)
        return FALSE;

    /* determine the filesystem IDs */
    filesystem_id_a = g_file_info_get_attribute_string (file_a->info, 
                                                        G_FILE_ATTRIBUTE_ID_FILESYSTEM);

    filesystem_id_b = g_file_info_get_attribute_string (file_b->info, 
                                                        G_FILE_ATTRIBUTE_ID_FILESYSTEM);

    /* compare the filesystem IDs */
    return eel_str_is_equal (filesystem_id_a, filesystem_id_b);
}

/**
 * gof_file_accepts_drop (imported from thunar):
 * @file                    : a #GOFFile instance.
 * @file_list               : the list of #GFile<!---->s that will be droppped.
 * @context                 : the current #GdkDragContext, which is used for the drop.
 * @suggested_action_return : return location for the suggested #GdkDragAction or %NULL.
 *
 * Checks whether @file can accept @path_list for the given @context and
 * returns the #GdkDragAction<!---->s that can be used or 0 if no actions
 * apply.
 *
 * If any #GdkDragAction<!---->s apply and @suggested_action_return is not
 * %NULL, the suggested #GdkDragAction for this drop will be stored to the
 * location pointed to by @suggested_action_return.
 *
 * Return value: the #GdkDragAction<!---->s supported for the drop or
 *               0 if no drop is possible.
**/

GdkDragAction
gof_file_accepts_drop (GOFFile          *file,
                       GList            *file_list,
                       GdkDragContext   *context,
                       GdkDragAction    *suggested_action_return)
{
    GdkDragAction   suggested_action;
    GdkDragAction   actions;
    GOFFile         *ofile;
    GFile           *parent_file;
    GList           *lp;
    guint           n;

    g_return_val_if_fail (GOF_IS_FILE (file), 0);
    g_return_val_if_fail (GDK_IS_DRAG_CONTEXT (context), 0);

    /* we can never drop an empty list */
    if (G_UNLIKELY (file_list == NULL))
        return 0;

    /* default to whatever GTK+ thinks for the suggested action */
    suggested_action = gdk_drag_context_get_suggested_action (context);

    char *uri = g_file_get_uri (file_list->data);
    g_debug ("%s %s %s\n", G_STRFUNC, file->uri, uri);
    _g_free0 (uri);

    /* check if we have a writable directory here or an executable file */
    if (file->is_directory && gof_file_is_writable (file))
    {
        /* determine the possible actions */
        actions = gdk_drag_context_get_actions (context) & (GDK_ACTION_COPY | GDK_ACTION_MOVE | GDK_ACTION_LINK | GDK_ACTION_ASK);

        /* cannot create symbolic links in the trash or copy to the trash */
        if (gof_file_is_trashed (file))
            actions &= ~(GDK_ACTION_COPY | GDK_ACTION_LINK);

        /* check up to 100 of the paths (just in case somebody tries to
         * drag around his music collection with 5000 files).
         */
        for (lp = file_list, n = 0; lp != NULL && n < 100; lp = lp->next, ++n)
        {
            uri = g_file_get_uri (lp->data);
            g_debug ("%s %s %s\n", G_STRFUNC, file->uri, uri);
            _g_free0 (uri);

            /* we cannot drop a file on itself */
            if (G_UNLIKELY (g_file_equal (file->location, lp->data)))
                return 0;

            /* check whether source and destination are the same */
            parent_file = g_file_get_parent (lp->data);
            if (G_LIKELY (parent_file != NULL))
            {
                if (g_file_equal (file->location, parent_file))
                {
                    g_object_unref (parent_file);
                    return 0;
                }
                else
                    g_object_unref (parent_file);
            }

            /* copy/move/link within the trash not possible */
            if (G_UNLIKELY (eel_g_file_is_trashed (lp->data) && gof_file_is_trashed (file)))
                return 0;
        }

        /* if the source offers both copy and move and the GTK+ suggested action is copy, try to be smart telling whether we should copy or move by default by checking whether the source and target are on the same disk. */
        if ((actions & (GDK_ACTION_COPY | GDK_ACTION_MOVE)) != 0 
            && (suggested_action == GDK_ACTION_COPY))
        {
            /* default to move as suggested action */
            suggested_action = GDK_ACTION_MOVE;

            /* check for up to 100 files, for the reason state above */
            for (lp = file_list, n = 0; lp != NULL && n < 100; lp = lp->next, ++n)
            {
                /* dropping from the trash always suggests move */
                if (G_UNLIKELY (eel_g_file_is_trashed (lp->data)))
                    break;

                /* determine the cached version of the source file */
                ofile = gof_file_get(lp->data);

                /* we have only move if we know the source and both the source and the target
                 * are on the same disk, and the source file is owned by the current user.
                 */
                if (ofile == NULL 
                    || !gof_file_same_filesystem (file, ofile)
                    || (ofile->info != NULL 
                        && g_file_info_get_attribute_uint32 (ofile->info, 
                                                             G_FILE_ATTRIBUTE_UNIX_UID) != effective_user_id))
                {
                    //printf ("%s default suggested action GDK_ACTION_COPY\n", G_STRFUNC);
                    /* default to copy and get outa here */
                    suggested_action = GDK_ACTION_COPY;
                    break;
                }
            }
            //printf ("%s actions MOVE %d COPY %d suggested %d\n", G_STRFUNC, GDK_ACTION_MOVE, GDK_ACTION_COPY, suggested_action);
        }
    }
    else if (gof_file_is_executable (file))
    {
        /* determine the possible actions */
        actions = gdk_drag_context_get_actions (context) & (GDK_ACTION_COPY | GDK_ACTION_MOVE | GDK_ACTION_LINK | GDK_ACTION_PRIVATE);
    }
    else
        return 0;

    /* determine the preferred action based on the context */
    if (G_LIKELY (suggested_action_return != NULL))
    {
        /* determine a working action */
        if (G_LIKELY ((suggested_action & actions) != 0))
            *suggested_action_return = suggested_action;
        else if ((actions & GDK_ACTION_ASK) != 0)
            *suggested_action_return = GDK_ACTION_ASK;
        else if ((actions & GDK_ACTION_COPY) != 0)
            *suggested_action_return = GDK_ACTION_COPY;
        else if ((actions & GDK_ACTION_LINK) != 0)
            *suggested_action_return = GDK_ACTION_LINK;
        else if ((actions & GDK_ACTION_MOVE) != 0)
            *suggested_action_return = GDK_ACTION_MOVE;
        else
            *suggested_action_return = GDK_ACTION_PRIVATE;
    }

    /* yeppa, we can drop here */
    return actions;
}

static gboolean
gof_spawn_command_line_on_screen (char *cmd, GdkScreen *screen)
{
    GAppInfo *app;
    GdkAppLaunchContext *ctx;
    GError *error = NULL;
    gboolean succeed = FALSE;

    app = g_app_info_create_from_commandline (cmd, NULL, 0, &error);

    if (app != NULL && screen != NULL) {
        ctx = gdk_app_launch_context_new ();
        gdk_app_launch_context_set_screen (ctx, screen);

        succeed = g_app_info_launch (app, NULL, G_APP_LAUNCH_CONTEXT (ctx), &error);

        g_object_unref (app);
        g_object_unref (ctx);
    }

    if (error != NULL) {
        g_message ("Could not start application on terminal: %s", error->message);
        g_error_free (error);
    }

    return (succeed);
}


/**
 * gof_file_get_default_handler: imported from thunar
 * @file : a #GOFFile instance.
 *
 * Returns the default #GAppInfo for @file or %NULL if there is none.
 * 
 * The caller is responsible to free the returned #GAppInfo using
 * g_object_unref().
 *
 * Return value: Default #GAppInfo for @file or %NULL if there is none.
**/
GAppInfo *
gof_file_get_default_handler (GOFFile *file) 
{
    const gchar *content_type;
    GAppInfo    *app_info = NULL;
    gboolean     must_support_uris = FALSE;
    gchar       *path;

    g_return_val_if_fail (GOF_IS_FILE (file), NULL);

    //TODO
    //content_type = thunar_file_get_content_type (file);
    content_type = file->ftype;
    if (content_type != NULL)
    {
        path = g_file_get_path (file->location);
        must_support_uris = (path == NULL);
        _g_free0 (path);

        app_info = g_app_info_get_default_for_type (content_type, must_support_uris);
    }

    if (app_info == NULL)
        app_info = g_file_query_default_handler (file->location, NULL, NULL);

    return app_info;
}

gboolean
gof_file_execute (GOFFile *file, GdkScreen *screen, GList *file_list, GError **error)
{
    /*gboolean    snotify = FALSE;
    gboolean    terminal;*/
    gboolean    result = FALSE;
    GKeyFile    *key_file;
    GError      *err = NULL;
    gchar       *icon = NULL;
    gchar       *name;
    gchar       *type;
    gchar       *url;
    gchar       *location;
    gchar       *exec;

    gchar       *cmd = NULL;
    gchar       *quoted_location;

    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);
    g_return_val_if_fail (GDK_IS_SCREEN (screen), FALSE);
    g_return_val_if_fail (error == NULL || *error == NULL, FALSE);

    /* only execute locale executable files */
    if (!g_file_is_native (file->location))
        return FALSE;
    location = g_file_get_path (file->location);

    if (gof_file_is_desktop_file (file))
    {
        key_file = eel_g_file_query_key_file (file->location, NULL, &err);

        if (key_file == NULL)
        {
            g_set_error (error, G_FILE_ERROR, G_FILE_ERROR_INVAL,
                         _("Failed to parse the desktop file: %s"), err->message);
            g_error_free (err);
            return FALSE;
        }

        type = g_key_file_get_string (key_file, G_KEY_FILE_DESKTOP_GROUP,
                                      G_KEY_FILE_DESKTOP_KEY_TYPE, NULL);

        if (G_LIKELY (eel_str_is_equal (type, "Application")))
        {
            exec = g_key_file_get_string (key_file, G_KEY_FILE_DESKTOP_GROUP,
                                          G_KEY_FILE_DESKTOP_KEY_EXEC, NULL);
            if (G_LIKELY (exec != NULL))
            {
                /* parse other fields */
                name = g_key_file_get_locale_string (key_file, G_KEY_FILE_DESKTOP_GROUP,
                                                     G_KEY_FILE_DESKTOP_KEY_NAME, NULL,
                                                     NULL);
                icon = g_key_file_get_string (key_file, G_KEY_FILE_DESKTOP_GROUP,
                                              G_KEY_FILE_DESKTOP_KEY_ICON, NULL);
                /* TODO use terminal snotify */
                /*terminal = g_key_file_get_boolean (key_file, G_KEY_FILE_DESKTOP_GROUP,
                                                   G_KEY_FILE_DESKTOP_KEY_TERMINAL, NULL);
                snotify = g_key_file_get_boolean (key_file, G_KEY_FILE_DESKTOP_GROUP,
                                                  G_KEY_FILE_DESKTOP_KEY_STARTUP_NOTIFY, 
                                                  NULL);*/

                cmd = marlin_exec_parse (exec, file_list, icon, name, location); 

                _g_free0 (name);
                _g_free0 (icon);
                _g_free0 (exec);
            }
            else
            {
                /* TRANSLATORS: `Exec' is a field name in a .desktop file. 
                 * Don't translate it. */
                g_set_error (error, G_FILE_ERROR, G_FILE_ERROR_INVAL, 
                             _("No Exec field specified"));
            }
        }
        else if (eel_str_is_equal (type, "Link"))
        {
            url = g_key_file_get_string (key_file, G_KEY_FILE_DESKTOP_GROUP,
                                         G_KEY_FILE_DESKTOP_KEY_URL, NULL);
            if (G_LIKELY (url != NULL))
            {
                //printf ("%s Link %s\n", G_STRFUNC, url);
                GOFFile *link = gof_file_get_by_commandline_arg (url);
                result = gof_file_launch (link, screen);
                g_object_unref (link);
                return (result); 
            }
            else
            {
                /* TRANSLATORS: `URL' is a field name in a .desktop file.
                 * Don't translate it. */
                g_set_error (error, G_FILE_ERROR, G_FILE_ERROR_INVAL, 
                             _("No URL field specified"));
            }
        }
        else
        {
            g_set_error (error, G_FILE_ERROR, G_FILE_ERROR_INVAL, 
                         _("Invalid desktop file"));
        }

        _g_free0 (type);
        g_key_file_free (key_file);
    }
    else
    {
        quoted_location = g_shell_quote (location);
        cmd = marlin_exec_auto_parse (quoted_location, file_list);
        //printf ("%s exec: %s\n", G_STRFUNC, cmd);
        _g_free0 (quoted_location);
    }

    if (cmd != NULL) {
        //printf ("%s cmd: %s\n", G_STRFUNC, cmd);
        result = gof_spawn_command_line_on_screen (cmd, screen);
    }

    _g_free0 (location);
    _g_free0 (cmd);

    return result;
}

gboolean
gof_file_launch (GOFFile  *file, GdkScreen *screen)
{
    GdkAppLaunchContext *context;
    GAppInfo            *app_info;
    gboolean             succeed;
    GList                path_list;
    GError              *error = NULL;

    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);
    g_return_val_if_fail (GDK_IS_SCREEN (screen), FALSE);

    /* check if we should execute the file */
    if (gof_file_is_executable (file))
        return gof_file_execute (file, screen, NULL, &error);

    /* determine the default application to open the file */
    /* TODO We should probably add a cancellable argument to gof_file_launch() */
    app_info = gof_file_get_default_handler (file);

    /* display the application chooser if no application is defined for this file
     * type yet */
    if (G_UNLIKELY (app_info == NULL))
    {
        //TODO
        /*thunar_show_chooser_dialog (parent, file, TRUE);*/
        printf ("%s application show_chooser_dialog\n", G_STRFUNC);
        return TRUE;
    }

    /* check if we're not trying to launch another file manager again, possibly
     * ourselfs which will end in a loop */
    /*if (g_strcmp0 (g_app_info_get_id (app_info), "exo-file-manager.desktop") == 0
      || g_strcmp0 (g_app_info_get_id (app_info), "Thunar.desktop") == 0
      || g_strcmp0 (g_app_info_get_name (app_info), "exo-file-manager") == 0)
      {
      g_object_unref (G_OBJECT (app_info));
      thunar_show_chooser_dialog (parent, file, TRUE);
      return TRUE;
      }*/

    /* TODO allow launch of multiples same content type files */
    /* fake a path list */
    path_list.data = file->location;
    path_list.next = path_list.prev = NULL;

    context = gdk_app_launch_context_new ();
    gdk_app_launch_context_set_screen (context, screen);
    succeed = g_app_info_launch (app_info, &path_list, G_APP_LAUNCH_CONTEXT (context), &error);

    g_object_unref (context);
    g_object_unref (G_OBJECT (app_info));

    return succeed;
}

gboolean
gof_file_launch_with (GOFFile  *file, GdkScreen *screen, GAppInfo* app_info)
{
    GdkAppLaunchContext *context;
    gboolean             succeed;
    GList                path_list;
    GError              *error = NULL;

    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);
    g_return_val_if_fail (GDK_IS_SCREEN (screen), FALSE);

    /* fake a path list */
    path_list.data = file->location;
    path_list.next = path_list.prev = NULL;

    context = gdk_app_launch_context_new ();
    gdk_app_launch_context_set_screen (context, screen);
    succeed = g_app_info_launch (app_info, &path_list, G_APP_LAUNCH_CONTEXT (context), &error);

    g_object_unref (context);
    g_object_unref (G_OBJECT (app_info));

    return succeed;
}

gboolean
gof_files_launch_with (GList *files, GdkScreen *screen, GAppInfo* app_info)
{
    GdkAppLaunchContext *context;
    gboolean             succeed;
    GList               *gfiles;
    GError              *error = NULL;

    g_return_val_if_fail (files != NULL, FALSE);
    g_return_val_if_fail (GDK_IS_SCREEN (screen), FALSE);

    context = gdk_app_launch_context_new ();
    gdk_app_launch_context_set_screen (context, screen);

    gfiles = gof_files_get_location_list (files);

    succeed = g_app_info_launch (app_info, gfiles, G_APP_LAUNCH_CONTEXT (context), &error);
    print_error (error);

    g_list_free_full (gfiles, (GDestroyNotify) eel_g_file_unref);
    g_object_unref (context);

    return succeed;
}

void
gof_file_open_single (GOFFile *file, GdkScreen *screen)
{
    gof_file_launch (file, screen);
}

void
gof_file_list_free (GList *list)
{
    g_list_foreach (list, (GFunc) gof_file_unref, NULL);
    g_list_free (list);
}

GList *
gof_file_list_ref (GList *list)
{
    g_list_foreach (list, (GFunc) gof_file_ref, NULL);
    return list;
}

GList *
gof_file_list_copy (GList *list)
{
    return g_list_copy (gof_file_list_ref (list));
}


/* TODO move this mini job to marlin-file-operations? */
GOFFileOperation *
gof_file_operation_new (GOFFile *file,
                        GOFFileOperationCallback callback,
                        gpointer callback_data)
{
    GOFFileOperation *op;

    op = g_new0 (GOFFileOperation, 1);
    op->file = gof_file_ref (file);
    op->callback = callback;
    op->callback_data = callback_data;
    op->cancellable = g_cancellable_new ();

    /* FIXME check this Glist */
    op->file->operations_in_progress = g_list_prepend
        (op->file->operations_in_progress, op);

    return op;
}

static void
gof_file_operation_remove (GOFFileOperation *op)
{
    op->file->operations_in_progress = g_list_remove
        (op->file->operations_in_progress, op);
}

void
gof_file_operation_free (GOFFileOperation *op)
{
    gof_file_operation_remove (op);
    gof_file_unref (op->file);
    g_object_unref (op->cancellable);
    if (op->free_data) {
        op->free_data (op->data);
    }
    _g_free0 (op);
}

void
gof_file_operation_complete (GOFFileOperation *op, GFile *result_file, GError *error)
{
    /* Claim that something changed even if the operation failed.
     * This makes it easier for some clients who see the "reverting"
     * as "changing back".
     */
    gof_file_operation_remove (op);
    //gof_file_icon_changed (op->file);
    if (op->callback) {
        (* op->callback) (op->file, result_file, error, op->callback_data);
    }
    gof_file_operation_free (op);
}

void
gof_file_operation_cancel (GOFFileOperation *op)
{
    /* Cancel the operation if it's still in progress. */
    g_cancellable_cancel (op->cancellable);
}

static void
rename_callback (GObject *source_object,
                 GAsyncResult *res,
                 gpointer callback_data)
{
    GOFFileOperation *op;
    GFile *new_file;
    GError *error;

    op = callback_data;
    error = NULL;
    new_file = g_file_set_display_name_finish (G_FILE (source_object),
                                               res, &error);

    gof_file_operation_complete (op, NULL, error);
    if (new_file != NULL) {
        g_object_unref (new_file);
    } else { 
        g_error_free (error);
    }
}

void
gof_file_rename (GOFFile *file,
                 const char *new_name,
                 GOFFileOperationCallback callback,
                 gpointer callback_data)
{
    GOFFileOperation *op;
    //char *uri;
    //char *old_name;
    //char *new_file_name;
    //gboolean success, name_changed;
    GError *error;

    g_return_if_fail (GOF_IS_FILE (file));
    g_return_if_fail (new_name != NULL);
    g_return_if_fail (callback != NULL);

    //TODO rename .desktop files
    /* Return an error for incoming names containing path separators.
     * But not for .desktop files as '/' are allowed for them */
    if (strstr (new_name, "/") != NULL) {
        error = g_error_new (G_IO_ERROR, G_IO_ERROR_INVALID_ARGUMENT,
                             _("Slashes are not allowed in filenames"));
        (* callback) (file, NULL, error, callback_data);
        g_error_free (error);
        return;
    }

    //TODO check

    /* Self-owned files can't be renamed. Test the name-not-actually-changing
     * case before this case.
     */
#if 0
    if (nautilus_file_is_self_owned (file)) {
        /* Claim that something changed even if the rename
         * failed. This makes it easier for some clients who
         * see the "reverting" to the old name as "changing
         * back".
         */
        nautilus_file_changed (file);
        error = g_error_new (G_IO_ERROR, G_IO_ERROR_NOT_SUPPORTED,
                             _("Toplevel files cannot be renamed"));

        (* callback) (file, NULL, error, callback_data);
        g_error_free (error);
        return;
    }
#endif

    /* Set up a renaming operation. */
    op = gof_file_operation_new (file, callback, callback_data);
    op->is_rename = TRUE;

    /* Do the renaming. */
    g_file_set_display_name_async (file->location,
                                   new_name,
                                   G_PRIORITY_DEFAULT,
                                   op->cancellable,
                                   rename_callback,
                                   op);
}


gboolean
gof_file_can_set_owner (GOFFile *file)
{
    /* unknown file uid */
    if (file->uid == -1) 
		return FALSE;

	/* root */
	return geteuid() == 0;
}

/* copied from nautilus-file.c */
/**
 * gof_file_can_set_group:
 * 
 * Check whether the current user is allowed to change
 * the group of a file.
 * 
 * @file: The file in question.
 * 
 * Return value: TRUE if the current user can change the
 * group of @file, FALSE otherwise. It's always possible
 * that when you actually try to do it, you will fail.
 */
gboolean
gof_file_can_set_group (GOFFile *file)
{
	uid_t user_id;

	if (file->gid == -1)
		return FALSE;

	user_id = geteuid();

	/* Owner is allowed to set group (with restrictions). */
	if (user_id == (uid_t) file->uid) 
		return TRUE;

	/* Root is also allowed to set group. */
	if (user_id == 0) 
		return TRUE;

	return FALSE;
}

/* copied from nautilus-file.c */
/**
 * nautilus_file_get_settable_group_names:
 * 
 * Get a list of all group names that the current user
 * can set the group of a specific file to.
 * 
 * @file: The NautilusFile in question.
 */
GList *
gof_file_get_settable_group_names (GOFFile *file)
{
	uid_t user_id;
	GList *result = NULL;

	if (!gof_file_can_set_group (file))
		return NULL;

	/* Check the user. */
	user_id = geteuid();

	if (user_id == 0) {
		/* Root is allowed to set group to anything. */
		result = eel_get_all_group_names ();
	} else if (user_id == (uid_t) file->uid) {
		/* Owner is allowed to set group to any that owner is member of. */
		result = eel_get_group_names_for_user ();
	} else {
		g_warning ("unhandled case in %s", G_STRFUNC);
	}

	return result;
}

/* copied from nautilus-file.c */
/**
 * gof_file_can_set_permissions:
 * 
 * Check whether the current user is allowed to change
 * the permissions of a file.
 * 
 * @file: The file in question.
 * 
 * Return value: TRUE if the current user can change the
 * permissions of @file, FALSE otherwise. It's always possible
 * that when you actually try to do it, you will fail.
 */
gboolean
gof_file_can_set_permissions (GOFFile *file)
{
    uid_t user_id;

    if (file->uid != -1 && g_file_is_native (file->location)) 
    {
        /* Check the user. */
        user_id = geteuid();

        /* Owner is allowed to set permissions. */
        if (user_id == (uid_t) file->uid) 
            return TRUE;

        /* Root is also allowed to set permissions. */
        if (user_id == 0) 
            return TRUE;

        /* Nobody else is allowed. */
        return FALSE;
    }

    /* pretend to have full chmod rights when no info is available, relevant when
     * the FS can't provide ownership info, for instance for FTP */
    return TRUE;
}

/* copied from nautilus-file.c */
/**
 * gof_file_get_permissions_as_string:
 * 
 * Get a user-displayable string representing a file's permissions. The caller
 * is responsible for _g_free0-ing this string.
 * @file: GOFFile representing the file in question.
 * 
 * Returns: Newly allocated string ready to display to the user.
 * 
 **/
char *
gof_file_get_permissions_as_string (GOFFile *file)
{
    gboolean is_link;
    gboolean suid, sgid, sticky;

    g_assert (GOF_IS_FILE (file));

    is_link = gof_file_is_symlink (file);

    /* We use ls conventions for displaying these three obscure flags */
    suid = file->permissions & S_ISUID;
    sgid = file->permissions & S_ISGID;
    sticky = file->permissions & S_ISVTX;

    return g_strdup_printf ("%c%c%c%c%c%c%c%c%c%c",
                            is_link ? 'l' : file->is_directory ? 'd' : '-',
                            file->permissions & S_IRUSR ? 'r' : '-',
                            file->permissions & S_IWUSR ? 'w' : '-',
                            file->permissions & S_IXUSR 
                            ? (suid ? 's' : 'x') 
                            : (suid ? 'S' : '-'),
                            file->permissions & S_IRGRP ? 'r' : '-',
                            file->permissions & S_IWGRP ? 'w' : '-',
                            file->permissions & S_IXGRP
                            ? (sgid ? 's' : 'x') 
                            : (sgid ? 'S' : '-'),		
                            file->permissions & S_IROTH ? 'r' : '-',
                            file->permissions & S_IWOTH ? 'w' : '-',
                            file->permissions & S_IXOTH
                            ? (sticky ? 't' : 'x') 
                            : (sticky ? 'T' : '-'));
}

