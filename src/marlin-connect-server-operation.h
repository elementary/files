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

#ifndef __MARLIN_CONNECT_SERVER_OPERATION_H__
#define __MARLIN_CONNECT_SERVER_OPERATION_H__

#include <gio/gio.h>
#include <gtk/gtk.h>

#include "marlin-connect-server-dialog.h"

#define MARLIN_TYPE_CONNECT_SERVER_OPERATION\
    (marlin_connect_server_operation_get_type ())
#define MARLIN_CONNECT_SERVER_OPERATION(obj)\
    (G_TYPE_CHECK_INSTANCE_CAST ((obj),\
                                 MARLIN_TYPE_CONNECT_SERVER_OPERATION,\
                                 MarlinConnectServerOperation))
#define MARLIN_CONNECT_SERVER_OPERATION_CLASS(klass)\
    (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_CONNECT_SERVER_OPERATION,\
                              MarlinConnectServerOperationClass))
#define MARLIN_IS_CONNECT_SERVER_OPERATION(obj)\
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_CONNECT_SERVER_OPERATION))

typedef struct _MarlinConnectServerOperationDetails MarlinConnectServerOperationDetails;

typedef struct {
    GtkMountOperation parent;
    MarlinConnectServerOperationDetails *details;
} MarlinConnectServerOperation;

typedef struct {
    GtkMountOperationClass parent_class;
} MarlinConnectServerOperationClass;

GType marlin_connect_server_operation_get_type (void);

GMountOperation *marlin_connect_server_operation_new (MarlinConnectServerDialog *dialog);


#endif /* __MARLIN_CONNECT_SERVER_OPERATION_H__ */
