/* 
 * marlin-bookmark.c - implementation of individual bookmarks.
 *
 * Copyright (C) 1999, 2000 Eazel, Inc.
 *
 * The Gnome Library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * The Gnome Library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with the Gnome Library; see the file COPYING.LIB.  If not,
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authors: John Sullivan <sullivan@eazel.com>
 */

#include <config.h>
#include "marlin-bookmark.h"

#include "nautilus-icon-info.h"
#include "marlin-icons.h"

enum {
    APPEARANCE_CHANGED,
    CONTENTS_CHANGED,
    LAST_SIGNAL
};

//#define ELLIPSISED_MENU_ITEM_MIN_CHARS  32

static guint signals[LAST_SIGNAL];

//static void	  marlin_bookmark_connect_file	  (MarlinBookmark	 *file);
//static void	  marlin_bookmark_disconnect_file	  (MarlinBookmark	 *file);

G_DEFINE_TYPE (MarlinBookmark, marlin_bookmark, G_TYPE_OBJECT);

/* GObject methods.  */

static void
marlin_bookmark_finalize (GObject *object)
{
    MarlinBookmark *bookmark;

    g_assert (MARLIN_IS_BOOKMARK (object));

    bookmark = MARLIN_BOOKMARK (object);
    //marlin_bookmark_disconnect_file (bookmark);	
    g_free (bookmark->label);
    g_object_unref (bookmark->file);

    G_OBJECT_CLASS (marlin_bookmark_parent_class)->finalize (object);
}

/* Initialization.  */

static void
marlin_bookmark_class_init (MarlinBookmarkClass *class)
{
    G_OBJECT_CLASS (class)->finalize = marlin_bookmark_finalize;

    signals[APPEARANCE_CHANGED] =
        g_signal_new ("appearance_changed",
                      G_TYPE_FROM_CLASS (class),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (MarlinBookmarkClass, appearance_changed),
                      NULL, NULL,
                      g_cclosure_marshal_VOID__VOID,
                      G_TYPE_NONE, 0);

    signals[CONTENTS_CHANGED] =
        g_signal_new ("contents_changed",
                      G_TYPE_FROM_CLASS (class),
                      G_SIGNAL_RUN_LAST,
                      G_STRUCT_OFFSET (MarlinBookmarkClass, contents_changed),
                      NULL, NULL,
                      g_cclosure_marshal_VOID__VOID,
                      G_TYPE_NONE, 0);

}

static void
marlin_bookmark_init (MarlinBookmark *bookmark)
{
    ;
}

/**
 * marlin_bookmark_compare_with:
 *
 * Check whether two bookmarks are considered identical.
 * @a: first MarlinBookmark*.
 * @b: second MarlinBookmark*.
 * 
 * Return value: 0 if @a and @b have same name and uri, 1 otherwise 
 * (GCompareFunc style)
**/
int		    
marlin_bookmark_compare_with (gconstpointer a, gconstpointer b)
{
    MarlinBookmark *bookmark_a;
    MarlinBookmark *bookmark_b;

    g_return_val_if_fail (MARLIN_IS_BOOKMARK (a), 1);
    g_return_val_if_fail (MARLIN_IS_BOOKMARK (b), 1);

    bookmark_a = MARLIN_BOOKMARK (a);
    bookmark_b = MARLIN_BOOKMARK (b);

    if (eel_strcmp (bookmark_a->name,
                    bookmark_b->name) != 0) {
        return 1;
    }

    if (!g_file_equal (bookmark_a->file->location,
                       bookmark_b->file->location)) {
        return 1;
    }

    return 0;
}

/**
 * marlin_bookmark_compare_uris:
 *
 * Check whether the uris of two bookmarks are for the same location.
 * @a: first MarlinBookmark*.
 * @b: second MarlinBookmark*.
 * 
 * Return value: 0 if @a and @b have matching uri, 1 otherwise 
 * (GCompareFunc style)
**/
int		    
marlin_bookmark_compare_uris (gconstpointer a, gconstpointer b)
{
    MarlinBookmark *bookmark_a;
    MarlinBookmark *bookmark_b;

    g_return_val_if_fail (MARLIN_IS_BOOKMARK (a), 1);
    g_return_val_if_fail (MARLIN_IS_BOOKMARK (b), 1);

    bookmark_a = MARLIN_BOOKMARK (a);
    bookmark_b = MARLIN_BOOKMARK (b);

    return !g_file_equal (bookmark_a->file->location,
                          bookmark_b->file->location);
}

MarlinBookmark *
marlin_bookmark_copy (MarlinBookmark *bookmark)
{
    g_return_val_if_fail (MARLIN_IS_BOOKMARK (bookmark), NULL);

    return marlin_bookmark_new (bookmark->file, bookmark->label);
}

