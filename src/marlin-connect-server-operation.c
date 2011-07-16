/*
 * Nautilus
 *
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
 * write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Author: Cosimo Cecchi <cosimoc@gnome.org>
 */

#include <config.h>

#include "marlin-connect-server-operation.h"

G_DEFINE_TYPE (MarlinConnectServerOperation,
               marlin_connect_server_operation, GTK_TYPE_MOUNT_OPERATION);

enum {
    PROP_DIALOG = 1,
    NUM_PROPERTIES
};

struct _MarlinConnectServerOperationDetails {
    MarlinConnectServerDialog *dialog;
};

static void
fill_details_async_cb (GObject *source,
                       GAsyncResult *result,
                       gpointer user_data)
{
    MarlinConnectServerDialog *dialog;
    MarlinConnectServerOperation *self;
    gboolean res;

    self = user_data;
    dialog = MARLIN_CONNECT_SERVER_DIALOG (source);

    res = marlin_connect_server_dialog_fill_details_finish (dialog, result);

    if (!res) {
        g_mount_operation_reply (G_MOUNT_OPERATION (self), G_MOUNT_OPERATION_ABORTED);
    } else {
        g_mount_operation_reply (G_MOUNT_OPERATION (self), G_MOUNT_OPERATION_HANDLED);
    }
}

static void
marlin_connect_server_operation_ask_password (GMountOperation *op,
                                              const gchar *message,
                                              const gchar *default_user,
                                              const gchar *default_domain,
                                              GAskPasswordFlags flags)
{
    MarlinConnectServerOperation *self;

    self = MARLIN_CONNECT_SERVER_OPERATION (op);

    marlin_connect_server_dialog_fill_details_async (self->details->dialog,
                                                     G_MOUNT_OPERATION (self),
                                                     default_user,
                                                     default_domain,
                                                     flags,
                                                     fill_details_async_cb,
                                                     self);
}

static void
marlin_connect_server_operation_set_property (GObject *object,
                                              guint property_id,
                                              const GValue *value,
                                              GParamSpec *pspec)
{
    MarlinConnectServerOperation *self;

    self = MARLIN_CONNECT_SERVER_OPERATION (object);

    switch (property_id) {
    case PROP_DIALOG:
        self->details->dialog = g_value_dup_object (value);
        break;
    default:
        G_OBJECT_WARN_INVALID_PROPERTY_ID (object, property_id, pspec);
        break;
    }
}

static void
marlin_connect_server_operation_dispose (GObject *object)
{
    MarlinConnectServerOperation *self = MARLIN_CONNECT_SERVER_OPERATION (object);

    g_clear_object (&self->details->dialog);

    G_OBJECT_CLASS (marlin_connect_server_operation_parent_class)->dispose (object);
}

static void
marlin_connect_server_operation_class_init (MarlinConnectServerOperationClass *klass)
{
    GMountOperationClass *mount_op_class;
    GObjectClass *object_class;
    GParamSpec *pspec;

    object_class = G_OBJECT_CLASS (klass);
    object_class->set_property = marlin_connect_server_operation_set_property;
    object_class->dispose = marlin_connect_server_operation_dispose;

    mount_op_class = G_MOUNT_OPERATION_CLASS (klass);
    mount_op_class->ask_password = marlin_connect_server_operation_ask_password;

    pspec = g_param_spec_object ("dialog", "The connect dialog",
                                 "The connect to server dialog",
                                 MARLIN_TYPE_CONNECT_SERVER_DIALOG,
                                 G_PARAM_CONSTRUCT_ONLY | G_PARAM_WRITABLE | G_PARAM_STATIC_STRINGS);
    g_object_class_install_property (object_class, PROP_DIALOG, pspec);

    g_type_class_add_private (klass, sizeof (MarlinConnectServerOperationDetails));
}

static void
marlin_connect_server_operation_init (MarlinConnectServerOperation *self)
{
    self->details = G_TYPE_INSTANCE_GET_PRIVATE (self,
                                                 MARLIN_TYPE_CONNECT_SERVER_OPERATION,
                                                 MarlinConnectServerOperationDetails);
}

GMountOperation *
marlin_connect_server_operation_new (MarlinConnectServerDialog *dialog)
{
    return g_object_new (MARLIN_TYPE_CONNECT_SERVER_OPERATION,
                         "dialog", dialog,
                         NULL);
}
