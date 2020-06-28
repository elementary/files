/***
    Copyright (c) 2007, 2011 Red Hat, Inc.
    Copyright (c) 2013 Julián Unrrein <junrrein@gmail.com>

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
             Jeremy Wootten <jeremy@elementaryos.org>
***/

/*** One instance of this class is owned by the application and handles UI for file transfers initiated by
 *   of the app windows.  Feedback is provided by a dialog window which appears if a transfer takes longer than
 *   approximately 1 second. The unity launcher is also updated if present and a notification is sent of the
 *   completion of the operation unless it was cancelled by the user.
***/
public class Marlin.Progress.UIHandler : Object {
    private PF.Progress.InfoManager manager = null;
#if HAVE_UNITY
    private Marlin.QuicklistHandler quicklist_handler = null;
#endif
    private Gtk.Dialog progress_window = null;
    private Gtk.Box window_vbox = null;
    private uint active_infos = 0;
    private Gtk.Application application;

    construct {
        application = (Gtk.Application) GLib.Application.get_default ();
        manager = PF.Progress.InfoManager.get_instance ();

        manager.new_progress_info.connect ((info) => {
            info.started.connect (progress_info_started_cb);
        });
    }

    ~UIHandler () {
        debug ("ProgressUIHandler destruct");
        if (active_infos > 0) {
            warning ("ProgressUIHandler destruct when infos active");
            var infos = manager.get_all_infos ();
            foreach (var info in infos) {
                info.cancel ();
            }
        }
    }

    private void progress_info_started_cb (PF.Progress.Info info) {
        application.hold ();

        if (info == null || !(info is PF.Progress.Info) ||
            info.is_finished || info.is_cancelled) {

            application.release ();
            return;
        }

        info.finished.connect (progress_info_finished_cb);
        this.active_infos++;


        var operation_running = false;
        Timeout.add_full (GLib.Priority.LOW, 500, () => {
            if (info == null || !(info is PF.Progress.Info) ||
                info.is_finished || info.is_cancelled) {

                return GLib.Source.REMOVE;
            }

            if (info.is_paused) {
                return GLib.Source.CONTINUE;
            } else if (operation_running && !info.is_finished) {
                add_progress_info_to_window (info);
                return GLib.Source.REMOVE;
            } else {
                operation_running = true;
                return GLib.Source.CONTINUE;
            }
        });
    }

    private void add_progress_info_to_window (PF.Progress.Info info) {
        if (this.active_infos == 1) {
            /* This is the only active operation, present the window */
            add_to_window (info);
            progress_window.present ();
        } else if (progress_window.visible) {
                add_to_window (info);
        }

#if HAVE_UNITY
        update_unity_launcher (info, true);
#endif
    }

    private void add_to_window (PF.Progress.Info info) {
        ensure_window ();

        var progress_widget = new Marlin.Progress.InfoWidget (info);
        window_vbox.pack_start (progress_widget, false, false, 6);

        progress_widget.cancelled.connect ((info) => {
            progress_info_finished_cb (info);
            progress_widget.hide ();
        });

        progress_widget.show ();
        if (progress_window.visible) {
            progress_window.present ();
        }
    }

    private void ensure_window () {
        if (progress_window == null) {
            /* This provides an undeletable, unminimisable window in which to show the info widgets */
            progress_window = new Gtk.Dialog () {
                resizable = false,
                deletable = false,
                title = _("File Operations"),
                icon_name = "system-file-manager"
            };

            window_vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);

            progress_window.get_content_area ().set_border_width (10);
            progress_window.get_content_area ().add (this.window_vbox);
            this.window_vbox.show ();

            progress_window.delete_event.connect ((widget, event) => {
                widget.hide ();
                return true;
            });
        }

        progress_window.set_transient_for (application.get_active_window ());
    }

    private void progress_info_finished_cb (PF.Progress.Info info) {
        /* Must only be called once for each info */
        info.finished.disconnect (progress_info_finished_cb);
        application.release ();

        if (active_infos > 0) {
            this.active_infos--;
            /* Only notify if application is not focussed. Add a delay
             * so that the active application window has time to refocus (if the application itself is focussed)
             * after progress window dialog is hidden. We have to wait until the dialog is hidden
             * because it steals focus from the application main window. This also means that a notification
             * is only sent after last operation finishes and the progress window closes.
             * FIXME: Avoid use of a timeout by not using a dialog for progress window or otherwise.*/

            if (!info.is_cancelled) {
                var title = info.title;  /* Do not keep ref to info */
                Timeout.add (100, () => {
                    if (!application.get_active_window ().has_toplevel_focus) {
                        show_operation_complete_notification (title, active_infos < 1);
                    }

                    return GLib.Source.REMOVE;
                });
            }
        } else {
            warning ("Attempt to decrement zero active infos");
        }
        /* For rapid file transfers this can get called before progress window was been created */
        if (active_infos < 1 && progress_window != null && progress_window.visible) {
            progress_window.hide ();
        }
#if HAVE_UNITY
        update_unity_launcher (info, false);
#endif
    }

    private void show_operation_complete_notification (string title, bool all_finished) {
        /// TRANSLATORS: %s will be replaced by the title of the file operation
        var result = (_("Completed %s")).printf (title);

        if (all_finished) {
            result = result + "\n" + _("All file operations have ended");
        }

        var complete_notification = new GLib.Notification (_("File Operations"));
        complete_notification.set_body (result);
        complete_notification.set_icon (new GLib.ThemedIcon (Marlin.ICON_APP_LOGO));
        application.send_notification ("Pantheon Files Operation", complete_notification);
    }

