/***
    Copyright (c) 2000 Eazel, Inc.
    Copyright (c) 2011 ammonkey <am.monkeyd@gmail.com>
    Copyright (c) 2013-2018 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors: Maciej Stachowiak <mjs@eazel.com>
             ammonkey <am.monkeyd@gmail.com>
             Julián Unrrein <junrrein@gmail.com>
***/

namespace Files {
    public Gtk.Window get_active_window () {
        unowned Gtk.Application gtk_app = (Gtk.Application)(GLib.Application.get_default ());
        return gtk_app.get_active_window ();
    }
}

public class Files.MimeActions {

    public static AppInfo? get_default_application_for_file (Files.File file) {
        AppInfo app = file.get_default_handler ();

        if (app == null) {
            string uri_scheme = file.location.get_uri_scheme ();

            if (uri_scheme != null) {
                app = AppInfo.get_default_for_uri_scheme (uri_scheme);
            }
        }

        return app;
    }

    public static AppInfo? get_default_application_for_files (GLib.List<Files.File> files) {
        /* Need to make a new list to avoid corrupting the selection */
        GLib.List<Files.File> sorted_files = null;
        files.@foreach ((file) => {
            sorted_files.prepend (file);
        });

        sorted_files.sort (file_compare_by_mime_type);

        AppInfo? app = null;
        Files.File? previous_file = null;

        foreach (Files.File file in sorted_files) {
            if (previous_file == null) {
                app = get_default_application_for_file (file);
                previous_file = file;
                continue;
            }

            if (file_compare_by_mime_type (file, previous_file) == 0 &&
                file_compare_by_parent_uri (file, previous_file) == 0) {

                continue;
            }

            var one_app = get_default_application_for_file (file);

            if (one_app == null || (app != null) && !app.equal (one_app)) {
                app = null;
                break;
            }

            if (app == null) {
                app = one_app;
            }

            previous_file = file;
        }

        return app;
    }

    public static List<AppInfo> get_applications_for_file (Files.File file) {
        List<AppInfo> result = null;
        string? type = file.get_ftype ();
        if (type == null) {
            return result;
        }

        /* For some reason this may return null even when a default app exists (e.g. for
         * compressed files */
        result = AppInfo.get_all_for_type (type);

        string uri_scheme = file.location.get_uri_scheme ();

        if (uri_scheme != null) {
            var uri_handler = AppInfo.get_default_for_uri_scheme (uri_scheme);

            if (uri_handler != null) {
                result.prepend (uri_handler);
            }
        }

        if (!file_has_local_path (file)) {
            filter_non_uri_apps (result);
        }

        result.sort (application_compare_by_name);

        return result;
    }

    public static List<AppInfo> get_applications_for_folder (Files.File file) {
        List<AppInfo> result = AppInfo.get_all_for_type (ContentType.get_mime_type ("inode/directory"));
        string uri_scheme = file.location.get_uri_scheme ();

        if (uri_scheme != null) {
            var uri_handler = AppInfo.get_default_for_uri_scheme (uri_scheme);

            if (uri_handler != null) {
                result.prepend (uri_handler);
            }
        }

        if (!file_has_local_path (file)) {
            result = filter_non_uri_apps (result);
        }

        result.sort (application_compare_by_name);
        return result;
    }

    public static List<AppInfo> get_applications_for_files (
        GLib.List<Files.File> files,
        string this_app_name,
        bool filter_default_if_not_executable,
        bool filter_this_app
    ) {
        /* Need to make a new list to avoid corrupting the selection */
        GLib.List<Files.File> sorted_files = null;
        files.@foreach ((file) => {
            sorted_files.prepend (file);
        });

        sorted_files.sort (file_compare_by_mime_type);
        List<AppInfo> result = null;
        Files.File previous_file = null;

        foreach (var file in sorted_files) {
            if (previous_file == null) {
                result = get_applications_for_file (file);
                if (result == null) {
                    debug ("No application found for %s", file.get_ftype ());
                    return result;
                }
                previous_file = file;
                continue;
            }

            if (file_compare_by_mime_type (file, previous_file) == 0 &&
                file_compare_by_parent_uri (file, previous_file) == 0) {

                continue;
            }

            GLib.List<AppInfo> one_result = get_applications_for_file (file);
            one_result.sort (application_compare_by_id);

            if (result != null && result.data != null) {
                //Get applications able to open all file types (if possible)
                result = intersect_application_lists (result, one_result);
            } else {
                result = (owned) one_result;
            }

            if (result == null) {
                break;
            }

            previous_file = file;
        }

        if (result == null) {
            return result;
        }

        result.sort (application_compare_by_name);
        if (filter_default_if_not_executable) {
            var default_app = get_default_application_for_files (files);
            if (default_app != null) {
                string? id1, id2;
                id2 = default_app.get_id ();

                if (id2 != null) {
                    unowned GLib.List<AppInfo> l = result;
                    while (l != null && l.data is AppInfo) {
                        id1 = l.data.get_id ();

                        if (id1 != null && id1 == id2) {
                            result.delete_link (l);
                            break;
                        }

                        l = l.next;
                    }
                }
            }
        }

        if (result == null) {
            return result;
        }

        if (filter_this_app) {
            unowned GLib.List<AppInfo> l = result;
            while (l != null) {
                if (l.data is AppInfo) {
                    if (l.data.get_executable () == this_app_name) {
                        result.delete_link (l);
                        break;
                    }
                } else {
                    result.delete_link (l);
                    l = result;
                    if (l == null) {
                        break;
                    }
                }

                l = l.next;
            }
        }

        return result;
    }

