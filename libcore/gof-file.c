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

#include "gof-file.h"
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <glib/gi18n.h>
#include <gio/gdesktopappinfo.h>

#include "marlin-icons.h"
#include "fm-list-model.h"
#include "pantheon-files-core.h"


G_LOCK_DEFINE_STATIC (file_cache_mutex);

static GHashTable   *file_cache;

G_DEFINE_TYPE (GOFFile, gof_file, G_TYPE_OBJECT)

#define SORT_LAST_CHAR1 '.'
#define SORT_LAST_CHAR2 '#'

#define ICON_NAME_THUMBNAIL_LOADING   "image-loading"

enum {
    CHANGED,
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

const gchar     *gof_file_get_thumbnail_path (GOFFile *file);

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

GOFFile *
gof_file_new (GFile *location, GFile *dir)
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

    return (file);
}

void
gof_file_icon_changed (GOFFile *file)
{
    GOFDirectoryAsync *dir = NULL;

    /* get the DirectoryAsync associated to the file */
    if (file->directory != NULL) {
        dir = gof_directory_async_cache_lookup (file->directory);
        if (dir != NULL) {
            if (!file->is_hidden || gof_preferences_get_show_hidden_files (gof_preferences_get_default ())) {
                g_signal_emit_by_name (dir, "icon-changed", file);
            }

            g_object_unref (dir);
        }
    }
    g_signal_emit_by_name (file, "icon_changed");
}

static void
gof_file_clear_info (GOFFile *file)
{
    g_return_if_fail (file != NULL);

    _g_object_unref0 (file->target_location);
    _g_object_unref0 (file->mount);
    _g_free0(file->utf8_collation_key);
    _g_free0(file->formated_type);
    _g_free0(file->format_size);
    _g_free0(file->formated_modified);
    _g_object_unref0 (file->icon);
    _g_free0 (file->custom_display_name);
    _g_free0 (file->custom_icon_name);

    file->uid = -1;
    file->gid = -1;
    file->has_permissions = FALSE;
    file->permissions = 0;
    _g_free0(file->owner);
    _g_free0(file->group);
    file->can_unmount = FALSE;
}

/**
 * gof_file_is_location_uri_default:
 *
 * example: afp://server.local:123/)
 *
 * Returns: TRUE if it is an URI at "/"; FALSE otherwise.
**/
static gboolean
gof_file_is_location_uri_default (GOFFile *file)
{
    g_return_val_if_fail (file->info != NULL, FALSE);
    gboolean res;

    const char *target_uri = g_file_info_get_attribute_string (file->info, G_FILE_ATTRIBUTE_STANDARD_TARGET_URI);

    if (target_uri == NULL)
        target_uri = file->uri;

    gchar **split = g_strsplit (target_uri, "/", 4);
    res = (split[3] == NULL || !strcmp (split[3], ""));
    g_strfreev (split);

    return res;
}

gboolean
gof_file_is_mountable (GOFFile *file) {
    g_return_val_if_fail (file->info != NULL, FALSE);
    return g_file_info_get_file_type(file->info) == G_FILE_TYPE_MOUNTABLE;
}

guint
get_number_of_uri_parts (GOFFile *file) {
    const char *target_uri = NULL;
    if (file->info != NULL)
        target_uri = g_file_info_get_attribute_string (file->info, G_FILE_ATTRIBUTE_STANDARD_TARGET_URI);

    if (target_uri == NULL)
        target_uri = file->uri;

    gchar **split = g_strsplit (target_uri, "/", 6);
    guint i, count;
    count = 0;
    for (i = 0; i < g_strv_length (split); i++) {
        if (split [i][0] != NULL) {
            count++;
        }
    }
    g_strfreev (split);
    return count;
}

gboolean
gof_file_is_smb_share (GOFFile *file)
{
    gboolean res;
    res = FALSE;

    if (gof_file_is_smb_uri_scheme (file) || gof_file_is_network_uri_scheme (file)) {
        res = get_number_of_uri_parts (file) == 3;
    }

    return res;
}

gboolean
gof_file_is_smb_server (GOFFile *file)
{
    gboolean res;
    res = FALSE;

    if (gof_file_is_smb_uri_scheme (file) || gof_file_is_network_uri_scheme (file)){
        res = get_number_of_uri_parts (file) == 2;
    }

    return res;
}

gboolean
gof_file_is_remote_uri_scheme (GOFFile *file)
{
    if (gof_file_is_root_network_folder (file) || gof_file_is_other_uri_scheme (file))
        return TRUE;
}

gboolean
gof_file_is_root_network_folder (GOFFile *file)
{
    return (gof_file_is_network_uri_scheme (file) || gof_file_is_smb_server (file));
}

gboolean
gof_file_is_network_uri_scheme (GOFFile *file)
{
    if (!G_IS_FILE (file->location))
        return TRUE;

    return g_file_has_uri_scheme (file->location, "network");
}

gboolean
gof_file_is_smb_uri_scheme (GOFFile *file)
{
    if (!G_IS_FILE (file->location))
        return TRUE;

    return g_file_has_uri_scheme (file->location, "smb");
}

