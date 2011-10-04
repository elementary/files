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

#ifndef __CONTACTS_VIEW_H__
#define __CONTACTS_VIEW_H__

#include <gtk/gtk.h>
#include <libedataserver/e-source-list.h>
#include <libebook/e-book.h>
#ifdef HAVE_NAUTILUS_30
#include <gio/gio.h>
#include <libedataserver/e-client.h>
#else
#include <gconf/gconf-client.h>
#endif

#define TYPE_CONTACTS_VIEW                (contacts_view_get_type ())
#define CONTACTS_VIEW(obj)                (G_TYPE_CHECK_INSTANCE_CAST ((obj), TYPE_CONTACTS_VIEW, ContactsView))
#define IS_CONTACTS_VIEW(obj)             (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TYPE_CONTACTS_VIEW))
#define CONTACTS_VIEW_CLASS(klass)        (G_TYPE_CHECK_CLASS_CAST ((klass), TYPE_CONTACTS_VIEW, ContactsViewClass))
#define IS_CONTACTS_VIEW_CLASS(klass)     (G_TYPE_CHECK_CLASS_TYPE ((klass), TYPE_CONTACTS_VIEW))
#define CONTACTS_VIEW_GET_CLASS(obj)      (G_TYPE_INSTANCE_GET_CLASS ((obj), TYPE_CONTACTS_VIEW, ContactsViewClass))

typedef struct {
	GtkScrolledWindow parent;

#ifdef HAVE_NAUTILUS_30
	GSettings *settings;
#else
	GConfClient *config_client;
#endif

	/* Data from addressbooks */
	ESourceList *source_list;
	GSList *books;
	GHashTable *selection;
	GHashTable *recently_used;
	GHashTable *added_contacts;

	/* Widgets */
	GtkWidget *contacts_list;

	guint matched_contacts;
} ContactsView;

typedef struct {
	GtkScrolledWindowClass parent_class;

	/* Signals */
	void (* selection_changed) (ContactsView *cv);
	void (* contacts_count_changed) (ContactsView *cv, gint total);
} ContactsViewClass;

GType      contacts_view_get_type (void);

GtkWidget *contacts_view_new (void);
void       contacts_view_search (ContactsView *cv, const gchar *search_string);
GSList    *contacts_view_get_selected_emails (ContactsView *cv);
guint      contacts_view_get_contacts_count (ContactsView *cv);
guint      contacts_view_get_matched_contacts_count (ContactsView *cv);
void       contacts_view_add_contact (ContactsView *cv, const gchar *contact_name, const gchar *contact_email);

#endif
