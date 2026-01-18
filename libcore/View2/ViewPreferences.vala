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

       public static void set_up_view_preferences (
            Settings? icon_settings,
            Settings? list_settings,
            Settings? column_settings
        ) {
            var view_prefs = ViewPreferences.get_default ();
            if (icon_settings != null) {
                icon_settings.bind ("default-zoom-level", view_prefs, "icon-default-zoom-level", DEFAULT);
                icon_settings.bind ("minimum-zoom-level", view_prefs, "icon-minimum-zoom-level", DEFAULT);
                icon_settings.bind ("maximum-zoom-level", view_prefs, "icon-maximum-zoom-level", DEFAULT);
                icon_settings.bind ("zoom-level", view_prefs, "icon-zoom-level", DEFAULT);
            }

            if (list_settings != null) {
                list_settings.bind ("default-zoom-level", view_prefs, "list-default-zoom-level", DEFAULT);
                list_settings.bind ("minimum-zoom-level", view_prefs, "list-minimum-zoom-level", DEFAULT);
                list_settings.bind ("maximum-zoom-level", view_prefs, "list-maximum-zoom-level", DEFAULT);
                list_settings.bind ("zoom-level", view_prefs, "list-zoom-level", DEFAULT);
            }

            if (column_settings != null) {
                column_settings.bind ("default-zoom-level", view_prefs, "column-default-zoom-level", DEFAULT);
                column_settings.bind ("minimum-zoom-level", view_prefs, "column-minimum-zoom-level", DEFAULT);
                column_settings.bind ("maximum-zoom-level", view_prefs, "column-maximum-zoom-level", DEFAULT);
                column_settings.bind ("zoom-level", view_prefs, "column-zoom-level", DEFAULT);
                //TODO Separate preferred-col-width for list view
                column_settings.bind ("preferred_column_width", view_prefs, "preferred_column_width", DEFAULT);
            }
        }

        public static void get_zoom_levels (
            ViewMode mode,
            out ZoomLevel normal,
            out ZoomLevel minimum,
            out ZoomLevel maximum,
            out ZoomLevel current
        ) {

            normal = ZoomLevel.NORMAL;
            minimum = ZoomLevel.SMALLEST;
            minimum = ZoomLevel.LARGEST;
            current = ZoomLevel.NORMAL;

            switch (mode) {
                case ZoomLevel.ICON:
                    normal = icon_default_zoom_level;
                    minimum = icon_minimum_zoom_level;
                    minimum = icon_maximum_zoom_level;
                    current = icon_zoom_level;
                    break;

                case ZoomLevel.LIST:
                    normal = list_default_zoom_level;
                    minimum = list_minimum_zoom_level;
                    minimum = list_maximum_zoom_level;
                    current = list_zoom_level;
                    break;

                case ZoomLevel.MILLER_COLUMNS:
                    normal = column_default_zoom_level;
                    minimum = column_minimum_zoom_level;
                    minimum = column_maximum_zoom_level;
                    current = column_zoom_level;
                    break;

                default:
                    assert_not_reached ();
            }
        }
    }
}
