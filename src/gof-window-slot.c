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

#include "gof-window-slot.h"
//#include "gof-directory-async.h"
#include "fm-list-view.h"
#include "fm-columns-view.h"
#include "marlin-view-window.h"

static void gof_window_slot_init       (GOFWindowSlot *slot);
static void gof_window_slot_class_init (GOFWindowSlotClass *class);
static void gof_window_slot_finalize   (GObject *object);

G_DEFINE_TYPE (GOFWindowSlot, gof_window_slot, G_TYPE_OBJECT)
#define parent_class gof_window_slot_parent_class

enum {
    ACTIVE,
    INACTIVE,
    LAST_SIGNAL
};

static guint signals[LAST_SIGNAL] = { 0 };

void
gof_window_column_add (GOFWindowSlot *slot, GtkWidget *column)
{
    GtkWidget *hpane = gtk_hpaned_new();
    gtk_widget_show (hpane);
    gtk_container_add(GTK_CONTAINER(slot->colpane), hpane);
    GtkWidget *vbox2 = gtk_hbox_new(FALSE, 0);
    gtk_widget_show (vbox2);
    slot->colpane = vbox2;
    slot->hpane = hpane;

    gtk_widget_set_size_request (column, 180,-1);

    gtk_paned_pack1 (GTK_PANED (hpane), column, FALSE, FALSE);
    gtk_paned_pack2 (GTK_PANED (hpane), vbox2, TRUE, FALSE);
}

void
gof_window_columns_add_location (GOFWindowSlot *slot, GFile *location)
{
    log_printf (LOG_LEVEL_UNDEFINED, "%s\n", G_STRFUNC);
    slot->mwcols->active_slot = slot;
    gtk_container_foreach (GTK_CONTAINER (slot->colpane), (GtkCallback)gtk_widget_destroy, NULL);
    
    slot->mwcols->slot = NULL;

    marlin_window_columns_add (slot->mwcols, location);
    /*GOFWindowSlot *slot = gof_window_slot_column_new (location);
      slot->mwcols = mwcols;
      mwcols->active_slot = slot;
      add_column(mwcols, slot->view_box);*/
}

void
gof_window_columns_add_preview (GOFWindowSlot *slot, GtkWidget *context_view)
{
    gtk_container_foreach (GTK_CONTAINER (slot->colpane), (GtkCallback)gtk_widget_destroy, NULL);
    gtk_container_add(GTK_CONTAINER(slot->colpane), context_view);
}

static void
gof_window_slot_finalize (GObject *object)
{
    GOFWindowSlot *slot = GOF_WINDOW_SLOT (object);
    log_printf (LOG_LEVEL_UNDEFINED, "%s %s\n", G_STRFUNC, g_file_get_uri (slot->directory->location));

    //load_dir_async_cancel(slot->directory);
    g_object_unref(slot->directory);
    g_object_unref(slot->location);
    G_OBJECT_CLASS (parent_class)->finalize (object);
    printf ("test %s\n", G_STRFUNC);
    /* avoid a warning in vala code: slot is freed in ViewContainer */
    //slot = NULL;
}

GOFWindowSlot *
gof_window_slot_new (GFile *location, GObject *ctab)
{
    log_printf (LOG_LEVEL_UNDEFINED, "%s %s\n", G_STRFUNC, g_file_get_uri (location));
    GOFWindowSlot *slot;
    slot = g_object_new (GOF_TYPE_WINDOW_SLOT, NULL);
    slot->location = g_object_ref (location);
    slot->ctab = ctab;

    slot->directory = gof_directory_get (slot->location);

    return slot;
}

void
gof_window_slot_make_view (GOFWindowSlot *slot)
{
    slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_LIST_VIEW,
                                               "window-slot", slot, NULL));
    marlin_view_view_container_set_content (slot->ctab, slot->view_box);
    load_dir_async (slot->directory);
}

void
gof_window_slot_make_column_view (GOFWindowSlot *slot)
{
    slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_COLUMNS_VIEW,
                                               "window-slot", slot, NULL));
    load_dir_async (slot->directory);
}

static void
gof_window_slot_init (GOFWindowSlot *slot)
{
}

static void
gof_window_slot_class_init (GOFWindowSlotClass *class)
{
    signals[ACTIVE] =
	g_signal_new ("active",
		      G_TYPE_FROM_CLASS (class),
		      G_SIGNAL_RUN_LAST,
		      G_STRUCT_OFFSET (GOFWindowSlotClass, active),
		      NULL, NULL,
		      g_cclosure_marshal_VOID__VOID,
		      G_TYPE_NONE, 0);

    signals[INACTIVE] =
	g_signal_new ("inactive",
		      G_TYPE_FROM_CLASS (class),
		      G_SIGNAL_RUN_LAST,
		      G_STRUCT_OFFSET (GOFWindowSlotClass, inactive),
		      NULL, NULL,
		      g_cclosure_marshal_VOID__VOID,
		      G_TYPE_NONE, 0);

    G_OBJECT_CLASS (class)->finalize = gof_window_slot_finalize;
}

GFile *
gof_window_slot_get_location (GOFWindowSlot *slot)
{
    return slot->location;
}

char *
gof_window_slot_get_location_uri (GOFWindowSlot *slot)
{
    g_assert (GOF_IS_WINDOW_SLOT (slot));

    if (slot->location) {
        return g_file_get_uri (slot->location);
    }
    return NULL;
}