gboolean
gof_file_is_recent_uri_scheme (GOFFile *file)
{
    if (!G_IS_FILE (file->location))
        return TRUE;

    return g_file_has_uri_scheme (file->location, "recent");
}

gboolean
gof_file_is_other_uri_scheme (GOFFile *file)
{
    GFile *loc = file->location;
    if (!G_IS_FILE (file->location))
        return TRUE;

    gboolean res;

    res = g_file_has_uri_scheme (loc, "ftp") ||
          g_file_has_uri_scheme (loc, "sftp") ||
          g_file_has_uri_scheme (loc, "afp") ||
          g_file_has_uri_scheme (loc, "dav") ||
          g_file_has_uri_scheme (loc, "davs");

    return res;
}

void
gof_file_get_folder_icon_from_uri_or_path (GOFFile *file)
{
    if (file->icon != NULL)
        return;

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

static void
gof_file_target_location_update (GOFFile *file)
{
    if (file->target_location == NULL)
        return;

    /*GOFFile *gof = gof_file_get (file->target_location);
    gof_file_query_update (gof);
    file->is_directory = gof->is_directory;
    file->ftype = gof->ftype;*/

    file->target_gof = gof_file_get (file->target_location);
    /* TODO make async */
    gof_file_query_update (file->target_gof);
}

static void
gof_file_update_size (GOFFile *file)
{
    g_free (file->format_size);

    if (gof_file_is_folder (file) || gof_file_is_root_network_folder (file)) {
        file->format_size = g_strdup ("—");
    } else if (g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_STANDARD_SIZE)) {
        file->format_size = g_format_size (file->size);
    } else {
        file->format_size = g_strdup (_("Inaccessible"));
    }
}

static void
gof_file_update_formated_type (GOFFile *file)
{
    gchar *formated_type = NULL;

    _g_free0 (file->formated_type);
    const gchar *ftype = gof_file_get_ftype (file);
    /* Do not interpret desktop files (lp:1660742) */
    if (ftype != NULL) {
        formated_type = g_content_type_get_description (ftype);
        if (G_UNLIKELY (gof_file_is_symlink (file))) {
            file->formated_type = g_strdup_printf (_("link to %s"), formated_type);
        } else {
            file->formated_type = g_strdup (formated_type);
        }
    } else {
        file->formated_type = g_strdup ("");
    }
    g_free (formated_type);
}

static void
gof_file_update_icon_internal (GOFFile *file, gint size, gint scale);

void
gof_file_update_type (GOFFile *file)
{
    const gchar *ftype = gof_file_get_ftype (file);

    gof_file_update_formated_type (file);
    /* update icon */
    file->icon = g_content_type_get_icon (ftype);
    if (file->pix_size > 1 && file->pix_scale > 0)
        gof_file_update_icon_internal (file, file->pix_size, file->pix_scale);

    gof_file_icon_changed (file);
}

