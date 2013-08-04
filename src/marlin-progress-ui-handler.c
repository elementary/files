/*
 * marlin-progress-ui-handler.c: file operation progress user interface.
 *
 * Copyright (C) 2007, 2011 Red Hat, Inc.
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
 * Authors: Alexander Larsson <alexl@redhat.com>
 *          Cosimo Cecchi <cosimoc@redhat.com>
 *          Marco Trevisan <3v1n0@ubuntu.com>
 *
 */

#include "marlin-progress-ui-handler.h"

#include "marlin-vala.h"
#include "marlin-progress-info-widget.h"

#include "marlin-progress-info.h"
#include "marlin-progress-info-manager.h"
#include "eel-i18n.h"

#include <libnotify/notify.h>

#ifdef HAVE_UNITY
#include <unity.h>
#endif

struct _MarlinProgressUIHandlerPriv {
    MarlinProgressInfoManager *manager;

    GtkWidget *progress_window;
    GtkWidget *window_vbox;
    guint active_infos;

    gboolean notification_supports_persistence;
    NotifyNotification *progress_notification;
    GtkStatusIcon *status_icon;
#ifdef HAVE_UNITY
    MarlinQuicklistHandler *unity_quicklist_handler;
#endif
};

G_DEFINE_TYPE (MarlinProgressUIHandler, marlin_progress_ui_handler, G_TYPE_OBJECT);

/* Our policy for showing progress notification is the following:
 * - file operations that end within two seconds do not get notified in any way
 * - if no file operations are running, and one passes the two seconds
 *   timeout, a window is displayed with the progress
 * - if the window is closed, we show a resident notification, or a status icon, depending on
 *   the capabilities of the notification daemon running in the session
 * - if some file operations are running, and another one passes the two seconds
 *   timeout, and the window is showing, we add it to the window directly
 * - in the same case, but when the window is not showing, we update the resident
 *   notification, changing its message, or the status icon's tooltip
 * - when one file operation finishes, if it's not the last one, we only update the
 *   resident notification's message, or the status icon's tooltip
 * - in the same case, if it's the last one, we close the resident notification,
 *   or the status icon, and trigger a transient one
 * - in the same case, but the window was showing, we just hide the window
 */

#define ACTION_DETAILS "details"

static void
status_icon_activate_cb (GtkStatusIcon *icon,
                         MarlinProgressUIHandler *self)
{	
    gtk_status_icon_set_visible (icon, FALSE);
    gtk_window_present (GTK_WINDOW (self->priv->progress_window));
}

static void
notification_show_details_cb (NotifyNotification *notification,
                              char *action_name,
                              gpointer user_data)
{
    MarlinProgressUIHandler *self = user_data;


    if (g_strcmp0 (action_name, ACTION_DETAILS) != 0) {
        return;
    }

    notify_notification_close (self->priv->progress_notification, NULL);
    gtk_window_present (GTK_WINDOW (self->priv->progress_window));
}

static void
progress_ui_handler_ensure_notification (MarlinProgressUIHandler *self)
{
    NotifyNotification *notify;

    if (self->priv->progress_notification) {
        return;
    }

    notify = notify_notification_new (_("File Operations"),
                                      NULL, NULL);
    self->priv->progress_notification = notify;

    notify_notification_set_category (notify, "transfer");
    notify_notification_set_hint (notify, "resident",
                                  g_variant_new_boolean (TRUE));

    notify_notification_add_action (notify, ACTION_DETAILS,
                                    _("Show Details"),
                                    notification_show_details_cb,
                                    self,
                                    NULL);
}

static void
progress_ui_handler_ensure_status_icon (MarlinProgressUIHandler *self)
{
    GIcon *icon;
    GtkStatusIcon *status_icon;

    if (self->priv->status_icon != NULL) {
        return;
    }

    icon = g_themed_icon_new_with_default_fallbacks ("system-file-manager-symbolic");
    status_icon = gtk_status_icon_new_from_gicon (icon);
    g_signal_connect (status_icon, "activate",
                      (GCallback) status_icon_activate_cb,
                      self);

    gtk_status_icon_set_visible (status_icon, FALSE);
    g_object_unref (icon);

    self->priv->status_icon = status_icon;
}

