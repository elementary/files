/*
 * Copyright (C) 2011, Lucas Baudin <xapantu@gmail.com>
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
 */

#include "marlin-abstract-sidebar.h"

/**
 * MarlinAbstractSidebar is an object which is the parent of
 * MarlinPlacesSidebar. Since MarlinPlacesSidebar was not in a lib
 * (the stuff in it can't really be used outside the src directory),
 * we need to access it via another way for the plugins.
 * This object (will) provide some functions to add an item in the sidebar
 * for example, which could be used by any plugins.
 *
 * These functions will be abstract here, and will be implemented in
 * src/marlin-places-sidebar.c
 **/

G_DEFINE_ABSTRACT_TYPE (MarlinAbstractSidebar, marlin_abstract_sidebar, GTK_TYPE_SCROLLED_WINDOW)

#define PRIVATE(o) \
  (G_TYPE_INSTANCE_GET_PRIVATE ((o), MARLIN_TYPE_ABSTRACT_SIDEBAR, MarlinAbstractSidebarPrivate))

struct _MarlinAbstractSidebarPrivate
{
};

void marlin_abstract_sidebar_add_extra_item(MarlinAbstractSidebar* self, gchar* text)
{
    printf("%s\n", __FUNCTION__);
    GtkTreeIter iter;
    gtk_tree_store_append (self->store, &iter, NULL);
    gtk_tree_store_set (self->store, &iter,
                        PLACES_SIDEBAR_COLUMN_ICON, NULL,
                        PLACES_SIDEBAR_COLUMN_NAME, text,
                        PLACES_SIDEBAR_COLUMN_URI, "test://",
                        -1);
}

static void marlin_abstract_sidebar_class_init (MarlinAbstractSidebarClass *klass)
{
  GtkScrolledWindowClass *object_class = GTK_SCROLLED_WINDOW_CLASS (klass);
}

static void marlin_abstract_sidebar_init (MarlinAbstractSidebar *self)
{
    /* this is required to set the category cells to bold and higher than the other ones */
    self->store = gtk_tree_store_new (PLACES_SIDEBAR_COLUMN_COUNT,
                                      G_TYPE_INT, 
                                      G_TYPE_STRING,
                                      G_TYPE_DRIVE,
                                      G_TYPE_VOLUME,
                                      G_TYPE_MOUNT,
                                      G_TYPE_STRING,
                                      GDK_TYPE_PIXBUF,
                                      G_TYPE_INT,
                                      G_TYPE_BOOLEAN,
                                      G_TYPE_BOOLEAN,
                                      G_TYPE_BOOLEAN,
                                      G_TYPE_STRING,
                                      GDK_TYPE_PIXBUF,
                                      G_TYPE_UINT64, /* For disks, total size */
                                      G_TYPE_UINT64, /* Free space */
                                      -1
                                     );

}
