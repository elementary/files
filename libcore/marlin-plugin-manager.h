/*
 * marlin-plugin-manager.c
 * Copyright (C) Lucas Baudin 2011 <xapantu@gmail.com>
 * 
 * marlin-plugin-manager.c is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * marlin-plugin-manager.c is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "marlin-plugins-hook.h"
#include "marlinplugins.h"

#if 0

#ifndef _MARLIN_PLUGIN_MANAGER_H_
#define _MARLIN_PLUGIN_MANAGER_H_

#include <glib-object.h>
#include <gtk/gtk.h>
#include "marlin-plugin.h"
#include "gof-file.h"

G_BEGIN_DECLS

#define MARLIN_TYPE_PLUGIN_MANAGER             (marlin_plugin_manager_get_type ())
#define MARLIN_PLUGIN_MANAGER(obj)             (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_PLUGIN_MANAGER, MarlinPluginManager))
#define MARLIN_PLUGIN_MANAGER_CLASS(klass)     (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_PLUGIN_MANAGER, MarlinPluginManagerClass))
#define MARLIN_IS_PLUGIN_MANAGER(obj)          (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_PLUGIN_MANAGER))
#define MARLIN_IS_PLUGIN_MANAGER_CLASS(klass)  (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_PLUGIN_MANAGER))
#define MARLIN_PLUGIN_MANAGER_GET_CLASS(obj)   (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_PLUGIN_MANAGER, MarlinPluginManagerClass))

typedef struct _MarlinPluginManagerClass MarlinPluginManagerClass;
typedef struct _MarlinPluginManager MarlinPluginManager;

struct _MarlinPluginManagerClass
{
    GObjectClass parent_class;
};

struct _MarlinPluginManager
{
    GObject parent_instance;
    GList* plugins_list;
};

GType marlin_plugin_manager_get_type (void) G_GNUC_CONST;

MarlinPluginManager* marlin_plugin_manager_new(void);
void marlin_plugin_manager_load_plugins(MarlinPluginManager* plugin);
void marlin_plugin_manager_hook_context_menu(MarlinPluginManager* plugin, GtkWidget* win);
void marlin_plugin_manager_directory_loaded(MarlinPluginManager* plugin, GOFFile* path);
void marlin_plugin_manager_hook_send(MarlinPluginManager* plugin, void* user_data, int hook);
void marlin_plugin_manager_add_plugin(MarlinPluginManager* plugins, const gchar* path);
gboolean marlin_plugin_manager_disable_plugin(MarlinPluginManager* plugins, const gchar* path);

G_END_DECLS

#endif /* _MARLIN_PLUGIN_MANAGER_H_ */
#endif
extern MarlinPluginManager* plugins;