static void
progress_ui_handler_update_notification (MarlinProgressUIHandler *self)
{
    gchar *body;

    progress_ui_handler_ensure_notification (self);

    body = g_strdup_printf (ngettext ("%'d file operation active",
                                      "%'d file operations active",
                                      self->priv->active_infos),
                            self->priv->active_infos);

    notify_notification_update (self->priv->progress_notification,
                                _("File Operations"),
                                body,
                                NULL);

    notify_notification_show (self->priv->progress_notification, NULL);

    g_free (body);
}

static void
progress_ui_handler_update_status_icon (MarlinProgressUIHandler *self)
{
    gchar *tooltip;

    progress_ui_handler_ensure_status_icon (self);

    tooltip = g_strdup_printf (ngettext ("%'d file operation active",
                                         "%'d file operations active",
                                         self->priv->active_infos),
                               self->priv->active_infos);
    gtk_status_icon_set_tooltip_text (self->priv->status_icon, tooltip);
    g_free (tooltip);

    gtk_status_icon_set_visible (self->priv->status_icon, TRUE);
}

#ifdef HAVE_UNITY

static void
progress_ui_handler_unity_progress_changed (MarlinProgressInfo *info,
                                            MarlinProgressUIHandler *self)
{
    g_return_if_fail (self);
    g_return_if_fail (self->priv->unity_quicklist_handler);
    g_return_if_fail (self->priv->manager);

    GList *infos, *l;
    double progress = 0;
    double c, current = 0;
    double t, total = 0;

    infos = marlin_progress_info_manager_get_all_infos (self->priv->manager);

    for (l = infos; l; l = l->next) {
        MarlinProgressInfo *i = l->data;
        c = marlin_progress_info_get_current (i);
        t = marlin_progress_info_get_total (i);

        if (c < 0) c = 0;
        if (t <= 0) continue;

        total += t;
        current += c;
    }

    if (current >= 0 && total > 0)
        progress = current / total;

    if (progress > 1.0)
        progress = 1.0;

    for (l = marlin_quicklist_handler_get_launcher_entries (self->priv->unity_quicklist_handler); l; l = l->next) {
        UnityLauncherEntry *entry = marlin_quicklist_handler_get_launcher_entry (l);
        unity_launcher_entry_set_progress (entry, progress);
    }
}

static gboolean
progress_ui_handler_disable_unity_urgency (UnityLauncherEntry *entry)
{
    g_return_if_fail (entry);

    unity_launcher_entry_set_urgent (entry, FALSE);
    return FALSE;
}

static void
progress_ui_handler_unity_quicklist_show_activated (DbusmenuMenuitem *menu,
                                                    guint timestamp,
                                                    MarlinProgressUIHandler *self)
{
    g_return_if_fail (self);

    if (!gtk_widget_get_visible (self->priv->progress_window)) {
        gtk_window_present (GTK_WINDOW (self->priv->progress_window));
    } else {
        gtk_window_set_keep_above (GTK_WINDOW (self->priv->progress_window), TRUE);
        gtk_window_set_keep_above (GTK_WINDOW (self->priv->progress_window), FALSE);
    }
}

static void
progress_ui_handler_unity_quicklist_cancel_activated (DbusmenuMenuitem *menu,
                                                      guint timestamp,
                                                      MarlinProgressUIHandler *self)
{
    g_return_if_fail (self);
    g_return_if_fail (self->priv->manager);

    GList *infos, *l;
    infos = marlin_progress_info_manager_get_all_infos (self->priv->manager);

    for (l = infos; l; l = l->next) {
        MarlinProgressInfo *info = l->data;
        marlin_progress_info_cancel (info);
    }
}

