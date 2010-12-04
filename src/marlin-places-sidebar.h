/*
 *  Marlin
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License as
 *  published by the Free Software Foundation; either version 2 of the
 *  License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this library; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 *  Authors : Mr Jamie McCracken (jamiemcc at blueyonder dot co dot uk)
 *            ammonkey <am.monkeyd@gmail.com>
 *
 */
#ifndef _MARLIN_PLACES_SIDEBAR_H
#define _MARLIN_PLACES_SIDEBAR_H

#include "marlin-bookmark-list.h"
#include <gtk/gtk.h>

#define MARLIN_TYPE_PLACES_SIDEBAR marlin_places_sidebar_get_type()
#define MARLIN_PLACES_SIDEBAR(obj) \
    (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_PLACES_SIDEBAR, MarlinPlacesSidebar))
#define MARLIN_PLACES_SIDEBAR_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_PLACES_SIDEBAR, MarlinPlacesSidebarClass))
#define MARLIN_IS_PLACES_SIDEBAR(obj) \
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_PLACES_SIDEBAR))
#define MARLIN_IS_PLACES_SIDEBAR_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_PLACES_SIDEBAR))
#define MARLIN_PLACES_SIDEBAR_GET_CLASS(obj) \
    (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_PLACES_SIDEBAR, MarlinPlacesSidebarClass))

typedef struct {
    GtkScrolledWindow   parent;
    GtkTreeView         *tree_view;
    GtkCellRenderer     *indent_renderer;
    GtkCellRenderer     *icon_cell_renderer;
    GtkCellRenderer     *eject_text_cell_renderer;
    GtkCellRenderer	*expander_renderer;
    char 	        *uri;
    GtkTreeStore        *store;
    GtkWidget           *window;
    MarlinBookmarkList  *bookmarks;
    GVolumeMonitor      *volume_monitor;
    gint                n_builtins_before;

    /* DnD */
    GList     *drag_list;
    gboolean  drag_data_received;
    int       drag_data_info;
    gboolean  drop_occured;

    GtkWidget *popup_menu;
    GtkWidget *popup_menu_open_in_new_tab_item;
    GtkWidget *popup_menu_remove_item;
    GtkWidget *popup_menu_rename_item;
    GtkWidget *popup_menu_separator_item1;
    GtkWidget *popup_menu_separator_item2;
    GtkWidget *popup_menu_mount_item;
    GtkWidget *popup_menu_unmount_item;
    GtkWidget *popup_menu_eject_item;
    GtkWidget *popup_menu_rescan_item;
    GtkWidget *popup_menu_format_item;
    GtkWidget *popup_menu_empty_trash_item;
    GtkWidget *popup_menu_start_item;
    GtkWidget *popup_menu_stop_item;

    /* volume mounting - delayed open process */
    gboolean mounting;
    GOFWindowSlot *go_to_after_mount_slot;
    /*MarlinWindowOpenFlags go_to_after_mount_flags;*/

    GtkTreePath *eject_highlight_path;
} MarlinPlacesSidebar;

typedef struct {
    GtkScrolledWindowClass parent;
} MarlinPlacesSidebarClass;

GType marlin_places_sidebar_get_type (void);
void marlin_places_sidebar_register (void);

#endif
