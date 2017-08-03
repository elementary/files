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

FileManager1Proxy? proxy = null;
GLib.Cancellable? cancellable = null;
GLib.MainLoop loop;

/*** Tests ***/
void add_filemanager1_tests () {
    Test.add_func ("/FileManager1/initial_tabs", initial_tabs_test);
    Test.add_func ("/FileManager1/commandline1", commandline_test1);
    Test.add_func ("/FileManager1/commandline2", commandline_test2);
}

/** This checks Files is not already running when test started **/
void initial_tabs_test () {
    int tabs = 0;
    assert (proxy != null);

    try {
        tabs = proxy.get_opened_folders ().length;
        assert (tabs == 0);
    } catch (IOError ioe) {
        message ("io error after get_opened_folders - %s", ioe.message);
        assert (false);
    } catch (DBusError dbe) {
        message ("dbus error after get_opened_folders - %s", dbe.message);
        assert (false);
    }
}

void commandline_test1 () {
    string uri = """'New Folder'""";
    int opened_before = proxy.get_opened_folders ().length;
    assert (filemanager1_interface_test (uri));
    int opened_after = proxy.get_opened_folders ().length;
    assert (opened_after - opened_before == 1);
}

void commandline_test2 () {
    /* Should fail because contains more than one line */
    string uri = """if [ $number = "1" ]; then
                    echo "Number equals 1"
                    else echo "Number does not equal 1"
                    fi""";

    int opened_before = proxy.get_opened_folders ().length;
    assert (!filemanager1_interface_test (uri));
    int opened_after = proxy.get_opened_folders ().length;
    assert (opened_after - opened_before == 0);
}

bool filemanager1_interface_test (string uri) {
        var uris = new string[0];
        debug ("trying %s", uri);
        uris += uri;

        try {
            proxy.show_folders (uris, "");
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

        var object = new FileManager1 (null);
        conn.register_object (name, object);
        debug ("FileManager1 object registered with dbus connection name %s", name);

        proxy = Bus.get_proxy_sync (BusType.SESSION, "org.freedesktop.FileManager1",
                                     "/org/freedesktop/FileManager1", 0, cancellable);
    } catch (IOError e) {
        message ("Could not register FileManager1 service %s", e.message);
    }
}


void on_name_lost (DBusConnection connection, string name) {
    message ("Name %s was not acquired", name);
    proxy = null;
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

    if (proxy == null) {
        message ("Timed out trying set up dbus");
        proxy = new FileManager1 (new DummyApp ()) as FileManager1Proxy;
    } else {
        Source.remove (t_source.get_id ());
    }

    Test.init (ref args);

    add_filemanager1_tests ();

    return Test.run ();
}

private class DummyApp : Object, PF.AppInterface {

    GLib.List<GOF.Directory.Async> dirs = null;

    public int open_uris (string[] uris, Marlin.OpenFlag flag) {
        int valid = 0;

        foreach (string uri in uris) {
            string path = PF.FileUtils.sanitize_path (uri, null);
            if (path.length > 0) {
                var file = File.new_for_uri (PF.FileUtils.escape_uri (path));
                if (file != null) {
                    dirs.append (GOF.Directory.Async.from_gfile (file)); /* Unlikely to be many */
                    valid++;
                }
            }
        }

        return valid;
    }

    public string[] get_active_window_open_uris () {
        var uris = new string[0];

        foreach (GOF.Directory.Async dir in dirs) {
            uris += dir.file.uri;
        }

        return uris;
    }
}
