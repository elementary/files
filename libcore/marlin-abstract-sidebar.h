/*
 * Copyright (C) 2011, Lucas Baudin <xapantu@gmail.com>
 *
 * Marlin is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 */

#ifndef MARLIN_ABSTRACT_SIDEBAR_H
#define MARLIN_ABSTRACT_SIDEBAR_H

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define MARLIN_TYPE_ABSTRACT_SIDEBAR marlin_abstract_sidebar_get_type()
#define MARLIN_ABSTRACT_SIDEBAR(obj)  (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_ABSTRACT_SIDEBAR, MarlinAbstractSidebar))
#define MARLIN_ABSTRACT_SIDEBAR_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_ABSTRACT_SIDEBAR, MarlinAbstractSidebarClass))
#define MARLIN_IS_ABSTRACT_SIDEBAR(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_ABSTRACT_SIDEBAR))
#define MARLIN_IS_ABSTRACT_SIDEBAR_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_ABSTRACT_SIDEBAR))
#define MARLIN_ABSTRACT_SIDEBAR_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_ABSTRACT_SIDEBAR, MarlinAbstractSidebarClass))

typedef struct _MarlinAbstractSidebar MarlinAbstractSidebar;
typedef struct _MarlinAbstractSidebarClass MarlinAbstractSidebarClass;
typedef struct _MarlinAbstractSidebarPrivate MarlinAbstractSidebarPrivate;

struct _MarlinAbstractSidebar
{
    GtkScrolledWindow parent;
};

struct _MarlinAbstractSidebarClass
{
  GtkScrolledWindowClass parent_class;
};

GType marlin_abstract_sidebar_get_type (void) G_GNUC_CONST;

G_END_DECLS

#endif /* _MARLIN_ABSTRACT_SIDEBAR_H */
