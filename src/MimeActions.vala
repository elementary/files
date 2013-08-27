/***
  Copyright (C) 2000 Eazel, Inc.
  Copyright (C) 2011 ammonkey <am.monkeyd@gmail.com>
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

  Authors: Maciej Stachowiak <mjs@eazel.com>
           ammonkey <am.monkeyd@gmail.com>
           Julián Unrrein <junrrein@gmail.com>
***/

namespace Marlin.Mime {

    public AppInfo get_default_application_for_file (GOF.File file) {
        AppInfo app = file.get_default_handler ();

        if (app == null) {
            string uri_scheme = file.location.get_uri_scheme ();
            if (uri_scheme != null)
                app = AppInfo.get_default_for_uri_scheme (uri_scheme);
        }

        return app;
    }

    public AppInfo get_default_application_for_files (List<GOF.File> files) {
        assert (files != null);

        List<GOF.File> sorted_files = files.copy ();
        sorted_files.sort (file_compare_by_mime_type);

        AppInfo app = null;
        GOF.File previous_file = null;
        foreach (var file in sorted_files) {
            if (previous_file == null) {
                app = get_default_application_for_file (file);
                previous_file = file;
                continue;
            }

            if (file_compare_by_mime_type (file, previous_file) == 0 &&
                file_compare_by_parent_uri (file, previous_file) == 0)
                continue;

            var one_app = get_default_application_for_file (file);

            if (one_app == null || (app != null) && !app.equal (one_app)) {
                app = null;
                break;
            }

            if (app == null)
                app = one_app;

            previous_file = file;
        }

        return app;
    }

    public List<AppInfo> get_applications_for_file (GOF.File file) {
        List<AppInfo> result = AppInfo.get_all_for_type (file.get_ftype ());
        string uri_scheme = file.location.get_uri_scheme ();
        
        if (uri_scheme != null) {
            var uri_handler = AppInfo.get_default_for_uri_scheme (uri_scheme);
            
            if (uri_handler != null)
                result.prepend (uri_handler);
        }
        
        if (!file_has_local_path (file))
            filter_non_uri_apps (result);
            
        result.sort (application_compare_by_name);
        
        return result;
    }

    public List<AppInfo> get_applications_for_files (List<GOF.File> files) {
        assert (files != null);
        
        List<GOF.File> sorted_files = files.copy ();
        sorted_files.sort (file_compare_by_mime_type);
        
        List<AppInfo> result = null;
        GOF.File previous_file = null;
        
        foreach (var file in sorted_files) {
            if (previous_file == null) {
                result = get_applications_for_file (file);
                previous_file = file;
                continue;
            }
            
            if (file_compare_by_mime_type (file, previous_file) == 0 &&
                file_compare_by_parent_uri (file, previous_file) == 0)
                continue;
                
            List<AppInfo> one_result = get_applications_for_file (file);
            one_result.sort (application_compare_by_id);
            
            if (result != null)
                result = intersect_application_lists (result, one_result);
            else
                result = one_result.copy ();
                
            if (result == null)
                break;
                
            previous_file = file;
        }
        
        result.sort (application_compare_by_name);
        
        return result;
    }

    private bool file_has_local_path (GOF.File file) {

        if (file.location.is_native ()) {
            return true;
        } else {
            var path = file.location.get_path ();
            return path != null;
        }
    }

    private int file_compare_by_mime_type (GOF.File a, GOF.File b) {
        return strcmp (a.get_ftype (), b.get_ftype ());
    }

    private string gof_get_parent_uri (GOF.File file) {
        return file.directory != null ? file.directory.get_uri () : "";
    }

    private int file_compare_by_parent_uri (GOF.File a, GOF.File b) {
        return strcmp (gof_get_parent_uri (a), gof_get_parent_uri (b));
    }

    private int application_compare_by_name (AppInfo a, AppInfo b) {
        return a.get_display_name ().collate (b.get_display_name ());
    }

    private int application_compare_by_id (AppInfo a, AppInfo b) {
        return strcmp (a.get_id (), b.get_id ());
    }

    private void filter_non_uri_apps (List<AppInfo> apps) {
        foreach (var app in apps)
            if (!app.supports_uris ())
                apps.remove (app);
    }
    
    private List<AppInfo> intersect_application_lists (List<AppInfo> a, List<AppInfo> b) {
        List<AppInfo> result = null;
        
        /* This is going to look ugly, but doing the same thing using
           "foreach" would take m*n operations. */
        unowned List<AppInfo> l = a;
        unowned List<AppInfo> m = b;
        
        while (l != null && m != null) {
            AppInfo app_a = l.data;
            AppInfo app_b = m.data;
            
            int cmp = application_compare_by_id (app_a, app_b);
            
            if (cmp > 0) {
                m = m.next;
            } else if (cmp < 0) {
                l = l.next;
            } else {
                result.append (app_a);
                l = l.next;
                m = m.next;
            }
        }
        
        return result;
    }
}
