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
                previous_file = file;
                continue;
            }
            
            /* FIXME: What happens if the list is 2 items long, but
               they are of the same mymetipe/directory ?
               No app is set? */
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
        return new List<AppInfo> ();
    }

    public List<AppInfo> get_applications_for_files (List<GOF.File> files) {
        return new List<AppInfo> ();
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
}
