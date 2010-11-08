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

#ifndef FM_COLUMNS_VIEW_H
#define FM_COLUMNS_VIEW_H

#include <gtk/gtk.h>
#include "fm-list-model.h"
//#include "gof-window-slot.h"
#include "fm-directory-view.h"

G_BEGIN_DECLS

#define FM_TYPE_COLUMNS_VIEW fm_columns_view_get_type()
#define FM_COLUMNS_VIEW(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST ((obj), FM_TYPE_COLUMNS_VIEW, FMColumnsView))
#define FM_COLUMNS_VIEW_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_CAST ((klass), FM_TYPE_COLUMNS_VIEW, FMColumnsViewClass))
#define FM_IS_COLUMNS_VIEW(obj) \
  (G_TYPE_CHECK_INSTANCE_TYPE ((obj), FM_TYPE_COLUMNS_VIEW))
#define FM_IS_COLUMNS_VIEW_CLASS(klass) \
  (G_TYPE_CHECK_CLASS_TYPE ((klass), FM_TYPE_COLUMNS_VIEW))
#define FM_COLUMNS_VIEW_GET_CLASS(obj) \
  (G_TYPE_INSTANCE_GET_CLASS ((obj), FM_TYPE_COLUMNS_VIEW, FMColumnsViewClass))

#define FM_COLUMNS_VIEW_ID "OAFIID:Nautilus_File_Manager_Column_View"

typedef struct FMColumnsViewDetails FMColumnsViewDetails;

typedef struct {
        FMDirectoryViewClass parent_instance;
        GtkTreeView     *tree;
       	FMListModel     *model;
        //GFile           *location;
        //GOFWindowSlot   *slot;
       	//FMColumnsViewDetails *details;
} FMColumnsView;

typedef struct {
        FMDirectoryViewClass parent_class;
} FMColumnsViewClass;

GType fm_columns_view_get_type (void);
/*void  fm_list_view_register (void);*/
/*GtkTreeView* fm_list_view_get_tree_view (FMColumnsView *list_view);*/

G_END_DECLS

#endif /* FM_COLUMNS_VIEW_H */
