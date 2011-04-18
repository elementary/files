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

#ifndef FM_ICON_VIEW_H
#define FM_ICON_VIEW_H

#include <gtk/gtk.h>
#include "exo-icon-view.h"
#include "fm-list-model.h"
#include "fm-directory-view.h"

G_BEGIN_DECLS

#define FM_TYPE_ICON_VIEW fm_icon_view_get_type()
#define FM_ICON_VIEW(obj) \
    (G_TYPE_CHECK_INSTANCE_CAST ((obj), FM_TYPE_ICON_VIEW, FMIconView))
#define FM_ICON_VIEW_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_CAST ((klass), FM_TYPE_ICON_VIEW, FMIconViewClass))
#define FM_IS_ICON_VIEW(obj) \
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), FM_TYPE_ICON_VIEW))
#define FM_IS_ICON_VIEW_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_TYPE ((klass), FM_TYPE_ICON_VIEW))
#define FM_ICON_VIEW_GET_CLASS(obj) \
    (G_TYPE_INSTANCE_GET_CLASS ((obj), FM_TYPE_ICON_VIEW, FMIconViewClass))

typedef struct FMIconViewDetails FMIconViewDetails;

typedef struct {
    FMDirectoryViewClass parent_instance;
    ExoIconView         *icons;
    FMListModel         *model;
    FMIconViewDetails   *details;
} FMIconView;

typedef struct {
    FMDirectoryViewClass parent_class;
} FMIconViewClass;

GType fm_icon_view_get_type (void);

G_END_DECLS

#endif /* FM_ICON_VIEW_H */
