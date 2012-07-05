/*unity-quicklist-handler.c: handle Unity quicklists
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

#ifdef HAVE_UNITY
#include <config.h>

#include "unity-quicklist-handler.h"

#include "marlin-application.h"
#include <libdbusmenu-glib/dbusmenu-glib.h>
#include "marlin-bookmark-list.h"

struct _UnityQuicklistHandlerPriv {
    GList *launcher_entries;
};

G_DEFINE_TYPE (UnityQuicklistHandler, unity_quicklist_handler, G_TYPE_OBJECT);

static UnityQuicklistHandler *unity_quicklist_handler_singleton = NULL;

GList *
unity_quicklist_get_launcher_entries (UnityQuicklistHandler *self)
{
    return self->priv->launcher_entries;
}

UnityLauncherEntry *
unity_quicklist_get_launcher_entry (GList *l)
{
    LauncherEntry *lentry = l->data;
    return lentry->entry;
}

static void
unity_quicklist_handler_dispose (GObject *obj)
{
    UnityQuicklistHandler *self = UNITY_QUICKLIST_HANDLER (obj);
    GList *l;

    if (self->priv->launcher_entries) {
        for (l = unity_quicklist_get_launcher_entries (self); l; l = l->next) {
            LauncherEntry *lentry = l->data;
            g_list_free_full (lentry->bookmark_quicklists, g_object_unref);
            lentry->bookmark_quicklists = NULL;
            g_list_free_full (lentry->progress_quicklists, g_object_unref);
            lentry->bookmark_quicklists = NULL;
            g_object_unref (lentry->entry);
        }
        g_list_free_full (self->priv->launcher_entries, g_object_unref);
        self->priv->launcher_entries = NULL;
    }

    G_OBJECT_CLASS (unity_quicklist_handler_parent_class)->dispose (obj);
}

static void
unity_quicklist_handler_launcher_entry_add (UnityQuicklistHandler *self,
                                            const gchar *entry_id)
{
    GList **entries;
    UnityLauncherEntry *entry;
    LauncherEntry *lentry;

    entries = &(self->priv->launcher_entries);
    entry = unity_launcher_entry_get_for_desktop_id (entry_id);

    if (entry) {
        lentry = g_new0 (LauncherEntry, 1);
        lentry->entry = entry;
        lentry->bookmark_quicklists = NULL;
        lentry->progress_quicklists = NULL;
        *entries = g_list_prepend (*entries, lentry);
    
        /* ensure dynamic quicklists exist */
        DbusmenuMenuitem *ql = unity_launcher_entry_get_quicklist (entry);
        if (!ql) {
            ql = dbusmenu_menuitem_new ();
            unity_launcher_entry_set_quicklist (entry, ql);
        }
    }
}

static void
activate_bookmark_by_quicklist (DbusmenuMenuitem *menu,
								guint timestamp,
								MarlinBookmark *bookmark)
{
	g_assert (MARLIN_IS_BOOKMARK (bookmark));

    /* TODO make an option to open in tab */
	GFile *location;

	location = marlin_bookmark_get_location (bookmark);
	marlin_application_create_window (marlin_application_get (), location, 
                                      gdk_screen_get_default ());

	g_object_unref (location);
}

static void
unity_bookmarks_handler_remove_bookmark_quicklists (UnityQuicklistHandler *self)
{

    GList *l, *m;

    /* remove unity quicklist bookmarks to launcher entries */
    for (l = unity_quicklist_get_launcher_entries (self); l; l = l->next) {
        LauncherEntry *lentry = l->data;
        UnityLauncherEntry *entry = lentry->entry;
        DbusmenuMenuitem *ql = unity_launcher_entry_get_quicklist (entry);
        if (!ql)
            break;

        for (m = lentry->bookmark_quicklists; m; m = m->next) {
            g_signal_handlers_disconnect_matched (m->data, G_SIGNAL_MATCH_FUNC, 0, 0, 0, (GCallback) activate_bookmark_by_quicklist, 0);
            dbusmenu_menuitem_child_delete (ql, m->data);
        }
        g_list_free_full (lentry->bookmark_quicklists, g_object_unref);
        lentry->bookmark_quicklists = NULL;
    }
}

