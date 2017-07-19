/***
    Copyright (c) 2013 Julián Unrrein <junrrein@gmail.com>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.
***/

public const string APP_NAME = "pantheon-files";
public const string TERMINAL_NAME = "pantheon-terminal";

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

public static int main (string[] args) {
    /* Initiliaze gettext support */
    Intl.setlocale (LocaleCategory.ALL, "");
    Intl.textdomain (Config.GETTEXT_PACKAGE);

    Environment.set_application_name (APP_NAME);
    Environment.set_prgname (APP_NAME);

    Bus.own_name (BusType.SESSION, "org.freedesktop.FileManager1", BusNameOwnerFlags.REPLACE,
                  on_fm1_bus_aquired,
                  () => {},
                  on_name_lost);


    var application = new Marlin.Application ();

    return application.run (args);
}
