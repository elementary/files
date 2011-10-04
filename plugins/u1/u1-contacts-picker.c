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

#include <config.h>

#include <glib/gi18n-lib.h>
#include "u1-contacts-picker.h"
#include "add-contact-dialog.h"
#include "contacts-view.h"

struct _U1ContactsPickerPrivate {
	GtkWidget *search_entry;
	GtkWidget *total_label;
	GtkWidget *contacts_view;

	/* Hidden widgets to add a new contact */
	GtkWidget *add_contact_button;
};

enum {
	SELECTION_CHANGED_SIGNAL,
	LAST_SIGNAL
};

static guint u1_contacts_picker_signals[LAST_SIGNAL] = { 0, };

G_DEFINE_TYPE(U1ContactsPicker, u1_contacts_picker, GTK_TYPE_VBOX)

static void
u1_contacts_picker_finalize (GObject *object)
{
	U1ContactsPicker *picker = U1_CONTACTS_PICKER (object);

	if (picker->priv != NULL) {
		g_free (picker->priv);
		picker->priv = NULL;
	}

	G_OBJECT_CLASS (u1_contacts_picker_parent_class)->finalize (object);
}

static void
u1_contacts_picker_class_init (U1ContactsPickerClass *klass)
{
	GObjectClass *object_class = G_OBJECT_CLASS (klass);

	object_class->finalize = u1_contacts_picker_finalize;

	/* Register object signals */
	u1_contacts_picker_signals[SELECTION_CHANGED_SIGNAL] =
		g_signal_new ("selection-changed",
			      G_TYPE_FROM_CLASS (klass),
			      (GSignalFlags) G_SIGNAL_RUN_LAST,
			      G_STRUCT_OFFSET (U1ContactsPickerClass, selection_changed),
			      NULL,
			      NULL,
			      g_cclosure_marshal_VOID__VOID,
			      G_TYPE_NONE,
			      0);
}

static void
search_activated_cb (GtkEditable *entry, gpointer data)
{
	const gchar *text;
	U1ContactsPicker *picker = (U1ContactsPicker *) data;

	text = gtk_entry_get_text (GTK_ENTRY (entry));
	contacts_view_search (CONTACTS_VIEW (picker->priv->contacts_view), text);

	/* If no contacts, offer the user to add it to the contacts database */
	if (contacts_view_get_matched_contacts_count (CONTACTS_VIEW (picker->priv->contacts_view)) == 0 &&
	    g_strrstr (text, "@") != NULL)
		gtk_widget_show (picker->priv->add_contact_button);
	else
		gtk_widget_hide (picker->priv->add_contact_button);
}

static void
view_selection_changed_cb (ContactsView *cv, gpointer user_data)
{
	U1ContactsPicker *picker = U1_CONTACTS_PICKER (user_data);

	g_signal_emit (picker, u1_contacts_picker_signals[SELECTION_CHANGED_SIGNAL], 0);
}

static void
contacts_count_changed_cb (ContactsView *cv, gint total, gpointer user_data)
{
	gchar *label;
	U1ContactsPicker *picker = U1_CONTACTS_PICKER (user_data);

	if (strlen (gtk_entry_get_text (GTK_ENTRY (picker->priv->search_entry))) > 0)
		label = g_strdup_printf (g_dngettext (GETTEXT_PACKAGE, "Found %d match", "Found %d matches", total), total);
	else
		label = g_strdup_printf (g_dngettext (GETTEXT_PACKAGE, "%d contact", "%d contacts", total), total);
	gtk_label_set_text (GTK_LABEL (picker->priv->total_label), label);

	g_free (label);
}

static void
entry_icon_pressed_cb (GtkEntry *entry, GtkEntryIconPosition icon_pos, GdkEventButton *event, gpointer user_data)
{
	U1ContactsPicker *picker = U1_CONTACTS_PICKER (user_data);

	if (icon_pos == GTK_ENTRY_ICON_SECONDARY)
		gtk_entry_set_text (GTK_ENTRY (picker->priv->search_entry), "");
}

static void
add_contact_cb (GtkButton *button, gpointer user_data)
{
	GtkWidget *dialog;
	const gchar *search_text;
	U1ContactsPicker *picker = (U1ContactsPicker *) user_data;

	/* Create the dialog */
	search_text = gtk_entry_get_text (GTK_ENTRY (picker->priv->search_entry));
	dialog = add_contact_dialog_new (GTK_WINDOW (gtk_widget_get_toplevel (GTK_WIDGET (picker))), search_text);

	/* Run the dialog */
	if (gtk_dialog_run (GTK_DIALOG (dialog)) == GTK_RESPONSE_OK) {
		contacts_view_add_contact (CONTACTS_VIEW (picker->priv->contacts_view),
					   add_contact_dialog_get_name_text (ADD_CONTACT_DIALOG (dialog)),
					   add_contact_dialog_get_email_text (ADD_CONTACT_DIALOG (dialog)));
		gtk_entry_set_text (GTK_ENTRY (picker->priv->search_entry), "");
	}

	gtk_widget_destroy (dialog);
	gtk_widget_hide (picker->priv->add_contact_button);
}

