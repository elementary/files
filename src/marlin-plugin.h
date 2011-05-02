/*
 * marlin-plugin.c
 * Copyright (C) Lucas Baudin 2011 <xapantu@gmail.com>
 * 
 * marlin-plugin.c is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * marlin-plugin.c is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#ifndef _MARLIN_PLUGIN_H_
#define _MARLIN_PLUGIN_H_

#include <glib-object.h>

G_BEGIN_DECLS

#define MARLIN_TYPE_PLUGIN             (marlin_plugin_get_type ())
#define MARLIN_PLUGIN(obj)             (G_TYPE_CHECK_INSTANCE_CAST ((obj), MARLIN_TYPE_PLUGIN, MarlinPlugin))
#define MARLIN_PLUGIN_CLASS(klass)     (G_TYPE_CHECK_CLASS_CAST ((klass), MARLIN_TYPE_PLUGIN, MarlinPluginClass))
#define MARLIN_IS_PLUGIN(obj)          (G_TYPE_CHECK_INSTANCE_TYPE ((obj), MARLIN_TYPE_PLUGIN))
#define MARLIN_IS_PLUGIN_CLASS(klass)  (G_TYPE_CHECK_CLASS_TYPE ((klass), MARLIN_TYPE_PLUGIN))
#define MARLIN_PLUGIN_GET_CLASS(obj)   (G_TYPE_INSTANCE_GET_CLASS ((obj), MARLIN_TYPE_PLUGIN, MarlinPluginClass))

typedef struct _MarlinPluginClass MarlinPluginClass;
typedef struct _MarlinPlugin MarlinPlugin;

struct _MarlinPluginClass
{
    GObjectClass parent_class;
};

struct _MarlinPlugin
{
    GObject parent_instance;
    void* plugin_handle;
    void (*hook_interface_loaded)(void*);
    void (*hook_context_menu)(void*);

    void (*hook_plugin_init)(void);

    void (*hook_plugin_finish)(void);

    void (*hook_file_loaded)(void*);

    void (*hook_directory_loaded)(void*);
};

GType marlin_plugin_get_type (void) G_GNUC_CONST;

MarlinPlugin* marlin_plugin_new(const gchar* path);

G_END_DECLS

#endif /* _MARLIN_PLUGIN_H_ */
