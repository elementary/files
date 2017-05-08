/*
 * Nautilus
 *
 * Copyright (C) 2003 Red Hat, Inc.
 * Copyright (C) 2010 Cosimo Cecchi <cosimoc@gnome.org>
 *
 * Nautilus is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Nautilus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; see the file COPYING.  If not,
 * write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1335 USA.
 */

#ifndef MARLIN_CONNECT_SERVER_DIALOG_H
#define MARLIN_CONNECT_SERVER_DIALOG_H

#include <gio/gio.h>
#include <gtk/gtk.h>

#define MARLIN_TYPE_CONNECT_SERVER_DIALOG\
    (marlin_connect_server_dialog_get_type ())
#define MARLIN_CONNECT_SERVER_DIALOG(obj)\
    (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_CONNECT_SERVER_DIALOG,\
                                 MarlinConnectServerDialog))
#define MARLIN_CONNECT_SERVER_DIALOG_CLASS(klass)\
    (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_CONNECT_SERVER_DIALOG,\
                              MarlinConnectServerDialogClass))
#define MARLIN_IS_CONNECT_SERVER_DIALOG(obj)\
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_CONNECT_SERVER_DIALOG))

typedef struct _MarlinConnectServerDialog MarlinConnectServerDialog;
typedef struct _MarlinConnectServerDialogClass MarlinConnectServerDialogClass;
typedef struct _MarlinConnectServerDialogDetails MarlinConnectServerDialogDetails;

struct _MarlinConnectServerDialog {
    GtkDialog parent;
    MarlinConnectServerDialogDetails *details;
};

struct _MarlinConnectServerDialogClass {
    GtkDialogClass parent_class;
};

GType marlin_connect_server_dialog_get_type (void);

MarlinConnectServerDialog *marlin_connect_server_dialog_new (GtkWindow *window);

void marlin_connect_server_dialog_show (GtkWidget *widget);
void marlin_connect_server_dialog_display_location_async (MarlinConnectServerDialog *self,
                                                          GFile *location,
                                                          GAsyncReadyCallback callback,
                                                          gpointer user_data);
gboolean marlin_connect_server_dialog_display_location_finish (MarlinConnectServerDialog *self,
                                                               GAsyncResult *result,
                                                               GError **error);

void marlin_connect_server_dialog_fill_details_async (MarlinConnectServerDialog *self,
                                                      GMountOperation *operation,
                                                      const gchar *default_user,
                                                      const gchar *default_domain,
                                                      GAskPasswordFlags flags,
                                                      GAsyncReadyCallback callback,
                                                      gpointer user_data);
gboolean marlin_connect_server_dialog_fill_details_finish (MarlinConnectServerDialog *self,
                                                           GAsyncResult *result);

#endif /* MARLIN_CONNECT_SERVER_DIALOG_H */
