/*
 * UbuntuOne Marlin plugin
 *
 * Authors: Rodrigo Moya <rodrigo.moya@canonical.com>
 *          ammonkey <am.monkeyd@gmail.com>
 *
 * Copyright 2009-2010  Canonical Ltd.
 *           20011      ammonkey
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
#include <gio/gio.h>
#include <libsyncdaemon/libsyncdaemon.h>
#include "context-menu.h"
#include "share-dialog.h"

static gpointer _g_object_ref0 (gpointer self) {
	return self ? g_object_ref (self) : NULL;
}

typedef struct {
    MarlinPluginsUbuntuOne *uon;
    gchar *path;
    GtkWidget *parent;

    /* Whether to make a file public or private */
    gboolean make_public;
} MenuCallbackData;

static void
free_menu_cb_data (gpointer data, GObject *where_the_object_was)
{
    MenuCallbackData *cb_data = (MenuCallbackData *) data;

    g_free (cb_data->path);
    g_free (cb_data);
}

/* Menu callbacks */
static void
got_public_meta (SyncdaemonFilesystemInterface *interface,
                 gboolean success,
                 SyncdaemonMetadata *metadata,
                 gpointer user_data)
{
    MenuCallbackData *data = (MenuCallbackData *) user_data;
    const gchar * share_id, * node_id;
    SyncdaemonInterface *public;

    if (!success) {
        g_warning ("ERROR: getting metadata for public file");
        return;
    }

    share_id = syncdaemon_metadata_get_share_id (metadata);
    node_id = syncdaemon_metadata_get_node_id (metadata);

    public = syncdaemon_daemon_get_publicfiles_interface (data->uon->syncdaemon);
    if (public != NULL) {
        syncdaemon_publicfiles_interface_change_public_access (SYNCDAEMON_PUBLICFILES_INTERFACE (public),
                                                               share_id, node_id, data->make_public);
    }
}

static void
unsubscribe_folder_cb (GtkWidget *item, gpointer user_data)
{
    SyncdaemonInterface *interface;
    MenuCallbackData * data = (MenuCallbackData *) user_data;

    /* Perform the removal of this folder */
    interface = syncdaemon_daemon_get_folders_interface (data->uon->syncdaemon);
    if (interface != NULL) {
        SyncdaemonFolderInfo *folder_info;

        folder_info = syncdaemon_folders_interface_get_info (SYNCDAEMON_FOLDERS_INTERFACE (interface),
                                                             data->path);
        if (folder_info != NULL) {
            if (ubuntuone_check_shares_and_public_files (data->uon, folder_info, data->parent)) {
                syncdaemon_folders_interface_delete (SYNCDAEMON_FOLDERS_INTERFACE (interface),
                                                     syncdaemon_folder_info_get_volume_id (folder_info));
            }
            g_object_unref (G_OBJECT (folder_info));
        }
    }
}

static void
subscribe_folder_cb (GtkWidget *item, gpointer user_data)
{
    SyncdaemonInterface *interface;
    MenuCallbackData * data = (MenuCallbackData *) user_data;

    /* Perform the addition of this folder */
    interface = syncdaemon_daemon_get_folders_interface (data->uon->syncdaemon);
    if (interface != NULL) {
        /* If there is no user authenticated, make Syncdaemon do so */
        if (!syncdaemon_authentication_has_credentials (syncdaemon_daemon_get_authentication (data->uon->syncdaemon)))
            syncdaemon_daemon_connect (data->uon->syncdaemon);
        syncdaemon_folders_interface_create (SYNCDAEMON_FOLDERS_INTERFACE (interface),
                                             data->path);
    }
}

static void
copy_public_url_cb (GtkWidget *item, gpointer user_data)
{
    MenuCallbackData * data = (MenuCallbackData *) user_data;
    gchar * url;

    url = g_hash_table_lookup (data->uon->public, data->path);
    gtk_clipboard_set_text (gtk_clipboard_get(GDK_SELECTION_CLIPBOARD),
                            url, strlen (url));
    gtk_clipboard_store (gtk_clipboard_get(GDK_SELECTION_CLIPBOARD));
}

static void
toggle_publicity_cb (GtkWidget * item, gpointer user_data)
{
    SyncdaemonFilesystemInterface *interface;
    MenuCallbackData * data = (MenuCallbackData *) user_data;

    interface = (SyncdaemonFilesystemInterface *) syncdaemon_daemon_get_filesystem_interface (data->uon->syncdaemon);
    if (interface != NULL) {
        /* we know this will not be a directory (so no need for _and_quick_tree_synced) */
        syncdaemon_filesystem_interface_get_metadata_async (interface, data->path, FALSE,
                                                            (SyncdaemonGotMetadataFunc) got_public_meta, data);
    }

    g_hash_table_replace (data->uon->public, g_strdup (data->path), g_strdup (UPDATE_PENDING));
    file_watcher_update_path (data->uon->file_watcher, data->path);
}

