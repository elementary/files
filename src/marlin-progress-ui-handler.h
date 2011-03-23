/*
 * marlin-progress-ui-handler.h: file operation progress user interface.
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

#ifndef __MARLIN_PROGRESS_UI_HANDLER_H__
#define __MARLIN_PROGRESS_UI_HANDLER_H__

#include <glib-object.h>

G_BEGIN_DECLS

#define MARLIN_TYPE_PROGRESS_UI_HANDLER marlin_progress_ui_handler_get_type()
#define MARLIN_PROGRESS_UI_HANDLER(obj) \
    (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_PROGRESS_UI_HANDLER, MarlinProgressUIHandler))
#define MARLIN_PROGRESS_UI_HANDLER_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_PROGRESS_UI_HANDLER, MarlinProgressUIHandlerClass))
#define MARLIN_IS_PROGRESS_UI_HANDLER(obj) \
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_PROGRESS_UI_HANDLER))
#define MARLIN_IS_PROGRESS_UI_HANDLER_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_PROGRESS_UI_HANDLER))
#define MARLIN_PROGRESS_UI_HANDLER_GET_CLASS(obj) \
    (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_PROGRESS_UI_HANDLER, MarlinProgressUIHandlerClass))

typedef struct _MarlinProgressUIHandlerPriv MarlinProgressUIHandlerPriv;

typedef struct {
    GObject parent;

    /* private */
    MarlinProgressUIHandlerPriv *priv;
} MarlinProgressUIHandler;

typedef struct {
    GObjectClass parent_class;
} MarlinProgressUIHandlerClass;

GType marlin_progress_ui_handler_get_type (void);

MarlinProgressUIHandler * marlin_progress_ui_handler_new (void);

G_END_DECLS

#endif /* __MARLIN_PROGRESS_UI_HANDLER_H__ */