char *
marlin_bookmark_get_name (MarlinBookmark *bookmark)
{
    g_return_val_if_fail(MARLIN_IS_BOOKMARK (bookmark), NULL);

    return g_strdup (bookmark->name);
}


gboolean
marlin_bookmark_get_has_custom_name (MarlinBookmark *bookmark)
{
    g_return_val_if_fail(MARLIN_IS_BOOKMARK (bookmark), FALSE);

    return (bookmark->label != NULL);
}

#if 0
GdkPixbuf *	    
marlin_bookmark_get_pixbuf (MarlinBookmark *bookmark,
                              GtkIconSize stock_size)
{
    GdkPixbuf *result;
    GIcon *icon;
    NautilusIconInfo *info;
    int pixel_size;


    g_return_val_if_fail (MARLIN_IS_BOOKMARK (bookmark), NULL);

    icon = marlin_bookmark_get_icon (bookmark);
    if (icon == NULL) {
        return NULL;
    }

    pixel_size = nautilus_get_icon_size_for_stock_size (stock_size);
    info = nautilus_icon_info_lookup (icon, pixel_size);
    //result = marlin_icon_info_get_pixbuf_at_size (info, pixel_size);	
    result = nautilus_icon_info_get_pixbuf_nodefault (info);
    g_object_unref (info);

    g_object_unref (icon);

    return result;
}
#endif

GIcon *
marlin_bookmark_get_icon (MarlinBookmark *bookmark)
{
    g_return_val_if_fail (MARLIN_IS_BOOKMARK (bookmark), NULL);
    g_return_val_if_fail (G_IS_FILE (bookmark->file->location), NULL);

    /* Try to connect a file in case file exists now but didn't earlier. */
    //marlin_bookmark_connect_file (bookmark);

    if (bookmark->file->icon) {
        return g_object_ref (bookmark->file->icon);
    }
    return g_themed_icon_new (MARLIN_ICON_FOLDER);

    return NULL;
}

GFile *
marlin_bookmark_get_location (MarlinBookmark *bookmark)
{
    g_return_val_if_fail(MARLIN_IS_BOOKMARK (bookmark), NULL);

    /* Try to connect a file in case file exists now but didn't earlier.
     * This allows a bookmark to update its image properly in the case
     * where a new file appears with the same URI as a previously-deleted
     * file. Calling connect_file here means that attempts to activate the 
     * bookmark will update its image if possible. 
     */
    //marlin_bookmark_connect_file (bookmark);

    return g_object_ref (bookmark->file->location);
}

char *
marlin_bookmark_get_uri (MarlinBookmark *bookmark)
{
    GFile *file;
    char *uri;

    file = marlin_bookmark_get_location (bookmark);
    uri = g_file_get_uri (file);
    g_object_unref (file);
    return uri;
}


/**
 * marlin_bookmark_set_name:
 *
 * Change the user-displayed name of a bookmark.
 * @new_name: The new user-displayed name for this bookmark, mustn't be NULL.
 * 
 * Returns: TRUE if the name changed else FALSE.
**/
gboolean
marlin_bookmark_set_name (MarlinBookmark *bookmark, char *new_name)
{
    g_return_val_if_fail (new_name != NULL, FALSE);
    g_return_val_if_fail (MARLIN_IS_BOOKMARK (bookmark), FALSE);

    if (strcmp (new_name, bookmark->file->name) == 0) {
        return FALSE;
    } 

    g_free (bookmark->label);
    bookmark->label = g_strdup (new_name);
    bookmark->name = bookmark->label;

    /* TODO check the two signals */
    g_signal_emit (bookmark, signals[APPEARANCE_CHANGED], 0);
    g_signal_emit (bookmark, signals[CONTENTS_CHANGED], 0);

    return TRUE;
}

#if 0
static gboolean
marlin_bookmark_icon_is_different (MarlinBookmark *bookmark,
                                     GIcon *new_icon)
{
    g_assert (MARLIN_IS_BOOKMARK (bookmark));
    g_assert (new_icon != NULL);

    if (bookmark->details->icon == NULL) {
        return TRUE;
    }

    return !g_icon_equal (bookmark->details->icon, new_icon) != 0;
}
#endif

/**
 * Update icon if there's a better one available.
 * Return TRUE if the icon changed.
 */
