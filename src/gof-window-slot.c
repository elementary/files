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

#if 0
static void
real_active (NautilusWindowSlot *slot)
{
	NautilusWindow *window;

	window = slot->pane->window;

	/* sync window to new slot */
	nautilus_window_sync_status (window);
	nautilus_window_sync_allow_stop (window, slot);
	nautilus_window_sync_title (window, slot);
	nautilus_window_sync_zoom_widgets (window);
	nautilus_window_pane_sync_location_widgets (slot->pane);
	nautilus_window_pane_sync_search_widgets (slot->pane);

	if (slot->viewed_file != NULL) {
		nautilus_window_load_view_as_menus (window);
		nautilus_window_load_extension_menus (window);
	}
}

static void
nautilus_window_slot_active (NautilusWindowSlot *slot)
{
	NautilusWindow *window;
	NautilusWindowPane *pane;

	g_assert (NAUTILUS_IS_WINDOW_SLOT (slot));

	pane = NAUTILUS_WINDOW_PANE (slot->pane);
	window = NAUTILUS_WINDOW (slot->pane->window);
	g_assert (g_list_find (pane->slots, slot) != NULL);
	g_assert (slot == window->details->active_pane->active_slot);

	EEL_CALL_METHOD (NAUTILUS_WINDOW_SLOT_CLASS, slot,
			 active, (slot));
}

static void
real_inactive (NautilusWindowSlot *slot)
{
	NautilusWindow *window;

	window = NAUTILUS_WINDOW (slot->pane->window);
	g_assert (slot == window->details->active_pane->active_slot);
}

static void
nautilus_window_slot_inactive (NautilusWindowSlot *slot)
{
	NautilusWindow *window;
	NautilusWindowPane *pane;

	g_assert (NAUTILUS_IS_WINDOW_SLOT (slot));

	pane = NAUTILUS_WINDOW_PANE (slot->pane);
	window = NAUTILUS_WINDOW (pane->window);

	g_assert (g_list_find (pane->slots, slot) != NULL);
	g_assert (slot == window->details->active_pane->active_slot);

	EEL_CALL_METHOD (NAUTILUS_WINDOW_SLOT_CLASS, slot,
			 inactive, (slot));
}
#endif

#if 0
void
gof_window_slot_change_location (GOFWindowSlot *slot, GFile *location)
{
        GtkWidget *window = slot->window;

        //TODO add if not end loaded
        load_dir_async_cancel(slot->directory);
        /*g_object_unref(slot->directory);
        g_object_unref(slot->location);*/
        //g_object_unref(slot->list_view);
        //gtk_widget_destroy (slot->view_box);
     
        slot = gof_window_slot_new (location, GTK_WIDGET (window));
        //marlin_window_set_active_slot (MARLIN_WINDOW (window), slot);

        /*slot->location = location;
        slot->directory = gof_directory_async_new(location);
        slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_LIST_VIEW,
                                                   "window-slot", slot, NULL));*/
        /*slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_COLUMNS_VIEW,
                                                   "window-slot", slot, NULL));*/
        //gtk_container_add( GTK_CONTAINER(slot->window), GTK_WIDGET (slot->view_box));
        //gtk_widget_show(slot->view_box);
        //gtk_widget_show_all(slot->view_box);
        //load_dir_async (slot->directory);
}
#endif

