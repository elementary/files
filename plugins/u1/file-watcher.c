/*
 * UbuntuOne Nautilus plugin
 *
 * Authors: Rodrigo Moya <rodrigo.moya@canonical.com>
 *
 * Copyright 2009-2010 Canonical Ltd.
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License version 3, as published
 * by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranties of
 * MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 * PURPOSE.  See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include <config.h>
#include <glib/gi18n-lib.h>
#include <libsyncdaemon/libsyncdaemon.h>
#include "file-watcher.h"
#include "plugin.h"

G_DEFINE_TYPE(FileWatcher, file_watcher, G_TYPE_OBJECT)

static void observed_file_unrefed (gpointer user_data, GObject *where_the_object_was);

static void
foreach_weak_unref (gpointer key, gpointer value, gpointer user_data)
{
	g_object_weak_unref (G_OBJECT (value),
			     (GWeakNotify) observed_file_unrefed,
			     user_data);
}

static void
file_watcher_finalize (GObject *object)
{
	FileWatcher *watcher = FILE_WATCHER (object);

	if (watcher->files != NULL) {
		g_hash_table_foreach (watcher->files, (GHFunc) foreach_weak_unref, watcher);
		g_hash_table_destroy (watcher->files);
	}

	G_OBJECT_CLASS (file_watcher_parent_class)->finalize (object);
}

static void
file_watcher_class_init (FileWatcherClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);

	object_class->finalize = file_watcher_finalize;
}

static void
file_watcher_init (FileWatcher *watcher)
{
	watcher->uon = NULL;
	watcher->files = g_hash_table_new_full (g_str_hash, g_str_equal, g_free, NULL);
}

static void
transfer_started_cb (SyncdaemonDaemon *daemon,
		   gchar *path,
		   gpointer user_data)
{
    //amtest
    g_message ("!!!!!!!!! %s %s", G_STRFUNC, path);
	FileWatcher *watcher = FILE_WATCHER (user_data);

	file_watcher_update_path (watcher, path);
}

static void
transfer_finished_cb (SyncdaemonDaemon *daemon,
		    gchar *path,
		    SyncdaemonTransferInfo * info,
		    gpointer user_data)
{
	FileWatcher *watcher = FILE_WATCHER (user_data);

	file_watcher_update_path (watcher, path);
}

static void
share_created_cb (SyncdaemonDaemon *daemon,
		  gboolean success,
		  SyncdaemonShareInfo *share_info,
		  gpointer user_data)
{
	FileWatcher *watcher = FILE_WATCHER (user_data);
	const gchar * path;

	path = syncdaemon_share_info_get_path (share_info);
	if (success) {
		file_watcher_update_path (watcher, path);
	} else {
        //FIXME
		/*ubuntuone_show_error_dialog (watcher->uon, _("Error creating share."),
					     _("There was an error sharing the folder '%s'"),
					     path);*/
	}
}

static void
share_deleted_cb (SyncdaemonDaemon *daemon,
		  gboolean success,
		  SyncdaemonShareInfo *share_info,
		  gpointer user_data)
{
	FileWatcher *watcher = FILE_WATCHER (user_data);
	const gchar *path;

	path = syncdaemon_share_info_get_path (share_info);
	if (success) {
		file_watcher_update_path (watcher, path);
	} else {
        //FIXME
		/*ubuntuone_show_error_dialog (watcher->uon, _("Error deleting share."),
					     _("There was an error deleting the share for folder '%s'"),
					     path);*/
	}
}

static void
udf_created_cb (SyncdaemonDaemon *daemon,
		gboolean success,
		SyncdaemonFolderInfo *folder_info,
		gpointer user_data)
{
	FileWatcher *watcher = FILE_WATCHER (user_data);
	const gchar *path, *id;
	gboolean subscribed;

	path = syncdaemon_folder_info_get_path (folder_info);
	id = syncdaemon_folder_info_get_volume_id (folder_info);
	subscribed = syncdaemon_folder_info_get_subscribed (folder_info);
	if (success) {
		if (!g_hash_table_lookup (watcher->uon->udfs, path)) {
			if (subscribed) {
				g_hash_table_insert (watcher->uon->udfs, g_strdup (path), g_strdup (id));

				/* Update the emblems of the files on this new UDF */
				file_watcher_update_path (watcher, path);
			}
		}
	}
}