static void
share_folder_cb (GtkWidget *item, gpointer user_data)
{
    MenuCallbackData * data = (MenuCallbackData *) user_data;
    GtkWidget * dialog;

    dialog = share_dialog_new (data->parent, data->uon, data->path);
    gtk_widget_show (dialog);
}

static void
unshare_folder_cb (GtkWidget *item, gpointer user_data)
{
    MenuCallbackData * data = (MenuCallbackData *) user_data;
    SyncdaemonSharesInterface *interface;

    interface = (SyncdaemonSharesInterface *) syncdaemon_daemon_get_shares_interface (data->uon->syncdaemon);
    if (interface != NULL)
        syncdaemon_shares_interface_delete (interface, data->path);
}

gboolean
check_share_offer_pending (MarlinPluginsUbuntuOne *uon, const gchar *path)
{
    GSList *shares, *l;
    SyncdaemonInterface *interface;
    gboolean is_share_offer_pending = FALSE;
    const gchar *node_id;

    interface = syncdaemon_daemon_get_shares_interface (uon->syncdaemon);
    if (SYNCDAEMON_IS_SHARES_INTERFACE (interface)) {
        shares = syncdaemon_shares_interface_get_shared (SYNCDAEMON_SHARES_INTERFACE (interface));
        for (l = shares; l != NULL; l = l->next) {
            SyncdaemonShareInfo *share_info = SYNCDAEMON_SHARE_INFO (l->data);

            if (g_strcmp0 (syncdaemon_share_info_get_path (share_info), path) == 0) {
                node_id = syncdaemon_share_info_get_node_id (share_info);
                if (node_id == NULL)
                    is_share_offer_pending = TRUE;
                break;
            }
        }

        g_slist_free (shares);
    }

    return is_share_offer_pending;
}

