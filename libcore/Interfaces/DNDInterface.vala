/*
* Copyright 2022 elementary, Inc. (https://elementary.io)
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
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

public interface Files.DNDInterface : Gtk.Widget {
    public abstract List<Files.File> get_file_list_for_drag (double x, double y, out Gdk.Paintable? paintable);
    public abstract Files.File get_target_file_for_drop (double x, double y);
    public abstract bool can_accept_drops ();
    public abstract bool can_start_drags ();
}