void
gof_window_column_add (GOFWindowSlot *slot, GtkWidget *column)
{
        //GtkWidget *scrolled;

        GtkWidget *hpane = gtk_hpaned_new();
        gtk_widget_show (hpane);
        //gtk_paned_set_position(GTK_PANED (hpane), 200);
        gtk_container_add(GTK_CONTAINER(slot->colpane), hpane);
        //gtk_box_pack_end(GTK_BOX(slot->colpane), hpane, TRUE, FALSE, 0);
        GtkWidget *vbox2 = gtk_hbox_new(FALSE, 0);
        gtk_widget_show (vbox2);
        slot->colpane = vbox2;
        slot->hpane = hpane;

        /*scrolled = gtk_scrolled_window_new(0, 0);
        gtk_widget_show(scrolled);
        gtk_scrolled_window_add_with_viewport(GTK_SCROLLED_WINDOW (scrolled), column);
        gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (scrolled),
                                        GTK_POLICY_NEVER,
                                        GTK_POLICY_AUTOMATIC);*/
        //gtk_container_add(GTK_CONTAINER(scrolled), column);
        gtk_widget_set_size_request (column, 180,-1);

        gtk_paned_pack1 (GTK_PANED (hpane), column, FALSE, FALSE);
        //gtk_paned_pack1 (GTK_PANED (hpane), column, TRUE, TRUE);
        //gtk_paned_pack1 (GTK_PANED (hpane), scrolled, FALSE, FALSE);
        gtk_paned_pack2 (GTK_PANED (hpane), vbox2, TRUE, FALSE);
}

void
gof_window_columns_add_location (GOFWindowSlot *slot, GFile *location)
{
        printf ("%s\n", G_STRFUNC);
        slot->mwcols->active_slot = slot;
        //GList *childs = gtk_container_get_children (slot->colpane);
        gtk_container_foreach (GTK_CONTAINER (slot->colpane), (GtkCallback)gtk_widget_destroy, NULL);
        marlin_window_columns_add (slot->mwcols, location);
        /*GOFWindowSlot *slot = gof_window_slot_column_new (location);
        slot->mwcols = mwcols;
        mwcols->active_slot = slot;
        add_column(mwcols, slot->view_box);*/
}

void
gof_window_columns_add_preview (GOFWindowSlot *slot, GFile *location)
{
        printf ("%s\n", G_STRFUNC);
        gtk_container_foreach (GTK_CONTAINER (slot->colpane), (GtkCallback)gtk_widget_destroy, NULL);
}

static void
gof_window_slot_finalize (GObject *object)
{
        printf ("%s\n", G_STRFUNC);
	GOFWindowSlot *slot = GOF_WINDOW_SLOT (object);
        
        //load_dir_async_cancel(slot->directory);
        g_object_unref(slot->directory);
        /*g_object_unref(slot->location);*/
        G_OBJECT_CLASS (parent_class)->finalize (object);
}

GOFWindowSlot *
gof_window_slot_new (GFile *location, GObject *ctab)
{
        printf("%s\n", G_STRFUNC);
        GOFWindowSlot *slot;
        slot = g_object_new (GOF_TYPE_WINDOW_SLOT, NULL);
        slot->location = location;
        slot->ctab = ctab;
        
        slot->directory = gof_directory_async_new(slot->location);
        slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_LIST_VIEW,
                                                   "window-slot", slot, NULL));
        //marlin_window_set_active_slot (MARLIN_WINDOW (window), slot);
        //marlin_view_window_set_active_slot (MARLIN_VIEW_WINDOW (window), slot);
#if 0
        slot->colpane = gtk_hbox_new (FALSE, 0);
        gtk_widget_show (slot->colpane);
        slot->view_box = gtk_scrolled_window_new(0, 0);

        //gtk_container_add (GTK_CONTAINER (view), hpane);
        //gtk_container_add (GTK_CONTAINER (slot->view_box), slot->colpane);
        gtk_scrolled_window_add_with_viewport(GTK_SCROLLED_WINDOW (slot->view_box), slot->colpane);
        gtk_scrolled_window_set_policy (GTK_SCROLLED_WINDOW (slot->view_box),
                                        GTK_POLICY_AUTOMATIC,
                                        GTK_POLICY_NEVER);
        /*add_column(slot, GTK_WIDGET (g_object_new (FM_TYPE_COLUMNS_VIEW,
                                                   "window-slot", slot, NULL)));*/
        /*slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_COLUMNS_VIEW,
                                                   "window-slot", slot, NULL));*/
        gtk_widget_show (slot->view_box);

        /*int i;
        for (i=0; i<4; i++) {
                GtkWidget *test = gtk_label_new ("test");
                //gtk_widget_set_size_request(test, 100,-1);
                gtk_widget_show(test);
                add_column(slot, test);
        }*/
