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
    MarlinPlugin* plugin = marlin_plugin_new(path);
    if(plugin != NULL)
        plugins->plugins_list = g_list_append(plugins->plugins_list, plugin);
}

void marlin_plugin_manager_load_plugins(MarlinPluginManager* plugin)
{
    /* We should use GOF File here */
    GFile* dir = g_file_new_for_path("/usr/share/marlin/plugins/");
    GFileEnumerator* enumerator = g_file_enumerate_children(dir, "standard::*", 0, NULL, NULL);
    GFileInfo* file_info = g_file_enumerator_next_file(enumerator, NULL, NULL);
    while(file_info != NULL)
    {
        printf("%s\n", g_file_info_get_content_type(file_info));
        if(!g_strcmp0(g_file_info_get_content_type(file_info), "text/plain"))
        {
            marlin_plugin_manager_add_plugin(plugins, g_strdup_printf("/usr/share/marlin/plugins/%s", g_file_info_get_name(file_info)));
        }
        file_info = g_file_enumerator_next_file(enumerator, NULL, NULL);
    }
}

void marlin_plugin_manager_interface_loaded(MarlinPluginManager* plugin, GtkWidget* win)
{
    marlin_plugin_manager_hook_send(plugin, win, MARLIN_PLUGIN_HOOK_INTERFACE);
}

void marlin_plugin_manager_directory_loaded(MarlinPluginManager* plugin, GOFFile* path)
{
    marlin_plugin_manager_hook_send(plugin, path, MARLIN_PLUGIN_HOOK_DIRECTORY);
}

void marlin_plugin_manager_hook_context_menu(MarlinPluginManager* plugin, GtkWidget* win)
{
    marlin_plugin_manager_hook_send(plugin, win, MARLIN_PLUGIN_HOOK_CONTEXT_MENU);
}

void marlin_plugin_manager_hook_send(MarlinPluginManager* plugin, void* user_data, int hook)
{
    g_debug("Plugin Hook: %d", hook);

    GList* item = g_list_first(plugin->plugins_list);

    while(item != NULL)
    {
        ((MarlinPlugin*)item->data)->hook_receive(user_data, hook);
        item = g_list_next(item);
    }

}
