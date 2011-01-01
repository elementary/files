/* marlin-dnd.h - Common Drag & drop handling code 
 *
 * Copyright (C) 2000 Eazel, Inc.
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
 * Authors: Pavel Cisler <pavel@eazel.com>,
 *	    Ettore Perazzoli <ettore@gnu.org>
 */

#ifndef MARLIN_DND_H
#define MARLIN_DND_H

#include <gtk/gtk.h>
#include "gof-file.h"
/*#include <libnautilus-private/nautilus-window-slot-info.h>*/
//#include "marlin-private.h"

/* Drag & Drop target names. */
#define MARLIN_ICON_DND_GNOME_ICON_LIST_TYPE	"x-special/gnome-icon-list"
#define MARLIN_ICON_DND_URI_LIST_TYPE		"text/uri-list"
#define MARLIN_ICON_DND_NETSCAPE_URL_TYPE	"_NETSCAPE_URL"
#define MARLIN_ICON_DND_BGIMAGE_TYPE		"property/bgimage"
#define MARLIN_ICON_DND_ROOTWINDOW_DROP_TYPE	"application/x-rootwindow-drop"
#define MARLIN_ICON_DND_XDNDDIRECTSAVE_TYPE	"XdndDirectSave0" /* XDS Protocol Type */
#define MARLIN_ICON_DND_RAW_TYPE	        "application/octet-stream"

/* Item of the drag selection list */
typedef struct {
    char *uri;
    gboolean got_icon_position;
    int icon_x, icon_y;
    int icon_width, icon_height;
} MarlinDragSelectionItem;

#if 0
/* Standard Drag & Drop types. */
typedef enum {
    MARLIN_ICON_DND_GNOME_ICON_LIST,
    MARLIN_ICON_DND_URI_LIST,
    MARLIN_ICON_DND_NETSCAPE_URL,
    MARLIN_ICON_DND_TEXT,
    MARLIN_ICON_DND_XDNDDIRECTSAVE,
    MARLIN_ICON_DND_RAW,
    MARLIN_ICON_DND_ROOTWINDOW_DROP
} MarlinIconDndTargetType;
#endif

typedef enum {
    MARLIN_DND_ACTION_FIRST = GDK_ACTION_ASK << 1,
    MARLIN_DND_ACTION_SET_AS_BACKGROUND = MARLIN_DND_ACTION_FIRST << 0,
    MARLIN_DND_ACTION_SET_AS_FOLDER_BACKGROUND = MARLIN_DND_ACTION_FIRST << 1,
    MARLIN_DND_ACTION_SET_AS_GLOBAL_BACKGROUND = MARLIN_DND_ACTION_FIRST << 2
} MarlinDndAction;

#if 0
/* drag&drop-related information. */
typedef struct {
    GtkTargetList *target_list;

    /* Stuff saved at "receive data" time needed later in the drag. */
    gboolean got_drop_data_type;
    MarlinIconDndTargetType data_type;
    GtkSelectionData *selection_data;
    char *direct_save_uri;

    /* Start of the drag, in window coordinates. */
    int start_x, start_y;

    /* List of MarlinDragSelectionItems, representing items being dragged, or NULL
     * if data about them has not been received from the source yet.
     */
    GList *selection_list;

    /* has the drop occured ? */
    gboolean drop_occured;

    /* whether or not need to clean up the previous dnd data */
    gboolean need_to_destroy;

    /* autoscrolling during dragging */
    int auto_scroll_timeout_id;
    gboolean waiting_to_autoscroll;
    gint64 start_auto_scroll_in;

} MarlinDragInfo;

typedef struct {
    /* NB: the following elements are managed by us */
    gboolean have_data;
    gboolean have_valid_data;

    gboolean drop_occured;

    unsigned int info;
    union {
        GList *selection_list;
        GList *uri_list;
        char *netscape_url;
    } data;

    /* NB: the following elements are managed by the caller of
     *   marlin_drag_slot_proxy_init() */

    /* a fixed location, or NULL to use slot's location */
    GFile *target_location;
    /* a fixed slot, or NULL to use the window's active slot */
    //MarlinWindowSlotInfo *target_slot;
    GtkWidget *target_slot;
} MarlinDragSlotProxyInfo;

