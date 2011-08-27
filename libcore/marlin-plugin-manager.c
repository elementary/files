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
MarlinPluginManager* plugins = NULL;

#if 0


G_DEFINE_TYPE (MarlinPluginManager, marlin_plugin_manager, G_TYPE_OBJECT);


static void marlin_plugin_manager_init (MarlinPluginManager *object)
{
    /* TODO: Add initialization code here */
}

static void marlin_plugin_manager_finalize (GObject *object)
{
    /* TODO: Add deinitalization code here */

    G_OBJECT_CLASS (marlin_plugin_manager_parent_class)->finalize (object);
}

static void marlin_plugin_manager_class_init (MarlinPluginManagerClass *klass)
{
    GObjectClass* object_class = G_OBJECT_CLASS (klass);
    GObjectClass* parent_class = G_OBJECT_CLASS (klass);

    object_class->finalize = marlin_plugin_manager_finalize;
}

MarlinPluginManager* marlin_plugin_manager_new (void)
{
    return g_object_new(MARLIN_TYPE_PLUGIN_MANAGER, NULL);
}

gboolean marlin_plugin_manager_disable_plugin(MarlinPluginManager* plugins, const gchar* path)
{
#if 0
    GList* all_plugins = g_list_first(plugins->plugins_list);
    while(all_plugins != NULL)
    {
        if(!g_strcmp0(MARLIN_PLUGIN(all_plugins->data)->name, path))
        {
            g_object_unref(MARLIN_PLUGIN(all_plugins->data));
            plugins->plugins_list = g_list_remove(plugins->plugins_list, all_plugins->data);
            return TRUE;
        }
        all_plugins = g_list_next(all_plugins);
    }
#endif
    return FALSE;
}

/**
 * In thie function, we have the name of the plugin (path), which is the displayed name
 * of the plugin, e.g. "Marlin Bzr Plugin".
 * This function enumerate over the plugins to see if one is the plugin that is named.
 * If there is no plugin named like this, the fucntion call is just ignored.
 **/
void marlin_plugin_manager_load_plugin(MarlinPluginManager* plugins, const gchar* path)
{
#if 0
    /* We should use GOF File here */
    GFile* dir = g_file_new_for_path(PLUGIN_DIR);
    GFileEnumerator* enumerator = g_file_enumerate_children(dir, "standard::*", 0, NULL, NULL);
    GFileInfo* file_info = g_file_enumerator_next_file(enumerator, NULL, NULL);
    GKeyFile* keyfile;
    gchar* keyfile_value = NULL;
    gchar* plugin_path = NULL;

    while(file_info != NULL)
    {
        if(!g_strcmp0(g_file_info_get_content_type(file_info), "text/plain"))
        {
            
            /* Creating a new keyfile object, to load the plugin config in it. */
            keyfile = g_key_file_new();

            /* Load the plugin dir */
            if(plugin_path != NULL) g_free(plugin_path);
            plugin_path = g_build_filename(PLUGIN_DIR, g_file_info_get_name(file_info), NULL);

            /* Load the keys, it can be empty, that's why we will put some default value
             * then. */
            g_key_file_load_from_file(keyfile, plugin_path,
                                      G_KEY_FILE_NONE,
                                      NULL);
            /* Get the value of the Name field */
            if(keyfile_value != NULL) g_free(keyfile_value);
            keyfile_value = g_key_file_get_value(keyfile, "Plugin", "Name", NULL);

            if(!g_strcmp0(keyfile_value, path))
            {
                marlin_plugin_manager_add_plugin(plugins, plugin_path);
                g_debug("Loading: %s", plugin_path);
                break;
            }
            g_key_file_free(keyfile);
        }
        file_info = g_file_enumerator_next_file(enumerator, NULL, NULL);
    }
    _g_object_unref0(keyfile);
    if(plugin_path != NULL) g_free(plugin_path);
    if(keyfile_value != NULL) g_free(keyfile_value);

    g_object_unref(dir);
    g_object_unref(enumerator);
#endif
}