static gboolean
marlin_bookmark_update_icon (MarlinBookmark *bookmark)
{
    //TODO
    GIcon *new_icon;

    g_assert (MARLIN_IS_BOOKMARK (bookmark));

#if 0
    if (bookmark->details->file == NULL) {
        return FALSE;
    }

    if (!marlin_file_is_local (bookmark->details->file)) {
        /* never update icons for remote bookmarks */
        return FALSE;
    }
#endif
    //amtest
    /*
    if (!marlin_file_is_not_yet_confirmed (bookmark->details->file) &&
        marlin_file_check_if_ready (bookmark->details->file,
                                      MARLIN_FILE_ATTRIBUTES_FOR_ICON)) {
        new_icon = marlin_file_get_gicon (bookmark->details->file, 0);
        if (marlin_bookmark_icon_is_different (bookmark, new_icon)) {
            if (bookmark->details->icon) {
                g_object_unref (bookmark->details->icon);
            }
            bookmark->details->icon = new_icon;
            return TRUE;
        }
        g_object_unref (new_icon);
    }*/

    return FALSE;
}

#if 0
static void
bookmark_file_changed_callback (GOFFile *file, MarlinBookmark *bookmark)
{
    GFile *location;
    gboolean should_emit_appearance_changed_signal;
    gboolean should_emit_contents_changed_signal;
    const char *display_name;

    g_assert (GOF_IS_FILE (file));
    g_assert (MARLIN_IS_BOOKMARK (bookmark));
    g_assert (file == bookmark->details->file);

    should_emit_appearance_changed_signal = FALSE;
    should_emit_contents_changed_signal = FALSE;
    location = file->location;

    if (!g_file_equal (bookmark->file->location, location) &&
        !marlin_file_is_in_trash (file)) {
        g_object_unref (bookmark->file->location);
        bookmark->file->location = location;
        should_emit_contents_changed_signal = TRUE;
    } else {
        g_object_unref (location);
    }

    if (marlin_file_is_gone (file) ||
        marlin_file_is_in_trash (file)) {
        /* The file we were monitoring has been trashed, deleted,
         * or moved in a way that we didn't notice. We should make 
         * a spanking new GOFFile object for this 
         * location so if a new file appears in this place 
         * we will notice. However, we can't immediately do so
         * because creating a new GOFFile directly as a result
         * of noticing a file goes away may trigger i/o on that file
         * again, noticeing it is gone, leading to a loop.
         * So, the new GOFFile is created when the bookmark
         * is used again. However, this is not really a problem, as
         * we don't want to change the icon or anything about the
         * bookmark just because its not there anymore.
         */
        //marlin_bookmark_disconnect_file (bookmark);
    } else if (marlin_bookmark_update_icon (bookmark)) {
        /* File hasn't gone away, but it has changed
         * in a way that affected its icon.
         */
        should_emit_appearance_changed_signal = TRUE;
    }

    if (!bookmark->details->has_custom_name) {
        display_name = g_strdup (file->display_name);

        // TODO check alloc display_name
        if (strcmp (bookmark->name, display_name) != 0) {
            g_free (bookmark->name);
            bookmark->name = display_name;
            should_emit_appearance_changed_signal = TRUE;
        } else {
            g_free (display_name);
        }
    }

    if (should_emit_appearance_changed_signal) {
        g_signal_emit (bookmark, signals[APPEARANCE_CHANGED], 0);
    }

    if (should_emit_contents_changed_signal) {
        g_signal_emit (bookmark, signals[CONTENTS_CHANGED], 0);
    }
}
#endif

#if 0
/**
 * marlin_bookmark_set_icon_to_default:
 * 
 * Reset the icon to either the missing bookmark icon or the generic
 * bookmark icon, depending on whether the file still exists.
 */
static void
marlin_bookmark_set_icon_to_default (MarlinBookmark *bookmark)
{
    GIcon *icon, *emblemed_icon, *folder;
    GEmblem *emblem;

    if (bookmark->details->icon) {
        g_object_unref (bookmark->details->icon);
    }

    folder = g_themed_icon_new (MARLIN_ICON_FOLDER);

    if (marlin_bookmark_uri_known_not_to_exist (bookmark)) {
        icon = g_themed_icon_new (GTK_STOCK_DIALOG_WARNING);
        emblem = g_emblem_new (icon);

        emblemed_icon = g_emblemed_icon_new (folder, emblem);

        g_object_unref (emblem);
        g_object_unref (icon);
        g_object_unref (folder);

        folder = emblemed_icon;
    }

    bookmark->details->icon = folder;
}
#endif

//TODO
#if 0
static void
marlin_bookmark_disconnect_file (MarlinBookmark *bookmark)
{
    g_assert (MARLIN_IS_BOOKMARK (bookmark));

    if (bookmark->details->file != NULL) {
        g_signal_handlers_disconnect_by_func (bookmark->details->file,
                                              G_CALLBACK (bookmark_file_changed_callback),
                                              bookmark);
        marlin_file_unref (bookmark->details->file);
        bookmark->details->file = NULL;
    }

    if (bookmark->details->icon != NULL) {
        g_object_unref (bookmark->details->icon);
        bookmark->details->icon = NULL;
    }
}

