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
#include "gof-file.h"

static gchar* current_path = NULL;
static gboolean menu_added = FALSE;

void hook_interface_loaded(void* win_)
{
    printf("Interface Loaded\n");
}

void hook_plugin_init(void)
{
    printf("Init the plugin\n");
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
    GAppInfo* term_app = g_app_info_create_from_commandline(g_strdup_printf("/usr/bin/gnome-terminal --working-directory=%s", current_path),
                                                            "Terminal",
                                                            0,
                                                            NULL);
    g_app_info_launch(term_app,NULL,NULL,NULL);
}

void hook_context_menu(GtkWidget* menu)
{
    g_debug("Open Terminall");
    
    if(!menu_added)
    {
    g_debug("Open Terminall");
        GtkWidget* menuitem = gtk_menu_item_new_with_label("Open a terminal here");
	    gtk_menu_shell_append(menu, menuitem);
	    g_signal_connect(menuitem, "activate", on_open_terminal_activated, NULL);
	    gtk_widget_show_all (GTK_WIDGET (menu));
	    menu_added = TRUE;
	}
}

