/***
    Copyright (c) 2015-2022 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation, Inc.,.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Lucas Baudin <xapantu@gmail.com>
              Jeremy Wootten <jeremy@elementaryos.org>
***/

public interface Files.SlotInterface : Gtk.Widget {
    public abstract Directory? directory { get; set; }
    public abstract ViewMode view_mode { get; construct; }
    public signal void selection_changed (List<Files.File> selected_files);

    public abstract GLib.List<Files.File> get_selected_files ();
    public virtual bool set_all_selected (bool all_selected) { return false; }
}
