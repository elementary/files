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

    private PF.AppInterface app;

    public FileManager1 (PF.AppInterface? _app = null) {
        if (_app == null) {
            app = Marlin.Application.@get ();
        } else {
            app = _app;
        }
    }

    private void open_items_and_folders (string[] uris, string startup_id) throws DBusError, IOError {
        /* The pantheon-files app will open folder uris as view, other items will cause the parent folder
         * to open and the item be selected.  Each view will open in a separate tab in one window */

        /* Startup notification id currently ignored */

        GLib.File[] files = null;

        foreach (string s in uris) {
            var file = PF.FileUtils.get_file_for_path (s);

            if (file != null) {
                files += file;
            } else {
                warning ("Invalid uri %s received by FileManager1 interface", s);
            }
        }

        app.open_tabs (files);
    }
}