/** Avoid calling this unnecessarily (e.g. for whole directory if not visible) **/
void
gof_file_update (GOFFile *file)
{
    GKeyFile *key_file;
    gchar *p;

    g_return_if_fail (file->info != NULL);

    /* free previously allocated */
    gof_file_clear_info (file);

    file->is_hidden = g_file_info_get_is_hidden (file->info) || g_file_info_get_is_backup (file->info);
    file->size = (guint64) g_file_info_get_size (file->info);
    file->file_type = g_file_info_get_file_type (file->info);
    file->is_directory = (file->file_type == G_FILE_TYPE_DIRECTORY);
    file->modified = g_file_info_get_attribute_uint64 (file->info, G_FILE_ATTRIBUTE_TIME_MODIFIED);

    /* metadata */
    if (file->is_directory) {
        if (g_file_info_has_attribute (file->info, "metadata::marlin-sort-column-id"))
            file->sort_column_id = fm_list_model_get_column_id_from_string (g_file_info_get_attribute_string (file->info, "metadata::marlin-sort-column-id"));
        if (g_file_info_has_attribute (file->info, "metadata::marlin-sort-reversed"))
            file->sort_order = !g_strcmp0 (g_file_info_get_attribute_string (file->info, "metadata::marlin-sort-reversed"), "true") ? GTK_SORT_DESCENDING : GTK_SORT_ASCENDING;
    }

    if (g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_STANDARD_ICON)) {
        file->icon = (GIcon *) g_file_info_get_attribute_object (file->info, G_FILE_ATTRIBUTE_STANDARD_ICON);
        g_object_ref (file->icon);
    }

    /* Any location or target on a mount will now have the file->mount and file->is_mounted set */
    const char *target_uri =  g_file_info_get_attribute_string (file->info, G_FILE_ATTRIBUTE_STANDARD_TARGET_URI);
    if (target_uri != NULL) {
        file->target_location = g_file_new_for_uri (target_uri);
        gof_file_target_location_update (file);

        file->mount = g_file_find_enclosing_mount (file->target_location, NULL, NULL);
        file->is_mounted = (file->mount != NULL);
    } else {
        file->mount = g_file_find_enclosing_mount (file->location, NULL, NULL);
        file->is_mounted = (file->mount != NULL);
    }

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
        key_file = pf_file_utils_key_file_from_file (file->location, NULL, NULL);
        if (key_file != NULL)
        {
            /* read the icon name from the .desktop file */
            file->custom_icon_name = g_key_file_get_string (key_file,
                                                            G_KEY_FILE_DESKTOP_GROUP,
                                                            G_KEY_FILE_DESKTOP_KEY_ICON,
                                                            NULL);

            if (G_UNLIKELY (g_strcmp0 (file->custom_icon_name, NULL) == 0))
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

            /* Do not show name from desktop file as this can be used as an exploit (lp:1660742) */

            /* check if we have a target location */
            gchar *url;
            gchar *type;

            type = g_key_file_get_string (key_file, G_KEY_FILE_DESKTOP_GROUP,
                                          G_KEY_FILE_DESKTOP_KEY_TYPE, NULL);
            if (g_strcmp0 (type, "Link") == 0)
            {
                url = g_key_file_get_string (key_file, G_KEY_FILE_DESKTOP_GROUP,
                                             G_KEY_FILE_DESKTOP_KEY_URL, NULL);
                if (G_LIKELY (url != NULL))
                {
                    g_debug ("%s .desktop Link %s\n", G_STRFUNC, url);
                    file->target_location = g_file_new_for_uri (url);
                    gof_file_target_location_update (file);
                    g_free (url);
                }
            }
            _g_free0 (type);

            /* free the key file */
            g_key_file_free (key_file);
        }
    }

    if (file->custom_display_name == NULL) {
        /* Use custom_display_name to store default display name if there is no custom name */
        if (file->info && g_file_info_get_display_name (file->info) != NULL) {
            if (file->directory != NULL &&
                strcmp (g_file_get_uri_scheme (file->directory), "network") == 0 &&
                !(strcmp (g_file_get_uri (file->target_location), "smb:///") == 0)) {
                /* Show protocol after server name (lp:1184606) */
                file->custom_display_name = g_strdup_printf ("%s (%s)", g_file_info_get_display_name (file->info),
                                                                        g_utf8_strup (g_file_get_uri_scheme (file->target_location), -1));
            } else {
                file->custom_display_name = g_strdup (g_file_info_get_display_name (file->info));
            }
        }
    }

    /* sizes */
    gof_file_update_size (file);
    /* modified date */
    if (g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_TIME_MODIFIED)) {
        file->formated_modified = gof_file_get_formated_time (file, G_FILE_ATTRIBUTE_TIME_MODIFIED);
    } else {
        file->formated_modified = g_strdup (_("Inaccessible"));
    }
    /* icon */
    if (file->is_directory) {
        gof_file_get_folder_icon_from_uri_or_path (file);
    } else if (g_file_info_get_file_type(file->info) == G_FILE_TYPE_MOUNTABLE) {
        file->icon = g_themed_icon_new_with_default_fallbacks ("folder-remote");
    } else {
        const gchar *ftype = gof_file_get_ftype (file);
        if (ftype != NULL && file->icon == NULL)
            file->icon = g_content_type_get_icon (ftype);
    }

    file->utf8_collation_key = g_utf8_collate_key_for_filename  (gof_file_get_display_name (file), -1);
    /* mark the thumb flags as state none, we'll load the thumbs once the directory
     * would be loaded on a thread */
    if (gof_file_get_thumbnail_path (file) != NULL) {
        file->flags = GOF_FILE_THUMB_STATE_UNKNOWN;  /* UNKNOWN means thumbnail not known to be unobtainable */
    }

    /* formated type */
    gof_file_update_formated_type (file);

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
        if (file->owner == NULL) {
            file->owner = g_strdup_printf ("%d", file->uid);
        }
    } else if (file->owner != NULL) { /* e.g. ftp info yields owner but not uid */
        file->uid = atoi (file->owner);
    }

    if (g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_UNIX_GID)) {
        file->gid = g_file_info_get_attribute_uint32 (file->info, G_FILE_ATTRIBUTE_UNIX_GID);
        if (file->group == NULL) {
            file->group = g_strdup_printf ("%d", file->gid);
        }
    } else if (file->group != NULL) {  /* e.g. ftp info yields owner but not uid */
        file->gid = atoi (file->group);
    }

    if (g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_MOUNTABLE_CAN_UNMOUNT))
        file->can_unmount = g_file_info_get_attribute_boolean (file->info, G_FILE_ATTRIBUTE_MOUNTABLE_CAN_UNMOUNT);

    gof_file_update_trash_info (file);

    gof_file_update_emblem (file);
}

static MarlinIconInfo *
gof_file_get_special_icon (GOFFile *file, int size, int scale, GOFFileIconFlags flags)
{
    g_return_val_if_fail (size >= 1, NULL);

    if (file->custom_icon_name != NULL) {
        if (g_path_is_absolute (file->custom_icon_name))
            return marlin_icon_info_lookup_from_path (file->custom_icon_name, size, scale);
        else
            return marlin_icon_info_lookup_from_name (file->custom_icon_name, size, scale);
    }
    if (flags & GOF_FILE_ICON_FLAGS_USE_THUMBNAILS
        && file->flags == GOF_FILE_THUMB_STATE_READY) {
        const gchar *thumb_path = gof_file_get_thumbnail_path (file);

        if (thumb_path != NULL) {
            return marlin_icon_info_lookup_from_path (thumb_path, size, scale);
        }
    }

    return NULL;
}

