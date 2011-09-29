/*
 * Copyright (C) 2011 ammonkey <am.monkeyd@gmail.com>
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

#include "plugin.h"
#include <gtk/gtk.h>
#include <glib/gi18n.h>
#include <gof-file.h>
#include <libsyncdaemon/syncdaemon-folders-interface.h>
#include <libsyncdaemon/syncdaemon-publicfiles-interface.h>
#include <libsyncdaemon/syncdaemon-status-interface.h>

//static gpointer marlin_plugins_ubuntuone_parent_class = NULL;

#define MARLIN_PLUGINS_UBUNTUONE_GET_PRIVATE(o) (G_TYPE_INSTANCE_GET_PRIVATE ((o), MARLIN_PLUGINS_TYPE_UBUNTUONE, MarlinPluginsUbuntuOnePrivate))

G_DEFINE_TYPE (MarlinPluginsUbuntuOne, marlin_plugins_ubuntuone, MARLIN_PLUGINS_TYPE_BASE)

static void marlin_plugins_ubuntuone_finalize (MarlinPluginsBase* obj);

/*static gchar* current_path = NULL;
static gboolean menu_added = FALSE;
static GSettings* settings = NULL;
static GList *menus = NULL;
static GtkWidget *menu;*/

/* DBus signal handlers and async method call handlers */
static void
marlin_plugins_ubuntuone_daemon_ready (SyncdaemonDaemon *daemon, gpointer user_data)
{
	MarlinPluginsUbuntuOne * uon = MARLIN_PLUGINS_UBUNTUONE (user_data);
	gboolean is_online = FALSE;
	SyncdaemonInterface *interface;

	interface = syncdaemon_daemon_get_status_interface (daemon);
	if (interface != NULL) {
		SyncdaemonStatusInfo *status_info;

		status_info = syncdaemon_status_interface_get_current_status (SYNCDAEMON_STATUS_INTERFACE (interface));
		is_online = syncdaemon_status_info_get_online (status_info);
	}

	/* Get the root when we get a status change signal, if we haven't yet */
	if (!uon->gotroot) {
		uon->managed = g_build_filename (syncdaemon_daemon_get_root_dir (uon->syncdaemon), G_DIR_SEPARATOR_S, NULL);
		if (uon->managed != NULL)
			uon->gotroot = TRUE;
	}

	/* Get the list of UDFs if we haven't already */
	if (!uon->gotudfs) {
		SyncdaemonInterface *interface;

		interface = syncdaemon_daemon_get_folders_interface (uon->syncdaemon);
		if (interface != NULL) {
			GSList *folders, *l;

			folders = syncdaemon_folders_interface_get_folders (SYNCDAEMON_FOLDERS_INTERFACE (interface));
			for (l = folders; l != NULL; l = l->next) {
				const gchar *path, *id;
				gboolean subscribed;
				SyncdaemonFolderInfo *folder_info = SYNCDAEMON_FOLDER_INFO (l->data);

				path = syncdaemon_folder_info_get_path (folder_info);
        //amtest
        g_message ("U1 path %s %s", G_STRFUNC, path);
				id = syncdaemon_folder_info_get_volume_id (folder_info);
				subscribed = syncdaemon_folder_info_get_subscribed (folder_info);
				if (subscribed) {
					g_hash_table_insert (uon->udfs, g_strdup (path), g_strdup (id));
					uon->gotudfs = TRUE;

					file_watcher_update_path (uon->file_watcher, path);
				}
			}

			g_slist_free (folders);
		}
	}

	/* Get the list of public files if we haven't already */
	if (is_online) {
		SyncdaemonInterface *public;

		public = syncdaemon_daemon_get_publicfiles_interface (uon->syncdaemon);
		if (public != NULL) {
			GSList *files_list;

			/* We just call it here so that libsyncdaemon caches it, but we discard
			   the list, as we don't need it yet */
			files_list = syncdaemon_publicfiles_interface_get_public_files (SYNCDAEMON_PUBLICFILES_INTERFACE (public));
			g_slist_free (files_list);
		}
	}
}

