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

using Gtk;
using Marlin;

public class Marlin.Plugins.Cserver : Marlin.Plugins.Base
{
    private InfoBar? infobar = null;

    public Cserver() {}

    public override void directory_loaded(void* user_data) {
        GOF.File file = ((Object[])user_data)[2] as GOF.File;
        if (file.location.get_uri_scheme () == "network") {
            assert(((Object[])user_data)[1] is GOF.AbstractSlot);
            GOF.AbstractSlot slot = ((Object[])user_data)[1] as GOF.AbstractSlot;

            infobar = new InfoBar();
            infobar.add_button(_("Connect to Server..."), 0);
            infobar.response.connect( (self, response) => {
                    Marlin.ConnectServerDialog.show_connect_server_dialog (self);
                });
            infobar.set_message_type(Gtk.MessageType.INFO);

            slot.add_extra_widget(infobar);
            infobar.show_all();
        }
    }
}


public Marlin.Plugins.Base module_init() {
    return new Marlin.Plugins.Cserver();
}
