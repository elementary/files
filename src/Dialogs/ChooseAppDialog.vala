/*
* Copyright (c) 2015-2018 elementary LLC. <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU Lesser General Public
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
* Boston, MA 02110-1335 USA.
*
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

class PF.ChooseAppDialog : Object {
    Gtk.AppChooserDialog dialog;
    Gtk.CheckButton check_default;

    public GLib.File file_to_open { get; construct; }
    public Gtk.Window parent { get; construct; }

    public ChooseAppDialog (Gtk.Window? parent, GLib.File file_to_open) {
        Object (parent: parent, file_to_open: file_to_open);
    }

    construct {
        dialog = new Gtk.AppChooserDialog (parent,
                                             Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                             file_to_open) {
            deletable = false
        };

        var app_chooser = dialog.get_widget () as Gtk.AppChooserWidget;
        app_chooser.show_recommended = true;

        check_default = new Gtk.CheckButton.with_label (_("Set as default")) {
            active = true,
            margin_start = 12,
            margin_bottom = 6
        };

        check_default.show ();

        dialog.get_content_area ().add (check_default);

        dialog.show ();
    }

    public AppInfo? get_app_info () {
        AppInfo? app = null;
        int response = dialog.run ();

        if (response == Gtk.ResponseType.OK) {
            app = dialog.get_app_info ();
            if (check_default.get_active ()) {
                try {
                    var info = file_to_open.query_info (FileAttribute.STANDARD_CONTENT_TYPE,
                                                        FileQueryInfoFlags.NONE, null);

                    app.set_as_default_for_type (info.get_attribute_string (GLib.FileAttribute.STANDARD_CONTENT_TYPE));
                }
                catch (GLib.Error error) {
                    critical ("Could not set as default: %s", error.message);
                }
            }
        }
        dialog.destroy ();
        return app;
    }
}
