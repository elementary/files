#include <gtk/gtk.h>


void hook_interface_loaded(void* win_)
{
     GtkWidget* win = gtk_window_new(0);
    gtk_container_add(win, gtk_label_new("Hello World"));
    gtk_widget_show_all(win);
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

void hook_directory_loaded(void* fm_view)
{
    printf("Directory loaded\n");
}
