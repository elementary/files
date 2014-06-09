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
#include "fm-columns-view.h"
#include "marlin-view-window.h"
#include "marlin-global-preferences.h"
#include <granite.h>

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
    slot->content_box = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);
    slot->width = 0;
    GOF_ABSTRACT_SLOT (slot)->extra_location_widgets = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);
    gtk_box_pack_start (GTK_BOX (slot->content_box), GOF_ABSTRACT_SLOT(slot)->extra_location_widgets, FALSE, FALSE, 0);
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
    //g_warning ("%s %s %u\n", G_STRFUNC, slot->directory->file->uri, G_OBJECT (slot->directory)->ref_count);
    g_signal_handlers_disconnect_by_data (slot->directory, slot);
    g_object_unref(slot->directory);
    g_object_unref(slot->location);
    G_OBJECT_CLASS (parent_class)->finalize (object);
    /* avoid a warning in vala code: slot is freed in ViewContainer */
    //slot = NULL;
}

void
update_total_width (GtkWidget *widget, GtkAllocation *allocation, void *data)
{
    GOFWindowSlot* slot = data;

    if (slot->mwcols->total_width != 0 && slot->width != allocation->width) {
        slot->mwcols->total_width += allocation->width - slot->width;
        slot->width = allocation->width;
        gtk_widget_set_size_request (slot->mwcols->colpane, slot->mwcols->total_width, -1);
    }

    if (slot->slot_number == slot->mwcols->active_slot->slot_number)
        marlin_window_columns_scroll_to_slot (slot->mwcols, slot);
}

void
gof_window_column_add (GOFWindowSlot *slot, GtkWidget *column)
{
    GtkWidget *hpane = GTK_WIDGET (granite_widgets_thin_paned_new (GTK_ORIENTATION_HORIZONTAL));
    gtk_widget_set_hexpand(hpane, TRUE);

    gtk_container_add(GTK_CONTAINER (slot->mwcols->active_slot->colpane), hpane);

    GtkWidget *box1 = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 0);

    slot->colpane = box1;
    slot->hpane = hpane;
    gtk_paned_pack1 (GTK_PANED (hpane), column, FALSE, FALSE);
    gtk_paned_pack2 (GTK_PANED (hpane), box1, TRUE, FALSE);

    gtk_widget_set_size_request (column, slot->mwcols->preferred_column_width, -1);
    g_signal_connect (column, "size-allocate", G_CALLBACK (update_total_width), slot);
    gtk_widget_show_all (slot->hpane);

    gof_directory_async_load (slot->directory);
}

void autosize_slot (GOFWindowSlot *slot)
{
    g_return_if_fail (GOF_IS_WINDOW_SLOT (slot));
    g_return_if_fail (slot->view_box != NULL);
    g_return_if_fail (GTK_IS_WIDGET (slot->view_box));
    g_return_if_fail (GOF_DIRECTORY_IS_ASYNC (slot->directory));
    g_return_if_fail (slot->mwcols != NULL);

    g_debug ("Autosize slot %i", slot->slot_number);
    PangoLayout* layout = gtk_widget_create_pango_layout (GTK_WIDGET (slot->view_box), NULL);

    if (gof_directory_async_is_empty (slot->directory))
        pango_layout_set_markup (layout, FM_DIRECTORY_VIEW (slot->view_box)->empty_message, -1);
    else
        pango_layout_set_markup (layout,
                                 g_markup_escape_text (slot->directory->longest_file_name, -1),
                                 -1);

    PangoRectangle extents;
    pango_layout_get_extents (layout, NULL, &extents);

    gint column_width = (int) pango_units_to_double(extents.width)
                        + 2 * slot->directory->icon_size
                        + 2 * slot->mwcols->handle_size
                        + 12;

    gint min_width = slot->mwcols->preferred_column_width / 2;

    if (column_width < min_width)
        column_width = min_width;
    else {
        //TODO make max_width a setting
        gint max_width = 2 * slot->mwcols->preferred_column_width;
        if (column_width > max_width)
            column_width = max_width;
    }

    gtk_paned_set_position (GTK_PANED (slot->hpane), column_width);
    slot->width = column_width;
    gtk_widget_show_all (slot->mwcols->colpane);
    gtk_widget_queue_draw (slot->mwcols->colpane);
}