typedef void		(* MarlinDragEachSelectedItemDataGet)	(const char *url, 
                                                                 int x, int y, int w, int h, 
                                                                 gpointer data);
typedef void            (* MarlinDragEachSelectedItemIterator)	(MarlinDragEachSelectedItemDataGet iteratee, 
                                                                 gpointer iterator_context, 
                                                                 gpointer data);

void			marlin_drag_init			(MarlinDragInfo *drag_info,
                                                                 const GtkTargetEntry *drag_types,
                                                                 int drag_type_count,
                                                                 gboolean add_text_targets);
void			marlin_drag_finalize			(MarlinDragInfo *drag_info);
#endif
MarlinDragSelectionItem *marlin_drag_selection_item_new		(void);
void		        marlin_drag_destroy_selection_list	(GList	*selection_list);
#if 0
GList		        *marlin_drag_build_selection_list   	(GtkSelectionData *data);

char **		        marlin_drag_uri_array_from_selection_list (const GList *selection_list);
GList *		        marlin_drag_uri_list_from_selection_list (const GList *selection_list);

char **		        marlin_drag_uri_array_from_list		(const GList *uri_list);
GList *		        marlin_drag_uri_list_from_array		(const char **uris);

gboolean	        marlin_drag_items_local			(const char *target_uri,
                                                                 const GList *selection_list);
gboolean	        marlin_drag_uris_local			(const char *target_uri,
                                                                 const GList *source_uri_list);
gboolean	        marlin_drag_items_in_trash		(const GList *selection_list);
gboolean	        marlin_drag_items_on_desktop		(const GList *selection_list);
void		        marlin_drag_default_drop_action_for_icons (
                                                                 GdkDragContext *context,
                                                                 const char *target_uri,
                                                                 const GList *items,
                                                                 int *action);
GdkDragAction           marlin_drag_default_drop_action_for_netscape_url (
                                                                 GdkDragContext *context);
GdkDragAction		marlin_drag_default_drop_action_for_uri_list (
                                                                 GdkDragContext *context,
                                                                 const char *target_uri_string);
gboolean		marlin_drag_drag_data_get		(GtkWidget *widget,
                                                                 GdkDragContext	*context,
                                                                 GtkSelectionData *selection_data,
                                                                 guint info,
                                                                 guint32 time,
                                                                 gpointer container_context,
                                                                 MarlinDragEachSelectedItemIterator  each_selected_item_iterator);
int			marlin_drag_modifier_based_action	(int default_action,
                                                                 int non_default_action);
#endif
GdkDragAction		marlin_drag_drop_action_ask		(GtkWidget *widget,
                                                                 GdkDragAction possible_actions);
#if 0
gboolean		marlin_drag_autoscroll_in_scroll_region	(GtkWidget *widget);
void			marlin_drag_autoscroll_calculate_delta	(GtkWidget *widget,
                                                                 float *x_scroll_delta,
                                                                 float *y_scroll_delta);
void			marlin_drag_autoscroll_start		(MarlinDragInfo *drag_info,
                                                                 GtkWidget *widget,
                                                                 GtkFunction callback,
                                                                 gpointer user_data);
void			marlin_drag_autoscroll_stop		(MarlinDragInfo *drag_info);

gboolean		marlin_drag_selection_includes_special_link (GList *selection_list);

void                    marlin_drag_slot_proxy_init             (GtkWidget *widget,
                                                                 MarlinDragSlotProxyInfo *drag_info);
#endif
gboolean                marlin_dnd_perform  (GtkWidget       *widget,
                                             GOFFile         *file,
                                             GList           *file_list,
                                             GdkDragAction   action,
                                             GClosure        *new_files_closure);

#endif
