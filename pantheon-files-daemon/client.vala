/***
    Copyright (c) 2015-2017 elementary LLC (http://launchpad.net/elementary)

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.
***/

[DBus (name = "io.elementary.files.db")]
interface Demo : Object {
    public abstract bool    showTable   (string table)  throws IOError;
    public abstract int     getColor    (string uri)    throws IOError;
    public abstract bool    setColor    (string uri, int color)     throws IOError;
    public abstract bool    deleteEntry (string uri)    throws IOError;
    public abstract bool    clearDB     ()              throws IOError;
}

void main () {
    try {
        Demo demo = Bus.get_proxy_sync (BusType.SESSION, "io.elementary.files.db",
                                        "/io/elementary/files/db");

        demo.showTable ("tags");

    } catch (IOError e) {
        stderr.printf ("%s\n", e.message);
    }
}
