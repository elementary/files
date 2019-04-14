/*-
 * Copyright (c) 2019 elementary, Inc. (https://elementary.io)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

void on_file_chooser_bus_acquired (DBusConnection conn, string n) {
    try {
        string name = "/org/freedesktop/portal/desktop";
        var object = new FileChooser (conn);
        conn.register_object (name, object);
        debug ("FileChooser object registered with dbus connection name %s", name);
    } catch (IOError e) {
        error ("Could not register FileChooser service");
    }   
}

extern void exit (int exit_code);

void on_name_lost (DBusConnection connection, string name) {
    critical ("Name %s was not acquired", name);
    exit (-1);
}


void main (string[] args) {
    Gtk.init (ref args);

    Bus.own_name (BusType.SESSION, "org.freedesktop.portal.Desktop", BusNameOwnerFlags.REPLACE,
        on_file_chooser_bus_acquired,
        () => {},
        on_name_lost);

    Gtk.main ();
}
