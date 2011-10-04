/* -*- Mode: C; tab-width: 8; indent-tabs-mode: t; c-basic-offset: 8 -*- */
/*
 * Copyright (C) 2009 Canonical Services Ltd (www.canonical.com)
 *
 * Authors: Rodrigo Moya <rodrigo.moya@canonical.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of version 2 of the GNU Lesser General Public
 * License as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

#include <string.h>
#include <config.h>

#include <glib/gi18n-lib.h>
#include "add-contact-dialog.h"

G_DEFINE_TYPE(AddContactDialog, add_contact_dialog, GTK_TYPE_DIALOG)

static void
add_contact_dialog_finalize (GObject *object)
{
	G_OBJECT_CLASS (add_contact_dialog_parent_class)->finalize (object);
}

static void
add_contact_dialog_class_init (AddContactDialogClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);

	object_class->finalize = add_contact_dialog_finalize;
}

static void
entry_changed_cb (GtkEditable *entry, gpointer user_data)
{
	const gchar *text_name, *text_email;
	AddContactDialog *dialog = (AddContactDialog *) user_data;

	text_name = gtk_entry_get_text (GTK_ENTRY (dialog->name_entry));
	text_email = gtk_entry_get_text (GTK_ENTRY (dialog->email_entry));
	if (strlen (text_name) > 0 && strlen (text_email) > 0)
		gtk_dialog_set_response_sensitive (GTK_DIALOG (dialog), GTK_RESPONSE_OK, TRUE);
	else
		gtk_dialog_set_response_sensitive (GTK_DIALOG (dialog), GTK_RESPONSE_OK, FALSE);
}

static void
entry_activated_cb (GtkEntry *entry, gpointer user_data)
{
	const gchar *text_name, *text_email;
	AddContactDialog *dialog = (AddContactDialog *) user_data;

	text_name = gtk_entry_get_text (GTK_ENTRY (dialog->name_entry));
	text_email = gtk_entry_get_text (GTK_ENTRY (dialog->email_entry));
	if (strlen (text_name) > 0 && strlen (text_email) > 0)
		gtk_dialog_response (GTK_DIALOG (dialog), GTK_RESPONSE_OK);
}

static void
add_contact_dialog_init (AddContactDialog *dialog)
{
	GtkWidget *table, *label;

	/* Build the dialog */
	gtk_window_set_title (GTK_WINDOW (dialog), _("Add contact"));
	gtk_dialog_add_button (GTK_DIALOG (dialog), GTK_STOCK_CANCEL, GTK_RESPONSE_CANCEL);
	gtk_dialog_add_button (GTK_DIALOG (dialog), GTK_STOCK_ADD, GTK_RESPONSE_OK);

	gtk_dialog_set_default_response (GTK_DIALOG (dialog), GTK_RESPONSE_OK);
	gtk_dialog_set_response_sensitive (GTK_DIALOG (dialog), GTK_RESPONSE_OK, FALSE);

	table = gtk_table_new (2, 2, FALSE);
	gtk_widget_show (table);
	gtk_box_pack_start (GTK_BOX (gtk_dialog_get_content_area (GTK_DIALOG (dialog))),
			    table, TRUE, TRUE, 3);

	label = gtk_label_new (_("Contact name"));
	gtk_widget_show (label);
	gtk_table_attach (GTK_TABLE (table), label, 0, 1, 0, 1, GTK_FILL, GTK_FILL, 3, 3);

	dialog->name_entry = gtk_entry_new ();
	g_signal_connect (G_OBJECT (dialog->name_entry), "changed", G_CALLBACK (entry_changed_cb), dialog);
	g_signal_connect (G_OBJECT (dialog->name_entry), "activate", G_CALLBACK (entry_activated_cb), dialog);
	gtk_widget_show (dialog->name_entry);
	gtk_table_attach (GTK_TABLE (table), dialog->name_entry, 1, 2, 0, 1, GTK_FILL, GTK_FILL, 3, 3);

	label = gtk_label_new (_("Email address"));
	gtk_widget_show (label);
	gtk_table_attach (GTK_TABLE (table), label, 0, 1, 1, 2, GTK_FILL, GTK_FILL, 3, 3);

	dialog->email_entry = gtk_entry_new ();
	g_signal_connect (G_OBJECT (dialog->email_entry), "changed", G_CALLBACK (entry_changed_cb), dialog);
	g_signal_connect (G_OBJECT (dialog->email_entry), "activate", G_CALLBACK (entry_activated_cb), dialog);
	gtk_widget_show (dialog->email_entry);
	gtk_table_attach (GTK_TABLE (table), dialog->email_entry, 1, 2, 1, 2, GTK_FILL, GTK_FILL, 3, 3);
}

GtkWidget *
add_contact_dialog_new (GtkWindow *parent, const gchar *initial_text)
{
	AddContactDialog *dialog;

	dialog = g_object_new (TYPE_ADD_CONTACT_DIALOG, NULL);
	if (g_strrstr (initial_text, "@") != NULL)
		gtk_entry_set_text (GTK_ENTRY (dialog->email_entry), initial_text);
	else
		gtk_entry_set_text (GTK_ENTRY (dialog->name_entry), initial_text);

	gtk_window_set_transient_for (GTK_WINDOW (dialog), parent);

	return GTK_WIDGET (dialog);
}

const gchar *
add_contact_dialog_get_name_text (AddContactDialog *dialog)
{
	return gtk_entry_get_text (GTK_ENTRY (dialog->name_entry));
}

const gchar *
add_contact_dialog_get_email_text (AddContactDialog *dialog)
{
	return gtk_entry_get_text (GTK_ENTRY (dialog->email_entry));
}