static void
progress_ui_handler_build_unity_quicklist (MarlinProgressUIHandler *self)
{
    g_return_if_fail (self);
    GList *l;

    for (l = marlin_quicklist_handler_get_launcher_entries (self->priv->unity_quicklist_handler); l; l = l->next) {
        MarlinLauncherEntry *lentry = l->data;
        UnityLauncherEntry *entry = marlin_quicklist_handler_get_launcher_entry (l);
        DbusmenuMenuitem *ql = unity_launcher_entry_get_quicklist (entry);

        DbusmenuMenuitem *quickmenu = dbusmenu_menuitem_new ();
        dbusmenu_menuitem_property_set (quickmenu,
                                        DBUSMENU_MENUITEM_PROP_LABEL,
                                        _("Show Copy Dialog"));
        dbusmenu_menuitem_property_set_bool (quickmenu,
                                             DBUSMENU_MENUITEM_PROP_VISIBLE, FALSE);
        dbusmenu_menuitem_child_add_position (ql, quickmenu, -1);
        lentry->progress_quicklists = g_list_prepend (lentry->progress_quicklists, quickmenu);
        g_signal_connect (quickmenu, DBUSMENU_MENUITEM_SIGNAL_ITEM_ACTIVATED,
                          (GCallback) progress_ui_handler_unity_quicklist_show_activated,
                          self);

        quickmenu = dbusmenu_menuitem_new ();
        dbusmenu_menuitem_property_set (quickmenu,
                                        DBUSMENU_MENUITEM_PROP_LABEL,
                                        _("Cancel All In-progress Actions"));
        dbusmenu_menuitem_property_set_bool (quickmenu,
                                             DBUSMENU_MENUITEM_PROP_VISIBLE, FALSE);
        dbusmenu_menuitem_child_add_position (ql, quickmenu, -1);
        lentry->progress_quicklists = g_list_prepend (lentry->progress_quicklists, quickmenu);
        g_signal_connect (quickmenu, DBUSMENU_MENUITEM_SIGNAL_ITEM_ACTIVATED,
                          (GCallback) progress_ui_handler_unity_quicklist_cancel_activated,
                          self);
    }
}

static void
progress_ui_handler_show_unity_quicklist (MarlinProgressUIHandler *self,
                                          MarlinLauncherEntry *lentry,
                                          gboolean show)
{
    g_return_if_fail (self);
    g_return_if_fail (lentry);

    GList *l;

    for (l = lentry->progress_quicklists; l; l = l->next) {
        dbusmenu_menuitem_property_set_bool(l->data,
                                            DBUSMENU_MENUITEM_PROP_VISIBLE, show);
    }
}

static void
progress_ui_handler_update_unity_launcher_entry (MarlinProgressUIHandler *self,
                                                 MarlinProgressInfo *info,
                                                 MarlinLauncherEntry *lentry)
{
    UnityLauncherEntry *entry = lentry->entry;

    g_return_if_fail (self);
    g_return_if_fail (entry);

    if (self->priv->active_infos > 0) {
        unity_launcher_entry_set_progress_visible (entry, TRUE);
        progress_ui_handler_show_unity_quicklist (self, lentry, TRUE);
        progress_ui_handler_unity_progress_changed (NULL, self);
    } else {
        unity_launcher_entry_set_progress_visible (entry, FALSE);
        unity_launcher_entry_set_progress (entry, 0.0);
        unity_launcher_entry_set_count_visible (entry, FALSE);
        progress_ui_handler_show_unity_quicklist (self, lentry, FALSE);
        GCancellable *pc = marlin_progress_info_get_cancellable (info);

        if (!g_cancellable_is_cancelled (pc)) {
            unity_launcher_entry_set_urgent (entry, TRUE);

            g_timeout_add_seconds (2, (GSourceFunc)
                                   progress_ui_handler_disable_unity_urgency,
                                   entry);
        }
    }
}

static void
progress_ui_handler_update_unity_launcher (MarlinProgressUIHandler *self,
                                           MarlinProgressInfo *info,
                                           gboolean added)
{
    g_return_if_fail (self);
    GList *l;

    if (!self->priv->unity_quicklist_handler) {
        self->priv->unity_quicklist_handler = marlin_quicklist_handler_get_singleton ();
        if (!self->priv->unity_quicklist_handler)
            return;

        progress_ui_handler_build_unity_quicklist (self);
    }

    for (l = marlin_quicklist_handler_get_launcher_entries (self->priv->unity_quicklist_handler); l; l = l->next) {
        MarlinLauncherEntry *lentry = l->data;
        UnityLauncherEntry *entry = marlin_quicklist_handler_get_launcher_entry (l);
        progress_ui_handler_update_unity_launcher_entry (self, info, lentry);
    }

    if (added) {
        g_signal_connect (info, "progress-changed",
                          (GCallback) progress_ui_handler_unity_progress_changed,
                          self);
    }
}
#endif


static gboolean
progress_window_delete_event (GtkWidget *widget,
                              GdkEvent *event,
                              MarlinProgressUIHandler *self)
{
    gtk_widget_hide (widget);

    if (self->priv->notification_supports_persistence) {
        progress_ui_handler_update_notification (self);
    } else {
        progress_ui_handler_update_status_icon (self);
    }

    return TRUE;
}

