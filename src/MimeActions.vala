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
        return AppInfo.get_default_for_type ("", false);
    }
    
    public AppInfo get_default_application_for_files (List<GOF.File> files) {
        return AppInfo.get_default_for_type ("", false);
    }
    
    public List<AppInfo> get_applications_for_file (GOF.File file) {
        return new List<AppInfo> ();
    }
    
    public List<AppInfo> get_applications_for_files (List<GOF.File> files) {
        return new List<AppInfo> ();
    }
}