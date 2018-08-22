/*
* Copyright (c) 2016-2018 elementary LLC. <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1335 USA.
*/

namespace Permissions {
    public enum Type {
        USER,
        GROUP,
        OTHER
    }

    public enum Value {
        READ,
        WRITE,
        EXE
    }

    public static bool is_chmod_code (string str) {
        try {
            var regex = new Regex ("^[0-7]{3}$");
            if (regex.match (str)) {
                return true;
            }
        } catch (RegexError e) {
            assert_not_reached ();
        }

        return false;
    }
}
