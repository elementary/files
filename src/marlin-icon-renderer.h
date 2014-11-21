/*
 * Copyright (C) 2000  Red Hat, Inc.,  Jonathan Blandford <jrb@redhat.com>
 * Copyright (c) 2011  ammonkey <am.monkeyd@gmail.com>
 *
 * Originaly Written in gtk+: gtkcellrendererpixbuf.h
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef __MARLIN_ICON_RENDERER_H__
#define __MARLIN_ICON_RENDERER_H__

#include "marlin-enum-types.h"
#include "gof-file.h"

G_BEGIN_DECLS

#define MARLIN_TYPE_ICON_RENDERER			(marlin_icon_renderer_get_type ())
#define MARLIN_ICON_RENDERER(obj)			(G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_ICON_RENDERER, MarlinIconRenderer))
#define MARLIN_ICON_RENDERER_CLASS(klass)		(G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_ICON_RENDERER, MarlinIconRendererClass))
#define MARLIN_IS_ICON_RENDERER(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_ICON_RENDERER))
#define MARLIN_IS_ICON_RENDERER_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_ICON_RENDERER))
#define MARLIN_ICON_RENDERER_GET_CLASS(obj)         (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_ICON_RENDERER, MarlinIconRendererClass))

typedef struct _MarlinIconRenderer              MarlinIconRenderer;
typedef struct _MarlinIconRendererPrivate       MarlinIconRendererPrivate;
typedef struct _MarlinIconRendererClass         MarlinIconRendererClass;

struct _MarlinIconRenderer
{
    GtkCellRenderer parent;

    /*< private >*/
    MarlinIconRendererPrivate *priv;
};

struct _MarlinIconRendererClass
{
    GtkCellRendererClass parent_class;
};

GType            marlin_icon_renderer_get_type (void) G_GNUC_CONST;
GtkCellRenderer *marlin_icon_renderer_new      (void);


G_END_DECLS


#endif /* __MARLIN_ICON_RENDERER_H__ */
