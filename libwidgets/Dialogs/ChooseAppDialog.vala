/*
 * ChooseAppDialog.vala
 * 
 * Copyright 2015 jeremy <jeremy@jeremy-W54-55SU1-SUW>
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 * MA 02110-1301, USA.
 * 
 * 
 */

namespace PF {
    class ChooseAppDialog {
        Gtk.AppChooserDialog dialog;
        Gtk.CheckButton check_default;
        GLib.File file_to_open;
        public ChooseAppDialog (Gtk.Window parent, GLib.File file) {
            file_to_open = file;
            dialog = new Gtk.AppChooserDialog (parent,
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
//                        app.set_as_default_for_type (file.get_ftype ());
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