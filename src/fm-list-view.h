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

#ifndef FM_LIST_VIEW_H
#define FM_LIST_VIEW_H

#include <gtk/gtk.h>
#include "fm-list-model.h"
#include "fm-directory-view.h"

G_BEGIN_DECLS

#define FM_TYPE_LIST_VIEW fm_list_view_get_type()
#define FM_LIST_VIEW(obj) \
    (G_TYPE_CHECK_INSTANCE_CAST ((obj), FM_TYPE_LIST_VIEW, FMListView))
#define FM_LIST_VIEW_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_CAST ((klass), FM_TYPE_LIST_VIEW, FMListViewClass))
#define FM_IS_LIST_VIEW(obj) \
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), FM_TYPE_LIST_VIEW))
#define FM_IS_LIST_VIEW_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_TYPE ((klass), FM_TYPE_LIST_VIEW))
#define FM_LIST_VIEW_GET_CLASS(obj) \
    (G_TYPE_INSTANCE_GET_CLASS ((obj), FM_TYPE_LIST_VIEW, FMListViewClass))

typedef struct FMListViewDetails FMListViewDetails;

typedef struct {
    FMDirectoryViewClass parent_instance;
    GtkTreeView         *tree;
    FMListModel         *model;

    FMListViewDetails   *details;
    //GList               *loaded_subdirectories;
} FMListView;

typedef struct {
    FMDirectoryViewClass parent_class;
} FMListViewClass;

GType fm_list_view_get_type (void);

G_END_DECLS

#endif /* FM_LIST_VIEW_H */
