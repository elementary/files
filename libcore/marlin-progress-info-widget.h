/*
 * marlin-progress-info-widget.h: file operation progress user interface.
 *
 * Copyright (C) 2007, 2011 Red Hat, Inc.
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authors: Alexander Larsson <alexl@redhat.com>
 *          Cosimo Cecchi <cosimoc@redhat.com>
 *
 */

#ifndef __MARLIN_PROGRESS_INFO_WIDGET_H__
#define __MARLIN_PROGRESS_INFO_WIDGET_H__

#include <gtk/gtk.h>

#include "marlin-progress-info.h"

#define MARLIN_TYPE_PROGRESS_INFO_WIDGET marlin_progress_info_widget_get_type()
#define MARLIN_PROGRESS_INFO_WIDGET(obj) \
    (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_PROGRESS_INFO_WIDGET, MarlinProgressInfoWidget))
#define MARLIN_PROGRESS_INFO_WIDGET_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_PROGRESS_INFO_WIDGET, MarlinProgressInfoWidgetClass))
#define MARLIN_IS_PROGRESS_INFO_WIDGET(obj) \
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_PROGRESS_INFO_WIDGET))
#define MARLIN_IS_PROGRESS_INFO_WIDGET_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_PROGRESS_INFO_WIDGET))
#define MARLIN_PROGRESS_INFO_WIDGET_GET_CLASS(obj) \
    (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_PROGRESS_INFO_WIDGET, MarlinProgressInfoWidgetClass))

typedef struct _MarlinProgressInfoWidgetPriv MarlinProgressInfoWidgetPriv;

typedef struct {
    GtkBox parent;

    /* private */
    MarlinProgressInfoWidgetPriv *priv;
} MarlinProgressInfoWidget;

typedef struct {
    GtkBoxClass parent_class;
} MarlinProgressInfoWidgetClass;

GType marlin_progress_info_widget_get_type (void);

GtkWidget * marlin_progress_info_widget_new (MarlinProgressInfo *info);

#endif /* __MARLIN_PROGRESS_INFO_WIDGET_H__ */
