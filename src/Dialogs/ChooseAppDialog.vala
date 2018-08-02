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
        grid.margin_start = grid.margin_end = 12;
        grid.row_spacing = 6;
        grid.add (app_chooser);

        var show_text = _("View other applications");
        var hide_text = _("Hide other applications");

        var show_button = new Gtk.Button.with_label (show_text);
        show_button.tooltip_text = _("Show or hide applications that may not be suitable for this file type");

        grid.add (show_button);
        content_area.add (grid);

        var cancel_button = add_button (_("Cancel"), Gtk.ResponseType.CANCEL);
        var ok_button = add_button (_("Select"), Gtk.ResponseType.OK);

        var action_area = get_action_area () as Gtk.ButtonBox;
        action_area.margin_start = action_area.margin_end =  12;
        action_area.margin_bottom = action_area.margin_top = 6;

        action_area.add (check_default);
        action_area.set_child_secondary (check_default, true);

        show_button.clicked.connect (() => {
            var show_other = app_chooser.show_other;
            app_chooser.show_default = show_other;
            app_chooser.show_recommended = show_other;
            app_chooser.show_fallback = show_other;
            app_chooser.show_other = !show_other;

            show_other = app_chooser.show_other;
            show_button.label = show_other ? hide_text : show_text;
            check_default.active = !show_other;
            if (show_other) {
                cancel_button.grab_focus ();
            }
        });

        app_chooser.application_activated.connect (() => {
            response (Gtk.ResponseType.OK);
        });

        set_focus_child (app_chooser);
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
