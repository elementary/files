/*
 * Copyright (C) 2011 ammonkey <am.monkeyd@gmail.com>
 * 
 * Marlin is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * Marlin is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef MARLIN_DROPBOX_H
#define MARLIN_DROPBOX_H

#include <glib.h>
#include <glib-object.h>
#include <marlincore.h>
//#include <dbus/dbus-glib.h>

#include "dropbox-command-client.h"
#include "dropbox-hooks.h"
#include "dropbox-client.h"

#define MARLIN_TYPE_DROPBOX (marlin_dropbox_get_type ())
#define MARLIN_DROPBOX(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_DROPBOX, MarlinDropbox))
#define MARLIN_DROPBOX_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_DROPBOX, MarlinDropboxClass))
#define MARLIN_IS_DROPBOX(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_DROPBOX))
#define MARLIN_IS_DROPBOX_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_DROPBOX))
#define MARLIN_DROPBOX_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_DROPBOX, MarlinDropboxClass))

typedef struct _MarlinDropbox MarlinDropbox;
typedef struct _MarlinDropboxClass MarlinDropboxClass;
typedef struct _MarlinDropboxPrivate MarlinDropboxPrivate;
#define _g_object_unref0(var) ((var == NULL) ? NULL : (var = (g_object_unref (var), NULL)))

struct _MarlinDropbox {
	MarlinPluginsBase parent_instance;
	//MarlinDropboxPrivate * priv;

    GHashTable *filename2obj;
    GHashTable *obj2filename;
    /*GMutex *emblem_paths_mutex;
    GHashTable *emblem_paths;*/
    DropboxClient dc;

    GList *selection;
};

struct _MarlinDropboxClass {
	MarlinPluginsBaseClass parent_class;
};

struct _MarlinDropboxPrivate {
	/*MarlinTrashMonitor* trash_monitor;*/
};

GType marlin_dropbox_get_type (void) G_GNUC_CONST;

#endif