void 
context_menu_new (MarlinPluginsUbuntuOne *u1, GtkWidget *menu)
{
    GOFFile *file;
    GtkWidget *submenu;
    GtkWidget *root_item, *menu_item, *urlitem;
    gchar *path, *item, *homedir_path;
    gboolean is_managed, is_root, is_udf, is_public, is_shared, is_pending;
    gboolean is_shared_to_me, is_inhome, is_dir, is_regular, is_symlink;
    gboolean is_share_offer_pending;
    MenuCallbackData *cb_data;

    is_managed = is_root = is_udf = is_public = is_shared = is_pending = FALSE;
    is_shared_to_me = is_inhome = is_dir = is_regular = is_symlink = FALSE;
    is_share_offer_pending = FALSE;

    if (g_list_length (u1->selection) != 1)
        return;

    file = GOF_FILE (g_list_nth_data (u1->selection, 0));
    path = g_filename_from_uri (file->uri, NULL, NULL);

    if (path == NULL)
        return;

    if (syncdaemon_daemon_is_folder_enabled (u1->syncdaemon, path, &is_root))
        is_managed = TRUE;

    homedir_path = g_strdup_printf ("%s/", g_get_home_dir());
    if (strncmp (path, homedir_path, strlen (homedir_path)) == 0)
        is_inhome = TRUE;
    g_free (homedir_path);

    if ((item = g_hash_table_lookup (u1->udfs, path)) != NULL) {
        is_udf = TRUE;
        if (strcmp (item, UPDATE_PENDING) == 0)
            is_pending = TRUE;
    } else if ((item = g_hash_table_lookup (u1->public, path)) != NULL) {
        is_public = TRUE;
        if (strcmp (item, UPDATE_PENDING) == 0)
            is_pending = TRUE;
    }

    if (ubuntuone_is_folder_shared (u1, path)) {
        is_shared = TRUE;
        if (check_share_offer_pending (u1, path))
            is_share_offer_pending = TRUE;
    }

    if (ubuntuone_is_inside_shares (u1, path))
        is_shared_to_me = TRUE;

    is_dir = file->is_directory;
    is_regular = file->file_type == G_FILE_TYPE_REGULAR;

    is_symlink = gof_file_is_symlink (file);

    cb_data = g_new0 (MenuCallbackData, 1);
    cb_data->uon = u1;
    //FIXME
    //cb_data->parent = window;
    cb_data->parent = NULL;
    cb_data->path = g_strdup (path);

    root_item = gtk_menu_item_new_with_mnemonic (_("_Ubuntu One"));
    submenu = gtk_menu_new ();
    gtk_widget_show (root_item);
    gtk_menu_item_set_submenu ((GtkMenuItem *) root_item,submenu);
    gtk_menu_shell_append ((GtkMenuShell*) menu, root_item);
    plugins->menus = g_list_prepend (plugins->menus, _g_object_ref0 (root_item));

    g_object_weak_ref (G_OBJECT (root_item), (GWeakNotify) free_menu_cb_data, cb_data);

    menu_item = gtk_menu_item_new_with_mnemonic (_("_Share..."));
    /* Share/unshare */
    if ((is_managed || is_udf) && !is_root && is_dir && !is_symlink) {
        if (is_pending)
            g_object_set (menu_item, "sensitive", FALSE, NULL);

        g_signal_connect (menu_item, "activate",
                          G_CALLBACK (share_folder_cb), cb_data);
    } else {
        g_object_set (menu_item, "sensitive", FALSE, NULL);
    }

    //gtk_widget_show (menu_item);
    gtk_menu_shell_append (GTK_MENU_SHELL (submenu), menu_item);

    if ((is_managed && is_shared) && !is_root && is_dir && !is_symlink) {
        menu_item = gtk_menu_item_new_with_mnemonic (_("Stop _Sharing"));
        if (is_pending || is_share_offer_pending)
            g_object_set (menu_item, "sensitive", FALSE, NULL);

        g_signal_connect (menu_item, "activate",
                          G_CALLBACK (unshare_folder_cb), cb_data);
        gtk_menu_shell_append (GTK_MENU_SHELL (submenu), menu_item);
    }

    /* UDF logic
     *
     * XXX: clean this up and separate the logic out and reuse this
     * and locationbar somewhere (libsd?)
     */
    menu_item = NULL;

    if (is_dir && is_inhome && !is_symlink) {
        /* UDFs could be happening */
        if (is_managed) {
            menu_item = gtk_menu_item_new_with_mnemonic (_("Stop Synchronizing This _Folder"));
            if (strcmp (path, u1->managed) == 0) {
                /* the Ubuntu One directory, no UDFs */
                g_object_set (menu_item, "sensitive", FALSE, NULL);
            } else if (is_root) {
                /* the root of a UDF: disabling possible */

                g_signal_connect (menu_item, "activate",
                                  G_CALLBACK (unsubscribe_folder_cb), cb_data);
            }
        } else {
            /* unmanaged */
            menu_item = gtk_menu_item_new_with_mnemonic (_("Synchronize This _Folder"));

            g_signal_connect (menu_item, "activate",
                              G_CALLBACK (subscribe_folder_cb), cb_data);
        }
    } else {
        menu_item = gtk_menu_item_new_with_mnemonic (_("Synchronize This _Folder"));
        g_object_set (menu_item, "sensitive", FALSE, NULL);
    }

    if (!menu_item) {
        menu_item = gtk_menu_item_new_with_mnemonic (_("Synchronize This _Folder"));
        g_object_set (menu_item, "sensitive", FALSE, NULL);
    }

    gtk_menu_shell_append (GTK_MENU_SHELL (submenu), menu_item);

    /* public files */
    menu_item = urlitem = NULL;

    if (!is_shared_to_me && is_managed && is_regular && !is_symlink) {
        if (is_public) {
            urlitem = gtk_menu_item_new_with_mnemonic (_("Copy Web _Link"));
            if (is_pending)
                g_object_set (urlitem, "sensitive", FALSE, NULL);
            g_signal_connect (urlitem, "activate",
                              G_CALLBACK (copy_public_url_cb), cb_data);

            menu_item = gtk_menu_item_new_with_mnemonic (_("Stop _Publishing"));
            if (is_pending)
                g_object_set (menu_item, "sensitive", FALSE, NULL);

            cb_data->make_public = FALSE;
        } else {
            menu_item = gtk_menu_item_new_with_mnemonic (_("_Publish"));
            cb_data->make_public = TRUE;
        }
        g_signal_connect (menu_item, "activate",
                          G_CALLBACK (toggle_publicity_cb), cb_data);
    }

    if (!urlitem) {
        urlitem = gtk_menu_item_new_with_mnemonic (_("Copy Web _Link"));
        g_object_set (urlitem, "sensitive", FALSE, NULL);
    }

    if (!menu_item) {
        menu_item = gtk_menu_item_new_with_mnemonic (_("_Publish"));
        g_object_set (menu_item, "sensitive", FALSE, NULL);
    }

    gtk_menu_shell_append (GTK_MENU_SHELL (submenu), menu_item);
    gtk_menu_shell_append (GTK_MENU_SHELL (submenu), urlitem);

    g_free (path);
    
    gtk_widget_show_all (submenu);
}
