/***
    Copyright (c) 2015-2017 elementary LLC (http://launchpad.net/elementary)  

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.
***/

/* See src/Dialogs/ConnectServerDialog.vala */
extern unowned Gtk.Dialog pf_connect_server_dialog_new (Gtk.Window window);

public class Files.Plugins.NetworkPlaces : Marlin.Plugins.Base {

    public override void directory_loaded (void* user_data) {
    }

    private static void connect_callback (Gtk.Widget widget) {
        var toplevel = widget.get_toplevel ();
        if (toplevel.is_toplevel ()) {
            var dialog = pf_connect_server_dialog_new ((Gtk.Window) toplevel);
        }
    }

    public override void update_sidebar (Gtk.Widget widget) {
        var sidebar = widget as Marlin.AbstractSidebar;
        sidebar.add_extra_network_item (_("Connect to Server…"), _("Connect to a network file server"),
                                         new ThemedIcon.with_default_fallbacks ("network-server"),
                                         connect_callback);
    }
}

public Marlin.Plugins.Base module_init () {
    return new Files.Plugins.NetworkPlaces ();
}
