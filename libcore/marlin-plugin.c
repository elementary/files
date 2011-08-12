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

#include "marlin-plugin.h"
#include <gio/gio.h>
#include "marlin-global-preferences.h"
#include <stdio.h>
#include <dlfcn.h>


G_DEFINE_TYPE (MarlinPlugin, marlin_plugin, G_TYPE_OBJECT);

static void
marlin_plugin_init (MarlinPlugin *object)
{
    /* TODO: Add initialization code here */
}

static void
marlin_plugin_finalize (GObject *object)
{
    /* TODO: Add deinitalization code here */

    G_OBJECT_CLASS (marlin_plugin_parent_class)->finalize (object);
    g_free(MARLIN_PLUGIN(object)->name);
}

static void
marlin_plugin_class_init (MarlinPluginClass *klass)
{
    GObjectClass* object_class = G_OBJECT_CLASS (klass);
    GObjectClass* parent_class = G_OBJECT_CLASS (klass);

    object_class->finalize = marlin_plugin_finalize;
}

static MarlinPlugin* marlin_plugin_load(MarlinPlugin* plugin, GKeyFile* keyfile, const gchar* path)
{
    gchar* dl_error;
    gchar* library_file = g_key_file_get_value(keyfile, "Plugin", "File", NULL);
    gchar* library_path = g_build_filename(path, library_file, NULL);

    plugin->plugin_handle = dlopen(library_path, RTLD_NOW | RTLD_GLOBAL);
    
    g_free(library_file);
    g_free(library_path);

    if(!plugin->plugin_handle)
    {
        g_warning ("Can't load plugin: %s %s", path, dlerror());
        g_object_unref(plugin);
        return NULL;
    }

    plugin->hook_receive = dlsym(plugin->plugin_handle, "receive_all_hook");
    if((dl_error = dlerror()) != NULL)
    {
        g_warning ("Can't load plugin: %s, %s", path, dl_error);
        g_object_unref(plugin);
        return NULL;
    }

    plugin->hook_receive(NULL, MARLIN_PLUGIN_HOOK_INIT);
    return plugin;
}

static gboolean marlin_plugin_is_in_system_plugin_dir(const gchar* path, gchar** parent_path)
{
    gchar* core_plugins_path = g_build_filename(PLUGIN_DIR, "core", NULL);
    GFile* plugin_file, *parent, *plugin_system_dir;
    
    /* All plugins in system dirs are enabled by default */
    plugin_file = g_file_new_for_path(path);
    parent = g_file_get_parent(plugin_file);

    plugin_system_dir = g_file_new_for_path(core_plugins_path);

    *parent_path = g_file_get_path(parent);
    
    gboolean success = g_file_equal(parent, plugin_system_dir);

    g_free(core_plugins_path);
    g_object_unref(plugin_file);
    g_object_unref(parent);
    g_object_unref(plugin_system_dir);
    
    return success;
}

MarlinPlugin* marlin_plugin_new(const gchar* path)
{
    GKeyFile* keyfile;
    gchar* parent_path;
    MarlinPlugin* plugin_loaded = NULL;

    MarlinPlugin* plugin = g_object_new(MARLIN_TYPE_PLUGIN, NULL);

    /* Creating a new keyfile object, to load the plugin config in it. */
    keyfile = g_key_file_new();

    /* Load the keys, it can be empty, that's why we will put some default value
     * then. */
    g_key_file_load_from_file(keyfile, path,
                              G_KEY_FILE_NONE,
                              NULL);
    plugin->name = g_key_file_get_value(keyfile, "Plugin", "Name", NULL);

    gboolean in_system_dir = marlin_plugin_is_in_system_plugin_dir(path, &parent_path);
    
    if(in_system_dir == TRUE)
    {
        plugin_loaded = marlin_plugin_load(plugin, keyfile, parent_path);
        g_free(parent_path);
        return plugin_loaded;
    }

    gchar** plugins = g_settings_get_strv(settings, "plugins-enabled");
        
    int i;
    for(i = 0; i < g_strv_length(plugins); i++)
    {
        if(!g_strcmp0(plugin->name, plugins[i]))
        {
            plugin_loaded = marlin_plugin_load(plugin, keyfile, parent_path);
        }
    }
    if(plugin_loaded == NULL) g_warning ("Plugin not enabled: %s", path);
    g_free(parent_path);
    return plugin_loaded;
}
