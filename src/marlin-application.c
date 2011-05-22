/*
 * Copyright (C) 1999, 2000 Red Hat, Inc.
 * Copyright (C) 2000, 2001 Eazel, Inc.
 *
 * Marlin is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 * Authors: Elliot Lee <sopwith@redhat.com>,
 *          Darin Adler <darin@bentspoon.com>
 *
 */

#include <config.h>

#include "marlin-application.h"

#include "marlin-view-window.h"
#include "marlincore-vala.h"
#include "marlin-vala.h"
#include "marlin-progress-ui-handler.h"
#include "marlin-clipboard-manager.h"
#include "marlin-file-utilities.h"
#include "marlin-global-preferences.h"
#include "marlin-tags.h"
#include "marlin-plugin-manager.h"

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <glib/gstdio.h>
#include <glib/gi18n.h>
#include <gio/gio.h>
/*#include <eel/eel-gtk-extensions.h>
#include <eel/eel-gtk-macros.h>
#include <eel/eel-stock-dialogs.h>*/
#include <libnotify/notify.h>

#include <gdk/gdkx.h>
#include <gtk/gtk.h>

#define MARLIN_ACCEL_MAP_SAVE_DELAY 15

static MarlinApplication *singleton = NULL;

/* Keeps track of all the desktop windows. */
//static GList *marlin_application_desktop_windows;

/* The saving of the accelerator map was requested  */
static gboolean save_of_accel_map_requested = FALSE;

/*static void     mount_removed_callback            (GVolumeMonitor            *monitor,
  GMount                    *mount,
  MarlinApplication       *application);
  static void     mount_added_callback              (GVolumeMonitor            *monitor,
  GMount                    *mount,
  MarlinApplication       *application);*/

G_DEFINE_TYPE (MarlinApplication, marlin_application, GTK_TYPE_APPLICATION);

struct _MarlinApplicationPriv {
    /* TODO */
    //GVolumeMonitor *volume_monitor;
    MarlinProgressUIHandler *progress_handler;
    MarlinClipboardManager *clipboard;

    gboolean initialized;
};

static void
finish_startup (MarlinApplication *application,
                gboolean no_desktop)
{
    /* Initialize the UI handler singleton for file operations */
    notify_init (GETTEXT_PACKAGE);
    application->priv->progress_handler = marlin_progress_ui_handler_new ();
    application->priv->clipboard = marlin_clipboard_manager_new_get_for_display (gdk_display_get_default());

    /* TODO move the volume manager here? */
    /* TODO-gio: This should be using the UNMOUNTED feature of GFileMonitor instead */
    /*application->priv->volume_monitor = g_volume_monitor_get ();
      g_signal_connect_object (application->priv->volume_monitor, "mount_removed",
      G_CALLBACK (mount_removed_callback), application, 0);
      g_signal_connect_object (application->priv->volume_monitor, "mount_added",
      G_CALLBACK (mount_added_callback), application, 0);*/
}


static void selection_changed_plugin(GtkWidget* window, GOFFile* file)
{
    marlin_plugin_manager_hook_send(plugins, file, MARLIN_PLUGIN_HOOK_FILE);
}

static void
open_window (MarlinApplication *application,
             const char *uri, GdkScreen *screen)
{
    GFile *location;
    MarlinViewWindow *window;

    if (uri == NULL) {
        location = g_file_new_for_path (g_get_home_dir ());
    } else {
        location = g_file_new_for_uri (uri);
    }

    //DEBUG ("Opening new window at uri %s", uri);

    window = marlin_view_window_new (application, screen);
    g_signal_connect(window, "selection_changed", (GCallback) selection_changed_plugin, NULL);
    marlin_plugin_manager_interface_loaded(plugins, window);

    gtk_application_add_window (GTK_APPLICATION (application),
                                GTK_WINDOW (window));
    marlin_view_window_add_tab (window, location);
    marlin_plugin_manager_hook_send(plugins, window->ui, MARLIN_PLUGIN_HOOK_UI);

    g_object_unref (location);
}

static void
open_windows (MarlinApplication *application, char **uris, GdkScreen *screen)
{
    guint i;

    if (uris == NULL || uris[0] == NULL) {
        /* Open a window pointing at the default location. */
        open_window (application, NULL, screen);
    } else {
        /* Open windows at each requested location. */
        for (i = 0; uris[i] != NULL; i++) {
            open_window (application, uris[i], screen);
        }
    }
}

