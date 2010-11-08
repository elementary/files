/* -*- Mode: C; indent-tabs-mode: t; c-basic-offset: 8; tab-width: 8 -*- */
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

#ifndef GOF_WINDOW_SLOT_H
#define GOF_WINDOW_SLOT_H

#include <gtk/gtk.h>
//#include <glib/gi18n.h>
//#include "fm-list-view.h"
#include "gof-directory-async.h"
#include "marlin-window-columns.h"

#define GOF_TYPE_WINDOW_SLOT	 (gof_window_slot_get_type())
#define GOF_WINDOW_SLOT_CLASS(k)     (G_TYPE_CHECK_CLASS_CAST((k), GOF_TYPE_WINDOW_SLOT, GOFWindowSlotClass))
#define GOF_WINDOW_SLOT(obj)	 (G_TYPE_CHECK_INSTANCE_CAST ((obj), GOF_TYPE_WINDOW_SLOT, GOFWindowSlot))
#define GOF_IS_WINDOW_SLOT(obj)      (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GOF_TYPE_WINDOW_SLOT))
#define GOF_IS_WINDOW_SLOT_CLASS(k)  (G_TYPE_CHECK_CLASS_TYPE ((k), GOF_TYPE_WINDOW_SLOT))
#define GOF_WINDOW_SLOT_GET_CLASS(o) (G_TYPE_INSTANCE_GET_CLASS ((o), GOF_TYPE_WINDOW_SLOT, GOFWindowSlotClass))

/*
typedef enum {
	GOF_LOCATION_CHANGE_STANDARD,
	GOF_LOCATION_CHANGE_BACK,
	GOF_LOCATION_CHANGE_FORWARD,
	GOF_LOCATION_CHANGE_RELOAD,
	GOF_LOCATION_CHANGE_REDIRECT,
	GOF_LOCATION_CHANGE_FALLBACK
} GOFLocationChangeType;*/

struct GOFWindowSlot {
	GObject parent;

	/* content_box contains
 	 *  1) an event box containing extra_location_widgets
 	 *  2) the view box for the content view
 	 */
	GtkWidget *content_box;
	/*GtkWidget *extra_location_event_box;
	GtkWidget *extra_location_widgets;
	GtkWidget *extra_location_separator;*/
	GtkWidget *view_box;
        GtkWidget *colpane;
        GtkWidget *hpane;

	/* Current location. */
	GFile *location;
	char *title;
	char *status_text;

        GtkWidget *window;
        GOFDirectoryAsync *directory;

        MarlinWindowColumns *mwcols;

	/*NautilusFile *viewed_file;
	gboolean viewed_file_seen;
	gboolean viewed_file_in_trash;*/

	gboolean allow_stop;

	//NautilusQueryEditor *query_editor;

	/* New location. */
	//GOFLocationChangeType location_change_type;
	/*guint location_change_distance;
	GFile *pending_location;
	char *pending_scroll_to;
	GList *pending_selection;
	NautilusFile *determine_view_file;
	GCancellable *mount_cancellable;
	GError *mount_error;
	gboolean tried_mount;

	GCancellable *find_mount_cancellable;

	gboolean visible;*/
};

struct GOFWindowSlotClass {
	GObjectClass parent_class;

	/* wrapped GOFWindowInfo signals, for overloading */
	/*void (* active)   (NautilusWindowSlot *slot);
	void (* inactive) (NautilusWindowSlot *slot);*/

	//void (* update_query_editor) (NautilusWindowSlot *slot);
};


GType   gof_window_slot_get_type (void);

//GOFWindowSlot *gof_window_slot_new (gchar *path);
GOFWindowSlot   *gof_window_slot_new (GFile *, GtkWidget *);
GOFWindowSlot   *gof_window_slot_column_new (GFile *location, GtkWidget *window);
void            gof_window_slot_change_location (GOFWindowSlot *slot, GFile *location);

void            gof_window_column_add (GOFWindowSlot *slot, GtkWidget *column);
void            gof_window_columns_add_location (GOFWindowSlot *slot, GFile *location);
void            gof_window_columns_add_preview (GOFWindowSlot *slot, GFile *location);
GFile           *gof_window_slot_get_location (GOFWindowSlot *slot);
char            *gof_window_slot_get_location_uri (GOFWindowSlot *slot);

#endif /* GOF_WINDOW_SLOT_H */