static void 
marlin_plugins_ubuntuone_real_directory_loaded (MarlinPluginsBase *base, void *user_data) 
{
    GOFFile *file;

    g_message ("%s", G_STRFUNC);
    GObject *obj = ((GObject**) user_data)[2];
    file = g_object_ref ((GOFFile *) obj);
    g_message ("file %s", file->uri);

    //unref file

}

static void 
marlin_plugins_ubuntuone_update_file_info (MarlinPluginsBase *base, GOFFile *file) 
{
    MarlinPluginsUbuntuOne *u1 = MARLIN_PLUGINS_UBUNTUONE (base);

    file_watcher_add_file (u1->file_watcher, file);
}

static void 
marlin_plugins_ubuntuone_class_init (MarlinPluginsUbuntuOneClass *klass) {
    MarlinPluginsBaseClass *object_class = MARLIN_PLUGINS_BASE_CLASS (klass);
	//g_type_class_add_private (klass, sizeof (MarlinPluginsUbuntuOnePrivate));

	object_class->finalize = marlin_plugins_ubuntuone_finalize;
	object_class->directory_loaded = marlin_plugins_ubuntuone_real_directory_loaded;
	object_class->update_file_info = marlin_plugins_ubuntuone_update_file_info;
}


static void 
marlin_plugins_ubuntuone_init (MarlinPluginsUbuntuOne *u1) {
	//self->priv = MARLIN_PLUGINS_UBUNTUONE_GET_PRIVATE (self);
    //self->priv = g_new0 (MarlinPluginsUbuntuOnePrivate, 1);

    u1->connected = FALSE;
	u1->udfs = g_hash_table_new_full (g_str_hash, g_str_equal, g_free, NULL);
	u1->public = g_hash_table_new_full (g_str_hash, g_str_equal, g_free, g_free);

	u1->syncdaemon = syncdaemon_daemon_new ();
	g_signal_connect (G_OBJECT (u1->syncdaemon), "ready",
			  G_CALLBACK (marlin_plugins_ubuntuone_daemon_ready), u1);

	/* Create a FileWatcher object to watch files we know about */
	u1->file_watcher = file_watcher_new (u1);

	/* Default to ~/Ubuntu One for now, as it's all we really support */
	u1->managed = g_build_filename (g_get_home_dir (), "Ubuntu One", G_DIR_SEPARATOR_S, NULL);
	u1->gotroot = FALSE;
	u1->gotudfs = FALSE;
}


static void 
marlin_plugins_ubuntuone_finalize (MarlinPluginsBase* obj) {
	MarlinPluginsUbuntuOne * self = MARLIN_PLUGINS_UBUNTUONE (obj);

	//_g_object_unref0 (self->priv->trash_monitor);
	MARLIN_PLUGINS_BASE_CLASS (marlin_plugins_ubuntuone_parent_class)->finalize (obj);
}

MarlinPluginsUbuntuOne* marlin_plugins_ubuntuone_new () {
    MarlinPluginsUbuntuOne *u1;

    u1 = (MarlinPluginsUbuntuOne*) marlin_plugins_base_construct (MARLIN_PLUGINS_TYPE_UBUNTUONE);

	return u1;
}

MarlinPluginsBase* module_init()
{
    MarlinPluginsUbuntuOne* u1 = marlin_plugins_ubuntuone_new ();

    return MARLIN_PLUGINS_BASE (u1);
}

/*
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

static void hook_directory_loaded(GOFFile* path)
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
        hook_directory_loaded(((void**)user_data)[2]);
        break;
    case MARLIN_PLUGIN_HOOK_INIT:
        hook_plugin_init(user_data);
        break;
    default:
        g_debug("Don't know this hook: %d", hook);
    }
}*/