static void
udf_deleted_cb (SyncdaemonDaemon *daemon,
		gboolean success,
		SyncdaemonFolderInfo *folder_info,
		gpointer user_data)
{
	FileWatcher *watcher = FILE_WATCHER (user_data);
	const gchar * path;

	path = syncdaemon_folder_info_get_path (folder_info);
	if (path != NULL && success) {
		/* Remove the files from the status hash table */
		g_hash_table_remove (watcher->uon->udfs, path);

		file_watcher_update_path (watcher, path);
	}
}

static void
file_published_cb (SyncdaemonDaemon *daemon,
		   gboolean success,
		   SyncdaemonFileInfo *finfo,
		   gpointer user_data)
{
	FileWatcher *watcher = FILE_WATCHER (user_data);
	const gchar * path, * url;
	gboolean is_public;

	path = syncdaemon_file_info_get_path (finfo);
	if (success) {
		url = syncdaemon_file_info_get_public_url (finfo);
		is_public = syncdaemon_file_info_get_is_public (finfo);

		if (!is_public && g_hash_table_lookup (watcher->uon->public, path))
			g_hash_table_remove (watcher->uon->public, path);

		if (is_public)
			g_hash_table_replace (watcher->uon->public, g_strdup (path), g_strdup (url));

		file_watcher_update_path (watcher, path);
	} else {
        //FIXME
		/*ubuntuone_show_error_dialog (watcher->uon, _("Error publishing file."),
					     _("There was an error publishing file '%s'"),
					     path);*/
	}
}

FileWatcher *
file_watcher_new (MarlinPluginsUbuntuOne *uon)
{
	FileWatcher *watcher;

	watcher = g_object_new (TYPE_FILE_WATCHER, NULL);
	watcher->uon = uon;

	/* Connect to transfers-related signals */
	g_signal_connect (G_OBJECT (uon->syncdaemon), "upload_started",
			  G_CALLBACK (transfer_started_cb), watcher);
	g_signal_connect (G_OBJECT (uon->syncdaemon), "upload_finished",
			  G_CALLBACK (transfer_finished_cb), watcher);
	g_signal_connect (G_OBJECT (uon->syncdaemon), "download_started",
			  G_CALLBACK (transfer_started_cb), watcher);
	g_signal_connect (G_OBJECT (uon->syncdaemon), "download_finished",
			  G_CALLBACK (transfer_finished_cb), watcher);

	/* Connect to shares-related signals */
	g_signal_connect (G_OBJECT (uon->syncdaemon), "share_created",
			  G_CALLBACK (share_created_cb), watcher);
	g_signal_connect (G_OBJECT (uon->syncdaemon), "share_deleted",
			  G_CALLBACK (share_deleted_cb), watcher);

	/* Connect to folder-related signals */
	g_signal_connect (G_OBJECT (uon->syncdaemon), "folder_created",
		    G_CALLBACK (udf_created_cb), watcher);
	g_signal_connect (G_OBJECT (uon->syncdaemon), "folder_subscribed",
			  G_CALLBACK (udf_created_cb), watcher);
	g_signal_connect (G_OBJECT (uon->syncdaemon), "folder_deleted",
			  G_CALLBACK (udf_deleted_cb), watcher);
	g_signal_connect (G_OBJECT (uon->syncdaemon), "folder_unsubscribed",
			  G_CALLBACK (udf_deleted_cb), watcher);

	/* Connect to public files-related signals */
	g_signal_connect (G_OBJECT (uon->syncdaemon), "file_published",
			  G_CALLBACK (file_published_cb), watcher);
	g_signal_connect (G_OBJECT (uon->syncdaemon), "file_unpublished",
			  G_CALLBACK (file_published_cb), watcher);

	return watcher;
}

static gboolean
check_for_shared_folder (const gchar *path, GSList *list_of_shares)
{
	GSList *l;
	gboolean is_shared = FALSE;

	for (l = list_of_shares; l != NULL; l = l->next) {
		SyncdaemonShareInfo *share_info = SYNCDAEMON_SHARE_INFO (l->data);

		if (g_strcmp0 (syncdaemon_share_info_get_path (share_info), path) == 0) {
			is_shared = TRUE;
			break;
		}
	}

	g_slist_free (list_of_shares);

	return is_shared;
}

static void
observed_file_unrefed (gpointer user_data, GObject *where_the_object_was)
{
	gchar *path;
	FileWatcher *watcher = FILE_WATCHER (user_data);

	path = g_filename_from_uri (GOF_FILE (where_the_object_was)->uri, NULL, NULL);
    //amtest
    g_message (">>>>> %s %s", G_STRFUNC, path);

	if (path == NULL)
		return;

	if (g_hash_table_lookup (watcher->files, path))
		g_hash_table_remove (watcher->files, path);

	g_free (path);
}

