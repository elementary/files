/*
 * ViewWindowInterface.vala
 * 
 * Copyright 2015 jeremy <jeremy@jeremy-W54-55SU1-SUW>
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 * 
 * 
 */


public interface Marlin.Viewable : Gtk.ApplicationWindow {
    public abstract new void grab_focus ();
    public abstract void file_path_change_request (GLib.File file);
    public abstract void focus_location_request (GLib.File loc);
    public abstract void add_tab (GLib.File location = GLib.File.new_for_commandline_arg (GLib.Environment.get_home_dir ()),
                                  Marlin.ViewMode mode = Marlin.ViewMode.PREFERRED);
    public abstract GLib.File get_current_location ();
    public abstract bool get_frozen ();
    public abstract void refresh_view ();
    public abstract void go_to_parent ();
}
