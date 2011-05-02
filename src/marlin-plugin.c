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
    MarlinPlugin* plugin = g_object_new(MARLIN_TYPE_PLUGIN, NULL);
    plugin->plugin_handle = dlopen (path, RTLD_LAZY);
    if(! plugin->plugin_handle)
    {
        g_warning("Can't load plugin: %s", path);
        g_object_unref(plugin);
        return NULL;
    }

    plugin->hook_interface_loaded = dlsym(plugin->plugin_handle, "hook_interface_loaded");
    if((dl_error = dlerror()) != NULL)
    {
        g_warning("Can't load hook: %s, %s", path, dl_error);
    }

    plugin->hook_context_menu = dlsym(plugin->plugin_handle, "hook_context_menu");
    if((dl_error = dlerror()) != NULL)
    {
        g_warning("Can't load hook: %s, %s", path, dl_error);
    }

    plugin->hook_file_loaded = dlsym(plugin->plugin_handle, "hook_file_loaded");
    if((dl_error = dlerror()) != NULL)
    {
        g_warning("Can't load hook: %s, %s", path, dl_error);
    }


    plugin->hook_plugin_finish = dlsym(plugin->plugin_handle, "hook_plugin_finish");
    if((dl_error = dlerror()) != NULL)
    {
        g_warning("Can't load hook: %s, %s", path, dl_error);
    }

    plugin->hook_plugin_init = dlsym(plugin->plugin_handle, "hook_plugin_init");
    if((dl_error = dlerror()) != NULL)
    {
        g_warning("Can't load hook: %s, %s", path, dl_error);
    }

    plugin->hook_directory_loaded = dlsym(plugin->plugin_handle, "hook_directory_loaded");
    if((dl_error = dlerror()) != NULL)
    {
        g_warning("Can't load hook: %s, %s", path, dl_error);
    }

    plugin->hook_plugin_init();

    return plugin;
}
