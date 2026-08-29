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
        /* We have to hard code the colors while we are using renderers - cannot use css */
        public const string?[] TAGS_COLORS = {
            null,       // No color set
            "#64baff",  // CSS name "blue" (Elementary Blueberry 300)
            "#43d6b5",  // CSS name "mint" (Elementary Mint 300)
            "#9bdb4d",  // CSS name "green" (Elementary Lime 300)
            "#ffe16b",  // CSS name "yellow" (Elementary Banana 300)
            "#ffc27d",  // CSS name "orange" (Elementary Orange 100)
            "#ff8c82",  // CSS name "red" (Elementary Strawberry 100)
            "#f4679d",  // CSS name "pink" (Elementary Bubblegum 300)
            "#cd9ef7",  // CSS name "purple" (Elementary Grape 300)
            "#a3907c",  // CSS name "brown" (Elementary Cocoa 100)
            "#95a3ab",  // CSS name "slate" (Elementary Slate 100)
            "#efdfc4",   // CSS name "latte" (Elementary Latte 100)
            null
        };

        public bool show_hidden_files {get; set; default = false;}
        public bool show_file_preview {set; get; default = true;}
        public bool confirm_trash {set; get; default = true;}
        public bool remember_history { get; set; default = true; }

        public DateFormatMode date_format {set; get; default = DateFormatMode.ISO;}
        public string clock_format {set; get; default = "24h";}

        public static Preferences get_default () {
            if (preferences == null) {
                preferences = new Preferences ();
            }

            return preferences;
        }
    }
}
