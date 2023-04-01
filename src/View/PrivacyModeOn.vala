/*
 * Copyright 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
*/

public class Files.PrivacyModeOn : Granite.Placeholder {
    public PrivacyModeOn (ViewContainer tab) {
        Object (
            title: _("Privacy mode is on"),
            icon: new ThemedIcon ("dialog-warning"),
            description: _("No recent files are remembered")
        );
    }

    construct {
        var button = append_button (
            new ThemedIcon ("preferences-system-privacy"),
            _("Change security settings"),
            _("Open the system security and privacy settings app")
        );

        button.clicked.connect (() => {
            var ctx = Files.get_active_window ().get_display ().get_app_launch_context ();
            try {
                AppInfo.launch_default_for_uri ("settings://security", ctx);
            } catch (Error e) {
                critical ("No default security app found");
            }
        });
    }
}
