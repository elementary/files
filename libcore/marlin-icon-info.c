/* nautilus-icon-info.c
 * Copyright (C) 2007  Red Hat, Inc.,  Alexander Larsson <alexl@redhat.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation, Inc.,; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
 * Boston, MA 02110-1335 USA.
 */

//#include <config.h>
#include <string.h>
#include "marlin-icon-info.h"
#include <gtk/gtk.h>
#include <gio/gio.h>

struct _MarlinIconInfo
{
    GObject         parent;

    guint64         last_use_time;
    gboolean        is_first_ref;
    GdkPixbuf       *pixbuf;

    /*gboolean        got_embedded_rect;
      GdkRectangle    embedded_rect;
      gint            n_attach_points;
      GdkPoint        *attach_points;*/
    char            *display_name;
    char            *icon_name;
};

struct _MarlinIconInfoClass
{
    GObjectClass parent_class;
};

static void schedule_reap_cache (void);

G_DEFINE_TYPE (MarlinIconInfo, marlin_icon_info, G_TYPE_OBJECT);

/** This is required for testing themed icon functions under ctest when there is no default screen and
  * we have to set the icon theme manually.  We assume that any system being used for testing will have
  * the "hicolor" theme.
  */
static GtkIconTheme *
marlin_icon_info_get_gtk_icon_theme () {
    GtkIconTheme *theme;
    if (gdk_screen_get_default () == NULL) {
        theme = gtk_icon_theme_new ();
        gtk_icon_theme_set_custom_theme (theme, "hicolor");
    } else {
        theme = gtk_icon_theme_get_default ();
    }

    return theme;
}

static void
marlin_icon_info_init (MarlinIconInfo *icon)
{
    icon->last_use_time = g_get_monotonic_time ();
    icon->pixbuf = NULL;
    icon->is_first_ref = TRUE;
}

gboolean
marlin_icon_info_is_fallback (MarlinIconInfo  *icon)
{
    return icon != NULL ? icon->pixbuf == NULL : FALSE;
}

static void
pixbuf_toggle_notify (gpointer info, GObject *object, gboolean is_last_ref)
{
    MarlinIconInfo *icon;

    g_return_if_fail (object != NULL);
    g_return_if_fail (info != NULL && MARLIN_IS_ICON_INFO (info));

    icon = (MarlinIconInfo *) info;

    /*g_warning ("%s %s %s ref_count %u", G_STRFUNC, icon->display_name,
      icon->icon_name, G_OBJECT (icon->pixbuf)->ref_count);*/
    if (is_last_ref) {
        /*g_object_remove_toggle_ref (object,
          pixbuf_toggle_notify,
          info);*/
        icon->last_use_time = g_get_monotonic_time ();
        schedule_reap_cache ();
    }
}

static void
marlin_icon_info_finalize (GObject *object)
{
    MarlinIconInfo *icon = MARLIN_ICON_INFO (object);

    if (icon->pixbuf != NULL) {
        g_object_remove_toggle_ref (G_OBJECT (icon->pixbuf),
                                    pixbuf_toggle_notify,
                                    icon);
    }

    g_free (icon->display_name);
    g_free (icon->icon_name);

    G_OBJECT_CLASS (marlin_icon_info_parent_class)->finalize (object);
}

static void
marlin_icon_info_class_init (MarlinIconInfoClass *icon_info_class)
{
    GObjectClass *gobject_class;

    gobject_class = (GObjectClass *) icon_info_class;

    gobject_class->finalize = marlin_icon_info_finalize;

}

MarlinIconInfo *
marlin_icon_info_new_for_pixbuf (GdkPixbuf *pixbuf)
{
    MarlinIconInfo *icon;

    icon = g_object_new (MARLIN_TYPE_ICON_INFO, NULL);
    icon->pixbuf = pixbuf;
    if (pixbuf != NULL) {
        g_object_add_toggle_ref (G_OBJECT (pixbuf),
                                 pixbuf_toggle_notify,
                                 icon);
    }

    return icon;
}

