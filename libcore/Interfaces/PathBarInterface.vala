/***
    Copyright (c) 2015-2022 elementary LLC <https://elementary.io>

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
/* Interface implemented by BasicPathBar and PathBar */
public interface Files.PathBarInterface : Gtk.Widget {
    // public signal void path_change_request (string path, Files.OpenFlag flag = Files.OpenFlag.DEFAULT);
    /* Not used by BasicPathBar? */
    public abstract string display_uri { get; set; }
    public abstract Files.PathBarMode mode { get; set; default = PathBarMode.CRUMBS; }
    public signal void focus_file_request (GLib.File? file);
    public signal void reload_request ();
    // public signal void escape ();

    public virtual void search (string term) {}
    // public virtual void enter_navigate_mode () {} //TODO Improve name
    public virtual void cancel () {}
    // public abstract void set_display_uri (string uri);
    // public abstract string get_display_uri ();
    // public abstract bool set_focussed ();
}
