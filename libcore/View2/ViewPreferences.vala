/***
    Copyright (C) 2011 ammonkey <am.monkeyd@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, Inc.,, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
***/

namespace Files {
    public static ViewPreferences? view_preferences = null;
    public class ViewPreferences : Object {

        /* IconView Preferences */
            ZoomLevel icon_default_zoom_level;
            ZoomLevel icon_maximum_zoom_level;
            ZoomLevel icon_minimum_zoom_level;
            ZoomLevel icon_zoom_level;
        /* ListView Preferences */
            ZoomLevel list_default_zoom_level;
            ZoomLevel list_maximum_zoom_level;
            ZoomLevel list_minimum_zoom_level;
            ZoomLevel list_zoom_level;
        /* ColumnView Preferences */
            ZoomLevel column_default_zoom_level;
            ZoomLevel column_maximum_zoom_level;
            ZoomLevel column_minimum_zoom_level;
            ZoomLevel column_zoom_level;

            uint preferred_column_width;

        public static ViewPreferences get_default () {
            if (view_preferences == null) {
                view_preferences = new ViewPreferences ();
            }

            return view_preferences;
        }
    }
}