static MarlinIconInfo *
marlin_icon_info_new_for_icon_info (GtkIconInfo *icon_info)
{
    MarlinIconInfo *icon;
    /*GdkPoint *points;
      gint n_points;*/
    const char *filename;
    char *basename, *p;

    icon = g_object_new (MARLIN_TYPE_ICON_INFO, NULL);

    icon->pixbuf = gtk_icon_info_load_icon (icon_info, NULL);
    if (icon->pixbuf != NULL)
        g_object_add_toggle_ref (G_OBJECT (icon->pixbuf),
                                 pixbuf_toggle_notify,
                                 icon);

    /*icon->got_embedded_rect = gtk_icon_info_get_embedded_rect (icon_info,
      &icon->embedded_rect);

      if (gtk_icon_info_get_attach_points (icon_info, &points, &n_points)) {
      icon->n_attach_points = n_points;
      icon->attach_points = points;
      }*/

    icon->display_name = g_strdup (gtk_icon_info_get_display_name (icon_info));

    filename = gtk_icon_info_get_filename (icon_info);
    if (filename != NULL) {
        basename = g_path_get_basename (filename);
        p = strrchr (basename, '.');
        if (p) {
            *p = 0;
        }
        icon->icon_name = basename;
    }

    return icon;
}


typedef struct  {
    GIcon *icon;
    int size;
} LoadableIconKey;

typedef struct {
    char *filename;
    int size;
} ThemedIconKey;

static GHashTable *loadable_icon_cache = NULL;
static GHashTable *themed_icon_cache = NULL;
static guint reap_cache_timeout = 0;

#define MICROSEC_PER_SEC ((guint64)1000000L)

static guint64 time_now;

static gboolean
reap_old_icon (LoadableIconKey *key, gpointer value, gpointer user_info)
{
    MarlinIconInfo *icon;
    gboolean *reapable_icons_left = user_info;

    g_return_val_if_fail (value != NULL && MARLIN_IS_ICON_INFO (value), TRUE);

    icon = (MarlinIconInfo *) value;
    //g_return_val_if_fail (icon->pixbuf != NULL && GDK_IS_PIXBUF (icon->pixbuf), TRUE);

    /*char *str_icon = g_icon_to_string (key->icon);
    g_message ("%s %s %d %u\n", G_STRFUNC, str_icon, key->size, G_OBJECT (icon->pixbuf)->ref_count);
    g_free (str_icon);*/
    /* sole owner */
    if (icon->pixbuf && G_IS_OBJECT (icon->pixbuf) && G_OBJECT (icon->pixbuf)->ref_count == 1) {
        if (time_now - icon->last_use_time > 30 * MICROSEC_PER_SEC) {
            /* This went unused 30 secs ago. reap */
            return TRUE;
        } else {
            /* We can reap this soon */
            *reapable_icons_left = TRUE;
        }
    }

    return FALSE;
}

static gboolean
reap_cache (gpointer data)
{
    gboolean reapable_icons_left;

    reapable_icons_left = TRUE;

    time_now = g_get_monotonic_time ();

    if (loadable_icon_cache) {
        g_hash_table_foreach_remove (loadable_icon_cache,
                                     (GHRFunc) reap_old_icon,
                                     &reapable_icons_left);
    }

    if (themed_icon_cache) {
        g_hash_table_foreach_remove (themed_icon_cache,
                                     (GHRFunc) reap_old_icon,
                                     &reapable_icons_left);
    }

    if (reapable_icons_left) {
        return TRUE;
    } else {
        reap_cache_timeout = 0;
        return FALSE;
    }
}

static void
schedule_reap_cache (void)
{
    if (reap_cache_timeout == 0) {
        reap_cache_timeout = g_timeout_add_seconds_full (0, 5,
                                                         reap_cache,
                                                         NULL, NULL);
    }
}