#endif
        /*gtk_container_add( GTK_CONTAINER(window), slot->view_box);*/
        //marlin_view_window_set_content (window, slot->view_box);
        marlin_view_view_container_set_content (ctab, slot->view_box);
        load_dir_async (slot->directory);


        return slot;
}

GOFWindowSlot *
gof_window_slot_column_new (GFile *location, GObject *ctab)
{
        printf("%s\n", G_STRFUNC);
        GOFWindowSlot *slot;
        slot = g_object_new (GOF_TYPE_WINDOW_SLOT, NULL);
        slot->location = location;
        slot->ctab = ctab;
        
        slot->directory = gof_directory_async_new(slot->location);
        slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_COLUMNS_VIEW,
                                                   "window-slot", slot, NULL));
        load_dir_async (slot->directory);

        return slot;
}

#if 0
GOFWindowSlot *
gof_window_slot_column_new (GFile *location, GtkWidget *window)
{
        printf("%s\n", G_STRFUNC);
        GOFWindowSlot *slot;
        slot = g_object_new (GOF_TYPE_WINDOW_SLOT, NULL);
        slot->location = location;
        slot->window = window;
        
        slot->directory = gof_directory_async_new(slot->location);
        slot->view_box = GTK_WIDGET (g_object_new (FM_TYPE_COLUMNS_VIEW,
                                                   "window-slot", slot, NULL));
        load_dir_async (slot->directory);

        return slot;
}
#endif

static void
gof_window_slot_init (GOFWindowSlot *slot)
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
gof_window_slot_class_init (GOFWindowSlotClass *class)
{
	/*class->active = real_active;
	class->inactive = real_inactive;
	class->update_query_editor = real_update_query_editor; */

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

#if 0
char *
nautilus_window_slot_get_title (GOFWindowSlot *slot)
{
	g_assert (GOF_IS_WINDOW_SLOT (slot));

	if (slot->content_view != NULL) {
		title = nautilus_view_get_title (slot->content_view);
	}

	if (title == NULL) {
		title = nautilus_compute_title_for_location (slot->location);
	}

	return title;
}
#endif

#if 0
/* nautilus_window_slot_update_icon:
 * 
 * Re-calculate the slot icon
 * Called when the location or view or icon set has changed.
 * @slot: The NautilusWindowSlot in question.
 */
void
nautilus_window_slot_update_icon (NautilusWindowSlot *slot)
{
	NautilusWindow *window;
	NautilusIconInfo *info;
	const char *icon_name;
	GdkPixbuf *pixbuf;

	window = slot->pane->window;

	g_return_if_fail (NAUTILUS_IS_WINDOW (window));

	info = EEL_CALL_METHOD_WITH_RETURN_VALUE (NAUTILUS_WINDOW_CLASS, window,
						 get_icon, (window, slot));

	icon_name = NULL;
	if (info) {
		icon_name = nautilus_icon_info_get_used_name (info);
		if (icon_name != NULL) {
			/* Gtk+ doesn't short circuit this (yet), so avoid lots of work
			 * if we're setting to the same icon. This happens a lot e.g. when
			 * the trash directory changes due to the file count changing.
			 */
			if (g_strcmp0 (icon_name, gtk_window_get_icon_name (GTK_WINDOW (window))) != 0) {			
				gtk_window_set_icon_name (GTK_WINDOW (window), icon_name);
			}
		} else {
			pixbuf = nautilus_icon_info_get_pixbuf_nodefault (info);
			
			if (pixbuf) {
				gtk_window_set_icon (GTK_WINDOW (window), pixbuf);
				g_object_unref (pixbuf);
			} 
		}
		
		g_object_unref (info);
	}
}
#endif

#if 0
static void
remove_all (GtkWidget *widget,
	    gpointer data)
{
	GtkContainer *container;
	container = GTK_CONTAINER (data);

	gtk_container_remove (container, widget);
}

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

GtkWidget *
gof_window_slot_get_view (GOFWindowSlot *slot)
{
        return (slot->view_box);
}

