/***
    Copyright (C) 2010 Jordi Puigdellívol <jordi@gloobus.net>
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

    Authors: Jordi Puigdellívol <jordi@gloobus.net>
             ammonkey <am.monkeyd@gmail.com>
             Jeremy Wootten <jeremy@elementaryos.org>
***/

    void on_bus_aquired (DBusConnection conn, string n) {
        try {
            string name = "/io/elementary/files4/db";
            var object = new MarlinTags ();
            conn.register_object (name, object);
            debug ("MarlinTags object registered with dbus connection name %s", name);
        } catch (IOError e) {
            error ("Could not register MarlinTags service");
        }
    }

    void on_fm1_bus_aquired (DBusConnection conn, string n) {
        try {
            string name = "/org/freedesktop/FileManager1";
            var object = new FileManager1 ();
            conn.register_object (name, object);
            debug ("FileManager1 object registered with dbus connection name %s", name);
        } catch (IOError e) {
            error ("Could not register FileManager1 service");
        }
    }

    // Exit C function to quit the loop
    extern void exit (int exit_code);

    void on_name_lost (DBusConnection connection, string name) {
        critical ("Name %s was not acquired", name);
        exit (-1);
    }

    void main () {
        Bus.own_name (BusType.SESSION, "io.elementary.files4.db", BusNameOwnerFlags.NONE,
                      on_bus_aquired,
                      () => {},
                      on_name_lost);

        Bus.own_name (BusType.SESSION, "org.freedesktop.FileManager1", BusNameOwnerFlags.REPLACE,
                      on_fm1_bus_aquired,
                      () => {},
                      on_name_lost);

        new MainLoop ().run ();
    }