static void
marlin_bookmark_connect_file (MarlinBookmark *bookmark)
{
    const char *display_name;

    g_assert (MARLIN_IS_BOOKMARK (bookmark));

    if (bookmark->details->file != NULL) {
        return;
    }

    if (!marlin_bookmark_uri_known_not_to_exist (bookmark)) {
        bookmark->details->file = marlin_file_get (bookmark->file->location);
        g_assert (!marlin_file_is_gone (bookmark->details->file));

        g_signal_connect_object (bookmark->details->file, "changed",
                                 G_CALLBACK (bookmark_file_changed_callback), bookmark, 0);
    }	

    /* Set icon based on available information; don't force network i/o
     * to get any currently unknown information. 
     */
    if (!marlin_bookmark_update_icon (bookmark)) {
        if (bookmark->details->icon == NULL || bookmark->details->file == NULL) {
            marlin_bookmark_set_icon_to_default (bookmark);
        }
    }

    if (!bookmark->details->has_custom_name &&
        bookmark->details->file && 
        marlin_file_check_if_ready (bookmark->details->file, MARLIN_FILE_ATTRIBUTE_INFO)) {
        //display_name = marlin_file_get_display_name (bookmark->details->file);
        display_name = bookmark->details->file->name;
        if (strcmp (bookmark->name, display_name) != 0) {
            g_free (bookmark->name);
            bookmark->name = display_name;
        } /*else {
            g_free (display_name);
        }*/
    }
}
#endif

MarlinBookmark *
marlin_bookmark_new (GOFFile *file, char *label)
{
    MarlinBookmark *bookmark;

    bookmark = MARLIN_BOOKMARK (g_object_new (MARLIN_TYPE_BOOKMARK, NULL));
    g_object_ref_sink (bookmark);

    bookmark->name = NULL;
    bookmark->label = g_strdup (label);
    bookmark->file = g_object_ref (file);
    if (label != NULL) 
        bookmark->name = bookmark->label;
    if (bookmark->name == NULL)
        bookmark->name = file->name;
    if (bookmark->name == NULL)
        bookmark->name = file->basename;

    //marlin_bookmark_connect_file (new_bookmark);

    return bookmark;
}				 

#if 0
static GtkWidget *
create_image_widget_for_bookmark (MarlinBookmark *bookmark)
{
    GdkPixbuf *pixbuf;
    GtkWidget *widget;

    pixbuf = marlin_bookmark_get_pixbuf (bookmark, GTK_ICON_SIZE_MENU);
    if (pixbuf == NULL) {
        return NULL;
    }

    widget = gtk_image_new_from_pixbuf (pixbuf);

    g_object_unref (pixbuf);
    return widget;
}

/**
 * marlin_bookmark_menu_item_new:
 * 
 * Return a menu item representing a bookmark.
 * @bookmark: The bookmark the menu item represents.
 * Return value: A newly-created bookmark, not yet shown.
**/ 
GtkWidget *
marlin_bookmark_menu_item_new (MarlinBookmark *bookmark)
{
    GtkWidget *menu_item;
    GtkWidget *image_widget;
    GtkLabel *label;

    menu_item = gtk_image_menu_item_new_with_label (bookmark->name);
    label = GTK_LABEL (gtk_bin_get_child (GTK_BIN (menu_item)));
    gtk_label_set_use_underline (label, FALSE);
    gtk_label_set_ellipsize (label, PANGO_ELLIPSIZE_END);
    gtk_label_set_max_width_chars (label, ELLIPSISED_MENU_ITEM_MIN_CHARS);

    image_widget = create_image_widget_for_bookmark (bookmark);
    if (image_widget != NULL) {
        gtk_widget_show (image_widget);
        gtk_image_menu_item_set_image (GTK_IMAGE_MENU_ITEM (menu_item),
                                       image_widget);
    }

    return menu_item;
}
#endif

gboolean
marlin_bookmark_uri_known_not_to_exist (MarlinBookmark *bookmark)
{
    char *path_name;
    gboolean exists;

    /* Convert to a path, returning FALSE if not local. */
    if (!g_file_is_native (bookmark->file->location)) {
        return FALSE;
    }
    path_name = g_file_get_path (bookmark->file->location);

    /* Now check if the file exists (sync. call OK because it is local). */
    exists = g_file_test (path_name, G_FILE_TEST_EXISTS);
    g_free (path_name);

    return !exists;
}

#if 0
void
marlin_bookmark_set_scroll_pos (MarlinBookmark      *bookmark,
                                  const char            *uri)
{
    g_free (bookmark->details->scroll_file);
    bookmark->details->scroll_file = g_strdup (uri);
}

char *
marlin_bookmark_get_scroll_pos (MarlinBookmark      *bookmark)
{
    return g_strdup (bookmark->details->scroll_file);
}
#endif
