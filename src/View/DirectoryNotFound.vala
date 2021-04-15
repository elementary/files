/***
    Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>

    Marlin is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of the
    License, or (at your option) any later version.

    Marlin is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this program; see the file COPYING.  If not,
    write to the Free Software Foundation, Inc.,51 Franklin Street,
    Fifth Floor, Boston, MA 02110-1335 USA.

***/

namespace Files.View {
    public class DirectoryNotFound : Files.View.Welcome {
        public Directory dir_saved;
        public ViewContainer ctab;

        public DirectoryNotFound (Directory dir, ViewContainer tab) {
            base (_("This Folder Does Not Exist"),
                  _("The folder \"%s\" can't be found.").printf (dir.location.get_basename ()));

            append ("folder-new", _("Create"), _("Create the folder \"%s\"").printf (dir.location.get_basename ()));

            dir_saved = dir;
            ctab = tab;

            this.activated.connect ((index) => {
                bool success = false;

                try {
                    success = dir.location.make_directory_with_parents (null);
                } catch (Error e) {
                    if (e is IOError.EXISTS) {
                        success = true;
                    } else {
                        var dialog = new Granite.MessageDialog (
                            _("Failed to create the folder"),
                            e.message,
                            new ThemedIcon ("dialog-error"),
                            Gtk.ButtonsType.CLOSE
                        );

                        dialog.run ();
                        dialog.destroy ();
                    }
                }

                if (success) {
                    ctab.reload ();
                }
            });

            show_all ();
        }
    }
}
