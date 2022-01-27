 /* Copyright (C) 2019-2022  elementary LLC. <https://elementary.io>
 *
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 *  Authors:
 *  Vartan Belavejian <https://github.com/VartanBelavejian>
 *  Jeremy Wootten <jeremywootten@gmail.com>
 *
*/

public class Files.RenamerListBox : Gtk.ListBox {
    public class RenamerListRow : Gtk.ListBoxRow {
        public string old_name { get; construct; }
        public string new_name { get; set construct; }
        public Files.File file { get; construct; }

        public RenamerListRow (Files.File file) {
            Object (
                file: file,
                old_name: file.basename
            );
        }

        construct {
            can_focus = false;
            var oldname_label = new Gtk.Label (old_name) {
                xalign = 0.0f,
                width_chars = 24
            };


            var newname_label = new Gtk.Label (new_name) {
                xalign = 0.0f,
                width_chars = 24
            };

            var arrow_image = new Gtk.Image.from_icon_name ("go-next-symbolic", Gtk.IconSize.MENU);

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            box.pack_start (oldname_label);
            box.pack_end (newname_label);
            box.set_center_widget (arrow_image); // Should not pack center widget
            add (box);
            show_all ();

            notify["new-name"].connect (() => {
                newname_label.label = new_name;
            });
        }
    }

    construct {
        vexpand = true;
        can_focus = false;
        selection_mode = Gtk.SelectionMode.NONE;
        show_all ();
    }

    public RenamerListRow add_file (Files.File file) {
        var row = new RenamerListRow (file);
        add (row);
        return row;
    }
}
