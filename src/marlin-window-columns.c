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
#include "marlin-global-preferences.h"
#include "marlin-vala.h"
#include "fm-directory-view.h"

static void marlin_window_columns_finalize   (GObject *object);
void marlin_window_columns_activate_slot (MarlinWindowColumns *mwcols, GOFWindowSlot *slot);

G_DEFINE_TYPE (MarlinWindowColumns, marlin_window_columns, GOF_TYPE_ABSTRACT_SLOT)
#define parent_class marlin_window_columns_parent_class

/**
 * Handle key release events, like the left and right keys to change the
 * active column.
 **/
static gboolean marlin_window_columns_key_pressed (GtkWidget* box, GdkEventKey* event, MarlinWindowColumns* mwcols)
{
    GOFWindowSlot* to_active = NULL;
    /* The active slot position in the GList where there are all the slots */
    int active_position = 0;

    switch(event->keyval)
    {
    case GDK_KEY_Left:
        active_position = g_list_index(mwcols->slot_list, mwcols->active_slot);

        if (active_position > 0)
            to_active = GOF_WINDOW_SLOT(g_list_nth_data(mwcols->slot_list, active_position-1));

        if (to_active == NULL || !GOF_IS_WINDOW_SLOT (to_active))
            break;

        g_signal_emit_by_name (to_active->ctab, "path-changed", to_active->directory->location, to_active);
        return TRUE;

    case GDK_KEY_Right:
        active_position = g_list_index(mwcols->slot_list, mwcols->active_slot);

        GList* selection;
        GOFWindowSlot* active = mwcols->active_slot;
        GtkWidget* view = active->view_box;
        GFile* selected_location = NULL;
        selection = (*FM_DIRECTORY_VIEW_GET_CLASS (view)->get_selection) (view);

        /* Only take action if just one selection and it is a directory*/
        if (selection != NULL && g_list_length (selection) == 1 && gof_file_is_folder (GOF_FILE (selection->data)))
            selected_location = gof_file_get_target_location (GOF_FILE (selection->data));
        else
            break;

        if (active_position < g_list_length(mwcols->slot_list) - 1)
            to_active =  GOF_WINDOW_SLOT(g_list_nth_data(mwcols->slot_list, active_position + 1));

        /* If no slot to activate or the locations do not match, open a new slot */
        if (to_active == NULL || !GOF_IS_WINDOW_SLOT (to_active)
         || !g_file_equal (to_active->directory->location, selected_location))
            g_signal_emit_by_name (active->ctab, "path-changed", selected_location, active);
        else
        /* activate existing slot */
            g_signal_emit_by_name (to_active->ctab, "path-changed", to_active->directory->location, to_active);

        return TRUE;
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
marlin_window_columns_new (GFile *location, GtkOverlay *ctab)
{
    g_debug ("%s %s\n", G_STRFUNC, g_file_get_uri(location));
    MarlinWindowColumns *mwcols;
    mwcols = g_object_new (MARLIN_TYPE_WINDOW_COLUMNS, NULL);
    mwcols->location = g_object_ref (location);
    mwcols->ctab = ctab;

    GOFWindowSlot *slot = gof_window_slot_new (location, mwcols->ctab);
    slot->mwcols = mwcols;
    slot->slot_number = 0;
    mwcols->active_slot = slot;
    mwcols->slot_list = g_list_append(mwcols->slot_list, slot);
    return mwcols;
}

/**
 * TODO: doc
 **/
void
marlin_window_columns_make_view (MarlinWindowColumns *mwcols)
{
    mwcols->colpane = gtk_box_new (GTK_ORIENTATION_HORIZONTAL, 0);
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
    gtk_box_pack_start(GTK_BOX (mwcols->content_box), mwcols->view_box, TRUE, TRUE, 0);
    marlin_view_view_container_set_content ((MarlinViewViewContainer *) mwcols->ctab, mwcols->content_box);
    mwcols->hadj = gtk_scrolled_window_get_hadjustment (GTK_SCROLLED_WINDOW (mwcols->view_box));

    GOFWindowSlot *slot = mwcols->active_slot;
    gof_window_slot_make_column_view (slot);
    slot->colpane = mwcols->colpane;
    gof_window_column_add (slot, slot->view_box);

    /* store pane handle size*/
    gtk_widget_style_get (GTK_WIDGET (slot->hpane), "handle-size", &mwcols->handle_size, NULL);

    /* Left/Right events */
    gtk_widget_add_events (GTK_WIDGET(mwcols->colpane), GDK_KEY_RELEASE_MASK);
    g_signal_connect (mwcols->colpane, "key_release_event", (GCallback)marlin_window_columns_key_pressed, mwcols);
}

/**
 * Add a new column
 **/
void
marlin_window_columns_add_location (MarlinWindowColumns *mwcols, GFile *location)
{
    gof_window_slot_columns_add_location(mwcols->active_slot, location);
}
/**
 * Add a new column
 **/
void
marlin_window_columns_add (MarlinWindowColumns *mwcols, GFile *location)
{
    GOFWindowSlot *slot = gof_window_slot_new (location, mwcols->ctab);
    slot->width = mwcols->preferred_column_width;
    gof_window_slot_make_column_view (slot);
    slot->slot_number = mwcols->active_slot->slot_number + 1;
    slot->mwcols = mwcols;
    slot->colpane = mwcols->active_slot->colpane;
    gof_window_column_add (slot, slot->view_box);

    /* Add it in our GList */
    mwcols->slot_list = g_list_append(mwcols->slot_list, slot);
    //marlin_window_columns_activate_slot (mwcols, slot);
}

void
marlin_window_columns_activate_slot (MarlinWindowColumns *mwcols, GOFWindowSlot *slot)
{
    GList *l;
    int slot_indice, i;
    GOFWindowSlot *other_slot;
    guint width = 0;
    gboolean sum_completed = FALSE;

    g_return_if_fail (MARLIN_IS_WINDOW_COLUMNS (mwcols));
    g_return_if_fail (GOF_IS_WINDOW_SLOT (slot));

    for (i = 0, l = mwcols->slot_list; l != NULL; l = l->next, i++) {
        other_slot = GOF_WINDOW_SLOT (l->data);

        if (other_slot != slot)
            g_signal_emit_by_name (other_slot, "inactive");
         else
        {
            slot_indice = i;
            sum_completed = TRUE;
        }

        if (!sum_completed) {
            width += other_slot->width;
        }
    }

    mwcols->active_slot = slot;
    g_signal_emit_by_name (slot, "active");

    /* autoscroll Miller Columns */
    marlin_animation_smooth_adjustment_to (mwcols->hadj, width + slot_indice * mwcols->handle_size);
}

void
show_hidden_files_changed (GOFPreferences *prefs, GParamSpec *pspec, MarlinWindowColumns *mwcols)
{
    if (!prefs->pref_show_hidden_files) {
        /* we are hiding hidden files - check whether any slot is a hidden directory */
        GList *l;
        guint i;
        GOFDirectoryAsync *dir;

        for (i = 0, l = mwcols->slot_list; l != NULL; l = l->next, i++) {
            dir = GOF_WINDOW_SLOT (l->data)->directory;
            if (dir->file->is_hidden)
                break;
        }

        if (l == NULL || i == 0) {
            /* no hidden folder found or first folder hidden */
            return;
        }

        /* find last slot that is not a showing hidden folder */
        l = l->prev;

        GOFWindowSlot *slot = GOF_WINDOW_SLOT (l->data)->view_box;

        /* make the selected slot active and remove subsequent slots*/
        FMDirectoryView *view = FM_DIRECTORY_VIEW (slot);
        fm_directory_view_set_active_slot (view);
        //marlin_window_columns_activate_slot (mwcols, slot);
        gtk_container_foreach (GTK_CONTAINER (mwcols->active_slot->colpane), (GtkCallback) gtk_widget_destroy, NULL);
    }
}

static void
marlin_window_columns_init (MarlinWindowColumns *mwcol)
{
    mwcol->preferred_column_width = g_settings_get_int (marlin_column_view_settings, "preferred-column-width");
    mwcol->total_width = 0;
    mwcol->content_box = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);
    GOF_ABSTRACT_SLOT(mwcol)->extra_location_widgets = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_box_pack_start(GTK_BOX (mwcol->content_box), GOF_ABSTRACT_SLOT(mwcol)->extra_location_widgets, FALSE, FALSE, 0);

    g_signal_connect_object (gof_preferences_get_default (), "notify::show-hidden-files",
                                 G_CALLBACK (show_hidden_files_changed), mwcol, 0);
}

static void
marlin_window_columns_class_init (MarlinWindowColumnsClass *class)
{
    G_OBJECT_CLASS (class)->finalize = marlin_window_columns_finalize;
}

static void
marlin_window_columns_finalize (GObject *object)
{
    MarlinWindowColumns *mwcols = MARLIN_WINDOW_COLUMNS (object);
    g_debug ("%s\n", G_STRFUNC);

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

