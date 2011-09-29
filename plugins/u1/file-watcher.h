/*
 * UbuntuOne Nautilus plugin
 *
 * Authors: Rodrigo Moya <rodrigo.moya@canonical.com>
 *
 * Copyright 2009-2010 Canonical Ltd.
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#ifndef __FILE_WATCHER_H__
#define __FILE_WATCHER_H__

//#include <libnautilus-extension/nautilus-file-info.h>
#include <gof-file.h>

#define TYPE_FILE_WATCHER                (file_watcher_get_type ())
#define FILE_WATCHER(obj)                (G_TYPE_CHECK_INSTANCE_CAST ((obj), TYPE_FILE_WATCHER, FileWatcher))
#define IS_FILE_WATCHER(obj)             (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TYPE_FILE_WATCHER))
#define FILE_WATCHER_CLASS(klass)        (G_TYPE_CHECK_CLASS_CAST ((klass), TYPE_FILE_WATCHER, FileWatcherClass))
#define IS_FILE_WATCHER_CLASS(klass)     (G_TYPE_CHECK_CLASS_TYPE ((klass), TYPE_FILE_WATCHER))
#define FILE_WATCHER_GET_CLASS(obj)      (G_TYPE_INSTANCE_GET_CLASS ((obj), TYPE_FILE_WATCHER, FileWatcherClass))

typedef struct _MarlinPluginsUbuntuOne MarlinPluginsUbuntuOne;

typedef struct {
	GObject parent;

	/* Private data */
	MarlinPluginsUbuntuOne *uon;
	GHashTable *files;
} FileWatcher;

typedef struct {
	GObjectClass parent_class;
} FileWatcherClass;

GType        file_watcher_get_type (void);

FileWatcher *file_watcher_new (MarlinPluginsUbuntuOne *uon);
void         file_watcher_add_file (FileWatcher *watcher, GOFFile *file);
void         file_watcher_update_path (FileWatcher *watcher, const gchar *path);

#endif
