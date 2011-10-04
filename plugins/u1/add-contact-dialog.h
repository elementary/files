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

#ifndef __ADD_CONTACT_DIALOG_H__
#define __ADD_CONTACT_DIALOG_H__

#include <gtk/gtk.h>

#define TYPE_ADD_CONTACT_DIALOG                (add_contact_dialog_get_type ())
#define ADD_CONTACT_DIALOG(obj)                (G_TYPE_CHECK_INSTANCE_CAST ((obj), TYPE_ADD_CONTACT_DIALOG, AddContactDialog))
#define IS_ADD_CONTACT_DIALOG(obj)             (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TYPE_ADD_CONTACT_DIALOG))
#define ADD_CONTACT_DIALOG_CLASS(klass)        (G_TYPE_CHECK_CLASS_CAST ((klass), TYPE_ADD_CONTACT_DIALOG, AddContactDialogClass))
#define IS_ADD_CONTACT_DIALOG_CLASS(klass)     (G_TYPE_CHECK_CLASS_TYPE ((klass), TYPE_ADD_CONTACT_DIALOG))
#define ADD_CONTACT_DIALOG_GET_CLASS(obj)      (G_TYPE_INSTANCE_GET_CLASS ((obj), TYPE_ADD_CONTACT_DIALOG, AddContactDialogClass))

typedef struct {
	GtkDialog parent;

	GtkWidget *name_entry;
	GtkWidget *email_entry;
} AddContactDialog;

typedef struct {
	GtkDialogClass parent_class;
} AddContactDialogClass;

GType        add_contact_dialog_get_type (void);
GtkWidget   *add_contact_dialog_new (GtkWindow *parent, const gchar *initial_text);
const gchar *add_contact_dialog_get_name_text (AddContactDialog *dialog);
const gchar *add_contact_dialog_get_email_text (AddContactDialog *dialog);

#endif
