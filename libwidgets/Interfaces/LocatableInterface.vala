/***
    Copyright 2015-2020 elementary, Inc <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/
namespace Marlin.View.Chrome {
    /* Interface implemented by BasicLocationBar and LocationBar */
    public interface Locatable : Gtk.Box {
        public signal void path_change_request (string path, Marlin.OpenFlag flag = Marlin.OpenFlag.DEFAULT);

        public abstract void set_display_path (string path);
        public abstract string get_display_path ();
        public abstract bool set_focussed ();
    }
}
