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
}

static void
marlin_plugin_class_init (MarlinPluginClass *klass)
{
    GObjectClass* object_class = G_OBJECT_CLASS (klass);
    GObjectClass* parent_class = G_OBJECT_CLASS (klass);

    object_class->finalize = marlin_plugin_finalize;
}

MarlinPlugin* marlin_plugin_new(const gchar* path)
{
    gchar* dl_error;
    GKeyFile* keyfile;
    MarlinPlugin* plugin = g_object_new(MARLIN_TYPE_PLUGIN, NULL);
    /* Creating a new keyfile object, to load the plugin config in it. */
    keyfile = g_key_file_new();

    /* Load the keys, it can be empty, that's why we will put some default value
     * then. */
    g_key_file_load_from_file(keyfile, path,
                              G_KEY_FILE_NONE,
                              NULL);
    plugin->plugin_handle = dlopen (g_build_filename(PLUGIN_DIR, g_key_file_get_value(keyfile, "Plugin", "File", NULL)), RTLD_LAZY);
    if(! plugin->plugin_handle)
    {
        g_warning("Can't load plugin: %s", path);
        g_object_unref(plugin);
        return NULL;
    }

    plugin->hook_receive = dlsym(plugin->plugin_handle, "receive_all_hook");
    if((dl_error = dlerror()) != NULL)
    {
        g_warning("Can't load plugin: %s, %s", path, dl_error);
    }

    plugin->hook_receive(NULL, MARLIN_PLUGIN_HOOK_INIT);

    return plugin;
}