static void
progress_ui_handler_ensure_window (MarlinProgressUIHandler *self)
{
    GtkWidget *vbox, *progress_window;

    if (self->priv->progress_window != NULL) {
        return;
    }

    progress_window = gtk_window_new (GTK_WINDOW_TOPLEVEL);
    self->priv->progress_window = progress_window;
    gtk_window_set_resizable (GTK_WINDOW (progress_window),
                              FALSE);
    gtk_container_set_border_width (GTK_CONTAINER (progress_window), 10);

    gtk_window_set_title (GTK_WINDOW (progress_window),
                          _("File Operations"));
    gtk_window_set_wmclass (GTK_WINDOW (progress_window),
                            "file_progress", "Marlin");
    gtk_window_set_position (GTK_WINDOW (progress_window),
                             GTK_WIN_POS_CENTER);
    gtk_window_set_icon_name (GTK_WINDOW (progress_window),
                              "system-file-manager");

    vbox = gtk_box_new (GTK_ORIENTATION_VERTICAL, 0);
    gtk_box_set_spacing (GTK_BOX (vbox), 5);
    gtk_container_add (GTK_CONTAINER (progress_window),
                       vbox);
    self->priv->window_vbox = vbox;
    gtk_widget_show (vbox);

    g_signal_connect (progress_window,
                      "delete-event",
                      (GCallback) progress_window_delete_event, self);
}

static void
progress_ui_handler_update_notification_or_status (MarlinProgressUIHandler *self)
{
    if (self->priv->notification_supports_persistence) {
        progress_ui_handler_update_notification (self);
    } else {
        progress_ui_handler_update_status_icon (self);
    }
}

static void
progress_ui_handler_add_to_window (MarlinProgressUIHandler *self,
                                   MarlinProgressInfo *info)
{
    GtkWidget *progress;

    progress = marlin_progress_info_widget_new (info);
    progress_ui_handler_ensure_window (self);

    gtk_box_pack_start (GTK_BOX (self->priv->window_vbox),
                        progress,
                        FALSE, FALSE, 6);

    gtk_widget_show (progress);
}

static void
progress_ui_handler_show_complete_notification (MarlinProgressUIHandler *self)
{
    NotifyNotification *complete_notification;

    /* don't display the notification if we'd be using a status icon */
    if (!self->priv->notification_supports_persistence) {
        return;
    }

    complete_notification = notify_notification_new (_("File Operations"),
                                                     _("All file operations have been successfully completed"),
                                                     NULL);
    notify_notification_show (complete_notification, NULL);

    g_object_unref (complete_notification);
}

static void
progress_ui_handler_hide_notification_or_status (MarlinProgressUIHandler *self)
{
    if (self->priv->status_icon != NULL) {
        gtk_status_icon_set_visible (self->priv->status_icon, FALSE);
    }

    if (self->priv->progress_notification != NULL) {
        notify_notification_close (self->priv->progress_notification, NULL);
        g_clear_object (&self->priv->progress_notification);
    }
}

static void
progress_info_finished_cb (MarlinProgressInfo *info,
                           MarlinProgressUIHandler *self)
{
    self->priv->active_infos--;

    if (self->priv->active_infos > 0) {
        if (!gtk_widget_get_visible (self->priv->progress_window)) {
            progress_ui_handler_update_notification_or_status (self);
        }
    } else {
        if (gtk_widget_get_visible (self->priv->progress_window)) {
            gtk_widget_hide (self->priv->progress_window);
        } else {
            progress_ui_handler_hide_notification_or_status (self);
            progress_ui_handler_show_complete_notification (self);
        }
    }

#ifdef HAVE_UNITY
    progress_ui_handler_update_unity_launcher (self, info, FALSE);
#endif
}

static void
handle_new_progress_info (MarlinProgressUIHandler *self,
                          MarlinProgressInfo *info)
{
    g_signal_connect (info, "finished",
                      G_CALLBACK (progress_info_finished_cb), self);

    self->priv->active_infos++;

    if (self->priv->active_infos == 1) {
        /* this is the only active operation, present the window */
        progress_ui_handler_add_to_window (self, info);
        gtk_window_present (GTK_WINDOW (self->priv->progress_window));
    } else {
        if (gtk_widget_get_visible (self->priv->progress_window)) {
            progress_ui_handler_add_to_window (self, info);
        } else {
            progress_ui_handler_update_notification_or_status (self);
        }
    }

#ifdef HAVE_UNITY
    progress_ui_handler_update_unity_launcher (self, info, TRUE);
#endif
}

