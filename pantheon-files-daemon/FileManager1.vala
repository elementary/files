/***
    Copyright (c) 2017 elementary LLC.

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
    public void show_items (string[] uris, string startup_id)  throws DBusError, IOError {
        open_items_and_folders (uris, startup_id);
    }

    [DBus (name = "ShowItemProperties")]
    public void show_item_properties (string[] uris, string startup_id)  throws DBusError, IOError {
        var msg = "ShowItemProperties method not currently supported by Files.";
        throw new DBusError.NOT_SUPPORTED (msg);
    }

    private void open_items_and_folders (string[] uris, string startup_id) throws DBusError, IOError {
        /* The pantheon-files app will open folder uris as view, other items will cause the parent folder
         * to open and the item be selected.  Each view will open in a separate tab in one window */
 
        AppInfo? pf_app_info = null;
        string cmd = "pantheon-files -t";

        foreach (string s in uris) {
            s = s.replace ("'", "%27").replace ("%", "%%");
            cmd += (" \'" + PF.FileUtils.sanitize_path (s, null, false) + "\'");
        }

        try {
            pf_app_info = AppInfo.create_from_commandline (cmd,
                                                           null,
                                                           AppInfoCreateFlags.NONE);
        } catch (Error e) {
            var msg = "Unable to open item or folder with command %s. %s".printf (cmd, e.message);
            throw new IOError.FAILED (msg);
        }

        if (pf_app_info != null) {
            try {
                pf_app_info.launch (null, null);
            } catch (Error e) {
                var msg = "Unable to open item or folder with command %s. %s".printf (cmd, e.message);
                throw new IOError.FAILED (msg);
            }
        }
    }
}
