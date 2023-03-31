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

public class Files.PrivacyModeOn : Granite.Placeholder {
    public Directory dir_saved;
    public ViewContainer ctab;
    public bool remember_history {get; set;}
    //TODO Rework for Granite.Placeholder
    public PrivacyModeOn (ViewContainer tab) {
        base (_("Privacy mode is on"));

        // append ("preferences-system-privacy", _("Change security settings"),
        //         _("Open the system security and privacy settings app"));

        // this.activated.connect ((index) => {
        //     switch (index) {
        //         case 0:
        //             var ctx = get_window ().get_display ().get_app_launch_context ();
        //             try {
        //                 AppInfo.launch_default_for_uri ("settings://security", ctx);
        //             } catch (Error e) {
        //                 critical ("No default security app found");
        //             }
        //             break;
        //     }
        // });

        // show_all ();
    }
}
