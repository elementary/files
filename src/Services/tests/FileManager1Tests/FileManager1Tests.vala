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
}

FileManager1Proxy? fm1_interface = null;
GLib.Cancellable? cancellable = null;
GLib.MainLoop loop;

/*** Tests ***/
void add_filemanager1_tests () {
    Test.add_func ("/FileManager1/commandline1", commandline_test1);
    Test.add_func ("/FileManager1/commandline2", commandline_test2);
}

void commandline_test1 () {
    string uri = """'New Folder'""";
    if (fm1_interface != null) {
        assert (filemanager1_sanitize_commandline_test (uri));
    } else {
        assert (PF.FileUtils.sanitize_path_for_appinfo_from_commandline (uri) != null);
    }
}

void commandline_test2 () {
    /* Should fail because contains more than one line */
    string uri = """if [ $number = "1" ]; then
                    echo "Number equals 1"
                    else echo "Number does not equal 1"
                    fi""";
    if (fm1_interface != null) {
        assert (!filemanager1_sanitize_commandline_test (uri));
    } else {
        assert (PF.FileUtils.sanitize_path_for_appinfo_from_commandline (uri) == null);
    }
}

bool filemanager1_sanitize_commandline_test (string uri) {
        var uris = new string[1];
        debug ("trying %s", uri);
        debug ("sanitized: %s", PF.FileUtils.sanitize_path_for_appinfo_from_commandline (uri));
        uris[0] = uri;

        assert (fm1_interface != null);
        assert (fm1_interface is FileManager1Proxy);

        try {
            fm1_interface.show_folders (uris, "");
        } catch (IOError ioe) {
            message ("io error after show folders for uri %s - %s", uri, ioe.message);
            return false;
        } catch (DBusError dbe) {
            message ("dbus error after show folders for uri %s - %s", uri, dbe.message);
            return false;
        }

        return true;
}

/*** DBus functions ***/

void on_fm1_bus_aquired (DBusConnection conn, string n) {
    try {
        string name = "/org/freedesktop/FileManager1";
        var object = new FileManager1 ();
        conn.register_object (name, object);
        debug ("FileManager1 object registered with dbus connection name %s", name);

        fm1_interface = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.FileManager1",
                                     "/org/freedesktop/FileManager1", 0, cancellable);
    } catch (IOError e) {
        message ("Could not register FileManager1 service %s", e.message);
    }
}


void on_name_lost (DBusConnection connection, string name) {
    message ("Name %s was not acquired", name);
    fm1_interface = null;
}

uint timeout_id = 0;
int main (string[] args) {
    var context = GLib.MainContext.@default ();
    cancellable = new Cancellable ();

    var t_source = new TimeoutSource.seconds (1);
    t_source.set_callback (() => {
        cancellable.cancel ();
        timeout_id = 0;
        loop.quit ();
        return false;
    });

    t_source.attach (context);

    loop = new GLib.MainLoop (context, true);


    /* This starts the daemon if not already running (may stall on Travis CI) */
    var id = Bus.own_name (BusType.SESSION, "org.freedesktop.FileManager1", BusNameOwnerFlags.REPLACE,
                  (conn, n) => {on_fm1_bus_aquired (conn, n); loop.quit ();},
                  () => {},
                  (conn, n) => {on_name_lost (conn, n); loop.quit ();}
            );

    /* Wait until bus name acquired, FileManager1 object registered and proxy obtained
     * or timed out.
     */
    loop.run ();

    if (fm1_interface == null) {
        message ("Timed out trying set up dbus");
    } else {
        Source.remove (t_source.get_id ());
    }

    Test.init (ref args);

    add_filemanager1_tests ();

    return Test.run ();
}