typedef struct {
    MarlinProgressInfo *info;
    MarlinProgressUIHandler *self;
} TimeoutData;

static void
timeout_data_free (TimeoutData *data)
{
    g_clear_object (&data->self);
    g_clear_object (&data->info);

    g_slice_free (TimeoutData, data);
}

static TimeoutData *
timeout_data_new (MarlinProgressUIHandler *self,
                  MarlinProgressInfo *info)
{
    TimeoutData *retval;

    retval = g_slice_new0 (TimeoutData);
    retval->self = g_object_ref (self);
    retval->info = g_object_ref (info);

    return retval;
}

static gboolean
new_op_started_timeout (TimeoutData *data)
{
    MarlinProgressInfo *info = data->info;
    MarlinProgressUIHandler *self = data->self;

    if (marlin_progress_info_get_is_paused (info)) {
        return TRUE;
    }

    if (!marlin_progress_info_get_is_finished (info)) {
        handle_new_progress_info (self, info);
    }

    timeout_data_free (data);

    return FALSE;
}

static void
release_application (MarlinProgressInfo *info,
                     MarlinProgressUIHandler *self)
{
    MarlinApplication *app;

    /* release the GApplication hold we acquired */
    app = marlin_application_get ();
    g_application_release (G_APPLICATION (app));

    //amtest
    g_message ("%s", G_STRFUNC);
}

static void
progress_info_started_cb (MarlinProgressInfo *info,
                          MarlinProgressUIHandler *self)
{
    MarlinApplication *app;
    TimeoutData *data;

    /* hold GApplication so we never quit while there's an operation pending */
    app = marlin_application_get ();
    g_application_hold (G_APPLICATION (app));

    g_signal_connect (info, "finished",
                      G_CALLBACK (release_application), self);

    data = timeout_data_new (self, info);

    /* timeout for the progress window to appear */
    g_timeout_add_seconds (2,
                           (GSourceFunc) new_op_started_timeout,
                           data);
}

static void
new_progress_info_cb (MarlinProgressInfoManager *manager,
                      MarlinProgressInfo *info,
                      MarlinProgressUIHandler *self)
{
    g_signal_connect (info, "started",
                      G_CALLBACK (progress_info_started_cb), self);
}

static void
marlin_progress_ui_handler_dispose (GObject *obj)
{
    MarlinProgressUIHandler *self = MARLIN_PROGRESS_UI_HANDLER (obj);

    g_clear_object (&self->priv->manager);

    G_OBJECT_CLASS (marlin_progress_ui_handler_parent_class)->dispose (obj);
}

static gboolean
server_has_persistence (void)
{
    gboolean retval;
    GList *caps, *l;

    caps = notify_get_server_caps ();
    if (caps == NULL) {
        return FALSE;
    }

    l = g_list_find_custom (caps, "persistence", (GCompareFunc) g_strcmp0);
    retval = (l != NULL);

    g_list_free_full (caps, g_free);

    return retval;
}

static void
marlin_progress_ui_handler_init (MarlinProgressUIHandler *self)
{
    self->priv = G_TYPE_INSTANCE_GET_PRIVATE (self, MARLIN_TYPE_PROGRESS_UI_HANDLER,
                                              MarlinProgressUIHandlerPriv);

    self->priv->manager = marlin_progress_info_manager_new ();
    g_signal_connect (self->priv->manager, "new-progress-info",
                      G_CALLBACK (new_progress_info_cb), self);

    self->priv->notification_supports_persistence = server_has_persistence ();
}

static void
marlin_progress_ui_handler_class_init (MarlinProgressUIHandlerClass *klass)
{
    GObjectClass *oclass;

    oclass = G_OBJECT_CLASS (klass);
    oclass->dispose = marlin_progress_ui_handler_dispose;

    g_type_class_add_private (klass, sizeof (MarlinProgressUIHandlerPriv));
}

MarlinProgressUIHandler *
marlin_progress_ui_handler_new (void)
{
    return g_object_new (MARLIN_TYPE_PROGRESS_UI_HANDLER, NULL);
}
