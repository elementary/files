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

#ifndef __U1_CONTACTS_PICKER_H__
#define __U1_CONTACTS_PICKER_H__

#include <gtk/gtk.h>

G_BEGIN_DECLS

#define U1_TYPE_CONTACTS_PICKER                (u1_contacts_picker_get_type ())
#define U1_CONTACTS_PICKER(obj)                (G_TYPE_CHECK_INSTANCE_CAST ((obj), U1_TYPE_CONTACTS_PICKER, U1ContactsPicker))
#define U1_IS_CONTACTS_PICKER(obj)             (G_TYPE_CHECK_INSTANCE_TYPE ((obj), U1_TYPE_CONTACTS_PICKER))
#define U1_CONTACTS_PICKER_CLASS(klass)        (G_TYPE_CHECK_CLASS_CAST ((klass), U1_TYPE_CONTACTS_PICKER, U1ContactsPickerClass))
#define U1_IS_CONTACTS_PICKER_CLASS(klass)     (G_TYPE_CHECK_CLASS_TYPE ((klass), U1_TYPE_CONTACTS_PICKER))
#define U1_CONTACTS_PICKER_GET_CLASS(obj)      (G_TYPE_INSTANCE_GET_CLASS ((obj), U1_TYPE_CONTACTS_PICKER, U1ContactsPickerClass))

typedef struct _U1ContactsPicker        U1ContactsPicker;
typedef struct _U1ContactsPickerClass   U1ContactsPickerClass;
typedef struct _U1ContactsPickerPrivate U1ContactsPickerPrivate;

struct _U1ContactsPicker {
	GtkVBox parent;
	U1ContactsPickerPrivate *priv;
};

struct _U1ContactsPickerClass {
	GtkVBoxClass parent_class;

	/* Signals */
	void (* selection_changed) (U1ContactsPicker *picker);
};

GType      u1_contacts_picker_get_type (void);

GtkWidget *u1_contacts_picker_new (void);
guint      u1_contacts_picker_get_contacts_count (U1ContactsPicker *picker);
GSList    *u1_contacts_picker_get_selected_emails (U1ContactsPicker *picker);
void       u1_contacts_picker_free_selection_list (GSList *list);

G_END_DECLS

#endif
