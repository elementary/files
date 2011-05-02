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

#include "marlin-plugin-manager.h"



G_DEFINE_TYPE (MarlinPluginManager, marlin_plugin_manager, G_TYPE_OBJECT);

MarlinPluginManager* plugins = NULL;

static void
marlin_plugin_manager_init (MarlinPluginManager *object)
{
    /* TODO: Add initialization code here */
}

static void
marlin_plugin_manager_finalize (GObject *object)
{
    /* TODO: Add deinitalization code here */

    G_OBJECT_CLASS (marlin_plugin_manager_parent_class)->finalize (object);
}

static void
marlin_plugin_manager_class_init (MarlinPluginManagerClass *klass)
{
    GObjectClass* object_class = G_OBJECT_CLASS (klass);
    GObjectClass* parent_class = G_OBJECT_CLASS (klass);

    object_class->finalize = marlin_plugin_manager_finalize;
}

MarlinPluginManager* marlin_plugin_manager_new (void)
{
    return g_object_new(MARLIN_TYPE_PLUGIN_MANAGER, NULL);
}

static marlin_plugin_manager_add_plugin(MarlinPluginManager* plugins, const gchar* path)
{
    plugins->plugins_list = g_list_append(plugins->plugins_list, marlin_plugin_new(path));
}

void marlin_plugin_manager_load_plugins(MarlinPluginManager* plugin)
{
    marlin_plugin_manager_add_plugin(plugins, "hw/libhw.so");
}

void marlin_plugin_manager_interface_loaded(MarlinPluginManager* plugin, GtkWidget* win)
{
    printf("HERE\n\n\n\n\n\n");

    GList* item = g_list_nth(plugin->plugins_list, 0);

    ((MarlinPlugin*)item->data)->hook_interface_loaded(win);

    while((item = g_list_next(plugin->plugins_list)))
    {
        ((MarlinPlugin*)item->data)->hook_interface_loaded(win);
    }

}