static void
u1_contacts_picker_init (U1ContactsPicker *picker)
{
	GtkWidget *table;

	picker->priv = g_new0 (U1ContactsPickerPrivate, 1);

	/* Create the table to contain the layout */
	table = gtk_table_new (4, 3, FALSE);
	gtk_widget_show (table);
	gtk_box_pack_start (GTK_BOX (picker), table, TRUE, TRUE, 3);

	/* Create the search area */
	picker->priv->search_entry = gtk_entry_new ();
	gtk_entry_set_text (GTK_ENTRY (picker->priv->search_entry), _("Type here to search"));
	gtk_entry_set_icon_from_stock (GTK_ENTRY (picker->priv->search_entry), GTK_ENTRY_ICON_PRIMARY, GTK_STOCK_FIND);
	gtk_entry_set_icon_activatable (GTK_ENTRY (picker->priv->search_entry), GTK_ENTRY_ICON_PRIMARY, FALSE);
	gtk_entry_set_icon_tooltip_text (GTK_ENTRY (picker->priv->search_entry),
					 GTK_ENTRY_ICON_PRIMARY,
					 _("Type here to search for contacts"));
	gtk_entry_set_icon_from_stock (GTK_ENTRY (picker->priv->search_entry), GTK_ENTRY_ICON_SECONDARY, GTK_STOCK_CLEAR);
	gtk_entry_set_icon_activatable (GTK_ENTRY (picker->priv->search_entry), GTK_ENTRY_ICON_SECONDARY, TRUE);
	gtk_entry_set_icon_tooltip_text (GTK_ENTRY (picker->priv->search_entry),
					 GTK_ENTRY_ICON_SECONDARY,
					 _("Click here to clear the search field"));
	g_signal_connect (G_OBJECT (picker->priv->search_entry), "icon_press",
			  G_CALLBACK (entry_icon_pressed_cb), picker);
	g_signal_connect (G_OBJECT (picker->priv->search_entry), "changed",
			  G_CALLBACK (search_activated_cb), picker);
	gtk_widget_show (picker->priv->search_entry);
	gtk_table_attach (GTK_TABLE (table), picker->priv->search_entry, 0, 1, 0, 1, GTK_FILL, GTK_FILL, 3, 3);

	picker->priv->add_contact_button = gtk_button_new_from_stock (GTK_STOCK_ADD);
	g_signal_connect (G_OBJECT (picker->priv->add_contact_button), "clicked",
			  G_CALLBACK (add_contact_cb), picker);
	gtk_table_attach (GTK_TABLE (table), picker->priv->add_contact_button, 1, 2, 0, 1, GTK_FILL, GTK_FILL, 3, 3);

	picker->priv->total_label = gtk_label_new (g_dngettext (GETTEXT_PACKAGE, "0 contact", "0 contacts", 0));
	gtk_widget_show (picker->priv->total_label);
	gtk_table_attach (GTK_TABLE (table), picker->priv->total_label, 2, 3, 0, 1, GTK_FILL, GTK_FILL, 3, 3);

	/* Create the contacts view */
	picker->priv->contacts_view = contacts_view_new ();
	g_signal_connect (G_OBJECT (picker->priv->contacts_view), "selection-changed",
			  G_CALLBACK (view_selection_changed_cb), picker);
	g_signal_connect (G_OBJECT (picker->priv->contacts_view), "contacts-count-changed",
			  G_CALLBACK (contacts_count_changed_cb), picker);
	gtk_widget_show (picker->priv->contacts_view);
	gtk_table_attach (GTK_TABLE (table), picker->priv->contacts_view, 0, 3, 2, 4,
			  GTK_FILL | GTK_EXPAND | GTK_SHRINK,
			  GTK_FILL | GTK_EXPAND | GTK_SHRINK,
			  3, 3);
}

/**
 * u1_contacts_picker_new:
 *
 * Create a new contacts picker widget.
 *
 * Return value: the newly created widget.
 */
GtkWidget *
u1_contacts_picker_new (void)
{
	U1ContactsPicker *picker;

	picker = g_object_new (U1_TYPE_CONTACTS_PICKER, NULL);

	return (GtkWidget *) picker;
}

/**
 * u1_contacts_picker_get_contacts_count:
 * @picker: A #U1ContactsPicker widget
 *
 * Return the number of contacts being displayed by the contacts picker.
 *
 * Return value: Number of contacts being displayed.
 */
guint
u1_contacts_picker_get_contacts_count (U1ContactsPicker *picker)
{
	g_return_val_if_fail (U1_IS_CONTACTS_PICKER (picker), 0);

	//FIXME: return gtk_tree_model_iter_n_children (gtk_icon_view_get_model (GTK_ICON_VIEW (picker->priv->icon_view)), NULL);
	return 0;
}

/**
 * u1_contacts_picker_get_selected_emails:
 * @picker: A #U1ContactsPicker widget
 *
 * Return the list of selected emails in the contacts picker.
 *
 * Return value: A list of strings containing the email addresses selected.
 */
GSList *
u1_contacts_picker_get_selected_emails (U1ContactsPicker *picker)
{
	g_return_val_if_fail (U1_IS_CONTACTS_PICKER (picker), NULL);

	return contacts_view_get_selected_emails (CONTACTS_VIEW (picker->priv->contacts_view));
}

/**
 * u1_contacts_picker_free_selection_list:
 * @list: The list to free memory of
 *
 * Free a list returned by @u1_contacts_picker_get_selected_emails.
 */
void
u1_contacts_picker_free_selection_list (GSList *list)
{
	g_slist_foreach (list, (GFunc) g_free, NULL);
	g_slist_free (list);
}