static void
unity_bookmarks_handler_update_bookmarks (MarlinBookmarkList *bookmarks, UnityQuicklistHandler *self)
{
    MarlinBookmark *bookmark;
    guint bookmark_count;
    guint index;
    GList *l;

    /* append new set of bookmarks */
    bookmark_count = marlin_bookmark_list_length (bookmarks);
    for (index = 0; index < bookmark_count; ++index) {

        bookmark = marlin_bookmark_list_item_at (bookmarks, index);

        if (marlin_bookmark_uri_known_not_to_exist (bookmark)) {
            continue;
        }

        for (l = unity_quicklist_get_launcher_entries (self); l; l = l->next) {
            LauncherEntry *lentry = l->data;
            UnityLauncherEntry *entry = lentry->entry;
            DbusmenuMenuitem *ql = unity_launcher_entry_get_quicklist (entry);
            DbusmenuMenuitem* menuitem = dbusmenu_menuitem_new();
            dbusmenu_menuitem_property_set (menuitem, "label", marlin_bookmark_get_name (bookmark));
            g_signal_connect (menuitem, DBUSMENU_MENUITEM_SIGNAL_ITEM_ACTIVATED,
                              (GCallback) activate_bookmark_by_quicklist,
                              bookmark);

            dbusmenu_menuitem_child_add_position (ql, menuitem, index);
            lentry->bookmark_quicklists = g_list_prepend (lentry->bookmark_quicklists, menuitem);

            if (index == bookmark_count - 1) {
                menuitem = dbusmenu_menuitem_new();
                dbusmenu_menuitem_property_set (menuitem, DBUSMENU_MENUITEM_PROP_TYPE, DBUSMENU_CLIENT_TYPES_SEPARATOR);
                dbusmenu_menuitem_child_add_position (ql, menuitem, index+1);
                lentry->bookmark_quicklists = g_list_prepend (lentry->bookmark_quicklists, menuitem);
            }
        }
    }
}

static void
unity_bookmarks_handler_refresh_bookmarks (MarlinBookmarkList *bookmarks, UnityQuicklistHandler *self)
{
    unity_bookmarks_handler_remove_bookmark_quicklists (self);
    unity_bookmarks_handler_update_bookmarks (bookmarks, self);
}

static void
unity_quicklist_handler_init (UnityQuicklistHandler *self)
{
    GList *l;

    self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self, UNITY_TYPE_QUICKLIST_HANDLER,
                                              UnityQuicklistHandlerPriv);

    unity_quicklist_handler_launcher_entry_add (self, "pantheon-files.desktop");
    g_return_if_fail (g_list_length (self->priv->launcher_entries) != 0);

    MarlinBookmarkList *bookmarks = marlin_bookmark_list_new ();
    //unity_bookmarks_handler_refresh_bookmarks (self->priv->bookmarks, self);

    /* Recreate dynamic part of menu if bookmark list changes */
    g_signal_connect (bookmarks, "contents-changed",
                      G_CALLBACK (unity_bookmarks_handler_refresh_bookmarks), self);
}

static void
unity_quicklist_handler_class_init (UnityQuicklistHandlerClass *klass)
{
    GObjectClass *oclass;

    oclass = G_OBJECT_CLASS (klass);
    oclass->dispose = unity_quicklist_handler_dispose;

    g_type_class_add_private (klass, sizeof (UnityQuicklistHandlerPriv));
}

UnityQuicklistHandler *
unity_quicklist_handler_get_singleton (void)
{
    if (!unity_quicklist_handler_singleton)
        unity_quicklist_handler_singleton = unity_quicklist_handler_new ();
    return unity_quicklist_handler_singleton;
}

UnityQuicklistHandler *
unity_quicklist_handler_new (void)
{
    return g_object_new (UNITY_TYPE_QUICKLIST_HANDLER, NULL);
}

#endif
