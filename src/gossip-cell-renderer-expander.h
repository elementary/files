/* -*- Mode: C; tab-width: 8; indent-tabs-mode: t; c-basic-offset: 8 -*- */
/*
 * Copyright (C) 2006  Kristian Rietveld <kris@babi-pangang.org>
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
 */

#ifndef __GOSSIP_CELL_RENDERER_EXPANDER_H__
#define __GOSSIP_CELL_RENDERER_EXPANDER_H__

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define GOSSIP_TYPE_CELL_RENDERER_EXPANDER		(gossip_cell_renderer_expander_get_type ())
#define GOSSIP_CELL_RENDERER_EXPANDER(obj)		(G_TYPE_CHECK_INSTANCE_CAST ((obj), GOSSIP_TYPE_CELL_RENDERER_EXPANDER, GossipCellRendererExpander))
#define GOSSIP_CELL_RENDERER_EXPANDER_CLASS(klass)	(G_TYPE_CHECK_CLASS_CAST ((klass), GOSSIP_TYPE_CELL_RENDERER_EXPANDER, GossipCellRendererExpanderClass))
#define GOSSIP_IS_CELL_RENDERER_EXPANDER(obj)		(G_TYPE_CHECK_INSTANCE_TYPE ((obj), GOSSIP_TYPE_CELL_RENDERER_EXPANDER))
#define GOSSIP_IS_CELL_RENDERER_EXPANDER_CLASS(klass)	(G_TYPE_CHECK_CLASS_TYPE ((klass), GOSSIP_TYPE_CELL_RENDERER_EXPANDER))
#define GOSSIP_CELL_RENDERER_EXPANDER_GET_CLASS(obj)	(G_TYPE_INSTANCE_GET_CLASS ((obj), GOSSIP_TYPE_CELL_RENDERER_EXPANDER, GossipCellRendererExpanderClass))

typedef struct _GossipCellRendererExpander GossipCellRendererExpander;
typedef struct _GossipCellRendererExpanderClass GossipCellRendererExpanderClass;

struct _GossipCellRendererExpander {
  GtkCellRenderer parent;
};

struct _GossipCellRendererExpanderClass {
  GtkCellRendererClass parent_class;

  /* Padding for future expansion */
  void (*_gtk_reserved1) (void);
  void (*_gtk_reserved2) (void);
  void (*_gtk_reserved3) (void);
  void (*_gtk_reserved4) (void);
};

GType            gossip_cell_renderer_expander_get_type (void) G_GNUC_CONST;
GtkCellRenderer *gossip_cell_renderer_expander_new      (void);

G_END_DECLS

#endif /* __GOSSIP_CELL_RENDERER_EXPANDER_H__ */
