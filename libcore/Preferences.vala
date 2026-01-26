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

    public static Preferences? preferences = null;


    public class Preferences : Object {
        private static Settings app_settings;
        /* First element set to null in order that the text renderer background is not set */
        public const string?[] TAGS_COLORS = {
            null, "#64baff", "#43d6b5", "#9bdb4d", "#ffe16b", "#ffc27d", "#ff8c82", "#f4679d", "#cd9ef7", "#a3907c", "#95a3ab", null
        };

        public bool show_hidden_files {get; set; default = false;}
        public bool show_remote_thumbnails {set; get; default = true;}
        public bool show_local_thumbnails {set; get; default = true;}
        public bool show_file_preview {set; get; default = true;}
        public bool singleclick_select {set; get; default = false;}
        public bool confirm_trash {set; get; default = true;}
        public bool force_icon_size {set; get; default = true;}
        public bool sort_directories_first { get; set; default = true; }
        public bool remember_history { get; set; default = true; }
        public bool restore_tabs { get; set; default = true; }
        public DateFormatMode date_format {set; get; default = DateFormatMode.ISO;}
        public string clock_format {set; get; default = "24h";}
        public int active_tab_position {set; get; default = 0;}

        public static Preferences get_default () {
            if (preferences == null) {
                preferences = new Preferences ();
            }

            return preferences;
        }

        public static void set_up_preferences (Settings settings) {
            Files.Preferences.app_settings = settings;
            var prefs = Files.Preferences.get_default ();
            if (app_settings.settings_schema.has_key ("singleclick-select")) {
                app_settings.bind ("singleclick-select", prefs, "singleclick-select", DEFAULT);
            }

            app_settings.bind ("show-hiddenfiles", prefs, "show-hidden-files", DEFAULT);
            app_settings.bind ("show-remote-thumbnails", prefs, "show-remote-thumbnails", DEFAULT);
            app_settings.bind ("show-local-thumbnails", prefs, "show-local-thumbnails", DEFAULT);
            app_settings.bind ("show-file-preview", prefs, "show-file-preview", DEFAULT);
            app_settings.bind ("date-format", prefs, "date-format", DEFAULT);
            app_settings.bind ("restore-tabs", prefs, "restore-tabs", DEFAULT);
            app_settings.bind ("active-tab-position", prefs, "active-tab-position", DEFAULT);
        }

        //We cannot bind to variant type setting so have to provide getter and setter functions

        // takes variant of type "a(uss)" and saves to app settings.
        public static void save_tab_info (Variant tab_info_list) {
            app_settings.set_value ("tab-info-list", tab_info_list);
        }

        //returns variant of type "a(ss)"
        public static Variant get_tab_info () {
            return Files.Preferences.app_settings.get_value ("tab-info-list");
        }
    }
}
