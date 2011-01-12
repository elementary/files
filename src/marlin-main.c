#include <config.h>
#include "gof-directory-async.h"
#include "gof-window-slot.h"
#include "marlin-window-columns.h"
//#include <glib/gi18n.h>
//#include <libintl.h>
#include "marlin-global-preferences.h"
#include "marlin-view-window.h"
#include "marlin-vala.h"
#include "marlin-tags.h"


int
main (int argc, char *argv[])
{
    MarlinViewWindow *window;
    GtkWidget       *vbox;
    GtkWidget       *hbox;
    GtkWidget       *btn;
    GtkWidget       *entry;
    gchar           *path;
    GFile           *location;

    //log_level = LOG_LEVEL_DEBUG;
    log_level = LOG_LEVEL_UNDEFINED;
    log_println (LOG_LEVEL_INFO, "Welcome to Marlin");
    log_println (LOG_LEVEL_INFO, "Version: %s", "0.1");
    log_println (LOG_LEVEL_INFO, "Report any issues/bugs you might find to lp:marlin", "0.1");

    gtk_init (&argc, &argv);
    /* Initialize gettext support */
    bindtextdomain (GETTEXT_PACKAGE, GNOMELOCALEDIR);
    bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
    textdomain (GETTEXT_PACKAGE);

    g_set_application_name ("marlin");
    g_set_prgname ("marlin");

    /* gsettings parameters */
    settings = g_settings_new ("org.gnome.marlin.preferences");
    tags = marlin_view_tags_new ();
    /*gboolean showall = g_settings_get_boolean (settings, "showall");
      log_printf (LOG_LEVEL_UNDEFINED, "test gsettings showall: %d\n", showall);*/

    /*window = gtk_window_new (GTK_WINDOW_TOPLEVEL);
      gtk_window_set_title (GTK_WINDOW (window), "marlin");
      gtk_window_set_default_size (GTK_WINDOW (window), 600, 300);
      gtk_container_set_border_width (GTK_CONTAINER (window), 0);
      g_signal_connect (window, "destroy", gtk_main_quit, NULL);*/

    if (argc > 1) {
        path = g_strdup(argv[1]);
    } else {
        path = g_strdup(g_get_home_dir());
    }

    window = marlin_view_window_new ();
    location = g_file_new_for_commandline_arg(path);
    marlin_view_window_add_tab (window, location);

    /*g_signal_connect (window, "up", (GCallback) marlin_view_window_up, NULL);*/
    /*g_signal_connect (window, "back", (GCallback) marlin_view_window_back, NULL);
      g_signal_connect (window, "forward", (GCallback) __lambda23__marlin_view_window_forward, NULL);
      g_signal_connect (window, "refresh", (GCallback) __lambda24__marlin_view_window_refresh, NULL);*/
    //g_signal_connect (window, "quit", (GCallback) gtk_main_quit, NULL);
    //g_signal_connect (window, "path-changed", (GCallback) marlin_view_window_path_changed, NULL);
    //g_signal_connect (window, "browser-path-changed", (GCallback) marlin_view_window_path_changed, NULL);

    //g_signal_emit_by_name (window, "path-changed", g_file_new_for_commandline_arg (path));

    /*GtkBindingSet *binding_set;

      binding_set = gtk_binding_set_by_class (MARLIN_VIEW_WINDOW_CLASS (window));
      gtk_binding_entry_add_signal (binding_set, GDK_KEY_BackSpace, 0,
      "up", 1,
      G_TYPE_BOOLEAN, FALSE);*/
    
    g_object_unref (location);

    gtk_main ();
    g_free (path);
    return 0;
}

