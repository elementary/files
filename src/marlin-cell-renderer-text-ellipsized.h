/*
 * marlin-cell-renderer-text-ellipsized.c: Cell renderer for text which
 * will use pango ellipsization but deactivate it temporarily for the size
 * calculation to get the size based on the actual text length.
 *
 * Copyright (C) 2007 Martin Wehner
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
 * Author: Martin Wehner <martin.wehner@gmail.com>
 */

#ifndef MARLIN_CELL_RENDERER_TEXT_ELLIPSIZED_H
#define MARLIN_CELL_RENDERER_TEXT_ELLIPSIZED_H

#include <gtk/gtk.h>

#define MARLIN_TYPE_CELL_RENDERER_TEXT_ELLIPSIZED marlin_cell_renderer_text_ellipsized_get_type()
#define MARLIN_CELL_RENDERER_TEXT_ELLIPSIZED(obj) \
    (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_CELL_RENDERER_TEXT_ELLIPSIZED, MarlinCellRendererTextEllipsized))
#define MARLIN_CELL_RENDERER_TEXT_ELLIPSIZED_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_CELL_RENDERER_TEXT_ELLIPSIZED, MarlinCellRendererTextEllipsizedClass))
#define MARLIN_IS_CELL_RENDERER_TEXT_ELLIPSIZED(obj) \
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_CELL_RENDERER_TEXT_ELLIPSIZED))
#define MARLIN_IS_CELL_RENDERER_TEXT_ELLIPSIZED_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_CELL_RENDERER_TEXT_ELLIPSIZED))
#define MARLIN_CELL_RENDERER_TEXT_ELLIPSIZED_GET_CLASS(obj) \
    (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_CELL_RENDERER_TEXT_ELLIPSIZED, MarlinCellRendererTextEllipsizedClass))


typedef struct _MarlinCellRendererTextEllipsized MarlinCellRendererTextEllipsized;
typedef struct _MarlinCellRendererTextEllipsizedClass MarlinCellRendererTextEllipsizedClass;

struct _MarlinCellRendererTextEllipsized {
    GtkCellRendererText parent;
};

struct _MarlinCellRendererTextEllipsizedClass {
    GtkCellRendererTextClass parent_class;
};

GType		    marlin_cell_renderer_text_ellipsized_get_type   (void);
GtkCellRenderer *marlin_cell_renderer_text_ellipsized_new       (void);

#endif /* MARLIN_CELL_RENDERER_TEXT_ELLIPSIZED_H */
