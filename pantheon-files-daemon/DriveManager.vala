/***
    Copyright (c) 2021 elementary LLC.

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors: Pong Loong Yeat <pongloongyeat@gmail.com>
***/

public class Files.Daemon.DriveManager : GLib.Application {

    private VolumeMonitor volume_monitor;

    protected override void activate () {
        hold ();

        this.volume_monitor = VolumeMonitor.get ();

        var n_volumes = 0;

        this.volume_monitor.volume_added.connect ((volume) => {
            volume_added_callback (volume, ref n_volumes);
        });
    }

    private void volume_added_callback (Volume volume, ref int n_volumes) {
        var drive = volume.get_drive ();

        // Send notification only after all volumes are added
        if (!(++n_volumes < drive.get_volumes ().length ())) {
            var notification = new Notification (_("%s connected").printf (drive.get_name ()));
            notification.set_icon (drive.get_icon ());
            notification.set_body (_("With %u %s present").printf (n_volumes, ngettext ("volume", "volumes", n_volumes)));

            GLib.Application.get_default ().send_notification ("io.elementary.files", notification);

            // Reset for next added device
            n_volumes = 0;
        }
    }
}
