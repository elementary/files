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
#include "marlin-enum-types.h"

G_BEGIN_DECLS;

typedef struct _MarlinTextRendererClass MarlinTextRendererClass;
typedef struct _MarlinTextRenderer      MarlinTextRenderer;

#define MARLIN_TYPE_TEXT_RENDERER            (marlin_text_renderer_get_type ())
#define MARLIN_TEXT_RENDERER(obj)            (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_TEXT_RENDERER, MarlinTextRenderer))
#define MARLIN_TEXT_RENDERER_CLASS(klass)    (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_TEXT_RENDERER, MarlinTextRendererClass))
#define MARLIN_IS_TEXT_RENDERER(obj)         (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_TEXT_RENDERER))
#define MARLIN_IS_TEXT_RENDERER_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_TEXT_RENDERER))
#define MARLIN_TEXT_RENDERER_GET_CLASS(obj)  (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_TEXT_RENDERER, MarlinTextRendererClass))

struct _MarlinTextRendererClass
{
    GtkCellRendererClass __parent__;

    void (*edited) (MarlinTextRenderer *text_renderer,
                    const gchar        *path,
                    const gchar        *text);
};

struct _MarlinTextRenderer
{
    GtkCellRenderer __parent__;

    PangoLayout  *layout;
    GtkWidget    *widget;
    gboolean      text_static;
    gchar        *text;
    gint          char_width;
    gint          char_height;
    PangoWrapMode wrap_mode;
    gint          wrap_width;
    gboolean      follow_state;
    gint          focus_width;
    MarlinZoomLevel zoom_level;

    /* underline prelited rows */
    gboolean      follow_prelit;

    /* cell editing support */
    GtkWidget    *entry; 
    gboolean      entry_menu_active;
    gint          entry_menu_popdown_timer_id;
};


GType            marlin_text_renderer_get_type (void) G_GNUC_CONST;

GtkCellRenderer *marlin_text_renderer_new      (void) G_GNUC_MALLOC;

G_END_DECLS;

#endif /* !__MARLIN_TEXT_RENDERER_H__ */