void
marlin_icon_info_clear_caches (void)
{
    if (loadable_icon_cache) {
        g_hash_table_remove_all (loadable_icon_cache);
    }

    if (themed_icon_cache) {
        g_hash_table_remove_all (themed_icon_cache);
    }
}

static guint
loadable_icon_key_hash (LoadableIconKey *key)
{
    return g_icon_hash (key->icon) ^ key->size;
}

static gboolean
loadable_icon_key_equal (const LoadableIconKey *a,
                         const LoadableIconKey *b)
{
    return a->size == b->size &&
        g_icon_equal (a->icon, b->icon);
}

static LoadableIconKey *
loadable_icon_key_new (GIcon *icon, int size)
{
    LoadableIconKey *key;

    key = g_slice_new (LoadableIconKey);
    key->icon = g_object_ref (icon);
    key->size = size;

    return key;
}

static void
loadable_icon_key_free (LoadableIconKey *key)
{
    g_object_unref (key->icon);
    g_slice_free (LoadableIconKey, key);
}

static guint
themed_icon_key_hash (ThemedIconKey *key)
{
    return g_str_hash (key->filename) ^ key->size;
}

static gboolean
themed_icon_key_equal (const ThemedIconKey *a,
                       const ThemedIconKey *b)
{
    return a->size == b->size &&
        g_str_equal (a->filename, b->filename);
}

static ThemedIconKey *
themed_icon_key_new (const char *filename, int size)
{
    ThemedIconKey *key;

    key = g_slice_new (ThemedIconKey);
    key->filename = g_strdup (filename);
    key->size = size;

    return key;
}

static void
themed_icon_key_free (ThemedIconKey *key)
{
    g_free (key->filename);
    g_slice_free (ThemedIconKey, key);
}

static void destroy_cache_entry (MarlinIconInfo *icon_info)
{
    g_return_if_fail (icon_info != NULL);
    g_clear_object (&icon_info);
}

#if 0
GdkPixbuf *
test_get_pixbuf_at_size_from_raw_pixbuf (GdkPixbuf *pixbuf, gsize forced_size);

//static MarlinIconInfo *
static GdkPixbuf *
marlin_icon_info_get_and_cache_raw_pixbuf (GIcon *icon)
{
    MarlinIconInfo *icon_info = NULL;
    GdkPixbuf *pixbuf;
    char *str_icon = g_icon_to_string (icon);

    pixbuf = gdk_pixbuf_new_from_file (str_icon, NULL);

    if (pixbuf != NULL) {
        /* cache the raw pixbuf */
        LoadableIconKey *key = loadable_icon_key_new (icon, 0);
        icon_info = marlin_icon_info_new_for_pixbuf (pixbuf);
        /*icon_info = g_object_new (MARLIN_TYPE_ICON_INFO, NULL);
        icon_info->pixbuf = pixbuf;*/
        g_hash_table_insert (loadable_icon_cache, key, icon_info);
    }
    g_free (str_icon);

    //return icon_info;
    return pixbuf;
}
#endif

