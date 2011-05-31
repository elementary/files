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

#include "marlin-window-columns.h"
#include <gdk/gdkkeysyms.h>
//#include "gof-directory-async.h"
//#include "fm-list-view.h"
#include "fm-columns-view.h"

/*static void gof_window_slot_init       (GOFWindowSlot *slot);
  static void gof_window_slot_class_init (GOFWindowSlotClass *class);
  static void gof_window_slot_finalize   (GObject *object);*/
static void marlin_window_columns_finalize   (GObject *object);

G_DEFINE_TYPE (MarlinWindowColumns, marlin_window_columns, G_TYPE_OBJECT)

#define parent_class marlin_window_columns_parent_class

static void
hadj_changed (GtkAdjustment *hadj, gpointer user_data)
{
    MarlinWindowColumns *mwcols = MARLIN_WINDOW_COLUMNS (user_data);
    marlin_animation_smooth_adjustment_upper(hadj);
    gtk_adjustment_value_changed (hadj);
}

/**
 * Handle key release events, like the left and right keys to change the
 * active column. It is a GObject callback.
 **/
static gboolean marlin_window_columns_key_pressed(GtkWidget* box, GdkEventKey* event, MarlinWindowColumns* mwcols)
{
    GOFWindowSlot* to_active = NULL;
    /* The active slot position in the GList where there are all the slots */
    int active_position = 0;
    switch(event->keyval)
    {
    case GDK_KEY_Left:
        active_position = g_list_index(mwcols->slot, mwcols->active_slot);
        /* Get previous file list to grab_focus on it */
        if(active_position > 0)
        {
            to_active = GOF_WINDOW_SLOT(g_list_nth_data(mwcols->slot, active_position-1));
        }
        /* If it has been found in the GList mwcols->slot (and if it is not the first) */
        if(to_active != NULL)
        {
            gtk_widget_grab_focus(to_active->view_box);
            printf("GRAB FOCUS on : %d\n", active_position-1);
            mwcols->active_slot = to_active;
            return TRUE;
        }
        break;

    case GDK_KEY_Right:
        active_position = g_list_index(mwcols->slot, mwcols->active_slot);
        /* Get previous file list to grab_focus on it */
        if(active_position < g_list_length(mwcols->slot))
        {
            to_active =  GOF_WINDOW_SLOT(g_list_nth_data(mwcols->slot, active_position+1));
        }
        if(to_active != NULL)
        {
            gtk_widget_grab_focus(to_active->view_box);
            printf("GRAB FOCUS on : %d\n", active_position+1);
            mwcols->active_slot = to_active;
            return TRUE;
        }
        break;
    }

    return FALSE;
}

/**
 * Create a new MarlinWindowColumns
 *
 * @param location: a GFile, it is the location where you want start your
 * MarlinWindowColumns
 *
 * @param ctab: TODO: What is it?
 *
 **/
MarlinWindowColumns *
marlin_window_columns_new (GFile *location, GObject *ctab)
{
    g_message ("%s %s\n", G_STRFUNC, g_file_get_uri(location));
    MarlinWindowColumns *mwcols;
    mwcols = g_object_new (MARLIN_TYPE_WINDOW_COLUMNS, NULL);
    mwcols->location = g_object_ref (location);
    mwcols->ctab = ctab;

    GOFWindowSlot *slot = gof_window_slot_new (location, mwcols->ctab);
    slot->mwcols = mwcols;
    mwcols->active_slot = slot;
    mwcols->slot = g_list_append(mwcols->slot, slot);
    return mwcols;
}

/**
 * TODO: doc
 **/
void
marlin_window_columns_make_view (MarlinWindowColumns *mwcols)
{
    GOFWindowSlot *slot = mwcols->active_slot;

    gof_window_slot_make_column_view (slot);

    mwcols->colpane = gtk_hbox_new (FALSE, 0);
    slot->colpane = mwcols->colpane;
    gtk_widget_show (mwcols->colpane);
    mwcols->view_box = gtk_scrolled_window_new (0, 0);
    GtkWidget *viewport = gtk_viewport_new (0, 0);
    gtk_viewport_set_shadow_type (GTK_VIEWPORT (viewport), GTK_SHADOW_NONE);
    gtk_container_add (GTK_CONTAINER (viewport), mwcols->colpane);
    gtk_widget_show (viewport);
    gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (mwcols->view_box),
                                    GTK_POLICY_AUTOMATIC,
                                    GTK_POLICY_NEVER);
    gtk_widget_show (mwcols->view_box);
    gtk_container_add (GTK_CONTAINER (mwcols->view_box), viewport);

    mwcols->hadj = gtk_scrolled_window_get_hadjustment (GTK_SCROLLED_WINDOW (slot->mwcols->view_box));

    /* autoscroll Miller Columns */
    g_signal_connect(mwcols->hadj, "changed", (GCallback) hadj_changed, mwcols);

    gof_window_column_add(slot, slot->view_box);

    marlin_view_view_container_set_content (mwcols->ctab, mwcols->view_box);
    
    /* Left/Right events */
    gtk_widget_add_events (GTK_WIDGET(mwcols->colpane), GDK_KEY_RELEASE_MASK);
    g_signal_connect(mwcols->colpane, "key_release_event", (GCallback)marlin_window_columns_key_pressed, mwcols);
}

/**
 * Add a new column
 **/
void
marlin_window_columns_add_location (MarlinWindowColumns *mwcols, GFile *location)
{
    gof_window_columns_add_location(mwcols->active_slot, location);
}
/**
 * Add a new column
 **/
void
marlin_window_columns_add (MarlinWindowColumns *mwcols, GFile *location)
{
    GOFWindowSlot *slot = gof_window_slot_new (location, mwcols->ctab);
    gof_window_slot_make_column_view (slot);
    slot->mwcols = mwcols;
    slot->colpane = mwcols->active_slot->colpane;
    gof_window_column_add(slot, slot->view_box);
    //mwcols->active_slot = slot;
    /* Add it in our GList */
    mwcols->slot = g_list_append(mwcols->slot, slot);
    //gtk_widget_grab_focus(slot->view_box);
}

static void
marlin_window_columns_init (MarlinWindowColumns *mwcol)
{
}

static void
marlin_window_columns_class_init (MarlinWindowColumnsClass *class)
{
    G_OBJECT_CLASS (class)->finalize = marlin_window_columns_finalize;
}

GFile *
marlin_window_columns_get_location (MarlinWindowColumns *mwcols)
{
    return mwcols->location;
}

static void
marlin_window_columns_finalize (GObject *object)
{
    MarlinWindowColumns *mwcols = MARLIN_WINDOW_COLUMNS (object);
    g_message ("%s\n", G_STRFUNC);

    g_signal_handlers_disconnect_by_func (mwcols->colpane,
                                          G_CALLBACK (marlin_window_columns_key_pressed),
                                          mwcols);

    g_object_unref(mwcols->location);

    G_OBJECT_CLASS (parent_class)->finalize (object);
}

void
marlin_window_columns_freeze_updates (MarlinWindowColumns *mwcols)
{
    /* block key release events to not interfere while we rename a file 
    with the editing widget */
    g_signal_handlers_block_by_func (mwcols->colpane, marlin_window_columns_key_pressed, mwcols);
}

void
marlin_window_columns_unfreeze_updates (MarlinWindowColumns *mwcols)
{
    /* unblock key release events to not interfere while we rename a file 
    with the editing widget */
    g_signal_handlers_unblock_by_func (mwcols->colpane, marlin_window_columns_key_pressed, mwcols);
}

