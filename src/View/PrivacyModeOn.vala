/*
*    Copyright (c) 2011 Lucas Baudin <xapantu@gmail.com>
*    Copyright 2023 elementary, Inc. (https://elementary.io)
*    SPDX-License-Identifier: LGPL-3.0-or-later
*/

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
