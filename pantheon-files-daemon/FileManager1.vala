/***
    Copyright (c) 2017 - 2018 elementary LLC.

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors: Jeremy Wootten <jeremy@elementaryos.org>
***/

[DBus (name = "org.freedesktop.FileManager1")]
public class FileManager1 : Object {

    [DBus (name = "ShowFolders")]
    public void show_folders (string[] uris, string startup_id) throws DBusError, IOError {
        open_items_and_folders (uris, startup_id);
    }

    [DBus (name = "ShowItems")]
    public void show_items (string[] uris, string startup_id) throws DBusError, IOError {
        open_items_and_folders (uris, startup_id);
    }

    [DBus (name = "ShowItemProperties")]
    public void show_item_properties (string[] uris, string startup_id) throws DBusError, IOError {
        var msg = "ShowItemProperties method not currently supported by Files.";
        throw new DBusError.NOT_SUPPORTED (msg);
    }

    private void open_items_and_folders (string[] uris, string startup_id) throws DBusError, IOError {
        /* The io.elementary.files app will open folder uris as view, other items will cause the parent folder
         * to open and the item be selected.  Each view will open in a separate tab in one window */

        StringBuilder sb = new StringBuilder ("io.elementary.files4 -t");
        foreach (string s in uris) {
                sb.append (" ");
                sb.append (FileManager1.prepare_uri_for_appinfo_create (s));
        }

        try {
            var pf_app_info = AppInfo.create_from_commandline (sb.str,
                                                           null,
                                                           AppInfoCreateFlags.NONE);
            if (pf_app_info != null) {
                pf_app_info.launch (null, null);
            }
        } catch (Error e) {
            var msg = "Unable to open item or folder with command %s: %s".printf (sb.str, e.message);
            throw new IOError.FAILED (msg);
        }
    }

    static string reserved_chars = (GLib.Uri.RESERVED_CHARS_GENERIC_DELIMITERS +
                                    GLib.Uri.RESERVED_CHARS_SUBCOMPONENT_DELIMITERS)
                                   .replace ("#", "")
                                   .replace ("*", "");

    private static string prepare_uri_for_appinfo_create (string uri, bool allow_utf8 = true) {
        string? escaped_uri = Uri.escape_string ((Uri.unescape_string (uri) ?? uri), reserved_chars, allow_utf8);
        return (escaped_uri ?? "").replace ("%", "%%");
    }
}