MarlinIconInfo *
marlin_icon_info_lookup (GIcon *icon, int size)
{
    MarlinIconInfo *icon_info;
    GdkPixbuf *pixbuf = NULL;
    //GdkPixbuf *scaled_pixbuf = NULL;

    g_return_val_if_fail (icon && G_IS_ICON (icon), NULL);
    size = MAX (1, size);

    if (G_IS_LOADABLE_ICON (icon)) {
        LoadableIconKey lookup_key;
        LoadableIconKey *key;

        if (loadable_icon_cache == NULL) {
            loadable_icon_cache =
                g_hash_table_new_full ((GHashFunc)loadable_icon_key_hash,
                                       (GEqualFunc)loadable_icon_key_equal,
                                       (GDestroyNotify) loadable_icon_key_free,
                                       //(GDestroyNotify) g_object_unref);
                                       (GDestroyNotify) destroy_cache_entry);
        }

        lookup_key.icon = icon;
        lookup_key.size = size;
        icon_info = g_hash_table_lookup (loadable_icon_cache, &lookup_key);
        if (icon_info != NULL) {
            //g_message ("CACHED %s stream %s\n", G_STRFUNC, g_icon_to_string (icon));
            return g_object_ref (icon_info);
        }
#if 0

        /* get the raw pixbuf */
        lookup_key.size = 0;
        icon_info = g_hash_table_lookup (loadable_icon_cache, &lookup_key);

        if (icon_info == NULL) {
            //icon_info = marlin_icon_info_get_and_cache_raw_pixbuf (icon);
            pixbuf = marlin_icon_info_get_and_cache_raw_pixbuf (icon);
        } else {
            //pixbuf = marlin_icon_info_get_pixbuf_nodefault (icon_info);
            pixbuf = g_object_ref (icon_info->pixbuf);
            icon_info->last_use_time = g_get_monotonic_time ();
        }

        if (pixbuf == NULL)
            return marlin_icon_info_new_for_pixbuf (NULL);

        scaled_pixbuf = test_get_pixbuf_at_size_from_raw_pixbuf (pixbuf, size);
        icon_info = marlin_icon_info_new_for_pixbuf (scaled_pixbuf);
        /* destroy the rawpixbuf it has 30sec to be reused */
        g_object_unref (pixbuf);

        if (scaled_pixbuf != NULL) {
            key = loadable_icon_key_new (icon, size);
            g_hash_table_insert (loadable_icon_cache, key, g_object_ref (icon_info));
        }
#endif
//#if 0
        char *str_icon = g_icon_to_string (icon);
        gint width, height;

        gdk_pixbuf_get_file_info (str_icon, &width, &height);
        if ((width >= 1 || width == -1) && (height >= 1 || height == -1))
            pixbuf = gdk_pixbuf_new_from_file_at_size (str_icon, MIN (width, size), MIN (height, size), NULL);

        /*icon_info = g_object_new (MARLIN_TYPE_ICON_INFO, NULL);
        icon_info->pixbuf = pixbuf;*/
        if (pixbuf != NULL) {
            icon_info = marlin_icon_info_new_for_pixbuf (pixbuf);
            key = loadable_icon_key_new (icon, size);
            g_hash_table_insert (loadable_icon_cache, key, g_object_ref (icon_info));
            g_free (str_icon);
        }
//#endif

        return icon_info;
    } else if (G_IS_THEMED_ICON (icon)) {
        const char * const *names;
        ThemedIconKey lookup_key;
        ThemedIconKey *key;
        GtkIconTheme *icon_theme;
        GtkIconInfo *gtkicon_info;
        const char *filename;

        if (themed_icon_cache == NULL) {
            themed_icon_cache =
                g_hash_table_new_full ((GHashFunc)themed_icon_key_hash,
                                       (GEqualFunc)themed_icon_key_equal,
                                       (GDestroyNotify) themed_icon_key_free,
                                       (GDestroyNotify) g_object_unref);
        }

        names = g_themed_icon_get_names (G_THEMED_ICON (icon));

        icon_theme = marlin_icon_info_get_gtk_icon_theme ();
        gtkicon_info = gtk_icon_theme_choose_icon (icon_theme, (const char **)names, size, 0);

        if (gtkicon_info == NULL) {
            return marlin_icon_info_new_for_pixbuf (NULL);
        }

        filename = gtk_icon_info_get_filename (gtkicon_info);
        if (filename == NULL) {
            gtk_icon_info_free (gtkicon_info);
            return marlin_icon_info_new_for_pixbuf (NULL);
        }

        lookup_key.filename = (char *)filename;
        lookup_key.size = size;

        icon_info = g_hash_table_lookup (themed_icon_cache, &lookup_key);
        if (icon_info) {
            //g_message ("CACHED %s themed icon %s\n", G_STRFUNC, filename);
            gtk_icon_info_free (gtkicon_info);
            return g_object_ref (icon_info);
        }

        icon_info = marlin_icon_info_new_for_icon_info (gtkicon_info);
        //g_critical ("%s themed icon %s size %d\n", G_STRFUNC, gtk_icon_info_get_filename (gtkicon_info), size);

        key = themed_icon_key_new (filename, size);
        g_hash_table_insert (themed_icon_cache, key, icon_info);

        gtk_icon_info_free (gtkicon_info);

        return g_object_ref (icon_info);
    } else {
        GtkIconInfo *gtk_icon_info;

        //g_message ("%s ELSE ... %s", G_STRFUNC, g_icon_to_string (icon));
        gtk_icon_info = gtk_icon_theme_lookup_by_gicon (marlin_icon_info_get_gtk_icon_theme (),
                                                        icon,
                                                        size,
                                                        GTK_ICON_LOOKUP_GENERIC_FALLBACK);

        GError *error;
        error = NULL;

        if (gtk_icon_info != NULL) {
            pixbuf = gtk_icon_info_load_icon (gtk_icon_info, &error);
            gtk_icon_info_free (gtk_icon_info);
        }

        if (error == NULL)
            icon_info = marlin_icon_info_new_for_pixbuf (pixbuf);
        else
            return marlin_icon_info_new_for_pixbuf (NULL);

        /*if (pixbuf != NULL)
          g_object_unref (pixbuf);*/
        /* FIXME remove the extra ref and cache the icon_info */
        g_object_ref (icon_info);

        return icon_info;
    }
}

