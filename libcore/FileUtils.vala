/***
    Copyright (C) 2015 Elementary Developers

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/
namespace PF.FileUtils {
        const string reserved_chars = (GLib.Uri.RESERVED_CHARS_GENERIC_DELIMITERS + GLib.Uri.RESERVED_CHARS_SUBCOMPONENT_DELIMITERS + " ");

    public string? escape_uri (string uri, bool allow_utf8 = true) {
        string rc = reserved_chars.replace("#", "").replace ("*","");
        return Uri.escape_string ((Uri.unescape_string (uri) ?? uri), rc , allow_utf8);
    }
}
