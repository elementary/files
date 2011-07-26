/*
 * Copyright (C) Lucas Baudin 2011 <xapantu@gmail.com>
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

#include <gtk/gtk.h>
#include <glib/gi18n.h>
#include "gof-file.h"
#include "marlin-plugins-hook.h"

static gchar* current_path = NULL;
static gboolean menu_added = FALSE;
static GSettings* settings = NULL;
static GList *menus = NULL;
static GtkWidget *menu;

void hook_interface_loaded(void* win_)
{
    printf("Interface Loaded\n");
}

void hook_plugin_init(void* user_data)
{
    printf("Init the plugin\n");
    settings = settings = g_settings_new ("org.gnome.marlin.plugins.openterminal");
}

void hook_plugin_finish(void)
{
    printf("Shutdown\n");
}

void hook_directory_loaded(GOFFile* path)
{
    current_path = g_strdup(g_file_get_path(path->location));
    g_debug("Current path: %s", current_path);
}
static void on_open_terminal_activated(GtkWidget* widget, gpointer data)
{
    GAppInfo* term_app = g_app_info_create_from_commandline(g_strdup_printf("%s\"%s\"", g_settings_get_string(settings, "default-terminal"), current_path),
                                                            "Terminal",
                                                            0,
                                                            NULL);
    g_app_info_launch(term_app,NULL,NULL,NULL);
}

void hook_context_menu(GtkWidget* _menu)
{
    if (_menu != menu)
        return;
    g_debug("Open Terminal");
   
    g_list_free_full (menus, (GDestroyNotify) gtk_widget_destroy);
    menus = NULL;

    GtkWidget *menuitem = gtk_menu_item_new_with_label(_("Open a terminal here"));
    gtk_menu_shell_append (GTK_MENU_SHELL(menu), menuitem);
    menus = g_list_prepend (menus, menuitem);
    g_signal_connect (menuitem, "activate", (GCallback) on_open_terminal_activated, NULL);
    gtk_widget_show (menuitem);
}

static void put_right_click_menu(GtkUIManager* ui_manager)
{
    menu = gtk_ui_manager_get_widget (ui_manager, "/background");
}

void receive_all_hook(void* user_data, int hook)
{
    switch(hook)
    {
    case MARLIN_PLUGIN_HOOK_INTERFACE:
        hook_interface_loaded(user_data);
        break;
    case MARLIN_PLUGIN_HOOK_CONTEXT_MENU:
        hook_context_menu(user_data);
        break;
    case MARLIN_PLUGIN_HOOK_UI:
        put_right_click_menu(user_data);
        break;
    case MARLIN_PLUGIN_HOOK_DIRECTORY:
        hook_directory_loaded(user_data);
        break;
    case MARLIN_PLUGIN_HOOK_INIT:
        hook_plugin_init(user_data);
        break;
    default:
        g_debug("Don't know this hook: %d", hook);
    }
}

