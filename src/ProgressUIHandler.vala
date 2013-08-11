/***
  Copyright (C) 2007, 2011 Red Hat, Inc.
  Copyright (C) 2013 Julián Unrrein <junrrein@gmail.com>

  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE. See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program. If not, see <http://www.gnu.org/licenses/>.

  Authors: Alexander Larsson <alexl@redhat.com>
           Cosimo Cecchi <cosimoc@redhat.com>
           Julián Unrrein <junrrein@gmail.com>
***/

public class Marlin.Progress.UIHandler : Object {

    private Marlin.Progress.InfoManager manager = null;

    private Gtk.Widget progress_window = null;
    private Gtk.Widget window_vbox = null;
    private uint active_infos = 0;

    private bool notification_supports_persistence = false;
    private Notify.Notification progress_notification = null;
    private Gtk.StatusIcon status_icon = null;
#if HAVE_UNITY
    private Marlin.QuicklistHandler quicklist_handler = null;
#endif

    private const string ACTION_DETAILS = "details";

    /* Our policy for showing progress notification is the following:
     * - File operations that end within two seconds do not get notified in any way
     * - If no file operations are running, and one passes the two seconds
     *   timeout, a window is displayed with the progress
     * - If the window is closed, we show a resident notification, or a status icon, depending on
     *   the capabilities of the notification daemon running in the session
     * - If some file operations are running, and another one passes the two seconds
     *   timeout, and the window is showing, we add it to the window directly
     * - In the same case, but when the window is not showing, we update the resident
     *   notification, changing its message, or the status icon's tooltip
     * - When one file operation finishes, if it's not the last one, we only update the
     *   resident notification's message, or the status icon's tooltip
     * - In the same case, if it's the last one, we close the resident notification,
     *   or the status icon, and trigger a transient one
     * - In the same case, but the window was showing, we just hide the window
     */

    public UIHandler () {
        this.manager = new Marlin.Progress.InfoManager ();
        
        manager.new_progress_info.connect ((info) => {
            info.started.connect (progress_info_started_cb);
        });

        this.notification_supports_persistence = server_has_persistence ();
    }
    
    private void progress_info_started_cb (Marlin.Progress.Info info) {
        var application = Marlin.Application.get ();
        application.hold ();

        info.finished.connect (() => {
            application.release ();
            debug ("ProgressUIHandler - release_application");
        });

        Timeout.add_seconds (2, () => {
            if (info.get_is_paused ())
                return true;

            if (!info.get_is_finished ())
                handle_new_progress_info (info);

            return false;
        });
    }

    private void handle_new_progress_info (Marlin.Progress.Info info) {
        info.finished.connect (progress_info_finished_cb);

        this.active_infos++;

        if (this.active_infos == 1) {
            /* This is the only active operation, present the window */
            add_to_window (info);
            (this.progress_window as Gtk.Window).present ();
        } else {
            if (this.progress_window.visible)
                add_to_window (info);
            else
                update_notification_or_status ();
        }

#if HAVE_UNITY
        update_unity_launcher (info, true);
#endif
    }
    
    private void add_to_window (Marlin.Progress.Info info) {
        ensure_window ();

        var progress_widget = new Marlin.Progress.InfoWidget (info);
        (this.window_vbox as Gtk.Box).pack_start (progress_widget, false, false, 6);

        progress_widget.show ();
    }
    
    private void update_notification_or_status () {
        if (this.notification_supports_persistence)
            update_notification ();
        else
            update_status_icon ();
    }
    
    private void progress_info_finished_cb (Marlin.Progress.Info info) {
        this.active_infos--;

        if (this.active_infos > 0) {
            if (!this.progress_window.visible)
                update_notification_or_status ();
        } else {
            if (this.progress_window.visible) {
                progress_window.hide ();
            } else {
                hide_notification_or_status ();
                show_complete_notification ();
            }
        }

#if HAVE_UNITY
        update_unity_launcher (info, false);
#endif
    }
    
    private void hide_notification_or_status () {
        if (this.status_icon != null)
            this.status_icon.visible = false;

        if (this.progress_notification != null) {
            try {
                this.progress_notification.close ();
            } catch (Error error) {
                warning ("There was an error when showing the notification: %s", error.message);
            }

            //TODO: Are we leaking memory here?
            this.progress_notification = null;
        }
    }
    