static void
open_tab (MarlinViewWindow *window, const char *uri)
{
    GFile *location;

    if (uri == NULL) {
        location = g_file_new_for_path (g_get_home_dir ());
    } else {
        location = g_file_new_for_uri (uri);
    }

    //DEBUG ("Opening new tab at uri %s", uri);
    marlin_view_window_add_tab (window, location);
    g_object_unref (location);
}

static void
open_tabs (MarlinApplication *application, char **uris, GdkScreen *screen)
{
    MarlinViewWindow *window;
    GList *list;
    guint i;

    /* get the first windows if any */
    list = gtk_application_get_windows (GTK_APPLICATION (application));
    if (list != NULL && list->data != NULL) {
        window = list->data;
    } else {
        window = marlin_view_window_new (application, screen);
        gtk_application_add_window (GTK_APPLICATION (application),
                                    GTK_WINDOW (window));
       marlin_plugin_manager_interface_loaded(plugins, window);
    }

    if (uris == NULL || uris[0] == NULL) { 
        open_tab (window, NULL);
    } else {
        /* Open tabs at each requested location. */
        for (i = 0; uris[i] != NULL; i++)
            open_tab (window, uris[i]);
    }
}

static gboolean 
marlin_application_save_accel_map (gpointer data)
{
    if (save_of_accel_map_requested) {
        char *accel_map_filename;
        accel_map_filename = marlin_get_accel_map_file ();
        if (accel_map_filename) {
            gtk_accel_map_save (accel_map_filename);
            g_free (accel_map_filename);
        }
        save_of_accel_map_requested = FALSE;
    }

    return FALSE;
}


static void 
queue_accel_map_save_callback (GtkAccelMap *object, gchar *accel_path,
                               guint accel_key, GdkModifierType accel_mods,
                               gpointer user_data)
{
    if (!save_of_accel_map_requested) {
        save_of_accel_map_requested = TRUE;
        g_timeout_add_seconds (MARLIN_ACCEL_MAP_SAVE_DELAY, 
                               marlin_application_save_accel_map, NULL);
    }
}

#if 0
static GtkWidget *
get_desktop_manager_selection (GdkDisplay *display, int screen)
{
    char selection_name[32];
    GdkAtom selection_atom;
    Window selection_owner;
    GtkWidget *selection_widget;

    g_snprintf (selection_name, sizeof (selection_name), "_NET_DESKTOP_MANAGER_S%d", screen);
    selection_atom = gdk_atom_intern (selection_name, FALSE);

    selection_owner = XGetSelectionOwner (GDK_DISPLAY_XDISPLAY (display),
                                          gdk_x11_atom_to_xatom_for_display (display, 
                                                                             selection_atom));
    if (selection_owner != None) {
        return NULL;
    }

    selection_widget = gtk_invisible_new_for_screen (gdk_display_get_screen (display, screen));
    /* We need this for gdk_x11_get_server_time() */
    gtk_widget_add_events (selection_widget, GDK_PROPERTY_CHANGE_MASK);

    if (gtk_selection_owner_set_for_display (display,
                                             selection_widget,
                                             selection_atom,
                                             gdk_x11_get_server_time (gtk_widget_get_window (selection_widget)))) {

        g_signal_connect (selection_widget, "selection_get",
                          G_CALLBACK (selection_get_cb), NULL);
        return selection_widget;
    }

    gtk_widget_destroy (selection_widget);

    return NULL;
}

static void
desktop_unrealize_cb (GtkWidget        *widget,
                      GtkWidget        *selection_widget)
{
    gtk_widget_destroy (selection_widget);
}

static gboolean
selection_clear_event_cb (GtkWidget	        *widget,
                          GdkEventSelection     *event,
                          MarlinDesktopWindow *window)
{
    gtk_widget_destroy (GTK_WIDGET (window));

    marlin_application_desktop_windows =
        g_list_remove (marlin_application_desktop_windows, window);

    return TRUE;
}

