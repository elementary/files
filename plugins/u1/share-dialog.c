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
#include "share-dialog.h"
#include "u1-contacts-picker.h"

G_DEFINE_TYPE(ShareDialog, share_dialog, GTK_TYPE_DIALOG)

static void
share_dialog_finalize (GObject *object)
{
	ShareDialog *dialog = SHARE_DIALOG (object);

	if (dialog->path != NULL)
		g_free (dialog->path);

	G_OBJECT_CLASS (share_dialog_parent_class)->finalize (object);
}

static void
share_dialog_class_init (ShareDialogClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);

	object_class->finalize = share_dialog_finalize;
}

static void
picker_selection_changed_cb (U1ContactsPicker *picker, gpointer user_data)
{
	GSList *selection;
	GtkWidget * dialog = (GtkWidget *) user_data;

	selection = u1_contacts_picker_get_selected_emails (picker);
	if (selection != NULL) {
		gtk_dialog_set_response_sensitive (GTK_DIALOG (dialog), GTK_RESPONSE_ACCEPT, TRUE);
		u1_contacts_picker_free_selection_list (selection);
	} else
		gtk_dialog_set_response_sensitive (GTK_DIALOG (dialog), GTK_RESPONSE_ACCEPT, FALSE);
}

static void
dialog_response_cb (GtkDialog *gtk_dialog,
		    gint response,
		    gpointer user_data)
{
	ShareDialog *dialog = SHARE_DIALOG (gtk_dialog);

	switch (response) {
	case GTK_RESPONSE_ACCEPT: {
		GSList *emails;
		SyncdaemonSharesInterface *interface;
		gboolean allow_mods = FALSE;

		emails = u1_contacts_picker_get_selected_emails (U1_CONTACTS_PICKER (dialog->user_picker));
		if (emails == NULL) {
            //FIXME
			/*ubuntuone_show_error_dialog (dialog->uon,
						     _("Error"),
						     _("You need to select at least one contact to share this folder with"));*/

			return;
		}

		allow_mods = gtk_toggle_button_get_active (GTK_TOGGLE_BUTTON (dialog->allow_mods));

		interface = SYNCDAEMON_SHARES_INTERFACE (syncdaemon_daemon_get_shares_interface (dialog->uon->syncdaemon));
		if (interface != NULL) {
			syncdaemon_shares_interface_create (interface,
							    dialog->path,
							    emails,
							    g_path_get_basename (dialog->path),
							    allow_mods);
		}
 
		u1_contacts_picker_free_selection_list (emails);
	}
	default:
		gtk_widget_destroy (GTK_WIDGET (dialog));
		break;
	}
}

static void
share_dialog_init (ShareDialog *dialog)
{
	GtkWidget *area, *table;

	gtk_window_set_title (GTK_WINDOW (dialog), _("Share on Ubuntu One"));
	gtk_window_set_destroy_with_parent (GTK_WINDOW (dialog), TRUE);
	gtk_dialog_add_buttons (GTK_DIALOG (dialog),
				GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL,
				(_("Share")), GTK_RESPONSE_ACCEPT,
				NULL);
	gtk_dialog_set_default_response (GTK_DIALOG (dialog), GTK_RESPONSE_ACCEPT);
	gtk_dialog_set_response_sensitive (GTK_DIALOG (dialog),
                                       GTK_RESPONSE_ACCEPT, FALSE);
	gtk_window_set_icon_name (GTK_WINDOW (dialog), "ubuntuone");
	g_signal_connect (G_OBJECT (dialog), "response",
			  G_CALLBACK (dialog_response_cb), NULL);

	area = gtk_dialog_get_content_area (GTK_DIALOG (dialog));

    table = gtk_vbox_new (FALSE, 12);
    gtk_container_set_border_width (GTK_CONTAINER (table), 7);
    gtk_box_pack_start (GTK_BOX (area), table, TRUE, TRUE, 0);
    gtk_widget_show (table);

	dialog->user_picker = u1_contacts_picker_new ();
	g_signal_connect (G_OBJECT (dialog->user_picker), "selection-changed",
			  G_CALLBACK (picker_selection_changed_cb), dialog);
    gtk_box_pack_start (GTK_BOX (table), dialog->user_picker, TRUE, TRUE, 0);
	gtk_widget_show (dialog->user_picker);

	dialog->allow_mods = gtk_check_button_new_with_mnemonic (_("_Allow Modification"));
    /* Default to RW */
	gtk_toggle_button_set_active (GTK_TOGGLE_BUTTON (dialog->allow_mods),
                                  TRUE);
    gtk_box_pack_end (GTK_BOX (table), dialog->allow_mods, FALSE, FALSE, 0);
	gtk_widget_show (dialog->allow_mods);

	gtk_widget_set_size_request (GTK_WIDGET (dialog), 500, 450);
}

GtkWidget *
share_dialog_new (GtkWidget *parent, MarlinPluginsUbuntuOne *uon, const gchar *path)
{
	ShareDialog *dialog;
	
	dialog = (ShareDialog *) g_object_new (TYPE_SHARE_DIALOG, NULL);
	dialog->uon = uon;
	dialog->path = g_strdup (path);
	gtk_window_set_transient_for (GTK_WINDOW (dialog), GTK_WINDOW (parent));

	return (GtkWidget *) dialog;
}
