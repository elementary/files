/*
* Copyright (c) 2015-2017 elementary LLC. (http://launchpad.net/pantheon-files)
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

class PF.ChooseAppDialog : Gtk.Dialog {
    private Gtk.AppChooserWidget app_chooser;
    private Gtk.CheckButton check_default;
    private string content_type;

    public GLib.File file_to_open { get; construct; }

    public ChooseAppDialog (Gtk.Window? parent, GLib.File file_to_open) {
        Object (transient_for: parent,
                resizable: false,
                deletable: false,
                window_position: Gtk.WindowPosition.CENTER_ON_PARENT,
                destroy_with_parent: true,
                file_to_open: file_to_open
        );
    }

    construct {
        /* Called from view so corresponding GOF.File must exist and already have content type */
        content_type = (GOF.File.@get (file_to_open)).get_ftype ();

        app_chooser = new Gtk.AppChooserWidget (content_type);
        app_chooser.show_default = true;
        app_chooser.show_recommended = true;
        app_chooser.show_fallback = true;
        app_chooser.show_other = false;

        check_default = new Gtk.CheckButton.with_label (_("Set as default"));
        check_default.active = true;

        var content_area = get_content_area () as Gtk.Container;
        var grid = new Gtk.Grid ();
        grid.orientation = Gtk.Orientation.VERTICAL;
        grid.margin = 12;
        grid.row_spacing = 6;
        grid.add (app_chooser);

        var show_grid = new Gtk.Grid ();
        show_grid.orientation = Gtk.Orientation.HORIZONTAL;
        show_grid.column_spacing = 12;

        var show_label = new Gtk.Label (_("Show Other Applications"));
        show_label.tooltip_text = _("Show applications that may not be suitable for this file type");

        var show_switch = new Gtk.Switch ();
        show_switch.active = false;
        show_switch.state = false;

        show_grid.add (show_label);
        show_grid.add (show_switch);

        grid.add (show_grid);
        content_area.add (grid);

        add_button (_("Select"), Gtk.ResponseType.OK);
        add_button (_("Cancel"), Gtk.ResponseType.CANCEL);

        var action_area = get_action_area () as Gtk.ButtonBox;
        action_area.add (check_default);
        action_area.set_child_secondary (check_default, true);

        show_switch.notify["active"].connect (() => {
            var show_all = show_switch.get_active ();

            app_chooser.show_default = !show_all;
            app_chooser.show_recommended = !show_all;
            app_chooser.show_fallback = !show_all;
            app_chooser.show_other = show_all;

            check_default.active = !show_all;
        });

        app_chooser.application_activated.connect (() => {
            response (Gtk.ResponseType.OK);
        });
    }

    public AppInfo? get_app_info () {
        AppInfo? app = null;
        show_all ();
        int response =run ();
        if (response == Gtk.ResponseType.OK) {
            app = app_chooser.get_app_info ();
            if (check_default.active) {
                try {
                    app.set_as_default_for_type (content_type);
                }
                catch (GLib.Error error) {
                    critical ("Could not set as default: %s", error.message);
                }
            }
        }

        destroy ();
        return app;
    }
}
