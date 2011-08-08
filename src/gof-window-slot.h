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
#include "gof-abstract-slot.h"
#include "gof-directory-async.h"
#include "marlin-window-columns.h"

#define GOF_TYPE_WINDOW_SLOT	 (gof_window_slot_get_type())
#define GOF_WINDOW_SLOT_CLASS(k)     (G_TYPE_CHECK_CLASS_CAST((k), GOF_TYPE_WINDOW_SLOT, GOFWindowSlotClass))
#define GOF_WINDOW_SLOT(obj)	 (G_TYPE_CHECK_INSTANCE_CAST ((obj), GOF_TYPE_WINDOW_SLOT, GOFWindowSlot))
#define GOF_IS_WINDOW_SLOT(obj)      (G_TYPE_CHECK_INSTANCE_TYPE ((obj), GOF_TYPE_WINDOW_SLOT))
#define GOF_IS_WINDOW_SLOT_CLASS(k)  (G_TYPE_CHECK_CLASS_TYPE ((k), GOF_TYPE_WINDOW_SLOT))
#define GOF_WINDOW_SLOT_GET_CLASS(o) (G_TYPE_INSTANCE_GET_CLASS ((o), GOF_TYPE_WINDOW_SLOT, GOFWindowSlotClass))

struct GOFWindowSlot {
    GOFAbstractSlot parent;

    /* content_box contains
     *  1) an event box containing extra_location_widgets
     *  2) the view box for the content view
     */
    GtkWidget *content_box;
    /*GtkWidget *extra_location_event_box;*/
      /*GtkWidget *extra_location_separator;*/
    GtkWidget *view_box;
    GtkWidget *colpane;
    GtkWidget *hpane;

    /* Current location. */
    GFile *location;

    //GtkWidget *window;
    GtkEventBox *ctab;
    GOFDirectoryAsync *directory;

    MarlinWindowColumns *mwcols;
};

struct GOFWindowSlotClass {
    GObjectClass parent_class;

    /* wrapped GOFWindowInfo signals, for overloading */
    void (* active)   (GOFWindowSlot *slot);
    void (* inactive) (GOFWindowSlot *slot);
};


GType           gof_window_slot_get_type (void);

GOFWindowSlot   *gof_window_slot_new (GFile *location, GtkEventBox *ctab);

void            gof_window_column_add (GOFWindowSlot *slot, GtkWidget *column);
void            gof_window_columns_add_location (GOFWindowSlot *slot, GFile *location);
void            gof_window_columns_add_preview (GOFWindowSlot *slot, GtkWidget *context_view);

void            gof_window_slot_make_icon_view (GOFWindowSlot *slot);
void            gof_window_slot_make_list_view (GOFWindowSlot *slot);
void            gof_window_slot_make_column_view (GOFWindowSlot *slot);

void            gof_window_slot_freeze_updates (GOFWindowSlot *slot);
void            gof_window_slot_unfreeze_updates (GOFWindowSlot *slot);

#endif /* GOF_WINDOW_SLOT_H */