    private static bool file_has_local_path (Files.File file) {
        if (file.location.is_native ()) {
            return true;
        } else {
            var path = file.location.get_path ();
            return path != null;
        }
    }

    private static int file_compare_by_mime_type (Files.File a, Files.File b) {
        return strcmp (a.get_ftype (), b.get_ftype ());
    }

    private static string? gof_get_parent_uri (Files.File file) {
        return file.directory != null ? file.directory.get_uri () : null;
    }

    private static int file_compare_by_parent_uri (Files.File a, Files.File b) {
        return strcmp (gof_get_parent_uri (a), gof_get_parent_uri (b));
    }

    private static int application_compare_by_name (AppInfo a, AppInfo b) {
        return a.get_display_name ().collate (b.get_display_name ());
    }

    private static int application_compare_by_id (AppInfo a, AppInfo b) {
        return strcmp (a.get_id (), b.get_id ());
    }

    private static List<AppInfo> filter_non_uri_apps (List<AppInfo> apps) {
         List<AppInfo> uri_apps = null;
        foreach (var app in apps) {
            if (app.supports_uris ()) {
                uri_apps.append (app);
            }
        }

        return uri_apps;
    }

    private static List<AppInfo> intersect_application_lists (List<AppInfo> a, List<AppInfo> b) {
        List<AppInfo> result = null;

        /* This is going to look ugly, but doing the same thing using
           "foreach" would take m*n operations. */
        unowned List<AppInfo> iterator_a = a;
        unowned List<AppInfo> iterator_b = b;

        while (iterator_a != null && iterator_b != null) {
            AppInfo app_a = iterator_a.data;
            AppInfo app_b = iterator_b.data;

            int cmp = application_compare_by_id (app_a, app_b);

            if (cmp > 0) {
                iterator_b = iterator_b.next;
            } else if (cmp < 0) {
                iterator_a = iterator_a.next;
            } else {
                result.append (app_a);
                iterator_a = iterator_a.next;
                iterator_b = iterator_b.next;
            }
        }

        return result;
    }

    public static AppInfo? get_default_application_for_glib_file (GLib.File file) {
        return get_default_application_for_file (Files.File.@get (file));
    }

    public static void open_glib_file_request (GLib.File file_to_open, Gtk.Widget parent, AppInfo? app = null) {
        /* Note: This function should be only called if file_to_open is not an executable or it is not
         * intended to execute it (DirectoryView takes care of this) */
        if (app == null) {
            var choice = choose_app_for_glib_file (file_to_open, parent);
            if (choice != null) {
                launch_glib_file_with_app (file_to_open, parent, choice);
            }
        } else {
            launch_glib_file_with_app (file_to_open, parent, app);
        }
    }

    public static void open_multiple_gof_files_request (GLib.List<Files.File> gofs_to_open,
                                                        Gtk.Widget parent,
                                                        AppInfo? app = null) {
        /* Note: This function should be only called if files_to_open are not executables or it is not
         * intended to execute them (DirectoryView takes care of this) */
        AppInfo? app_info = null;
        if (app == null) {
            app_info = get_default_application_for_files (gofs_to_open);
        } else {
            app_info = app;
        }

        if (app_info == null) {
            PF.Dialogs.show_error_dialog (
                _("Multiple file types selected"),
                _("No single app can open all these types of file"),
                Files.get_active_window ());
        } else {
            GLib.List<GLib.File> files_to_open = null;
            foreach (var gof in gofs_to_open) {
                files_to_open.append (gof.location);
            }

            launch_with_app (files_to_open, app_info, Files.get_active_window ());
        }
    }

    public static AppInfo? choose_app_for_glib_file (GLib.File file_to_open, Gtk.Widget parent) {
        var chooser = new PF.ChooseAppDialog (Files.get_active_window (), file_to_open);
        return chooser.get_app_info ();
    }

     private static void launch_glib_file_with_app (GLib.File file_to_open, Gtk.Widget parent, AppInfo app) {
        GLib.List<GLib.File> files_to_open = null;
        files_to_open.append (file_to_open);
        launch_with_app (files_to_open, app, Files.get_active_window ());
     }

    private static void launch_with_app (GLib.List<GLib.File> files_to_open, AppInfo app, Gtk.Window? win) {
        if (app.supports_files ()) {
            try {
                app.launch (files_to_open, null);
            } catch (GLib.Error e) {
                PF.Dialogs.show_error_dialog (_("Failed to open files"), e.message, win);
            }
        } else if (app.supports_uris ()) {
            GLib.List<string> uris = null;
            foreach (var file in files_to_open) {
                uris.append (file.get_uri ());
            }
            try {
                app.launch_uris (uris, null);
            } catch (GLib.Error e) {
                PF.Dialogs.show_error_dialog (_("Could not open URIs"), e.message, win);
            }
        } else {
            PF.Dialogs.show_error_dialog (_("Could not open files or URIs with this app"), "", win);
        }
    }
}
