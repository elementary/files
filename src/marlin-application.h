/*
 * Copyright (C) 2000 Red Hat, Inc.
 *
 * Marlin is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 */

#ifndef __MARLIN_APPLICATION_H__
#define __MARLIN_APPLICATION_H__

#include <granite/granite.h>
#include <gdk/gdk.h>
#include <gio/gio.h>
#include <gtk/gtk.h>

#define MARLIN_TYPE_APPLICATION marlin_application_get_type()
#define MARLIN_APPLICATION(obj) \
    (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_APPLICATION, MarlinApplication))
#define MARLIN_APPLICATION_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_APPLICATION, MarlinApplicationClass))
#define MARLIN_IS_APPLICATION(obj) \
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_APPLICATION))
#define MARLIN_IS_APPLICATION_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_APPLICATION))
#define MARLIN_APPLICATION_GET_CLASS(obj) \
    (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_APPLICATION, MarlinApplicationClass))

typedef struct _MarlinApplicationPriv MarlinApplicationPriv;

typedef struct {
    GraniteApplication parent;

    MarlinApplicationPriv *priv;
} MarlinApplication;

typedef struct {
    GraniteApplicationClass parent_class;
} MarlinApplicationClass;

GType marlin_application_get_type (void);

MarlinApplication *marlin_application_new (void);
MarlinApplication *marlin_application_get (void);

void        marlin_application_create_window (MarlinApplication *application,
                                              GFile *location, GdkScreen *screen);
void        marlin_application_quit (MarlinApplication *self);

//void        marlin_application_close_all_windows (MarlinApplication *self);

gboolean    marlin_application_is_first_window (MarlinApplication *app, GtkWindow *win);

#endif /* __MARLIN_APPLICATION_H__ */
