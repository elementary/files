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
    gtk_adjustment_set_value (hadj, gtk_adjustment_get_upper (hadj));
    gtk_adjustment_value_changed (hadj);
}

MarlinWindowColumns *
marlin_window_columns_new (GFile *location, GObject *ctab)
{
    log_printf (LOG_LEVEL_UNDEFINED, "%s %s\n", G_STRFUNC, g_file_get_uri(location));
    MarlinWindowColumns *mwcols;
    mwcols = g_object_new (MARLIN_TYPE_WINDOW_COLUMNS, NULL);
    mwcols->location = g_object_ref (location);
    mwcols->ctab = ctab;

    GOFWindowSlot *slot = gof_window_slot_new (location, mwcols->ctab);
    slot->mwcols = mwcols;
    mwcols->active_slot = slot;

#if 0
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

    GtkAdjustment *hadj;
    hadj = gtk_scrolled_window_get_hadjustment (GTK_SCROLLED_WINDOW (slot->mwcols->view_box));
    
    /* autoscroll Miller Columns */
    g_signal_connect(hadj, "changed", (GCallback) hadj_changed, mwcols);

    gof_window_column_add(slot, slot->view_box);

    //gtk_container_add( GTK_CONTAINER(window), mwcols->view_box);
    //marlin_view_window_set_content (window, mwcols->view_box);
    marlin_view_view_container_set_content (ctab, mwcols->view_box);
#endif
    return mwcols;
}

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

    GtkAdjustment *hadj;
    hadj = gtk_scrolled_window_get_hadjustment (GTK_SCROLLED_WINDOW (slot->mwcols->view_box));
    
    /* autoscroll Miller Columns */
    g_signal_connect(hadj, "changed", (GCallback) hadj_changed, mwcols);

    gof_window_column_add(slot, slot->view_box);

    //gtk_container_add( GTK_CONTAINER(window), mwcols->view_box);
    //marlin_view_window_set_content (window, mwcols->view_box);
    marlin_view_view_container_set_content (mwcols->ctab, mwcols->view_box);
}

void
marlin_window_columns_add (MarlinWindowColumns *mwcols, GFile *location)
{
    GOFWindowSlot *slot = gof_window_slot_new (location, mwcols->ctab);
    gof_window_slot_make_column_view (slot);
    slot->mwcols = mwcols;
    slot->colpane = mwcols->active_slot->colpane;
    //mwcols->active_slot = slot;
    //add_column(mwcols, slot->view_box);
    gof_window_column_add(slot, slot->view_box);
}

static void
marlin_window_columns_init (MarlinWindowColumns *mwcol)
{
#if 0
    GtkWidget *content_box, *eventbox, *extras_vbox, *frame, *hsep;

    content_box = gtk_vbox_new (FALSE, 0);
    slot->content_box = content_box;
    gtk_widget_show (content_box);

    frame = gtk_frame_new (NULL);
    gtk_frame_set_shadow_type (GTK_FRAME (frame), GTK_SHADOW_ETCHED_IN);
    gtk_box_pack_start (GTK_BOX (content_box), frame, TRUE, TRUE, 0);
    gtk_widget_show (frame);

    slot->view_box = gtk_vbox_new (FALSE, 0);
    gtk_container_add (GTK_CONTAINER (frame), slot->view_box);
    gtk_widget_show (slot->view_box);
#endif
    //slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_LIST_VIEW, NULL));
    /*slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_LIST_VIEW,
      "window-slot", slot, NULL));*/
    //gtk_box_pack_start (GTK_BOX (slot->content_box), GTK_WIDGET (slot->list_view->tree), TRUE, TRUE, 0);


    /*GtkWidget *m_scwin;
      m_scwin = gtk_scrolled_window_new(NULL,NULL);
      slot->content_box = m_scwin;
      gtk_scrolled_window_set_policy( GTK_SCROLLED_WINDOW(m_scwin), GTK_POLICY_AUTOMATIC , GTK_POLICY_AUTOMATIC);
      gtk_scrolled_window_set_shadow_type( GTK_SCROLLED_WINDOW(m_scwin), GTK_SHADOW_NONE);*/

    //gtk_container_add( GTK_CONTAINER(m_scwin), GTK_WIDGET (slot->list_view->tree));


#if 0
    eventbox = gtk_event_box_new ();
    slot->extra_location_event_box = eventbox;
    gtk_widget_set_name (eventbox, "nautilus-extra-view-widget");
    gtk_box_pack_start (GTK_BOX (slot->view_box), eventbox, FALSE, FALSE, 0);

    extras_vbox = gtk_vbox_new (FALSE, 6);
    gtk_container_set_border_width (GTK_CONTAINER (extras_vbox), 6);
    slot->extra_location_widgets = extras_vbox;
    gtk_container_add (GTK_CONTAINER (eventbox), extras_vbox);
    gtk_widget_show (extras_vbox);

    hsep = gtk_hseparator_new ();
    gtk_box_pack_start (GTK_BOX (slot->view_box), hsep, FALSE, FALSE, 0);
    slot->extra_location_separator = hsep;

    slot->title = g_strdup (_("Loading..."));
#endif
}