    private void show_complete_notification () {
        /* Don't display the notification if we'd be using a status icon */
        if (!this.notification_supports_persistence)
            return;

        var complete_notification = new Notify.Notification (_("File Operations"),
                                                             _("All file operations have been successfully completed"),
                                                             null);
        try {
            complete_notification.show ();
        } catch (Error error) {
            warning ("There was an error when showing the notification: %s", error.message);
        }
    }
    
    private void update_notification () {
        ensure_notification ();

        string body = ngettext ("%'d file operation active",
                                "%'d file operations active",
                                this.active_infos);

        this.progress_notification.update (_("File Operations"),
                                           body, "");

        try {
            this.progress_notification.show ();
        } catch (Error error) {
            warning ("There was an error when showing the notification: %s", error.message);
        }
    }
    
    private void ensure_notification () {
        if (this.progress_notification != null)
            return;

        this.progress_notification = new Notify.Notification (_("File Operations"),
                                                              null, null);

        this.progress_notification.set_category ("transfer");
        this.progress_notification.set_hint ("resident", new Variant.boolean (true));
        this.progress_notification.add_action (ACTION_DETAILS,
                                               _("Show Details"),
                                               (Notify.ActionCallback) notification_show_details_cb);
    }
    
    private void notification_show_details_cb (Notify.Notification notification,
                                               string action_name) {
        if (action_name != ACTION_DETAILS)
            return;

        try {
            progress_notification.close ();
        } catch (Error error) {
            warning ("There was an error when closing the notification: %s", error.message);
        }

        (progress_window as Gtk.Window).present ();
    }

    private void update_status_icon () {
        ensure_status_icon ();

        string tooltip = ngettext ("%'d file operation active",
                                   "%'d file operations active",
                                   this.active_infos);

        this.status_icon.set_tooltip_text (tooltip);

        this.status_icon.visible = true;
    }
    
    private void ensure_status_icon () {
        if (this.status_icon != null)
            return;

        var icon = new ThemedIcon.with_default_fallbacks ("system-file-manager-symbolic");
        this.status_icon = new Gtk.StatusIcon.from_gicon (icon);

        this.status_icon.activate.connect (() => {
            this.status_icon.visible = false;
            (this.progress_window as Gtk.Window).present ();
        });
        
        this.status_icon.visible = false;
    }

#if HAVE_UNITY
    private void update_unity_launcher (Marlin.Progress.Info info,
                                        bool added) {
        if (this.quicklist_handler == null) {
            this.quicklist_handler = QuicklistHandler.get_singleton ();

            if (this.quicklist_handler == null)
                return;

            build_unity_quicklist ();
        }

        foreach (var marlin_lentry in this.quicklist_handler.launcher_entries)
            update_unity_launcher_entry (info, marlin_lentry);

        if (added)
            info.progress_changed.connect (unity_progress_changed);
    }
    
    private void build_unity_quicklist () {
        foreach (var marlin_lentry in this.quicklist_handler.launcher_entries) {
            Unity.LauncherEntry unity_lentry = marlin_lentry.entry;
            Dbusmenu.Menuitem quicklist = unity_lentry.quicklist;

            var show_menuitem = new Dbusmenu.Menuitem ();
            show_menuitem.property_set (Dbusmenu.MENUITEM_PROP_LABEL,
                                        _("Show Copy Dialog"));
            show_menuitem.property_set_bool (Dbusmenu.MENUITEM_PROP_VISIBLE,
                                             false);
            quicklist.child_add_position (show_menuitem, -1);

            marlin_lentry.progress_quicklists.prepend (show_menuitem);
            show_menuitem.item_activated.connect ((menuitem, timestamp) => {
                unity_quicklist_show_activated (menuitem, timestamp);
            });

            var cancel_menuitem = new Dbusmenu.Menuitem ();
            cancel_menuitem.property_set (Dbusmenu.MENUITEM_PROP_LABEL,
                                          _("Cancel All In-progress Actions"));
            cancel_menuitem.property_set_bool (Dbusmenu.MENUITEM_PROP_VISIBLE,
                                               false);
            quicklist.child_add_position (cancel_menuitem, -1);

            marlin_lentry.progress_quicklists.prepend (cancel_menuitem);
            cancel_menuitem.item_activated.connect ((menuitem, timestamp) => {
                unity_quicklist_cancel_activated (menuitem, timestamp);
            });
        }
    }

