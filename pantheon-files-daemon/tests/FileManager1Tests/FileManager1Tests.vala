/*
* Copyright (c) 2017 elementary LLC
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA 02111-1307, USA.
*
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

[DBus (name = "org.freedesktop.FileManager1")]
interface FileManager1Proxy : Object {
    public abstract void show_folders (string[] uris, string startup_id) throws DBusError, IOError;
    public abstract void show_items (string[] uris, string startup_id) throws DBusError, IOError;
}

FileManager1Proxy fm1_interface;

/*** Tests ***/
void add_filemanager1_tests () {
    Test.add_func ("/FileManager1/sanitize_commandline", filemanager1_sanitize_commandline_test);
}

void filemanager1_sanitize_commandline_test () {
message ("in filemanager sanitize test");
    assert (true);
}

/*** DBus functions ***/

void on_fm1_bus_aquired (DBusConnection conn, string n) {
    try {
        string name = "/org/freedesktop/FileManager1";
        var object = new FileManager1 ();
        conn.register_object (name, object);
        debug ("FileManager1 object registered with dbus connection name %s", name);
    } catch (IOError e) {
        error ("Could not register FileManager1 service");
    }

    try {
        fm1_interface = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.FileManager1",
                                     "/org/freedesktop/FileManager1");
    } catch (IOError e) {
        stderr.printf ("%s\n", e.message);
    }
}

// Exit C function to quit the loop
extern void exit (int exit_code);

void on_name_lost (DBusConnection connection, string name) {
    critical ("Name %s was not acquired", name);
    exit (-1);
}

int main (string[] args) {
    Bus.own_name (BusType.SESSION, "org.freedesktop.FileManager1", BusNameOwnerFlags.REPLACE,
                  on_fm1_bus_aquired,
                  () => {},
                  on_name_lost);


    Test.init (ref args);


    add_filemanager1_tests ();

    return Test.run ();
}
