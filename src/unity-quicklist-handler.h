/*
 * unity-quicklist.h: handle unity quicklists.
 *
 * Copyright (C) 2012 Canonical
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of the
 * License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authors: Didier Roche <didrocks@ubuntu.com>
 *          ammonkey <am.monkeyd@gmail.com>
 *
 */

#ifndef __UNITY_QUICKLIST_HANDLER_H__
#define __UNITY_QUICKLIST_HANDLER_H__

#ifdef HAVE_UNITY
#include <glib-object.h>
#include <glib/gi18n.h>

#include <libdbusmenu-glib/dbusmenu-glib.h>
#include <unity.h>

#define UNITY_TYPE_QUICKLIST_HANDLER unity_quicklist_handler_get_type()
#define UNITY_QUICKLIST_HANDLER(obj) \
    (G_TYPE_CHECK_INSTANCE_CAST ((obj), UNITY_TYPE_QUICKLIST_HANDLER, UnityQuicklistHandler))
#define UNITY_QUICKLIST_HANDLER_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_CAST ((klass), UNITY_TYPE_QUICKLIST_HANDLER, UnityQuicklistHandlerClass))
#define UNITY_IS_QUICKLIST_HANDLER(obj) \
    (G_TYPE_CHECK_INSTANCE_TYPE ((obj), UNITY_TYPE_QUICKLIST_HANDLER))
#define UNITY_IS_QUICKLIST_HANDLER_CLASS(klass) \
    (G_TYPE_CHECK_CLASS_TYPE ((klass), UNITY_TYPE_QUICKLIST_HANDLER))
#define UNITY_QUICKLIST_HANDLER_GET_CLASS(obj) \
    (G_TYPE_INSTANCE_GET_CLASS ((obj), UNITY_TYPE_QUICKLIST_HANDLER, UnityQuicklistHandlerClass))

typedef struct _UnityQuicklistHandlerPriv UnityQuicklistHandlerPriv;

typedef struct {
    UnityLauncherEntry *entry;
    GList *bookmark_quicklists;
    GList *progress_quicklists;
} LauncherEntry;

typedef struct {
    GObject parent;

    /* private */
    UnityQuicklistHandlerPriv *priv;
} UnityQuicklistHandler;

typedef struct {
    GObjectClass parent_class;
} UnityQuicklistHandlerClass;

GType unity_quicklist_handler_get_type (void);

static UnityQuicklistHandler *unity_quicklist_handler_singleton = NULL;

UnityQuicklistHandler * unity_quicklist_handler_new (void);
UnityQuicklistHandler * unity_quicklist_handler_get_singleton (void);

GList * unity_quicklist_get_launcher_entries (UnityQuicklistHandler *unity_quicklist_handler);
UnityLauncherEntry *unity_quicklist_get_launcher_entry (GList *l);

#endif /* HAVE_UNITY */
#endif /* __UNITY_QUICKLIST_HANDLER_H__ */
