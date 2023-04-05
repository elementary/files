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

public class Files.DirectoryNotFound : Granite.Placeholder {
    public GLib.File location { get; construct; }
    public DirectoryNotFound (string uri) {
        Object (
            title: _("This Folder Does Not Exist"),
            location: GLib.File.new_for_uri (uri)
        );

        description = _("The folder \"%s\" can't be found.").printf (location.get_basename ());
        var create_button = append_button (
            new ThemedIcon ("edit-add"),
            _("Create"),
            _("Create the folder \"%s\"").printf (location.get_basename ())
        );

        create_button.clicked.connect (() => {
            try {
                location.make_directory_with_parents (null);
                activate_action ("win.path-change-request", "(su)", location.get_uri (), OpenFlag.DEFAULT);
            } catch (Error e) {
                var dialog = new Granite.MessageDialog (
                    _("Failed to create the folder"),
                    e.message,
                    new ThemedIcon ("dialog-error"),
                    Gtk.ButtonsType.CLOSE
                );

                dialog.present ();
                dialog.destroy ();
            }
        });
    }
}