static void
marlin_application_create_desktop_windows (MarlinApplication *application)
{
    GdkDisplay *display;
    MarlinDesktopWindow *window;
    GtkWidget *selection_widget;
    int screens, i;

    display = gdk_display_get_default ();
    screens = gdk_display_get_n_screens (display);

    for (i = 0; i < screens; i++) {

        //DEBUG ("Creating a desktop window for screen %d", i);

        selection_widget = get_desktop_manager_selection (display, i);
        if (selection_widget != NULL) {
            window = marlin_desktop_window_new (application,
                                                gdk_display_get_screen (display, i));

            g_signal_connect (selection_widget, "selection_clear_event",
                              G_CALLBACK (selection_clear_event_cb), window);

            g_signal_connect (window, "unrealize",
                              G_CALLBACK (desktop_unrealize_cb), selection_widget);

            /* We realize it immediately so that the MARLIN_DESKTOP_WINDOW_ID
               property is set so gnome-settings-daemon doesn't try to set the
               background. And we do a gdk_flush() to be sure X gets it. */
            gtk_widget_realize (GTK_WIDGET (window));
            gdk_flush ();

            marlin_application_desktop_windows =
                g_list_prepend (marlin_application_desktop_windows, window);

            gtk_application_add_window (GTK_APPLICATION (application),
                                        GTK_WINDOW (window));
        }
    }
}

static void
marlin_application_open_desktop (MarlinApplication *application)
{
    if (marlin_application_desktop_windows == NULL) {
        marlin_application_create_desktop_windows (application);
    }
}

static void
marlin_application_close_desktop (void)
{
    if (marlin_application_desktop_windows != NULL) {
        g_list_foreach (marlin_application_desktop_windows,
                        (GFunc) gtk_widget_destroy, NULL);
        g_list_free (marlin_application_desktop_windows);
        marlin_application_desktop_windows = NULL;
    }
}
#endif

#if 0
void
marlin_application_close_all_windows (MarlinApplication *self)
{
    GList *list_copy;
    GList *l;

    list_copy = g_list_copy (gtk_application_get_windows (GTK_APPLICATION (self)));
    /* First hide all window to get the feeling of quick response */
    for (l = list_copy; l != NULL; l = l->next) {
        MarlinViewWindow *window;

        window = MARLIN_WINDOW (l->data);
        gtk_widget_hide (GTK_WIDGET (window));
    }

    for (l = list_copy; l != NULL; l = l->next) {
        MarlinViewWindow *window;

        window = MARLIN_WINDOW (l->data);
        marlin_window_close (window);
    }
    g_list_free (list_copy);
}
#endif

#if 0
/* callback for showing or hiding the desktop based on the user's preference */
static void
desktop_changed_callback (gpointer user_data)
{
    MarlinApplication *application;

    application = MARLIN_APPLICATION (user_data);
    if (g_settings_get_boolean (gnome_background_preferences, MARLIN_PREFERENCES_SHOW_DESKTOP)) {
        marlin_application_open_desktop (application);
    } else {
        marlin_application_close_desktop ();
    }
}
#endif

static GObject *
marlin_application_constructor (GType type,
                                guint n_construct_params,
                                GObjectConstructParam *construct_params)
{
    GObject *retval;

    if (singleton != NULL) {
        return g_object_ref (singleton);
    }

    retval = G_OBJECT_CLASS (marlin_application_parent_class)->constructor
        (type, n_construct_params, construct_params);

    singleton = MARLIN_APPLICATION (retval);
    g_object_add_weak_pointer (retval, (gpointer) &singleton);

    return retval;
}

static void
marlin_application_init (MarlinApplication *application)
{
    application->priv =
        G_TYPE_INSTANCE_GET_PRIVATE (application, MARLIN_TYPE_APPLICATION,
                                     MarlinApplicationPriv);
}

static void
marlin_application_finalize (GObject *object)
{
    MarlinApplication *application;

    application = MARLIN_APPLICATION (object);

    /* TODO check bookmarks */
    //marlin_bookmarks_exiting ();

    //g_clear_object (&application->priv->volume_monitor);
    g_clear_object (&application->priv->progress_handler);
    g_clear_object (&application->priv->clipboard);

    //marlin_dbus_manager_stop ();
    notify_uninit ();

    G_OBJECT_CLASS (marlin_application_parent_class)->finalize (object);
}

