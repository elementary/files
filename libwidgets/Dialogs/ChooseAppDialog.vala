/***
    Copyright (C) 2015 elementary Developers

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace PF {
    class ChooseAppDialog {
        Gtk.AppChooserDialog dialog;
        Gtk.CheckButton check_default;
        GLib.File file_to_open;
        public ChooseAppDialog (Gtk.Widget? parent, GLib.File file) {
            file_to_open = file;
            Gtk.Window? window = null;
            if (parent != null && parent is Gtk.Window) {
                window = parent as Gtk.Window;
            }
            dialog = new Gtk.AppChooserDialog (window,
                                               Gtk.DialogFlags.MODAL | Gtk.DialogFlags.DESTROY_WITH_PARENT,
                                               file_to_open);

            dialog.set_deletable (false);
            var app_chooser = dialog.get_widget () as Gtk.AppChooserWidget;
            app_chooser.set_show_recommended (true);
            check_default = new Gtk.CheckButton.with_label (_("Set as default"));
            check_default.set_active (true);
            check_default.show ();
            var action_area = dialog.get_action_area () as Gtk.ButtonBox;
            action_area.add (check_default);
            action_area.set_child_secondary (check_default, true);
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
                        app.set_as_default_for_type (info.get_content_type ());
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
}
