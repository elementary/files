/*
 * Marlin
 *
 * Copyright (C) 1999, 2000 Eazel, Inc.
 *
 * Marlin is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 * Authors: John Sullivan <sullivan@eazel.com>
 */

/* nautilus-bookmark-list.h - interface for centralized list of bookmarks.
*/

#ifndef MARLIN_BOOKMARK_LIST_H
#define MARLIN_BOOKMARK_LIST_H

#include "marlin-bookmark.h"
#include <gio/gio.h>

typedef struct MarlinBookmarkList MarlinBookmarkList;
typedef struct MarlinBookmarkListClass MarlinBookmarkListClass;

#define MARLIN_TYPE_BOOKMARK_LIST marlin_bookmark_list_get_type()
#define MARLIN_BOOKMARK_LIST(obj) \
    (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_BOOKMARK_LIST, MarlinBookmarkList))
#define MARLIN_BOOKMARK_LIST_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_BOOKMARK_LIST, MarlinBookmarkListClass))
#define MARLIN_IS_BOOKMARK_LIST(obj) \
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_BOOKMARK_LIST))
#define MARLIN_IS_BOOKMARK_LIST_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_BOOKMARK_LIST))
#define MARLIN_BOOKMARK_LIST_GET_CLASS(obj) \
    (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_BOOKMARK_LIST, MarlinBookmarkListClass))

struct MarlinBookmarkList {
    GObject object;

    GList *list; 
    GFileMonitor *monitor;
    GQueue *pending_ops;
};

struct MarlinBookmarkListClass {
    GObjectClass parent_class;
    void (* contents_changed) (MarlinBookmarkList *bookmarks);
};

GType                   marlin_bookmark_list_get_type            (void);
MarlinBookmarkList *    marlin_bookmark_list_new                 (void);
void                    marlin_bookmark_list_append              (MarlinBookmarkList   *bookmarks,
                                                                  MarlinBookmark *bookmark);
gboolean                marlin_bookmark_list_contains            (MarlinBookmarkList   *bookmarks,
                                                                  MarlinBookmark *bookmark);
void                    marlin_bookmark_list_delete_item_at      (MarlinBookmarkList   *bookmarks,
                                                                  guint                   index);
void                    marlin_bookmark_list_delete_items_with_uri (MarlinBookmarkList *bookmarks,
                                                                    const char		   *uri);
void                    marlin_bookmark_list_insert_item         (MarlinBookmarkList   *bookmarks,
                                                                  MarlinBookmark *bookmark,
                                                                  guint                   index);
guint                   marlin_bookmark_list_length              (MarlinBookmarkList   *bookmarks);
MarlinBookmark *        marlin_bookmark_list_item_at             (MarlinBookmarkList   *bookmarks,
                                                                  guint                   index);
void                    marlin_bookmark_list_move_item           (MarlinBookmarkList *bookmarks,
                                                                  guint                 index,
                                                                  guint                 destination);

#endif /* MARLIN_BOOKMARK_LIST_H */
