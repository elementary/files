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

//static void     marlin_view_window_up (MarlinViewWindow *window);
//static void     marlin_view_window_back (MarlinViewWindow *window);
//static void     marlin_view_window_path_changed (MarlinViewWindow *window, GFile *file, gpointer data);


int
main (int argc, char *argv[])
{
    MarlinViewWindow *window;
    GtkWidget       *vbox;
    GtkWidget       *hbox;
    GtkWidget       *btn;
    GtkWidget       *entry;
    gchar           *path;


    log_level = LOG_LEVEL_DEBUG;
    log_println (LOG_LEVEL_INFO, "Welcome to Marlin");
    log_println (LOG_LEVEL_INFO, "Version: %s", "0.1");
    log_println (LOG_LEVEL_INFO, "Report any issues/bugs you might find to lp:marlin", "0.1");

    gtk_init (&argc, &argv);
    /* Initialize gettext support */
    bindtextdomain (GETTEXT_PACKAGE, GNOMELOCALEDIR);
    bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
    textdomain (GETTEXT_PACKAGE);

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
        path = argv[1];
    } else {
        path = g_strdup(g_get_home_dir());
    }

    window = marlin_view_window_new ();
    marlin_view_window_add_tab (window, g_file_new_for_commandline_arg(path));

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


    gtk_main ();
    g_free (path);
    return 0;
}


#if 0
static void
marlin_view_window_up (MarlinViewWindow *window)
{
    GOFWindowSlot *slot;
    GFile *parent;

    if ((slot = GOF_WINDOW_SLOT (marlin_view_window_get_active_slot(window))) == NULL)
        return;
    if (slot->location == NULL)
        return;
    parent = g_file_get_parent (slot->location);
    if (parent == NULL)
        return;

    /*if (slot->mwcols != NULL)
      marlin_window_columns_change_location (slot, parent);
      else
      gof_window_slot_change_location (slot, parent);*/
    //g_signal_emit_by_name (window, "path-changed", "/home/am/Images");
    g_signal_emit_by_name (window, "path-changed", parent);
    g_object_unref (parent);
    log_printf (LOG_LEVEL_UNDEFINED, "!!!!!!!! %s\n", G_STRFUNC);
}
#endif

/*
   static void
   marlin_view_window_back (MarlinViewWindow *window)
   {
   log_printf (LOG_LEVEL_INFO, "%s\n", G_STRFUNC);
   }*/

#if 0
static void
marlin_view_window_path_changed (MarlinViewWindow *window, GFile *file, gpointer data)
{
    GOFWindowSlot *slot;
    MarlinWindowColumns *mwcols;

    g_return_if_fail (file != NULL);
    /*if ((slot = GOF_WINDOW_SLOT (marlin_view_window_get_active_slot(window))) != NULL)
      load_dir_async_cancel(slot->directory);*/
    slot = gof_window_slot_new(file, GTK_WIDGET (window));
    //mwcols = marlin_window_columns_new(file, GTK_WIDGET (window));
}
#endif

