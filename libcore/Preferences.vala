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
        /* First element set to null in order that the text renderer background is not set */
        public const string?[] TAGS_COLORS = {
            null, "#64baff", "#43d6b5", "#9bdb4d", "#ffe16b", "#ffc27d", "#ff8c82", "#f4679d", "#cd9ef7", "#a3907c", "#95a3ab", null
        };

        public bool show_hidden_files {get; set; default = false;}
        public bool show_remote_thumbnails {set; get; default = true;}
        public bool show_local_thumbnails {set; get; default = false;}
        public bool singleclick_select {set; get; default = false;}
        public bool confirm_trash {set; get; default = true;}
        public bool force_icon_size {set; get; default = true;}
        public bool sort_directories_first { get; set; default = true; }
        public bool remember_history { get; set; default = true; }

        public string date_format {set; get; default = "iso";}
        public string clock_format {set; get; default = "24h";}

        public static Preferences get_default () {
            if (preferences == null) {
                preferences = new Preferences ();
            }

            return preferences;
        }
    }
}