MarlinIconInfo *
marlin_icon_info_lookup_from_name (const char *name, int size)
{
    GIcon *icon;
    MarlinIconInfo *info;
    g_return_val_if_fail (size >= 1, NULL);
    icon = g_themed_icon_new (name);
    info = marlin_icon_info_lookup (icon, size);
    g_object_unref (icon);

    return info;
}

MarlinIconInfo *
marlin_icon_info_lookup_from_path (const char *path, int size)
{
    GFile *icon_file;
    GIcon *icon;
    MarlinIconInfo *info;

    g_return_val_if_fail (size >= 1, NULL);
    icon_file = g_file_new_for_path (path);
    icon = g_file_icon_new (icon_file);
    info = marlin_icon_info_lookup (icon, size);
    g_object_unref (icon);
    g_object_unref (icon_file);

    return info;
}

MarlinIconInfo *
marlin_icon_info_get_generic_icon (int size)
{
    MarlinIconInfo *icon;

    GIcon *generic_icon = g_themed_icon_new ("text-x-generic");
    icon = marlin_icon_info_lookup (generic_icon, size);
    g_object_unref (generic_icon);

    return icon;
}

GdkPixbuf *
marlin_icon_info_get_pixbuf_nodefault (MarlinIconInfo  *icon)
{
    GdkPixbuf *res = NULL;
    g_return_val_if_fail (icon != NULL && MARLIN_IS_ICON_INFO (icon), NULL);

    if (icon->pixbuf) {
        /* don't ref the first toggled reference */
        if (!icon->is_first_ref)
            g_object_ref (icon->pixbuf);
        icon->is_first_ref = FALSE;
        res = icon->pixbuf;
    }
    /*if (icon->pixbuf)
      g_warning ("%s ref count %u", G_STRFUNC, G_OBJECT (icon->pixbuf)->ref_count);*/

    return res;
}

#if 0
GdkPixbuf *
marlin_icon_info_get_pixbuf (MarlinIconInfo *icon)
{
    GdkPixbuf *res;

    res = marlin_icon_info_get_pixbuf_nodefault (icon);
    if (res == NULL) {
        res = gdk_pixbuf_new_from_data (marlin_default_file_icon,
                                        GDK_COLORSPACE_RGB,
                                        TRUE,
                                        8,
                                        marlin_default_file_icon_width,
                                        marlin_default_file_icon_height,
                                        marlin_default_file_icon_width * 4, /* stride */
                                        NULL, /* don't destroy info */
                                        NULL);
    }
    return res;
}

