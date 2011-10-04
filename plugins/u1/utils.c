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

#include <limits.h>
#include <stdlib.h>
#include <glib/gi18n.h>
#include <glib/gutils.h>
#include <glib/gfileutils.h>
#include <libsyncdaemon/libsyncdaemon.h>
#include "plugin.h"

gboolean
ubuntuone_check_shares_and_public_files (MarlinPluginsUbuntuOne *uon,
					 SyncdaemonFolderInfo *folder_info,
					 GtkWidget *widget)
{
	SyncdaemonInterface *interface;
	gboolean result = TRUE, has_shares = FALSE, has_published = FALSE;
	GString *question = NULL;

	question = g_string_new (_("This folder contains shared folders and/or published files:\n\n"));

	interface = syncdaemon_daemon_get_shares_interface (uon->syncdaemon);
	if (SYNCDAEMON_IS_SHARES_INTERFACE (interface)) {
		GSList *shared_list, *l;

		shared_list = syncdaemon_shares_interface_get_shared (SYNCDAEMON_SHARES_INTERFACE (interface));
		for (l = shared_list; l != NULL; l = l->next) {
			SyncdaemonShareInfo *share_info = SYNCDAEMON_SHARE_INFO (l->data);

			if (g_str_has_prefix (syncdaemon_share_info_get_path (share_info),
					      syncdaemon_folder_info_get_path (folder_info))
			    && syncdaemon_share_info_get_accepted (share_info)) {
				has_shares = TRUE;

				question = g_string_append (question, "\t- ");
				question = g_string_append (question, syncdaemon_share_info_get_path (share_info));
				question = g_string_append (question, _(" (Shared folder)\n"));
			}
		}

		g_slist_free (shared_list);
	}

	/* Now check for published files */
	interface = syncdaemon_daemon_get_publicfiles_interface (uon->syncdaemon);
	if (SYNCDAEMON_IS_PUBLICFILES_INTERFACE (interface)) {
		GSList *public_files, *l;
		public_files = syncdaemon_publicfiles_interface_get_public_files (SYNCDAEMON_PUBLICFILES_INTERFACE (interface));

		for (l = public_files; l != NULL; l = l->next) {
			const gchar *path;

			path = syncdaemon_file_info_get_path (SYNCDAEMON_FILE_INFO (l->data));
			if (g_str_has_prefix (path, syncdaemon_folder_info_get_path (folder_info))) {
				has_published = TRUE;

				question = g_string_append (question, "\t- ");
				question = g_string_append (question, path);
				question = g_string_append (question, _(" (Published at "));
				question = g_string_append (question, syncdaemon_file_info_get_public_url (SYNCDAEMON_FILE_INFO (l->data)));
				question = g_string_append (question, ")\n");
			}
		}

		g_slist_free (public_files);
	}

	if (has_shares || has_published) {
		GtkWidget *dialog;

		question = g_string_append (question, _("\nThis action will make these files and folders no "
							"longer available to other users. Would you like to "
							"proceed?"));
		dialog = gtk_message_dialog_new (
			GTK_WINDOW (gtk_widget_get_toplevel (widget)),
			0, GTK_MESSAGE_QUESTION,
			GTK_BUTTONS_YES_NO,
			"%s", question->str);
		if (gtk_dialog_run (GTK_DIALOG (dialog)) != GTK_RESPONSE_YES)
			result = FALSE;

		gtk_widget_destroy (dialog);
	}

	/* Free memory */
	g_string_free (question, TRUE);

	return result;
}

gboolean
ubuntuone_is_folder_shared (MarlinPluginsUbuntuOne *uon, const gchar *path)
{
	GSList *shares, *l;
	SyncdaemonInterface *interface;
	gboolean is_shared = FALSE;

	interface = syncdaemon_daemon_get_shares_interface (uon->syncdaemon);
	if (SYNCDAEMON_IS_SHARES_INTERFACE (interface)) {
		shares = syncdaemon_shares_interface_get_shared (SYNCDAEMON_SHARES_INTERFACE (interface));
		for (l = shares; l != NULL; l = l->next) {
			SyncdaemonShareInfo *share_info = SYNCDAEMON_SHARE_INFO (l->data);

			if (g_strcmp0 (syncdaemon_share_info_get_path (share_info), path) == 0) {
				is_shared = TRUE;
				break;
			}
		}

		g_slist_free (shares);
	}

	return is_shared;
}

/* 
 * Similar to ubuntuone_is_folder_shared but it checks if the passed
 * folder is inside a folder shared TO the user.
 *
 * Added to fix bug #712674
 */
gboolean
ubuntuone_is_inside_shares (MarlinPluginsUbuntuOne *uon, const gchar *path)
{
	gboolean is_shared_to_me = FALSE;
	gchar *resolved_path;
	gchar *prefix = g_build_filename (g_get_user_data_dir (), "ubuntuone", "shares", G_DIR_SEPARATOR_S, NULL);

	/* 
	 *  Have to use realpath because path contains a symlink like
	 * ~/Ubuntu One/Shared With Me -> ~/.local/share/ubuntuone/shares
	 * 
	 * This also claims ~/Ubuntu One/Shared with Me/foo is
	 * in a share even if it's not true. that's intentional since
	 * those files are never uploaded, and thus it makes no sense
	 * to publish them.
	 */
	resolved_path = realpath(path, NULL);
	if (g_str_has_prefix (resolved_path, prefix)) {
		is_shared_to_me = TRUE;
	}
	free (resolved_path);
	g_free (prefix);
	return is_shared_to_me;
}

