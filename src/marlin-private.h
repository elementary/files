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

#ifndef MARLIN_PRIVATE_H
#define MARLIN_PRIVATE_H

#define MARLIN_VIEW_TYPE_WINDOW (marlin_view_window_get_type ())
#define MARLIN_VIEW_WINDOW(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_VIEW_TYPE_WINDOW, MarlinViewWindow))
#define MARLIN_VIEW_WINDOW_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_VIEW_TYPE_WINDOW, MarlinViewWindowClass))
#define MARLIN_VIEW_IS_WINDOW(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_VIEW_TYPE_WINDOW))
#define MARLIN_VIEW_IS_WINDOW_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_VIEW_TYPE_WINDOW))
#define MARLIN_VIEW_WINDOW_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_VIEW_TYPE_WINDOW, MarlinViewWindowClass))

typedef struct _MarlinViewWindow MarlinViewWindow;
typedef struct _MarlinViewWindowClass MarlinViewWindowClass;
GType marlin_view_window_get_type (void) G_GNUC_CONST;

/*MarlinViewWindow* marlin_view_window_new (const gchar* path);
  MarlinViewWindow* marlin_view_window_construct (GType object_type, const gchar* path);
  GType marlin_view_window_get_type (void) G_GNUC_CONST;*/
MarlinViewWindow* marlin_view_window_new ();
MarlinViewWindow* marlin_view_window_construct (GType object_type);
GtkActionGroup* marlin_view_window_get_actiongroup (MarlinViewWindow *mvw);
void marlin_view_window_set_toolbar_items (MarlinViewWindow *mvw);

#define MARLIN_VIEW_TYPE_VIEW_CONTAINER (marlin_view_view_container_get_type ())
#define MARLIN_VIEW_VIEW_CONTAINER(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_VIEW_TYPE_VIEW_CONTAINER, MarlinViewViewContainer))
#define MARLIN_VIEW_VIEW_CONTAINER_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_VIEW_TYPE_VIEW_CONTAINER, MarlinViewViewContainerClass))
#define MARLIN_VIEW_IS_VIEW_CONTAINER(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_VIEW_TYPE_VIEW_CONTAINER))
#define MARLIN_VIEW_IS_VIEW_CONTAINER_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_VIEW_TYPE_VIEW_CONTAINER))
#define MARLIN_VIEW_VIEW_CONTAINER_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_VIEW_TYPE_VIEW_CONTAINER, MarlinViewViewContainerClass))

typedef struct _MarlinViewViewContainer MarlinViewViewContainer;
typedef struct _MarlinViewViewContainerClass MarlinViewViewContainerClass;
GType marlin_view_view_container_get_type (void) G_GNUC_CONST;

void marlin_view_window_add_tab (MarlinViewWindow* self, GFile *location);
MarlinViewViewContainer* marlin_view_view_container_new (GFile *location);
GtkWidget* marlin_view_view_container_get_window (MarlinViewViewContainer* self);

/*GOFWindowSlot* marlin_view_window_get_active_slot (MarlinViewWindow* self);
  void marlin_view_window_set_active_slot (MarlinViewWindow* self, GOFWindowSlot* value);*/

#include "gof-file.h"

#define MARLIN_VIEW_TYPE_TAGS (marlin_view_tags_get_type ())
#define MARLIN_VIEW_TAGS(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_VIEW_TYPE_TAGS, MarlinViewTags))
#define MARLIN_VIEW_TAGS_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_VIEW_TYPE_TAGS, MarlinViewTagsClass))
#define MARLIN_VIEW_IS_TAGS(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_VIEW_TYPE_TAGS))
#define MARLIN_VIEW_IS_TAGS_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_VIEW_TYPE_TAGS))
#define MARLIN_VIEW_TAGS_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_VIEW_TYPE_TAGS, MarlinViewTagsClass))

typedef struct _MarlinViewTags MarlinViewTags;
typedef struct _MarlinViewTagsClass MarlinViewTagsClass;

MarlinViewTags* marlin_view_tags_new (void);
void marlin_view_tags_set_color (MarlinViewTags* self, const gchar* uri, gint n, GError** error);
gint marlin_view_tags_get_color (MarlinViewTags* self, const gchar* uri, GOFFile *file, GError** error);

#endif /* MARLIN_PRIVATE_H */
