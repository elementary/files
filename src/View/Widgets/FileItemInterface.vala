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

public interface Files.FileItemInterface : Gtk.Widget {
    public abstract bool selected { get; set; default = false; }
    public abstract bool drop_pending { get; set; default = false; }
    public abstract bool cut_pending { get; set; default = false; }
    public abstract Files.File? file { get; set; default = null; }
    public abstract uint pos { get; set; default = 0; }

    public abstract void bind_file (Files.File? file);
    public virtual void rebind () {bind_file (this.file);}
}
