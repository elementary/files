#include <gtk/gtk.h>

static gchar* current_path = NULL;
static gboolean menu_added = FALSE;

void hook_interface_loaded(void* win_)
{
/*    GtkWidget* win = gtk_window_new(0);
    gtk_container_add(win, gtk_label_new("Hello World"));
    gtk_widget_show_all(win);*/
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

void hook_directory_loaded(gchar* path)
{
    current_path = g_strdup(path);
}
static void on_open_terminal_activated(GtkWidget* widget, gpointer data)
{
GAppInfo* term_app = g_app_info_create_from_commandline  (g_strdup_printf("/usr/bin/gnome-terminal --working-directory=%s", current_path),
                                                         "Terminal",
                                                         0,
                                                         NULL);
 g_app_info_launch(term_app,NULL,NULL,NULL);
 }

void hook_context_menu(GtkWidget* menu)
{
    g_debug("Open Terminal");
    
    if(!menu_added)
    {
        GtkWidget* menuitem = gtk_menu_item_new_with_label("Open a terminal here");
	    gtk_menu_shell_append(menu, menuitem);
	    g_signal_connect(menuitem, "activate", on_open_terminal_activated, NULL);
	    gtk_widget_show_all (GTK_WIDGET (menu));
	    menu_added = TRUE;
	}
}