_MarlinIconInfo *
gof_file_get_icon (GOFFile *file, int size, int scale, GOFFileIconFlags flags)
{
    MarlinIconInfo *icon = NULL;
    GIcon *gicon;

    g_return_val_if_fail (file, NULL);
    g_return_val_if_fail (size >= 1, NULL);

    icon = gof_file_get_special_icon (file, size, scale, flags);
    if (icon != NULL && !marlin_icon_info_is_fallback (icon))
        return icon;
    _g_object_unref0 (icon);

    if (flags & GOF_FILE_ICON_FLAGS_USE_THUMBNAILS
        && file->flags == GOF_FILE_THUMB_STATE_LOADING) {
        gicon = g_themed_icon_new (ICON_NAME_THUMBNAIL_LOADING);
    } else {
        gicon = _g_object_ref0 (file->icon);
    }

    if (gicon != NULL) {
        icon = marlin_icon_info_lookup (gicon, size, scale);
        if (icon != NULL && marlin_icon_info_is_fallback(icon)) {
            g_object_unref (icon);
            icon = marlin_icon_info_get_generic_icon (size, scale);
        }
        g_object_unref (gicon);
    } else {
        icon = marlin_icon_info_get_generic_icon (size, scale);
    }

    return icon;
}

GdkPixbuf *
gof_file_get_icon_pixbuf (GOFFile *file, gint size, gint scale, gboolean force_size, GOFFileIconFlags flags)
{
    MarlinIconInfo *nicon;
    GdkPixbuf *pix;
    g_return_val_if_fail (size >= 1, NULL);
    nicon = gof_file_get_icon (file, size, scale, flags);
    pix = marlin_icon_info_get_pixbuf_force_size (nicon, size * scale, force_size);

    if (nicon) {
        g_object_unref (nicon);
    }

    /* pantheon-files-core-C.vapi file indicates this function always returns non-null value */
    g_assert (pix != NULL);

    return pix;
}

static void
gof_file_update_icon_internal (GOFFile *file, gint size, gint scale)
{
    g_return_if_fail (size >= 1);
    /* destroy pixbuff if already present */
    _g_object_unref0 (file->pix);
    /* make sure we always got a non null pixbuf of the specified size */
    file->pix = gof_file_get_icon_pixbuf (file, size, scale,
                                          gof_preferences_get_force_icon_size (gof_preferences_get_default ()),
                                          GOF_FILE_ICON_FLAGS_USE_THUMBNAILS);
    file->pix_size = size;
    file->pix_scale = scale;
}

/* This function is used by the icon renderer and fm-list-model.
 * Store the pixbuf and update it only for size change.
 */
void gof_file_update_icon (GOFFile *file, gint size, gint scale)
{
    if (size <= 1)
        return;

    if (!(file->pix == NULL || file->pix_size != size || file->pix_scale != scale))
        return;

    gof_file_update_icon_internal (file, size, scale);
}

void gof_file_update_desktop_file (GOFFile *file)
{
    g_free (file->utf8_collation_key);
    file->utf8_collation_key = g_utf8_collate_key_for_filename  (gof_file_get_display_name (file), -1);
    gof_file_update_formated_type (file);
    gof_file_update_size (file);
    gof_file_icon_changed (file);
}

void gof_file_update_emblem (GOFFile *file)
{
    /* Do not try to add emblems to network and remote files (except smb) - can cause blocking io*/
    if (gof_file_is_other_uri_scheme (file) || gof_file_is_network_uri_scheme (file))
        return;

    /* Do not try to add emblems to smb shares either */
    if (gof_file_is_smb_share (file))
        return;

    /* erase previous stored emblems */
    if (file->emblems_list != NULL) {
        g_list_free (file->emblems_list);
        file->emblems_list = NULL;
    }

    if(gof_file_is_symlink(file) || (file->is_desktop && file->target_gof))
    {
        gof_file_add_emblem(file, "emblem-symbolic-link");

        /* testing up to 4 emblems */
        /*gof_file_add_emblem(file, "emblem-generic");
          gof_file_add_emblem(file, "emblem-important");
          gof_file_add_emblem(file, "emblem-favorite");*/
    }

    /* We hide lock emblems if in Recents, because files here are not real files and emblems would always shown. */
    if (!gof_file_is_writable (file) && !g_file_has_uri_scheme (file->location, "recent")) {
        if (gof_file_is_readable (file))
            gof_file_add_emblem (file, "emblem-readonly");
        else
            gof_file_add_emblem (file, "emblem-unreadable");
    }

    /* TODO update signal on real change */
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
        g_debug ("%s [code %d]\n", error->message, error->code);
        g_clear_error (&error);
    }
}

