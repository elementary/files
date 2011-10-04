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

#ifndef __SHARE_DIALOG_H__
#define __SHARE_DIALOG_H__

#include <gtk/gtk.h>
#include "plugin.h"

#define TYPE_SHARE_DIALOG                (share_dialog_get_type ())
#define SHARE_DIALOG(obj)                (G_TYPE_CHECK_INSTANCE_CAST ((obj), TYPE_SHARE_DIALOG, ShareDialog))
#define IS_SHARE_DIALOG(obj)             (G_TYPE_CHECK_INSTANCE_TYPE ((obj), TYPE_SHARE_DIALOG))
#define SHARE_DIALOG_CLASS(klass)        (G_TYPE_CHECK_CLASS_CAST ((klass), TYPE_SHARE_DIALOG, ShareDialogClass))
#define IS_SHARE_DIALOG_CLASS(klass)     (G_TYPE_CHECK_CLASS_TYPE ((klass), TYPE_SHARE_DIALOG))
#define SHARE_DIALOG_GET_CLASS(obj)      (G_TYPE_INSTANCE_GET_CLASS ((obj), TYPE_SHARE_DIALOG, ShareDialogClass))

typedef struct {
	GtkDialog parent;

	MarlinPluginsUbuntuOne *uon;
	gchar *path;
	GtkWidget *user_picker;
	GtkWidget *allow_mods;
} ShareDialog;

typedef struct {
	GtkDialogClass parent_class;
} ShareDialogClass;

GType      share_dialog_get_type (void);
GtkWidget *share_dialog_new (GtkWidget *parent, MarlinPluginsUbuntuOne *uon, const gchar *path);

#endif
