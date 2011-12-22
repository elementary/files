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
#include "fm-icon-view.h"
#include "fm-list-view.h"
#include "fm-compact-view.h"
#include "fm-columns-view.h"
#include "marlin-view-window.h"
#include "marlin-global-preferences.h"

static void gof_window_slot_init       (GOFWindowSlot *slot);
static void gof_window_slot_class_init (GOFWindowSlotClass *class);
static void gof_window_slot_finalize   (GObject *object);

G_DEFINE_TYPE (GOFWindowSlot, gof_window_slot, GOF_TYPE_ABSTRACT_SLOT)
#define parent_class gof_window_slot_parent_class

enum {
    ACTIVE,
    INACTIVE,
    LAST_SIGNAL
};

static guint signals[LAST_SIGNAL] = { 0 };


static void
gof_window_slot_init (GOFWindowSlot *slot)
{
    slot->content_box = gtk_vbox_new(FALSE, 0);
    GOF_ABSTRACT_SLOT(slot)->extra_location_widgets = gtk_vbox_new(FALSE, 0);
    gtk_box_pack_start(GTK_BOX (slot->content_box), GOF_ABSTRACT_SLOT(slot)->extra_location_widgets, FALSE, FALSE, 0);
}

static void
real_active (GOFWindowSlot *slot) 
{
    marlin_view_view_container_refresh_slot_info (MARLIN_VIEW_VIEW_CONTAINER (slot->ctab));
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
    class->active = real_active;
}

static void
gof_window_slot_finalize (GObject *object)
{
    GOFWindowSlot *slot = GOF_WINDOW_SLOT (object);

    //load_dir_async_cancel(slot->directory);
    g_debug ("%s %s\n", G_STRFUNC, slot->directory->file->uri);
    g_object_unref(slot->directory);
    g_object_unref(slot->location);
    G_OBJECT_CLASS (parent_class)->finalize (object);
    /* avoid a warning in vala code: slot is freed in ViewContainer */
    //slot = NULL;
}

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

    gtk_widget_set_size_request (column, slot->mwcols->preferred_column_width, -1);

    gtk_paned_pack1 (GTK_PANED (hpane), column, FALSE, FALSE);
    gtk_paned_pack2 (GTK_PANED (hpane), vbox2, TRUE, FALSE);
}

void
gof_window_columns_add_location (GOFWindowSlot *slot, GFile *location)
{
    gint current_slot_position = 0;
    gint i;
    GList* list_slot = slot->mwcols->slot;
    
    gtk_container_foreach (GTK_CONTAINER (slot->colpane), (GtkCallback)gtk_widget_destroy, NULL);
    
    current_slot_position = g_list_index(slot->mwcols->slot, slot);
    if(current_slot_position == -1) {
        g_warning ("Can't find the slot you are viewing, this should *not* happen.");
    } else {
        GList *l = NULL;
        for(i = 0; i <= current_slot_position; i++) {
            l = g_list_append(l, list_slot->data);
            list_slot = list_slot->next;
        }
        g_list_free (slot->mwcols->slot);
        slot->mwcols->slot = l;
    }
    
    marlin_window_columns_add (slot->mwcols, location);
}

GOFWindowSlot *
gof_window_slot_new (GFile *location, GtkEventBox *ctab)
{
    GOFWindowSlot *slot;
    slot = g_object_new (GOF_TYPE_WINDOW_SLOT, NULL);
    slot->location = g_object_ref (location);
    slot->ctab = ctab;

    slot->directory = gof_directory_async_from_gfile (slot->location);
    slot->directory->show_hidden_files = g_settings_get_boolean (settings, "show-hiddenfiles");
    g_debug ("%s %s\n", G_STRFUNC, slot->directory->file->uri);

    return slot;
}

/**
 * Used to make a view in the list view.
 * It replaces the content of the current tab by it own widget (wich is a list
 * of the current files of this directory).
 **/
void
gof_window_slot_make_icon_view (GOFWindowSlot *slot)
{
    if(slot->view_box != NULL)
    {
        gtk_widget_destroy(slot->view_box);
    }
    slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_ICON_VIEW,
                                               "window-slot", slot, NULL));
    gtk_box_pack_start(GTK_BOX (slot->content_box), slot->view_box, TRUE, TRUE, 0);
    
    marlin_view_view_container_set_content ((MarlinViewViewContainer *) slot->ctab, slot->content_box);
    gof_directory_async_load (slot->directory);
}

void
gof_window_slot_make_list_view (GOFWindowSlot *slot)
{
    if(slot->view_box != NULL)
    {
        gtk_widget_destroy(slot->view_box);
    }
    slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_LIST_VIEW,
                                               "window-slot", slot, NULL));
    gtk_box_pack_start (GTK_BOX (slot->content_box), slot->view_box, TRUE, TRUE, 0);
    marlin_view_view_container_set_content ((MarlinViewViewContainer *) slot->ctab, slot->content_box);
    gof_directory_async_load (slot->directory);
}

void
gof_window_slot_make_compact_view (GOFWindowSlot *slot)
{
    if(slot->view_box != NULL)
    {
        gtk_widget_destroy(slot->view_box);
    }
    slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_COMPACT_VIEW,
                                               "window-slot", slot, NULL));
    gtk_box_pack_start(GTK_BOX (slot->content_box), slot->view_box, TRUE, TRUE, 0);
    
    marlin_view_view_container_set_content ((MarlinViewViewContainer *) slot->ctab, slot->content_box);
    gof_directory_async_load (slot->directory);
}

/**
 * Used to make a view in the column view.
 * It replaces the content of the current tab by it own widget (wich is a list
 * of the current files of this directory).
 *
 * Note:
 * In miller column view, you'll have multiple column displayed, not only this
 * one.
 **/
void
gof_window_slot_make_column_view (GOFWindowSlot *slot)
{
    slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_COLUMNS_VIEW,
                                               "window-slot", slot, NULL));
    gof_directory_async_load (slot->directory);
}


void
gof_window_slot_active (GOFWindowSlot *slot)
{
    g_return_if_fail (GOF_IS_WINDOW_SLOT (slot));

    if (slot->mwcols)
        marlin_window_columns_active_slot (slot->mwcols, slot);
}

void
gof_window_slot_freeze_updates (GOFWindowSlot *slot)
{
    if (slot->mwcols != NULL)
        marlin_window_columns_freeze_updates (slot->mwcols);
}

void
gof_window_slot_unfreeze_updates (GOFWindowSlot *slot)
{
    if (slot->mwcols != NULL)
        marlin_window_columns_unfreeze_updates (slot->mwcols);
}