GdkPixbuf *
marlin_icon_info_get_pixbuf_nodefault_at_size (MarlinIconInfo  *icon,
                                               gsize              forced_size)
{
    GdkPixbuf *pixbuf, *scaled_pixbuf;
    int w, h, s;
    double scale;

    pixbuf = marlin_icon_info_get_pixbuf_nodefault (icon);

    if (pixbuf == NULL)
        return NULL;

    w = gdk_pixbuf_get_width (pixbuf);
    h = gdk_pixbuf_get_height (pixbuf);
    s = MAX (w, h);
    if (s == forced_size) {
        return pixbuf;
    }

    scale = (double)forced_size / s;
    scaled_pixbuf = gdk_pixbuf_scale_simple (pixbuf,
                                             w * scale, h * scale,
                                             GDK_INTERP_BILINEAR);
    g_object_unref (pixbuf);
    return scaled_pixbuf;
}
#endif

#if 0
GdkPixbuf *
test_get_pixbuf_at_size_from_raw_pixbuf (GdkPixbuf *pixbuf, gsize forced_size)
{
    GdkPixbuf *scaled_pixbuf = NULL;
    int w, h, s;
    double scale;

    g_return_val_if_fail (pixbuf != NULL && GDK_IS_PIXBUF (pixbuf), NULL);

    w = gdk_pixbuf_get_width (pixbuf);
    h = gdk_pixbuf_get_height (pixbuf);
    s = MAX (w, h);
    if (s == forced_size) {
        /* we have to return an owned object */
        return gdk_pixbuf_copy (pixbuf);
    }

    scale = (double)forced_size / s;
    int w_scaled = w * scale;
    int h_scaled = h * scale;
    if (w_scaled > 0 && h_scaled > 0)
        scaled_pixbuf = gdk_pixbuf_scale_simple (pixbuf,
                                                 w_scaled, h_scaled,
                                                 GDK_INTERP_BILINEAR);
    //g_message ("scale: %f s: %d w_scaled: %d h_scaled: %d", scale, s, w_scaled, h_scaled);
    return scaled_pixbuf;
}
#endif

GdkPixbuf *
marlin_icon_info_get_pixbuf_at_size (MarlinIconInfo *icon, gsize forced_size)
{
    GdkPixbuf *scaled_pixbuf = NULL;
    GdkPixbuf *pixbuf;
    int w, h, s;
    double scale;

    pixbuf = marlin_icon_info_get_pixbuf_nodefault (icon);
    if (pixbuf == NULL)
        return NULL;

    w = gdk_pixbuf_get_width (pixbuf);
    h = gdk_pixbuf_get_height (pixbuf);
    s = MAX (w, h);
    if (s == forced_size) {
        return g_object_ref (pixbuf);
    }

    scale = (double)forced_size / s;
    int w_scaled = w * scale;
    int h_scaled = h * scale;
    if (w_scaled > 0 && h_scaled > 0)
        scaled_pixbuf = gdk_pixbuf_scale_simple (pixbuf,
                                                 w_scaled, h_scaled,
                                                 GDK_INTERP_BILINEAR);
    g_object_unref (pixbuf);

    return scaled_pixbuf;
}

GdkPixbuf *
marlin_icon_info_get_pixbuf_force_size (MarlinIconInfo  *icon, gint size, gboolean force_size)
{
    if (force_size) {
        return marlin_icon_info_get_pixbuf_at_size (icon, size);
    } else {
        return marlin_icon_info_get_pixbuf_nodefault (icon);
    }
}

void marlin_icon_info_remove_cache (const char *path, int size)
{
    GFile *icon_file;
    GIcon *icon;
    LoadableIconKey *lookup_key;

    icon_file = g_file_new_for_path (path);
    icon = g_file_icon_new (icon_file);
    lookup_key = loadable_icon_key_new (icon, size);

    g_hash_table_remove (loadable_icon_cache, lookup_key);

    g_object_unref (icon_file);
    g_object_unref (icon);
    loadable_icon_key_free (lookup_key);
}