GMount *
gof_file_get_mount_at (GFile *target)
{
    GVolumeMonitor *monitor;
    GFile *root;
    GList *mounts, *l;
    GMount *found;

    monitor = g_volume_monitor_get ();
    mounts = g_volume_monitor_get_mounts (monitor);

    found = NULL;
    for (l = mounts; l != NULL; l = l->next) {
        GMount *mount = G_MOUNT (l->data);

        if (g_mount_is_shadowed (mount))
            continue;

        root = g_mount_get_root (mount);
        if (g_file_equal (target, root)) {
            found = g_object_ref (mount);
            break;
        }

        g_object_unref (root);
    }

    g_list_free_full (mounts, g_object_unref);
    g_object_unref (monitor);

    return found;
}

static GFileInfo *
gof_file_query_info (GOFFile *file)
{
    GFileInfo *info = NULL;
    GError *err = NULL;

    g_return_val_if_fail (G_IS_FILE (file->location), NULL);

    file->is_mounted = TRUE;
    file->exists = TRUE;
    file->is_connected = TRUE;

    info = g_file_query_info (file->location, "*", 0, NULL, &err);

    if (err != NULL) {
        if (err->domain == G_IO_ERROR && err->code == G_IO_ERROR_NOT_MOUNTED) {
            file->is_mounted = FALSE;
        } else if (err->code == G_IO_ERROR_NOT_FOUND
            || err->code == G_IO_ERROR_NOT_DIRECTORY) {
            file->exists = FALSE;
        } else if (err->code == G_IO_ERROR_TIMED_OUT) {
            file->is_connected = FALSE;
        }

        print_error (err); /* also frees error */
    }
    return info;
}

/* query info and update. This call is synchronous */
void
gof_file_query_update (GOFFile *file)
{
    GFileInfo *info = NULL;

    if ((info = gof_file_query_info (file)) != NULL) {
        g_clear_object (&file->info);
        file->info = info;
        gof_file_update (file);
    }
}

/* ensure we got the file info */
gboolean
gof_file_ensure_query_info (GOFFile *file)
{
    if (file->info == NULL) {
        gof_file_query_update (file);
    }

    return (file->info != NULL);
}

/* only the thumbnail has changed (been generated) */
void
gof_file_query_thumbnail_update (GOFFile *file)
{
    gchar    *base_name;
    gchar    *md5_hash;

    /* Silently ignore invalid requests */
    if (file->pix_size <= 1 || file->pix_scale <= 0)
        return;

    if (gof_file_get_thumbnail_path (file) == NULL) {
        /* get the thumbnail path from md5 filename */
        md5_hash = g_compute_checksum_for_string (G_CHECKSUM_MD5, file->uri, -1);
        base_name = g_strdup_printf ("%s.png", md5_hash);

        /* Use $XDG_CACHE_HOME specified thumbnail directory instead of hard coding */
        if (file->pix_size * file->pix_scale <= 128) {
            file->thumbnail_path = g_build_filename (g_get_user_cache_dir (), "thumbnails",
                                                     "normal", base_name, NULL);
        } else {
            file->thumbnail_path = g_build_filename (g_get_user_cache_dir (), "thumbnails",
                                                     "large", base_name, NULL);
        }
        g_free (base_name);
        g_free (md5_hash);
    }

    gof_file_update_icon_internal (file, file->pix_size, file->pix_scale);
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
}

void gof_file_remove_from_caches (GOFFile *file)
{
    /* remove from file_cache */
    if (file_cache != NULL && g_hash_table_remove (file_cache, file->location))
        g_debug ("remove from file_cache %s", file->uri);

    /* remove from directory_cache */
    if (file->directory && G_OBJECT (file->directory)->ref_count > 0) {
        gof_directory_async_remove_file_from_cache (file);
    }

    file->is_gone = TRUE;
}

static void gof_file_init (GOFFile *file) {
    file->info = NULL;
    file->location = NULL;
    file->target_location = NULL;
    file->icon = NULL;
    file->pix = NULL;
    file->color = 0;
    file->width = 0;
    file->height = 0;

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
    file->is_connected = TRUE;

    file->flags = GOF_FILE_THUMB_STATE_UNKNOWN;
    file->pix_size = -1;
    file->pix_scale = -1;

    file->target_gof = NULL;
    file->thumbnail_path = NULL;

    file->sort_column_id = FM_LIST_MODEL_FILENAME;
    file->sort_order = GTK_SORT_ASCENDING;

    file->is_expanded = FALSE;
}

static void gof_file_finalize (GObject* obj) {
    GOFFile *file;

    file = GOF_FILE (obj);

    if (!(G_IS_FILE (file->location))) {
        g_warning ("Invalid file location on finalize for %s", file->basename);
    } else {
        g_object_unref (file->location);
    }

    g_clear_object (&file->info);
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

    _g_object_unref0 (file->target_location);
    _g_object_unref0 (file->mount);
    /* TODO remove the target_gof */
    _g_free0 (file->thumbnail_path);

    if (file->target_gof != NULL) {
        _g_object_unref0 (file->target_gof);
    }

#ifndef NDEBUG
    g_warn_if_fail (file->target_gof == NULL);
#endif

    _g_free0 (file->owner);
    _g_free0 (file->group);

    G_OBJECT_CLASS (gof_file_parent_class)->finalize (obj);
}