void
marlin_application_create_window_from_gfile (MarlinApplication *application, 
                                             GFile *location, GdkScreen *screen)
{
    MarlinViewWindow *window;

    if (location == NULL)
        location = g_file_new_for_path (g_get_home_dir ());
    else
        g_object_ref (location);

    //DEBUG ("Opening new window at uri %s", uri);

    window = marlin_view_window_new (application, screen);
    
    g_signal_connect(window, "selection_changed", (GCallback) selection_changed_plugin, NULL);

    gtk_application_add_window (GTK_APPLICATION (application),
                                GTK_WINDOW (window));
    marlin_view_window_add_tab (window, location);

    g_object_unref (location);
}

void
marlin_application_create_window (MarlinApplication *application,
                                  const char *uri, GdkScreen *screen)
{
    open_window (application, uri, screen);
}

void
marlin_application_quit (MarlinApplication *self)
{
    GApplication *app = G_APPLICATION (self);
    GList *windows;

    windows = gtk_application_get_windows (GTK_APPLICATION (app));
    g_list_foreach (windows, (GFunc) gtk_widget_destroy, NULL);
}

static gint
marlin_application_command_line (GApplication *app,
                                 GApplicationCommandLine *command_line)
{
    gboolean version = FALSE;
    gboolean no_default_window = FALSE;
    gboolean no_desktop = FALSE;
    gboolean kill_shell = FALSE;
    gboolean autostart_mode = FALSE;
    gboolean tab = FALSE;
    const gchar *autostart_id;
    gchar **remaining = NULL;
    const GOptionEntry options[] = {
        { "version", '\0', 0, G_OPTION_ARG_NONE, &version,
            N_("Show the version of the program."), NULL },
        { "no-desktop", '\0', 0, G_OPTION_ARG_NONE, &no_desktop,
            N_("Do not manage the desktop (ignore the preference set in the preferences dialog)."), NULL },
        { "tab", 't', 0, G_OPTION_ARG_NONE, &tab,
            N_("Open uri(s) in new tab"), NULL },
        { "quit", 'q', 0, G_OPTION_ARG_NONE, &kill_shell, 
            N_("Quit Marlin."), NULL },
        { G_OPTION_REMAINING, 0, 0, G_OPTION_ARG_STRING_ARRAY, &remaining, NULL,  N_("[URI...]") },

        { NULL }
    };
    GOptionContext *context;
    GError *error = NULL;
    MarlinApplication *self = MARLIN_APPLICATION (app);
    gint argc = 0;
    gchar **argv = NULL, **uris = NULL;
    gint retval = EXIT_SUCCESS;

    context = g_option_context_new (_("\n\nBrowse the file system with the file manager"));
    g_option_context_add_main_entries (context, options, NULL);
    g_option_context_add_group (context, gtk_get_option_group (TRUE));

    argv = g_application_command_line_get_arguments (command_line, &argc);

    autostart_id = g_getenv ("DESKTOP_AUTOSTART_ID");
    if (autostart_id != NULL && *autostart_id != '\0') {
        autostart_mode = TRUE;
    }

    if (!g_option_context_parse (context, &argc, &argv, &error)) {
        g_printerr ("Could not parse arguments: %s\n", error->message);
        g_error_free (error);

        retval = EXIT_FAILURE;
        goto out;
    }

    if (version) {
        g_application_command_line_print (command_line, "marlin " PACKAGE_VERSION "\n");
        goto out;
    }
    if (kill_shell && remaining != NULL) {
        g_application_command_line_printerr (command_line, "%s\n",
                                             _("--quit cannot be used with URIs."));
        retval = EXIT_FAILURE;
        goto out;
    }

    /* If in autostart mode (aka started by gnome-session), we need to ensure 
     * nautilus starts with the correct options.
     */
    if (autostart_mode) {
        no_default_window = TRUE;
        no_desktop = FALSE;
    }

    if (kill_shell) {
        marlin_application_quit (self);
    } else {
        if (!self->priv->initialized) {
            char *accel_map_filename;

            /* TODO */
            /*if (!no_desktop &&
              !g_settings_get_boolean (gnome_background_preferences,
              MARLIN_PREFERENCES_SHOW_DESKTOP)) {
              no_desktop = TRUE;
              }

              if (!no_desktop) {
              marlin_application_open_desktop (self);
              }*/

            finish_startup (self, no_desktop);

            /* Monitor the preference to show or hide the desktop */
            /*g_signal_connect_swapped (gnome_background_preferences, "changed::" MARLIN_PREFERENCES_SHOW_DESKTOP,
              G_CALLBACK (desktop_changed_callback),
              self);*/

            /* load accelerator map, and register save callback */
            accel_map_filename = marlin_get_accel_map_file ();
            if (accel_map_filename) {
                gtk_accel_map_load (accel_map_filename);
                g_free (accel_map_filename);
            }

            g_signal_connect (gtk_accel_map_get (), "changed",
                              G_CALLBACK (queue_accel_map_save_callback), NULL);

            self->priv->initialized = TRUE;
        }

        /* Convert args to URIs */
        if (remaining != NULL) {
            GFile *file;
            GPtrArray *uris_array;
            gint i;
            gchar *uri;

            uris_array = g_ptr_array_new ();

            for (i = 0; remaining[i] != NULL; i++) {
                file = g_file_new_for_commandline_arg (remaining[i]);
                if (file != NULL) {
                    uri = g_file_get_uri (file);
                    g_object_unref (file);
                    if (uri) {
                        g_ptr_array_add (uris_array, uri);
                    }
                }
            }

            g_ptr_array_add (uris_array, NULL);
            uris = (char **) g_ptr_array_free (uris_array, FALSE);
            g_strfreev (remaining);
        }

        /* Create the other windows. */
        if (uris != NULL || !no_default_window) {
            if (!tab)
                open_windows (self, uris, gdk_screen_get_default ());
            else
                open_tabs (self, uris, gdk_screen_get_default ());
        }
    }

out:
    g_option_context_free (context);
    g_strfreev (argv);

    return retval;
}

