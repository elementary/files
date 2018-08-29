/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

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
    /* Interface implemented by SearchResults */
    public interface Searchable : Gtk.Widget {
        public signal void file_selected (GLib.File file);
        public signal void file_activated (GLib.File file);
        public signal void cursor_changed (GLib.File? file);
        public signal void first_match_found (GLib.File? file);
        public signal void exit (bool exit_navigate = true);

        public abstract void cancel ();
        public abstract void search (string txt, GLib.File search_location);
        public abstract bool has_popped_up ();
    }
}
