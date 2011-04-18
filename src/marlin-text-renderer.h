/*-
 * Copyright (c) 2005 Benedikt Meurer <benny@xfce.org>
 *
 * This program is free software; you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2 of the License, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
 * more details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program; if not, write to the Free Software Foundation, Inc., 59 Temple
 * Place, Suite 330, Boston, MA  02111-1307  USA
 */

#ifndef __MARLIN_TEXT_RENDERER_H__
#define __MARLIN_TEXT_RENDERER_H__

#include <gtk/gtk.h>

G_BEGIN_DECLS;

typedef struct _MarlinTextRendererClass MarlinTextRendererClass;
typedef struct _MarlinTextRenderer      MarlinTextRenderer;

#define MARLIN_TYPE_TEXT_RENDERER            (marlin_text_renderer_get_type ())
#define MARLIN_TEXT_RENDERER(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_TEXT_RENDERER, MarlinTextRenderer))
#define MARLIN_TEXT_RENDERER_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_TEXT_RENDERER, MarlinTextRendererClass))
#define MARLIN_IS_TEXT_RENDERER(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_TEXT_RENDERER))
#define MARLIN_IS_TEXT_RENDERER_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_TEXT_RENDERER))
#define MARLIN_TEXT_RENDERER_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_TEXT_RENDERER, MarlinTextRendererClass))

GType            marlin_text_renderer_get_type (void) G_GNUC_CONST;

GtkCellRenderer *marlin_text_renderer_new      (void) G_GNUC_MALLOC;

G_END_DECLS;

#endif /* !__MARLIN_TEXT_RENDERER_H__ */