static void gof_file_class_init (GOFFileClass * klass) {

    /* determine the effective user id of the process */
    effective_user_id = geteuid ();

    gof_file_parent_class = g_type_class_peek_parent (klass);

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
}


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
    if (gof_file_is_folder (file1) && !gof_file_is_folder (file2))
        return -1;
    if (gof_file_is_folder (file2) && !gof_file_is_folder (file1))
        return 1;

    return compare_files_by_time (file1, file2);
}

static int
compare_by_type (GOFFile *file1, GOFFile *file2)
{
    gchar *key1, *key2;
    int compare;

    /* Directories go first. Then, if mime types are identical,
     * don't bother getting strings (for speed). This assumes
     * that the string is dependent entirely on the mime type,
     * which is true now but might not be later.
     */
    if (gof_file_is_folder (file1) && gof_file_is_folder (file2))
        return 0;
    if (gof_file_is_folder (file1))
        return -1;
    if (gof_file_is_folder (file2))
        return +1;

    key1 = g_utf8_collate_key (file1->formated_type, -1);
    key2 = g_utf8_collate_key (file2->formated_type, -1);
    compare = g_strcmp0 (key1, key2);
    g_free (key1);
    g_free (key2);

    return compare;
}

static int
compare_by_display_name (GOFFile *file1, GOFFile *file2)
{
    g_return_val_if_fail (GOF_IS_FILE (file1), -1);
    g_return_val_if_fail (GOF_IS_FILE (file2), -1);
    const char *name_1, *name_2;
    gboolean sort_last_1, sort_last_2;
    int compare;

    name_1 = gof_file_get_display_name (file1);
    name_2 = gof_file_get_display_name (file2);

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
    if (gof_file_is_folder (file1) && !gof_file_is_folder (file2))
        return -1;
    if (gof_file_is_folder (file2) && !gof_file_is_folder (file1))
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
        if (gof_file_is_folder (file1) && !gof_file_is_folder (file2))
            return -1;
        if (gof_file_is_folder (file2) && !gof_file_is_folder (file1))
            return 1;
    }

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
            if (result == 0) {
                result = compare_by_display_name (file1, file2);
            }
            break;
        case FM_LIST_MODEL_TYPE:
            result = compare_by_type (file1, file2);
            if (result == 0) {
                result = compare_by_display_name (file1, file2);
            }
            break;
        case FM_LIST_MODEL_MODIFIED:
            result = compare_by_time (file1, file2);
            if (result == 0) {
                result = compare_by_display_name (file1, file2);
            }
            break;
        }

        if (reversed) {
            result = -result;
        }
    }

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
            gfile_list = g_list_prepend (gfile_list, g_object_ref (file->location));
        }
    }

    return (gfile_list);
}



/**
 * gof_file_is_writable: impoted from thunar
 * @file : a #GOFFile instance.
 *
 * Determines whether the owner of the current process is allowed
 * to write the @file.
 *
 * Return value: %TRUE if @file can be written.
**/
gboolean
gof_file_is_writable (GOFFile *file)
{
    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);
    if (file->target_gof && !g_file_equal (file->location, file->target_gof->location)) {
        return gof_file_is_writable (file->target_gof);
    } else if (file->info != NULL && g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_ACCESS_CAN_WRITE)) {
        return g_file_info_get_attribute_boolean (file->info, G_FILE_ATTRIBUTE_ACCESS_CAN_WRITE);
    } else if (file->has_permissions) {
        return ((file->permissions & S_IWOTH) > 0) ||
               ((file->permissions & S_IWUSR) > 0) && (file->uid < 0 || file->uid == geteuid ()) ||
               ((file->permissions & S_IWGRP) > 0) && pf_user_utils_user_in_group (file->group);
    } else {
        return TRUE;  /* We will just have to assume we can write to the file */
    }

    gboolean can_write = g_file_info_get_attribute_boolean (file->info, G_FILE_ATTRIBUTE_ACCESS_CAN_WRITE);

    if (file->directory && g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_ACCESS_CAN_EXECUTE)) {
        return can_write && g_file_info_get_attribute_boolean (file->info, G_FILE_ATTRIBUTE_ACCESS_CAN_EXECUTE);
    }

    return can_write;
}

gboolean
gof_file_is_readable (GOFFile *file)
{
    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);

    if (file->target_gof && !g_file_equal (file->location, file->target_gof->location)) {
        return gof_file_is_readable (file->target_gof);
    } else if (file->info != NULL && g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_ACCESS_CAN_READ)) {
        return g_file_info_get_attribute_boolean (file->info, G_FILE_ATTRIBUTE_ACCESS_CAN_READ);
    } else if (file->has_permissions) {
        return (file->permissions & S_IROTH) ||
               (file->permissions & S_IRUSR) && (file->uid < 0 || file->uid == geteuid ()) ||
               (file->permissions & S_IRGRP) && pf_user_utils_user_in_group (file->group);
    } else {
        return TRUE;  /* We will just have to assume we can read the file */
    }
}

