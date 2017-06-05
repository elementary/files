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

namespace GOF {

    public static Preferences? preferences = null;

    public class Preferences : Object {

        public const string TAGS_COLORS[10] = { null, "#fce94f", "#fcaf3e", "#997666", "#8ae234", "#729fcf", "#ad7fa8", "#ef2929", "#d3d7cf", "#888a85" };

        public bool show_hidden_files {get; set; default=false;}
        public bool show_remote_thumbnails {set; get; default=false;}
        public bool confirm_trash {set; get; default=true;}
        public bool force_icon_size {set; get; default=true;}
        public string date_format {set; get; default="iso";}
        public string clock_format {set; get; default="24h";}

        public static Preferences get_default () {
            if (preferences == null) {
                preferences = new Preferences ();
            }

            return preferences;
        }
    }
}
