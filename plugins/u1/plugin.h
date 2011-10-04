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

#include <glib.h>
#include <glib-object.h>
#include <marlinplugins.h>
//#include <dbus/dbus-glib.h>
#include <libsyncdaemon/syncdaemon-daemon.h>
#include "file-watcher.h"

#define MARLIN_PLUGINS_TYPE_UBUNTUONE (marlin_plugins_ubuntuone_get_type ())
#define MARLIN_PLUGINS_UBUNTUONE(obj) (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_PLUGINS_TYPE_UBUNTUONE, MarlinPluginsUbuntuOne))
#define MARLIN_PLUGINS_UBUNTUONE_CLASS(klass) (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_PLUGINS_TYPE_UBUNTUONE, MarlinPluginsUbuntuOneClass))
#define MARLIN_PLUGINS_IS_UBUNTUONE(obj) (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_PLUGINS_TYPE_UBUNTUONE))
#define MARLIN_PLUGINS_IS_UBUNTUONE_CLASS(klass) (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_PLUGINS_TYPE_UBUNTUONE))
#define MARLIN_PLUGINS_UBUNTUONE_GET_CLASS(obj) (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_PLUGINS_TYPE_UBUNTUONE, MarlinPluginsUbuntuOneClass))

typedef struct _MarlinPluginsUbuntuOne MarlinPluginsUbuntuOne;
typedef struct _MarlinPluginsUbuntuOneClass MarlinPluginsUbuntuOneClass;
typedef struct _MarlinPluginsUbuntuOnePrivate MarlinPluginsUbuntuOnePrivate;
#define _g_object_unref0(var) ((var == NULL) ? NULL : (var = (g_object_unref (var), NULL)))

#define UPDATE_PENDING "pending"

struct _MarlinPluginsUbuntuOne {
	MarlinPluginsBase parent_instance;
	//MarlinPluginsUbuntuOnePrivate * priv;

    SyncdaemonDaemon *syncdaemon;
	FileWatcher *file_watcher;

	/* Are we connected? */
	gboolean connected;

	/* The managed directory root */
	gchar * managed;

	/* Avoid calling get_rootdir and get_folders lots of times */
	gboolean gotroot;
	gboolean gotudfs;

	/* Lists of public files and user defined folders */
	GHashTable * public;
	GHashTable * udfs;

    GList *selection;
};

struct _MarlinPluginsUbuntuOneClass {
	MarlinPluginsBaseClass parent_class;
};

struct _MarlinPluginsUbuntuOnePrivate {
	/*MarlinTrashMonitor* trash_monitor;*/
};

GType marlin_plugins_ubuntuone_get_type (void) G_GNUC_CONST;
