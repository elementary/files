/*
 * Copyright 2008 Evenflow, Inc.
 *
 * dropbox-command-client.h
 * Header file for nautilus-dropbox-command.c
 *
 * This file is part of nautilus-dropbox.
 *
 * nautilus-dropbox is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * nautilus-dropbox is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with nautilus-dropbox.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#ifndef DROPBOX_COMMAND_CLIENT_H
#define DROPBOX_COMMAND_CLIENT_H

#include "config.h"
#include "pantheon-files-core.h"

G_BEGIN_DECLS

/* command structs */
typedef enum {GET_FILE_INFO, GENERAL_COMMAND} PFDropboxRequestType;

typedef struct {
  PFDropboxRequestType request_type;
} DropboxCommand;

typedef struct {
  DropboxCommand dc;
  MarlinPluginsBase *provider;
  GClosure *update_complete;
  GOFFile *file;
  gboolean cancelled;
} DropboxFileInfoCommand;

typedef struct {
  DropboxFileInfoCommand *dfic;
  GHashTable *file_status_response;
  GHashTable *folder_tag_response;
  GHashTable *emblems_response;
} DropboxFileInfoCommandResponse;

typedef void (*PFDropboxCommandResponseHandler)(GHashTable *, gpointer);

typedef struct {
  DropboxCommand dc;
  gchar *command_name;
  GHashTable *command_args;
  PFDropboxCommandResponseHandler handler;
  gpointer handler_ud;
} DropboxGeneralCommand;

typedef void (*DropboxCommandClientConnectionAttemptHook)(guint, gpointer);
typedef GHookFunc DropboxCommandClientConnectHook;

typedef struct {
  GMutex command_connected_mutex;
  gboolean command_connected;
  GAsyncQueue *command_queue;
  GList *ca_hooklist;
  GHookList onconnect_hooklist;
  GHookList ondisconnect_hooklist;
} DropboxCommandClient;

gboolean dropbox_command_client_is_connected(DropboxCommandClient *dcc);

void dropbox_command_client_force_reconnect(DropboxCommandClient *dcc);

void
dropbox_command_client_request(DropboxCommandClient *dcc, DropboxCommand *dc);

void
dropbox_command_client_setup(DropboxCommandClient *dcc);

void
dropbox_command_client_start(DropboxCommandClient *dcc);

void dropbox_command_client_send_simple_command(DropboxCommandClient *dcc,
                        const char *command);

void dropbox_command_client_send_command(DropboxCommandClient *dcc,
                     PFDropboxCommandResponseHandler h,
                     gpointer ud,
                     const char *command, ...);
void
dropbox_command_client_add_on_connect_hook(DropboxCommandClient *dcc,
                       DropboxCommandClientConnectHook dhcch,
                       gpointer ud);

void
dropbox_command_client_add_on_disconnect_hook(DropboxCommandClient *dcc,
                          DropboxCommandClientConnectHook dhcch,
                          gpointer ud);

void
dropbox_command_client_add_connection_attempt_hook(DropboxCommandClient *dcc,
                           DropboxCommandClientConnectionAttemptHook dhcch,
                           gpointer ud);

G_END_DECLS

#endif