static void
marlin_window_columns_class_init (MarlinWindowColumnsClass *class)
{
    /*class->active = real_active;
      class->inactive = real_inactive;
      class->update_query_editor = real_update_query_editor; */

    G_OBJECT_CLASS (class)->finalize = marlin_window_columns_finalize;
}

/*GOFWindowSlot *
  marlin_window_columns_get_active_slot (MarlinWindowColumns *mwcols)
  {
  return (mwcols->active_slot);
  }*/

GFile *
marlin_window_columns_get_location (MarlinWindowColumns *mwcols)
{
    return mwcols->location;
}

#if 0
void
nautilus_window_slot_remove_extra_location_widgets (NautilusWindowSlot *slot)
{
    gtk_container_foreach (GTK_CONTAINER (slot->extra_location_widgets),
                           remove_all,
                           slot->extra_location_widgets);
    gtk_widget_hide (slot->extra_location_event_box);
    gtk_widget_hide (slot->extra_location_separator);
}

void
nautilus_window_slot_add_extra_location_widget (NautilusWindowSlot *slot,
                                                GtkWidget *widget)
{
    gtk_box_pack_start (GTK_BOX (slot->extra_location_widgets),
                        widget, TRUE, TRUE, 0);
    gtk_widget_show (slot->extra_location_event_box);
    gtk_widget_show (slot->extra_location_separator);
}

void
nautilus_window_slot_add_current_location_to_history_list (NautilusWindowSlot *slot)
{

    if ((slot->pane->window == NULL || !NAUTILUS_IS_DESKTOP_WINDOW (slot->pane->window)) &&
        nautilus_add_bookmark_to_history_list (slot->current_location_bookmark)) {
        nautilus_send_history_list_changed ();
    }
}
#endif

static void
marlin_window_columns_finalize (GObject *object)
{
    //MarlinWindowColumns *mwcols = MARLIN_WINDOW_COLUMNS (object);

    G_OBJECT_CLASS (parent_class)->finalize (object);

#if 0
    GtkWidget *widget;

    if (slot->content_view) {
        widget = nautilus_view_get_widget (slot->content_view);
        gtk_widget_destroy (widget);
        g_object_unref (slot->content_view);
        slot->content_view = NULL;
    }

    if (slot->new_content_view) {
        widget = nautilus_view_get_widget (slot->new_content_view);
        gtk_widget_destroy (widget);
        g_object_unref (slot->new_content_view);
        slot->new_content_view = NULL;
    }

    nautilus_window_slot_set_viewed_file (slot, NULL);
    /* TODO? why do we unref here? the file is NULL.
     * It was already here before the slot move, though */
    nautilus_file_unref (slot->viewed_file);


    eel_g_list_free_deep (slot->pending_selection);
    slot->pending_selection = NULL;

    g_free (slot->title);
    slot->title = NULL;

    g_free (slot->status_text);
    slot->status_text = NULL;
#endif
    //G_OBJECT_CLASS (parent_class)->dispose (object);
}

