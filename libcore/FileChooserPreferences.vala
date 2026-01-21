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
    private static FileChooserPreferences? filechooser_preferences = null;

    public class FileChooserPreferences : Object {
        /* Open file mode settings */
        public string open_last_folder_uri { get; set; }
        public ViewMode open_viewmode { get; set; }

        /* Save file mode settings */
        public string save_last_folder_uri { get; set; }
        public ViewMode save_viewmode { get; set; }

        public static FileChooserPreferences get_default () {
            if (filechooser_preferences == null) {
                filechooser_preferences = new FileChooserPreferences ();
            }

            return filechooser_preferences;
        }

       public static void set_up_file_chooser_preferences (
            Settings? app_settings
        ) {
            var file_chooser_preferences = FileChooserPreferences.get_default ();

            app_settings.bind ("open-last-folder-uri", file_chooser_preferences, "open-last-folder-uri", DEFAULT);
            app_settings.bind ("open-viewmode", file_chooser_preferences, "open-viewmode", DEFAULT);
            app_settings.bind ("save-last-folder-uri", file_chooser_preferences, "save-last-folder-uri", DEFAULT);
            app_settings.bind ("save-viewmode", file_chooser_preferences, "save-viewmode", DEFAULT);
        }
    }
}