void
file_watcher_add_file (FileWatcher *watcher, GOFFile *file)
{
	gboolean is_root;
	gchar *path = NULL;
	GOFFile *old_file;

	g_return_if_fail (IS_FILE_WATCHER (watcher));

	path = g_filename_from_uri (file->uri, NULL, NULL);
	if (path == NULL)
		return;

	/* Always add it to the observed hash table, so that we can update emblems */
	if ((old_file = g_hash_table_lookup (watcher->files, path))) {
		g_object_weak_unref (G_OBJECT (old_file),
				     (GWeakNotify) observed_file_unrefed, watcher);
	}

	g_object_weak_ref (G_OBJECT (file),
			   (GWeakNotify) observed_file_unrefed, watcher);
	g_hash_table_insert (watcher->files, g_strdup (path), file);

	/* Retrieve metadata */
	if (syncdaemon_daemon_is_folder_enabled (watcher->uon->syncdaemon, path, &is_root)) {
		SyncdaemonInterface *interface;

		interface = syncdaemon_daemon_get_filesystem_interface (watcher->uon->syncdaemon);
		if (interface != NULL) {
			SyncdaemonMetadata *metadata;
			//gboolean is_dir = nautilus_file_info_is_directory (file);
			gboolean is_dir = file->is_directory;

			metadata = syncdaemon_filesystem_interface_get_metadata (
				SYNCDAEMON_FILESYSTEM_INTERFACE (interface), path, is_dir);
			if (SYNCDAEMON_IS_METADATA (metadata)) {
				if (syncdaemon_metadata_get_is_synced (metadata))
                    //FIXME
					//nautilus_file_info_add_emblem (file, "ubuntuone-synchronized");
					g_message ("U1: %s %s", file->uri, "ubuntuone-synchronized");
				else
					//nautilus_file_info_add_emblem (file, "ubuntuone-updating");
					g_message ("U1: %s %s", file->uri, "ubuntuone-updating");

				if (is_dir) {
					/* If it's a directory, check shares */
					interface = syncdaemon_daemon_get_shares_interface (watcher->uon->syncdaemon);
					if (check_for_shared_folder ((const gchar *) path,
								     syncdaemon_shares_interface_get_shared (SYNCDAEMON_SHARES_INTERFACE (interface))) ||
					    check_for_shared_folder ((const gchar *) path,
								     syncdaemon_shares_interface_get_shares (SYNCDAEMON_SHARES_INTERFACE (interface)))) {
						//nautilus_file_info_add_emblem (file, "shared");
					    g_message ("U1: %s %s", file->uri, "shared");
					}
				} else {
					GSList *public_files, *l;

					/* If it's a file, check for public files */
					interface = syncdaemon_daemon_get_publicfiles_interface (watcher->uon->syncdaemon);
					public_files = syncdaemon_publicfiles_interface_get_public_files (SYNCDAEMON_PUBLICFILES_INTERFACE (interface));
					for (l = public_files; l != NULL; l = l->next) {
						SyncdaemonFileInfo *file_info = SYNCDAEMON_FILE_INFO (l->data);

						if (!SYNCDAEMON_IS_FILE_INFO (file_info))
							continue;

						if (g_strcmp0 (path, syncdaemon_file_info_get_path (file_info)) == 0) {
							//nautilus_file_info_add_emblem (file, "ubuntuone-public");
					        g_message ("U1: %s %s", file->uri, "ubuntuone-public");
							break;
						}
					}

					g_slist_free (public_files);
				}

				/* Free memory */
				g_object_unref (G_OBJECT (metadata));
			}
		}
	}

	g_free (path);
}

void
file_watcher_update_path (FileWatcher *watcher, const gchar *path)
{
	GHashTableIter iter;
	gchar *key;
	GOFFile *file;

	g_return_if_fail (IS_FILE_WATCHER (watcher));

	/* Remove emblems from all files in the specified path */
	/*g_hash_table_iter_init (&iter, watcher->files);
	while (g_hash_table_iter_next (&iter, (gpointer *) &key, (gpointer *) &file)) {
		if (g_str_has_prefix (key, path) || g_strcmp0 (key, path) == 0)
			nautilus_file_info_invalidate_extension_info (file);
	}*/
}
