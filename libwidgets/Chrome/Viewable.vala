/***
    Copyright (C) 2015 elementary Developers

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


public interface Marlin.Viewable : Gtk.ApplicationWindow {
    public abstract new void grab_focus ();
    public abstract void file_path_change_request (GLib.File file);
    public abstract void focus_location_request (GLib.File? loc,
                                                 bool select_in_current_only = false,
                                                 bool unselect_others = false);
    public abstract void add_tab (GLib.File location = GLib.File.new_for_commandline_arg (GLib.Environment.get_home_dir ()),
                                  Marlin.ViewMode mode = Marlin.ViewMode.PREFERRED);
    public abstract GLib.File get_current_location ();
    public abstract bool get_frozen ();
    public abstract void refresh_view ();
    public abstract void go_to_parent ();
}
