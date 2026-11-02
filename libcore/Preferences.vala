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
    public enum TagColor {
        NONE,
        BLUE,
        MINT,
        GREEN,
        YELLOW,
        ORANGE,
        RED,
        PINK,
        PURPLE,
        BROWN,
        SLATE,
        LATTE,
        LAST_COLOR;

        /* We have to hard code the colors while we are using renderers - cannot use css */
        public string? get_rgb_string () {
            switch (this) {
                case NONE:
                    return null;
                case BLUE:
                    return "#64baff"; //(Elementary Blueberry 300)
                case MINT:
                    return "#43d6b5"; //(Elementary Mint 300)
                case GREEN:
                    return "#9bdb4d"; //(Elementary Lime 300)
                case YELLOW:
                    return "#ffe16b"; //(Elementary Banana 300)
                case ORANGE:
                    return "#ffc27d"; //(Elementary Orange 100)
                case RED:
                    return "#ff8c82"; //(Elementary Strawberry 100)
                case PINK:
                    return "#f4679d"; //(Elementary Bubblegum 300)
                case PURPLE:
                    return "#cd9ef7"; //(Elementary Grape 300)
                case BROWN:
                    return "#a3907c"; //(Elementary Cocoa 100)
                case SLATE:
                    return "#95a3ab"; //(Elementary Slate 100)
                case LATTE:
                    return "#efdfc4"; //(Elementary Latte 100)
                default:
                    return null;
            }
        }

        // Used for styling buttons in the menu
        public string get_css_name () {
            switch (this) {
                case NONE:
                    return "none";
                case BLUE:
                    return "blue"; //(Elementary Blueberry 300)
                case MINT:
                    return "mint"; //(Elementary Mint 300)
                case GREEN:
                    return "green"; //(Elementary Lime 300)
                case YELLOW:
                    return "yellow"; //(Elementary Banana 300)
                case ORANGE:
                    return "orange"; //(Elementary Orange 100)
                case RED:
                    return "red"; //(Elementary Strawberry 100)
                case PINK:
                    return "pink"; //(Elementary Bubblegum 300)
                case PURPLE:
                    return "purple"; //(Elementary Grape 300)
                case BROWN:
                    return "brown"; //(Elementary Cocoa 100)
                case SLATE:
                    return "slate"; //(Elementary Slate 100)
                case LATTE:
                    return "latte"; //(Elementary Latte 100)
                default:
                    return "none";
            }
        }
    }

    public class Preferences : Object {

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
