/*
* Copyright 2026 elementary, Inc. (https://elementary.io)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Jeremy Wootten <jeremywootten@gmail.com>
*/

/* Interface to be implemented by toplevel of both app (MainWindow) and
* filechooser (FilechooserDialog)
*/

public interface Files.SlotToplevelInterface : Gtk.Widget {
    public signal void free_space_change ();

    public abstract unowned AbstractSlot? get_view (); // Should return current slot
    public abstract AbstractSlot? prepare_reload ();
    public abstract void refresh (); // Reloads the current slot
    public abstract bool can_bookmark_uri (string uri);
    public abstract void change_state_show_hidden (SimpleAction action);
    public abstract void bookmark_uri (string uri, string custom_name = "");
    public abstract Gtk.Application? get_files_application ();
    public abstract Gtk.Window? get_gtk_window ();
    public abstract void go_up ();
    public abstract void uri_path_change_request (
        string uri,
        Files.OpenFlag flag = DEFAULT
    );
}