void marlin_plugin_manager_add_plugin(MarlinPluginManager* plugins, const gchar* path)
{
#if 0
    MarlinPlugin* plugin = marlin_plugin_new(path);
    if(plugin != NULL)
    {
        plugins->plugins_list = g_list_append(plugins->plugins_list, plugin);
    }
#endif
}

void marlin_plugin_manager_load_plugins(MarlinPluginManager* plugin)
{
    GIOModule* module = NULL;
    /*GList* all_modules = g_io_modules_load_all_in_directory("/usr/local/lib/marlin/gioplugins/");
    g_assert_cmpint(g_list_length(all_modules), ==, 1);*/
#if 0
    /* FIXME: We should use GOF File here */
    GFile* dir = g_file_new_for_path(PLUGIN_DIR);
    GFileEnumerator* enumerator = g_file_enumerate_children(dir, "standard::*", 0, NULL, NULL);
    GFileInfo* file_info = g_file_enumerator_next_file(enumerator, NULL, NULL);
    while(file_info != NULL)
    {
        if(!g_strcmp0(g_file_info_get_content_type(file_info), "text/plain"))
        {
            marlin_plugin_manager_add_plugin(plugins, g_strdup_printf("%s/%s", PLUGIN_DIR, g_file_info_get_name(file_info)));
        }
        g_object_unref(file_info);
        file_info = g_file_enumerator_next_file(enumerator, NULL, NULL);
    }

    g_object_unref(dir);
    g_object_unref(enumerator);

    dir = g_file_new_for_path(g_build_filename(PLUGIN_DIR, "core", NULL));
    enumerator = g_file_enumerate_children(dir, "standard::*", 0, NULL, NULL);
    file_info = g_file_enumerator_next_file(enumerator, NULL, NULL);

    while(file_info != NULL)
    {
        if(!g_strcmp0(g_file_info_get_content_type(file_info), "text/plain"))
        {
            marlin_plugin_manager_add_plugin(plugins, g_build_filename(PLUGIN_DIR, "core", g_file_info_get_name(file_info), NULL));
        }
        g_object_unref(file_info);
        file_info = g_file_enumerator_next_file(enumerator, NULL, NULL);
    }
    g_object_unref(dir);
    g_object_unref(enumerator);
#endif
}

/* This functions needs some tests, it is just a draft */
GList* marlin_plugin_manager_get_available_plugins(void)
{
#if 0
    GList* plugins = NULL;
    /* We should use GOF File here */
    GFile* dir = g_file_new_for_path(PLUGIN_DIR);
    GFileEnumerator* enumerator = g_file_enumerate_children(dir, "standard::*", 0, NULL, NULL);
    GFileInfo* file_info = g_file_enumerator_next_file(enumerator, NULL, NULL);
    GKeyFile* keyfile;
    gchar* keyfile_value = NULL;
    gchar* plugin_path = NULL;
    while(file_info != NULL)
    {
        if(!g_strcmp0(g_file_info_get_content_type(file_info), "text/plain"))
        {
            
            /* Creating a new keyfile object, to load the plugin config in it. */
            keyfile = g_key_file_new();

            /* Load the plugin dir */
            if(plugin_path != NULL) g_free(plugin_path);
            plugin_path = g_build_filename(PLUGIN_DIR, g_file_info_get_name(file_info), NULL);

            /* Load the keys, it can be empty, that's why we will put some default value
             * then. */
            g_key_file_load_from_file(keyfile, plugin_path,
                                      G_KEY_FILE_NONE,
                                      NULL);

            /* Get the value of the Name field */
            keyfile_value = g_key_file_get_value(keyfile, "Plugin", "Name", NULL);
            
            plugins = g_list_append(plugins, keyfile_value);

            g_key_file_free(keyfile);
        }
        file_info = g_file_enumerator_next_file(enumerator, NULL, NULL);
    }
    if(plugin_path != NULL) g_free(plugin_path);
    g_object_unref(dir);
    g_object_unref(enumerator);

    return plugins;
#endif
    return NULL;
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
        /*g_assert(MARLIN_PLUGIN(item->data)->hook_receive != NULL);
        MARLIN_PLUGIN(item->data)->hook_receive(user_data, hook);*/
        item = g_list_next(item);
    }

}
#endif