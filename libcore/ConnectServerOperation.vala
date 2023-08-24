/***
    Copyright (c) 2010 Cosimo Cecchi <cosimoc@gnome.org>
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors: Cosimo Cecchi <cosimoc@gnome.org>
             Julián Unrrein <junrrein@gmail.com>
***/

public class Files.ConnectServer.Operation : Gtk.MountOperation {

    private PF.ConnectServerDialog dialog;

    public Operation (PF.ConnectServerDialog connect_server) {
        this.dialog = connect_server;
        this.set_parent ((Gtk.Window)(connect_server.get_root ()));

        /* Turn the parent's modal functionality off because the mount operation needs to take over */
        this.dialog.modal = false;
        this.reply.connect ( (result) => {
           this.dialog.modal = true;
        });
    }

    /*
      When mounting a network share, the ask_password implementation in
      Gtk.MountOperation asks the user the password in a little separate window.
      But we don't want an extra window. Our ConnectServer.Dialog already
      provided a place to put the password in.

      This ask_password implementation gets the password directly from the
      dialog, so no extra window is spawned.
    */
    public override void ask_password (string message,
                                       string default_user,
                                       string default_domain,
                                       AskPasswordFlags flags) {

        this.dialog.fill_details_async.begin (this, default_user, default_domain, flags,
                                              (source, result) => {
            bool res = this.dialog.fill_details_async.end (result);

            if (res) {
                reply (MountOperationResult.HANDLED);
            } else {
                reply (MountOperationResult.ABORTED);
            }
        });
    }
}