static void
marlin_application_startup (GApplication *app)
{
    MarlinApplication *self = MARLIN_APPLICATION (app);

    /* chain up to the GTK+ implementation early, so gtk_init()
     * is called for us.
     */
    G_APPLICATION_CLASS (marlin_application_parent_class)->startup (app);

    //log_level = LOG_LEVEL_DEBUG;
    log_level = LOG_LEVEL_UNDEFINED;
    log_println (LOG_LEVEL_INFO, "Welcome to Marlin");
    log_println (LOG_LEVEL_INFO, "Version: %s", PACKAGE_VERSION);
    log_println (LOG_LEVEL_INFO, "Report any issues/bugs you might find to lp:marlin");

    /* create an undo manager */
    //self->undo_manager = marlin_undo_manager_new ();

    /* gsettings parameters */
    settings = g_settings_new ("org.gnome.marlin.preferences");
    marlin_icon_view_settings = g_settings_new ("org.gnome.marlin.icon-view");
    tags = marlin_view_tags_new ();

    plugins = marlin_plugin_manager_new ();
    marlin_plugin_manager_load_plugins (plugins);

    /* register property pages */
    //marlin_image_properties_page_register ();

    /* initialize search path for custom icons */
    /*gtk_icon_theme_append_search_path (gtk_icon_theme_get_default (),
      MARLIN_DATADIR G_DIR_SEPARATOR_S "icons");*/

    //marlin_dbus_manager_start (app);
}

static void
marlin_application_quit_mainloop (GApplication *app)
{
    //DEBUG ("Quitting mainloop");

    //marlin_icon_info_clear_caches ();
    //marlin_application_save_accel_map (NULL);

    G_APPLICATION_CLASS (marlin_application_parent_class)->quit_mainloop (app);
}

static void
marlin_application_class_init (MarlinApplicationClass *class)
{
    GObjectClass *object_class;
    GApplicationClass *application_class;

    object_class = G_OBJECT_CLASS (class);
    object_class->constructor = marlin_application_constructor;
    object_class->finalize = marlin_application_finalize;

    application_class = G_APPLICATION_CLASS (class);
    application_class->startup = marlin_application_startup;
    application_class->command_line = marlin_application_command_line;
    application_class->quit_mainloop = marlin_application_quit_mainloop;

    g_type_class_add_private (class, sizeof (MarlinApplication));
}

MarlinApplication *
marlin_application_new (void)
{
    return g_object_new (MARLIN_TYPE_APPLICATION,
                         "application-id", "org.elementary.MarlinApplication",
                         "flags", G_APPLICATION_HANDLES_COMMAND_LINE,
                         NULL);
}
