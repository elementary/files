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

public class Files.PrivacyModeOn : Gtk.Bin {
    public View.ViewContainer ctab {get; construct; }
    public bool remember_history { get; set; }

    public PrivacyModeOn (View.ViewContainer _ctab) {
        Object (
            ctab: _ctab
        );
    }

    construct {
        var placeholder = new Files.Placeholder (_("Privacy mode is on")) {
            description = _("No recent files are remembered")
        };

        var change_button = placeholder.append_button (
            new ThemedIcon ("preferences-system-privacy"),
            _("Change security settings"),
            _("Open the system security and privacy settings app")
        );

        change_button.clicked.connect ((index) => {
            var ctx = get_window ().get_display ().get_app_launch_context ();
            try {
                AppInfo.launch_default_for_uri ("settings://security", ctx);
            } catch (Error e) {
                critical ("No default security app found");
            }
        });

        add (placeholder);
        show_all ();
    }
}