    private void update_unity_launcher_entry (Marlin.Progress.Info info,
                                              Marlin.LauncherEntry marlin_lentry) {
        Unity.LauncherEntry unity_lentry = marlin_lentry.entry;

        if (this.active_infos > 0) {
            unity_lentry.progress_visible = true;
            show_unity_quicklist (marlin_lentry, true);
            unity_progress_changed (null);
        } else {
            unity_lentry.progress_visible = false;
            unity_lentry.progress = 0.0;
            show_unity_quicklist (marlin_lentry, false);

            Cancellable pc = info.get_cancellable ();

            if (!pc.is_cancelled ()) {
                unity_lentry.urgent = true;
                Timeout.add_seconds (2, () => {
                    return disable_unity_urgency (unity_lentry);
                });
            }
        }
    }

    private void unity_progress_changed (Marlin.Progress.Info? info) {
        double progress = 0;
        double current = 0;
        double total = 0;
        unowned List<Marlin.Progress.Info> infos = this.manager.get_all_infos ();

        foreach (var _info in infos) {
            double c = _info.get_current ();
            double t = _info.get_total ();

            if (c < 0)
                c = 0;

            if (t <= 0)
                continue;

            current += c;
            total += t;
        }

        if (current >= 0 && total > 0)
            progress = current / total;

        if (progress > 1.0)
            progress = 1.0;

        foreach (Marlin.LauncherEntry marlin_lentry in this.quicklist_handler.launcher_entries) {
            Unity.LauncherEntry unity_lentry = marlin_lentry.entry;
            unity_lentry.progress = progress;
        }
    }

    private bool disable_unity_urgency (Unity.LauncherEntry entry) {
        entry.urgent = false;

        return false;
    }

    private void unity_quicklist_show_activated (Dbusmenu.Menuitem menu,
                                                 uint timestamp) {
        if (!this.progress_window.visible)
            (this.progress_window as Gtk.Window).present ();
        else {
            //TODO: This does not seem to work correctly.
            (this.progress_window as Gtk.Window).set_keep_above (true);
            (this.progress_window as Gtk.Window).set_keep_above (false);
        }
    }

    private void unity_quicklist_cancel_activated (Dbusmenu.Menuitem menu,
                                                   uint timestamp) {
        unowned List<Marlin.Progress.Info> infos = this.manager.get_all_infos ();
        foreach (var info in infos)
            info.cancel ();
    }

    private void show_unity_quicklist (Marlin.LauncherEntry marlin_lentry,
                                       bool show) {
        foreach (Dbusmenu.Menuitem menuitem in marlin_lentry.progress_quicklists)
            menuitem.property_set_bool (Dbusmenu.MENUITEM_PROP_VISIBLE, show);
    }
#endif

    private bool progress_window_delete_event (Gtk.Widget widget,
                                               Gdk.EventAny event) {
        widget.hide ();

        if (this.notification_supports_persistence)
            this.update_notification ();
        else
            this.update_status_icon ();

        return true;
    }

    private void ensure_window () {
        if (this.progress_window != null)
            return;

        this.progress_window = new Gtk.Window (Gtk.WindowType.TOPLEVEL);

        (this.progress_window as Gtk.Window).resizable = false;
        (this.progress_window as Gtk.Container).set_border_width (10);
        (this.progress_window as Gtk.Window).title = _("File Operations");
        (this.progress_window as Gtk.Window).set_wmclass ("file_progress", "Marlin");
        (this.progress_window as Gtk.Window).set_position (Gtk.WindowPosition.CENTER);
        (this.progress_window as Gtk.Window).icon_name = "system-file-manager";

        this.window_vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);

        (this.progress_window as Gtk.Container).add (this.window_vbox);
        window_vbox.show ();

        progress_window.delete_event.connect ((widget, event) => {
            return progress_window_delete_event (widget, event);
        });
    }

    private bool server_has_persistence () {
        unowned List<string> caps = Notify.get_server_caps ();

        return caps.find ("persistence") != null ? true : false;
    }
}
