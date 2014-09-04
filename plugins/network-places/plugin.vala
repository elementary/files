/*
 *
 * Marlin is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * Marlin is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

// See src/marlin-connect-server-dialog.c
extern void marlin_connect_server_dialog_show (Gtk.Widget widget);

public class Files.Plugins.NetworkInfobar : Gtk.InfoBar {
    public NetworkInfobar () {
        message_type = Gtk.MessageType.INFO;
        add_button (_("Connect to Server…"), 0);
    }

    public override void response (int response_id) {
        marlin_connect_server_dialog_show (this);
    }
}

public class Files.Plugins.NetworkPlaces : Marlin.Plugins.Base {
    private bool sidebar_button_added = false;
    public override void directory_loaded (void* user_data) {
        var file = ((Object[]) user_data)[2] as GOF.File;
        return_if_fail (file != null);

        if (file.is_network_uri_scheme ()) {
            var slot = ((Object[]) user_data)[1] as GOF.AbstractSlot;
            return_if_fail (slot != null);

            var infobar = new NetworkInfobar ();
            slot.add_extra_widget (infobar);
            infobar.show_all ();
        }
    }

    public override void update_sidebar (Gtk.Widget sidebar) {
message ("Network plug update sidebar");
        if (!sidebar_button_added) {
            var sidebar_button = new Gtk.Button.from_icon_name ("gtk-add", Gtk.IconSize.MENU);
            sidebar_button.set_always_show_image (true);
            sidebar_button.set_label (_("Connect to server"));
            sidebar_button.clicked.connect ((w) => {
                marlin_connect_server_dialog_show (w);
            });
            sidebar_button.show_all ();
            (sidebar as Marlin.AbstractSidebar).add_extra_widget (sidebar_button, true, -1, false, false, 0);
            sidebar_button_added = true;
        }
    }
}

public Marlin.Plugins.Base module_init () {
    return new Files.Plugins.NetworkPlaces ();
}