void
gof_window_slot_columns_add_location (GOFWindowSlot *slot, GFile *location)
{
    gint current_slot_position = 0;
    gint i;
    GList* list_slot = slot->mwcols->slot_list;
    g_return_if_fail (slot->colpane != NULL);
    gtk_container_foreach (GTK_CONTAINER (slot->colpane), (GtkCallback)gtk_widget_destroy, NULL);

    current_slot_position = g_list_index (slot->mwcols->slot_list, slot);

    /* Rebuild list of slots and recalculate total width of slots */
    if(current_slot_position == -1) {
        g_warning ("Can't find the slot you are viewing, this should *not* happen.");
    } else {
        GList *l = NULL;
        slot->mwcols->total_width = 0;
        for(i = 0; i <= current_slot_position; i++) {
            l = g_list_append(l, list_slot->data);
            slot->mwcols->total_width += GOF_WINDOW_SLOT (list_slot->data)->width;
            list_slot = list_slot->next;
        }
        g_list_free (slot->mwcols->slot_list);
        slot->mwcols->slot_list = l;
    }

    slot->mwcols->total_width += slot->width + 10;
    gtk_widget_set_size_request (slot->mwcols->colpane, slot->mwcols->total_width, -1);
    marlin_window_columns_add (slot->mwcols, location);
}

GOFWindowSlot *
gof_window_slot_new (GFile *location, GtkOverlay *ctab)
{
    GOFWindowSlot *slot;
    slot = g_object_new (GOF_WINDOW_TYPE_SLOT, NULL);
    slot->location = g_object_ref (location);
    slot->ctab = ctab;

    slot->directory = gof_directory_async_from_gfile (slot->location);
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
        gtk_widget_destroy(slot->view_box);

    slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_ICON_VIEW,
                                               "window-slot", slot, NULL));
    gtk_box_pack_start(GTK_BOX (slot->content_box), slot->view_box, TRUE, TRUE, 0);

    marlin_view_view_container_set_content ((MarlinViewViewContainer *) slot->ctab, slot->content_box);
    slot->directory->track_longest_name = FALSE;
    gof_directory_async_load (slot->directory);
}

void
gof_window_slot_make_list_view (GOFWindowSlot *slot)
{
    if(slot->view_box != NULL)
        gtk_widget_destroy(slot->view_box);

    slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_LIST_VIEW,
                                               "window-slot", slot, NULL));
    gtk_box_pack_start (GTK_BOX (slot->content_box), slot->view_box, TRUE, TRUE, 0);
    marlin_view_view_container_set_content ((MarlinViewViewContainer *) slot->ctab, slot->content_box);
    slot->directory->track_longest_name = FALSE;
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
    if(slot->view_box != NULL)
        gtk_widget_destroy(slot->view_box);

    slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_COLUMNS_VIEW,
                                               "window-slot", slot, NULL));
    slot->directory->track_longest_name = TRUE;
}


void
gof_window_slot_active (GOFWindowSlot *slot)
{
    g_return_if_fail (GOF_IS_WINDOW_SLOT (slot));
    g_message ("%s slot uri %s", G_STRFUNC, slot->directory->file->uri);
    //g_message ("%s view uri %s", G_STRFUNC, view->details->slot->directory->file->uri);
    if (slot->mwcols != NULL)
        marlin_window_columns_activate_slot (slot->mwcols, slot);
}

void
gof_window_slot_freeze_updates (GOFWindowSlot *slot)
{
    if (slot->mwcols != NULL)
        marlin_window_columns_freeze_updates (slot->mwcols);
    g_object_set (slot->directory, "freeze-update", TRUE, NULL);
}

void
gof_window_slot_unfreeze_updates (GOFWindowSlot *slot)
{
    if (slot->mwcols != NULL)
        marlin_window_columns_unfreeze_updates (slot->mwcols);
    g_object_set (slot->directory, "freeze-update", FALSE, NULL);
}

