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

#ifndef MARLIN_WINDOW_COLUMNS_H
#define MARLIN_WINDOW_COLUMNS_H

#include <gtk/gtk.h>
#include "gof-abstract-slot.h"
#include "pantheon-files-core.h"
//#include "gof-window-slot.h"
#include "marlin-view-window.h"

#define MARLIN_TYPE_WINDOW_COLUMNS	 (marlin_window_columns_get_type())
#define MARLIN_WINDOW_COLUMNS_CLASS(k)     (G_TYPE_CHECK_CLASS_CAST((k), MARLIN_TYPE_WINDOW_COLUMNS, MarlinWindowColumnsClass))
#define MARLIN_WINDOW_COLUMNS(obj)	 (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_WINDOW_COLUMNS, MarlinWindowColumns))
#define MARLIN_IS_WINDOW_COLUMNS(obj)      (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_WINDOW_COLUMNS))
#define MARLIN_IS_WINDOW_COLUMNS_CLASS(k)  (G_TYPE_CHECK_CLASS_TYPE ((k), MARLIN_TYPE_WINDOW_COLUMNS))
#define MARLIN_WINDOW_COLUMNS_GET_CLASS(o) (G_TYPE_INSTANCE_GET_CLASS ((o), MARLIN_TYPE_WINDOW_COLUMNS, MarlinWindowColumnsClass))

typedef struct {
    GOFAbstractSlot parent;

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
    GtkAdjustment *hadj;
    gint handle_size;

    /* Current location. */
    GFile *location;

    GtkOverlay *ctab;
    GOFDirectoryAsync *directory;

    GList *slot;
    GOFWindowSlot *active_slot;

    gint preferred_column_width;
    guint total_width;
} MarlinWindowColumns;

typedef struct {
    GObjectClass parent_class;

    /* wrapped GOFWindowInfo signals, for overloading */
    /*void (* active)   (NautilusWindowSlot *slot);
      void (* inactive) (NautilusWindowSlot *slot);*/
} MarlinWindowColumnsClass;


GType                   marlin_window_columns_get_type (void);

MarlinWindowColumns     *marlin_window_columns_new (GFile *location, GtkOverlay *ctab);
void                    marlin_window_columns_make_view (MarlinWindowColumns *mwcols);
void                    marlin_window_columns_freeze_updates (MarlinWindowColumns *mwcols);
void                    marlin_window_columns_unfreeze_updates (MarlinWindowColumns *mwcols);
void                    marlin_window_columns_active_slot (MarlinWindowColumns *mwcols, GOFWindowSlot *slot);
const gchar             *marlin_window_columns_get_root_uri (MarlinWindowColumns *mwcols);
const gchar             *marlin_window_columns_get_tip_uri (MarlinWindowColumns *mwcols);

#endif /* MARLIN_WINDOW_COLUMNS_H */