#if HAVE_UNITY
    private void update_unity_launcher (PF.Progress.Info info,
                                        bool added) {

        if (this.quicklist_handler == null) {
            this.quicklist_handler = QuicklistHandler.get_singleton ();

            if (this.quicklist_handler == null) {
                return;
            }

            build_unity_quicklist ();
        }

        foreach (var marlin_lentry in this.quicklist_handler.launcher_entries) {
            update_unity_launcher_entry (info, marlin_lentry);
        }

        if (added) {
            info.progress_changed.connect (unity_progress_changed);
        }
    }

    private void build_unity_quicklist () {
        /* Create menu items for the quicklist */
        foreach (var marlin_lentry in this.quicklist_handler.launcher_entries) {
            /* Separator between bookmarks and progress items */
            var separator = new Dbusmenu.Menuitem ();

            separator.property_set (Dbusmenu.MENUITEM_PROP_TYPE,
                                    Dbusmenu.CLIENT_TYPES_SEPARATOR);
            separator.property_set (Dbusmenu.MENUITEM_PROP_LABEL,
                                    "Progress items separator");
            marlin_lentry.progress_quicklists.append (separator);

            /* "Show progress window" menu item */
            var show_menuitem = new Dbusmenu.Menuitem ();

            show_menuitem.property_set (Dbusmenu.MENUITEM_PROP_LABEL,
                                        _("Show Copy Dialog"));

            show_menuitem.item_activated.connect (() => {
                progress_window.present ();
            });

            marlin_lentry.progress_quicklists.append (show_menuitem);

            /* "Cancel in-progress operations" menu item */
            var cancel_menuitem = new Dbusmenu.Menuitem ();

            cancel_menuitem.property_set (Dbusmenu.MENUITEM_PROP_LABEL,
                                          _("Cancel All In-progress Actions"));

            cancel_menuitem.item_activated.connect (() => {
                var infos = this.manager.get_all_infos ();

                foreach (var info in infos) {
                    info.cancel ();
                }
            });

            marlin_lentry.progress_quicklists.append (cancel_menuitem);
        }
    }

    private void update_unity_launcher_entry (PF.Progress.Info info,
                                              Marlin.LauncherEntry marlin_lentry) {
        Unity.LauncherEntry unity_lentry = marlin_lentry.entry;

        if (this.active_infos > 0) {
            unity_lentry.progress_visible = true;
            unity_progress_changed ();
            show_unity_quicklist (marlin_lentry, true);
        } else {
            unity_lentry.progress_visible = false;
            unity_lentry.progress = 0.0;
            show_unity_quicklist (marlin_lentry, false);
        }
    }

    private void show_unity_quicklist (Marlin.LauncherEntry marlin_lentry,
                                       bool show) {

        Unity.LauncherEntry unity_lentry = marlin_lentry.entry;
        Dbusmenu.Menuitem quicklist = unity_lentry.quicklist;

        foreach (Dbusmenu.Menuitem menuitem in marlin_lentry.progress_quicklists) {
            var parent = menuitem.get_parent ();
            if (show) {
                if (parent == null) {
                    quicklist.child_add_position (menuitem, -1);
                }
            } else if (parent != null && parent == quicklist) {
                quicklist.child_delete (menuitem);
            }
        }
    }

    private void unity_progress_changed () {
        double progress = 0;
        double current = 0;
        double total = 0;
        var infos = this.manager.get_all_infos ();

        foreach (var _info in infos) {
            double c = _info.current;
            double t = _info.total;

            if (c < 0) {
                c = 0;
            }

            if (t <= 0) {
                continue;
            }

            current += c;
            total += t;
        }

        if (current >= 0 && total > 0) {
            progress = current / total;
        }

        if (progress > 1.0) {
            progress = 1.0;
        }

        foreach (Marlin.LauncherEntry marlin_lentry in this.quicklist_handler.launcher_entries) {
            Unity.LauncherEntry unity_lentry = marlin_lentry.entry;
            unity_lentry.progress = progress;
        }
    }
#endif

}