gboolean
gof_file_is_trashed (GOFFile *file)
{
    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);
    return pf_file_utils_location_is_in_trash (gof_file_get_target_location (file));
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

    return pf_file_utils_get_formatted_time_attribute_from_info (file->info, attr);
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

    content_type = gof_file_get_ftype (file);
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

    if (file->target_gof)
        return gof_file_is_executable (file->target_gof);
    if (file->info == NULL) {
        return FALSE;
    }

    if (g_file_info_get_attribute_boolean (file->info, G_FILE_ATTRIBUTE_ACCESS_CAN_EXECUTE))
    {
        /* get the content type of the file */
        content_type = gof_file_get_ftype (file);

        if (G_LIKELY (content_type != NULL))
        {
            /* check if the content type is save to execute, we don't use
             * g_content_type_can_be_executable() for unix because it also returns
             * true for "text/plain" and we don't want that */
            if (g_content_type_is_a (content_type, "application/x-executable")) {
                can_execute = TRUE;
            }
        }
    }

    return can_execute;
}

/**
 * gof_file_set_thumb_state: imported from thunar
 * @file        : a #GOFFile.
 * @thumb_state : the new #GOFFileThumbState.
 *
 * Sets the #GOFFileThumbState for @file to @thumb_state.
 * This will cause a "icon-changed" signal to be emitted from
 * #GOFMonitor.
**/
void
gof_file_set_thumb_state (GOFFile *file, GOFFileThumbState state)
{
    g_return_if_fail (GOF_IS_FILE (file));

    /* set the new thumbnail state */
    file->flags = (file->flags & ~GOF_FILE_THUMB_STATE_MASK) | (state);
    g_debug ("%s %s %u", G_STRFUNC, file->uri, file->flags);
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

void
gof_file_set_expanded (GOFFile *file, gboolean expanded) {
    g_return_if_fail (file != NULL && file->is_directory);
    file->is_expanded = expanded;
}

GOFFile*
gof_file_get (GFile *location)
{
    GFile *parent;
    GOFFile *file = NULL;
    GOFDirectoryAsync *dir = NULL;

    g_return_val_if_fail (location != NULL && G_IS_FILE (location), NULL);

    if ((parent = g_file_get_parent (location)) != NULL) {
        dir = gof_directory_async_cache_lookup (parent);
        if (dir != NULL) {
            file = gof_directory_async_file_hash_lookup_location (dir, location);
            g_object_unref (dir);
        }
    }

    if (file == NULL)
        file = gof_file_cache_lookup (location);

    if (file == NULL) {
        file = gof_file_new (location, parent);
        /* TODO Move file_cache to GOF.Directory.Async */
        G_LOCK (file_cache_mutex);
        if (file_cache != NULL)
            g_hash_table_insert (file_cache, g_object_ref (location), g_object_ref (file));
        G_UNLOCK (file_cache_mutex);
    }

    if (parent)
        g_object_unref (parent);

    return (file);
}

GOFFile* gof_file_get_by_uri (const char *uri)
{
    GFile *location;
    GOFFile *file;

    /* Check first that uri is valid */
    gchar *scheme;
    scheme = g_uri_parse_scheme (uri);
    if (scheme == NULL) {
        return gof_file_get_by_commandline_arg (uri);
    } else {
        g_free (scheme);

        location = g_file_new_for_uri (uri);
        if (location == NULL) {
            return NULL;
        }
    }

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
    gboolean     must_support_uris = FALSE;
    gchar       *path;

    g_return_val_if_fail (GOF_IS_FILE (file), NULL);

    content_type = gof_file_get_ftype (file);
    if (content_type != NULL)
    {
        path = g_file_get_path (file->location);
        must_support_uris = (path == NULL);
        _g_free0 (path);

        return g_app_info_get_default_for_type (content_type, must_support_uris);
    }

    if (file->target_location != NULL)
        return g_file_query_default_handler (file->target_location, NULL, NULL);

    return g_file_query_default_handler (file->location, NULL, NULL);
}

gboolean
gof_file_execute (GOFFile *file, GdkScreen *screen, GList *file_list, GError **error)
{
    GError      *err = NULL;
    GAppInfo    *app_info = NULL;


    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);
    g_return_val_if_fail (GDK_IS_SCREEN (screen), FALSE);
    g_return_val_if_fail (error == NULL || *error == NULL, FALSE);

    /* only execute locale executable files */
    if (!g_file_is_native (file->location))
        return FALSE;

    if (gof_file_is_desktop_file (file))
    {
        GKeyFile         *key_file;

        key_file = pf_file_utils_key_file_from_file (file->location, NULL, &err);

        if (key_file == NULL)
        {
            g_set_error (error, G_FILE_ERROR, G_FILE_ERROR_INVAL,
                         _("Failed to parse the desktop file: %s"), err->message);
            g_error_free (err);
            return FALSE;
        }

        app_info = G_APP_INFO (g_desktop_app_info_new_from_keyfile (key_file));
        if (app_info == NULL)
        {
            g_set_error (error, G_FILE_ERROR, G_FILE_ERROR_INVAL, _("Failed to parse the desktop file"));
            g_key_file_free (key_file);
            return FALSE;
        }

        g_key_file_free (key_file);
    }
    else
    {
        gchar  *location = g_file_get_path (file->location);

        app_info = g_app_info_create_from_commandline (location, NULL, 0, &error);
        if (app_info == NULL)
        {
            g_set_error (error, G_FILE_ERROR, G_FILE_ERROR_INVAL, _("Failed to create command from file: %s"), err->message);
            g_error_free (err);
            g_free (location);
            return FALSE;
        }

        g_free (location);
    }

    if (!g_app_info_launch (app_info, file_list, NULL, &err))
    {
        g_set_error (error, G_FILE_ERROR, G_FILE_ERROR_INVAL, _("Unable to Launch Desktop File: %s"), err->message);
        g_error_free (err);
        return FALSE;
    }

    g_object_unref (app_info);
    return TRUE;
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


static void
gof_file_update_existing (GOFFile *file, GFile *new_location)
{
    GOFDirectoryAsync *dir = NULL;
    if (file->directory != NULL) {
        dir = gof_directory_async_cache_lookup (file->directory);
    }

    gof_file_remove_from_caches (file);
    file->is_gone = FALSE;

    g_object_unref (file->location);
    file->location = g_object_ref (new_location);

    if (dir != NULL)
        gof_directory_async_file_hash_add_file (dir, file);

    _g_free0 (file->uri);
    file->uri = g_file_get_uri (new_location);
    _g_free0 (file->basename);
    file->basename = g_file_get_basename (file->location);
    file->pix_size = -1;
    file->pix_scale = -1;
    _g_free0 (file->thumbnail_path);
    file->flags = 0;

    gof_file_query_update (file);

    g_object_unref (dir);
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
        result = pf_user_utils_get_all_group_names ();
    } else if (user_id == (uid_t) file->uid) {
        /* Owner is allowed to set group to any that owner is member of. */
        result = pf_user_utils_get_group_names_for_user ();
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

gint
gof_file_compare_by_display_name (gconstpointer a, gconstpointer b)
{
    return compare_by_display_name (GOF_FILE (a), GOF_FILE (b));
}

GFile *
gof_file_get_target_location (GOFFile *file)
{
    /* Do not interpret desktop files (lp:1660742) */
    if (file->target_location != NULL)
        return file->target_location;

    return file->location;
}

const gchar *
gof_file_get_display_name (GOFFile *file)
{
    return file->custom_display_name ? file->custom_display_name : file->basename;
}

gboolean
gof_file_is_folder (GOFFile *file)
{
    if (file == NULL) {
        g_warning ("gof_file_is_folder () called with null file - ignoring");
        return FALSE;
    }

    /* TODO check this works for non-local files and other uri schemes*/
    if ((file->is_directory && !gof_file_is_root_network_folder (file)))
        return TRUE;

    if (gof_file_is_smb_share (file))
        return TRUE;

    if (file->file_type == G_FILE_TYPE_MOUNTABLE &&
        file->info != NULL &&
        g_file_info_get_attribute_boolean (file->info, G_FILE_ATTRIBUTE_MOUNTABLE_CAN_MOUNT))

        return TRUE;

    if (file->target_gof &&
        file->target_gof->is_directory &&
        gof_file_is_network_uri_scheme (file->target_gof)) {
            return TRUE;
    }

    return FALSE;
}

const gchar *
gof_file_get_ftype (GOFFile *file)
{
    if (file->info == NULL || gof_file_is_location_uri_default (file))
        return NULL;

    if (file->is_directory) {
        return g_strdup ("inode/directory");
    }

    const char *ftype = NULL;
    if (g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE))
        return g_file_info_get_attribute_string (file->info, G_FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE);

    if (g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE))
        ftype = g_file_info_get_attribute_string (file->info, G_FILE_ATTRIBUTE_STANDARD_FAST_CONTENT_TYPE);

    if (!g_strcmp0 (ftype, "application/octet-stream") && file->tagstype) /* If octet-stream then check tagtype */
        return file->tagstype;

    return ftype;
}

/**
 * transfer: none
 **/
const gchar *
gof_file_get_thumbnail_path (GOFFile *file)
{
    if (file->thumbnail_path != NULL)
        return file->thumbnail_path;
    if (file->info != NULL && g_file_info_has_attribute (file->info, G_FILE_ATTRIBUTE_THUMBNAIL_PATH))
        return g_file_info_get_attribute_byte_string (file->info, G_FILE_ATTRIBUTE_THUMBNAIL_PATH);

    return NULL;
}

char*
gof_file_get_display_target_uri (GOFFile *file)
{
    /* This returns a string that requires freeing */
    gchar* uri;

    uri = g_file_info_get_attribute_as_string (file->info, G_FILE_ATTRIBUTE_STANDARD_TARGET_URI);

    if (uri == NULL) {
        uri = strdup (file->uri);
    }

    return uri;
}

gboolean
gof_file_can_unmount (GOFFile *file)
{
    g_return_val_if_fail (GOF_IS_FILE (file), FALSE);

    return file->can_unmount || (file->mount != NULL && g_mount_can_unmount (file->mount));
}
