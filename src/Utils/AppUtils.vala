/***
    Copyright (c) 2020 elementary Inc <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation, Inc.,.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace Files {
    static Gtk.Window get_active_window () {
        unowned Gtk.Application gtk_app = (Gtk.Application)(GLib.Application.get_default ());
        return gtk_app.get_active_window ();
    }

    static bool is_admin () {
        return Posix.getuid () == 0;
    }
}
