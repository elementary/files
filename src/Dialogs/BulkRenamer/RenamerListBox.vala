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

public class Files.RenamerListBox : Gtk.Box {
    public class RenamerListRow : Gtk.ListBoxRow {
        public string old_name { get; construct; }
        public string new_name { get; set construct; }
        public Files.File file { get; construct; }
        public string extension { get; set; default = ""; }
        public RenameStatus status { get; set; default = RenameStatus.VALID; }

        public RenamerListRow (Files.File file) {
            Object (
                file: file,
                old_name: file.basename
            );
        }

        construct {
            can_focus = false;
            var oldname_label = new Gtk.Label (old_name) {
                xalign = 0.0f
            };


            var newname_label = new Gtk.Label (new_name) {
                xalign = 0.0f
            };

            var arrow_image = new Gtk.Image.from_icon_name ("go-next-symbolic") {
                icon_size = Gtk.IconSize.NORMAL
            };

            var status_image = new Gtk.Image () {
                halign = Gtk.Align.END
            };

            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            // box.pack_start (oldname_label);
            // box.pack_end (status_image);
            // box.pack_end (newname_label);
            // box.set_center_widget (arrow_image); // Should not pack center widget
            set_child (box);
            // show_all ();

            notify["new-name"].connect (() => {
                newname_label.label = new_name;
            });

            notify["status"].connect (() => {
                switch (status) {
                    case RenameStatus.IGNORED:
                        status_image.icon_name = "radio-mixed-symbolic";
                        status_image.tooltip_markup = _("Ignored") + "\n" + Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("Name is not changed"));
                        break;
                    case RenameStatus.INVALID:
                        status_image.icon_name = "process-error-symbolic";
                        status_image.tooltip_markup = _("Cannot rename") + "\n" + Granite.TOOLTIP_SECONDARY_TEXT_MARKUP.printf (_("Name is invalid or already exists"));
                        break;
                    case RenameStatus.VALID:
                        status_image.icon_name = "process-completed-symbolic";
                        status_image.tooltip_text = _("Will be renamed");
                        break;
                    default:
                        break;
                }
            });
        }
    }

    /* RenamerListBox */
    public Gtk.ListBox list_box { get; construct; }
    public SortBy sortby { get; set; default = SortBy.NAME; }
    construct {
        list_box = new Gtk.ListBox () {
            vexpand = true,
            can_focus = false,
            selection_mode = Gtk.SelectionMode.NONE
        };
        list_box.set_sort_func (sort_func);
        list_box.invalidate_sort ();
        list_box.set_parent (this); 
        // show_all ();

        notify["sortby"].connect (list_box.invalidate_sort);
    }

    public RenamerListRow add_file (Files.File file) {
        var row = new RenamerListRow (file);
        append (row);
        return row;
    }

    private int sort_func (Gtk.ListBoxRow row1, Gtk.ListBoxRow row2) {
        var file1 = ((RenamerListRow)row1).file;
        var file2 = ((RenamerListRow)row2).file;
        switch (sortby) {
            case SortBy.CREATED:
                return file1.compare_files_by_created (file2);
            case SortBy.MODIFIED:
                return file1.compare_files_by_time (file2);
            case SortBy.SIZE:
                return file1.compare_files_by_size (file2);
            default:
                return file1.compare_by_display_name (file2);
        }
    }
}
