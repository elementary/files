/*
*    Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
*    Copyright 2023 elementary, Inc. (https://elementary.io)
*    SPDX-License-Identifier: LGPL-3.0-or-later
*/
public class Files.DirectoryNotFound : Gtk.Bin {
    public Directory dir { get; construct set; }
    public View.ViewContainer ctab { get; construct set; }

    public DirectoryNotFound (Directory _dir, View.ViewContainer _ctab) {
        Object (
            dir: _dir,
            ctab: _ctab
        );
    }

    construct {
        var placeholder = new Files.Placeholder (_("This Folder Does Not Exist")) {
            description = _("The folder \"%s\" can't be found.").printf (
                dir.location.get_basename ()
            )
        };

        var create_button = placeholder.append_button (
            new ThemedIcon ("folder-new"),
            _("Create"),
            _("Create the folder \"%s\"").printf (dir.location.get_basename ())
        );

        create_button.clicked.connect ((index) => {
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

        add (placeholder);
        show_all ();
    }
}
