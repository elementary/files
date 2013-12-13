/*
 * marlin-bookmark.h - interface for individual bookmarks.
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

#ifndef MARLIN_BOOKMARK_H
#define MARLIN_BOOKMARK_H

#include <gtk/gtk.h>
#include <gio/gio.h>
#include "gof-file.h"

typedef struct MarlinBookmark MarlinBookmark;

#define MARLIN_TYPE_BOOKMARK marlin_bookmark_get_type()
#define MARLIN_BOOKMARK(obj) \
    (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_BOOKMARK, MarlinBookmark))
#define MARLIN_BOOKMARK_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_BOOKMARK, MarlinBookmarkClass))
#define MARLIN_IS_BOOKMARK(obj) \
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_BOOKMARK))
#define MARLIN_IS_BOOKMARK_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_BOOKMARK))
#define MARLIN_BOOKMARK_GET_CLASS(obj) \
    (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_BOOKMARK, MarlinBookmarkClass))

struct MarlinBookmark {
    GObject object;
    char  *name;
    char        *label;
    GOFFile     *file;
    GFileMonitor *monitor;
};

struct MarlinBookmarkClass {
    GObjectClass parent_class;

    /* Signals that clients can connect to. */

    /* The appearance_changed signal is emitted when the bookmark's
     * name or icon has changed.
     */
    void	(* appearance_changed) (MarlinBookmark *bookmark);

    /* The contents_changed signal is emitted when the bookmark's
     * URI has changed.
     */
    void	(* contents_changed) (MarlinBookmark *bookmark);
    
    /* The deleted signal is emitted when the bookmark's
     * file has been deleted.
     */
    void	(* deleted) (MarlinBookmark *bookmark);
};

typedef struct MarlinBookmarkClass MarlinBookmarkClass;

GType               marlin_bookmark_get_type               (void);

MarlinBookmark *    marlin_bookmark_new (GOFFile *file, char *label);
MarlinBookmark *    marlin_bookmark_copy                   (MarlinBookmark      *bookmark);
char *              marlin_bookmark_get_name               (MarlinBookmark      *bookmark);
GFile *             marlin_bookmark_get_location           (MarlinBookmark      *bookmark);
char *              marlin_bookmark_get_uri                (MarlinBookmark      *bookmark);
GIcon *             marlin_bookmark_get_icon               (MarlinBookmark      *bookmark);
gboolean	    marlin_bookmark_get_has_custom_name    (MarlinBookmark      *bookmark);		
gboolean            marlin_bookmark_set_name               (MarlinBookmark      *bookmark,
                                                            char                *new_name);		
gboolean            marlin_bookmark_uri_known_not_to_exist (MarlinBookmark      *bookmark);
int                 marlin_bookmark_compare_with           (gconstpointer          a,
                                                            gconstpointer          b);
int                 marlin_bookmark_compare_uris           (gconstpointer          a,
                                                            gconstpointer          b);
/*
void                marlin_bookmark_set_scroll_pos         (MarlinBookmark      *bookmark,
                                                            const char            *uri);
char *              marlin_bookmark_get_scroll_pos         (MarlinBookmark      *bookmark);
*/

/* Helper functions for displaying bookmarks */
/*GdkPixbuf *         marlin_bookmark_get_pixbuf             (MarlinBookmark      *bookmark,
                                                            GtkIconSize            icon_size);*/
GtkWidget *         marlin_bookmark_menu_item_new          (MarlinBookmark      *bookmark);

#endif /* MARLIN_BOOKMARK_H */
