/* Copyright (c) 2015-2022 elementary LLC <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation, Inc.,; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor
* Boston, MA 02110-1335 USA.
*/

namespace Files {
    public class BreadcrumbIconMap : Object {
        private static GLib.Once<BreadcrumbIconMap> instance;
        public static unowned BreadcrumbIconMap get_default () {
            return instance.once (() => { return new BreadcrumbIconMap (); });
        }

        private Gee.HashMap<string, BreadcrumbIconInfo> icon_info_map;
        private VolumeMonitor volume_monitor;

        construct {
            icon_info_map = new Gee.HashMap<string, BreadcrumbIconInfo> ();

            add_protocol_directory ("afp", Files.ICON_FOLDER_REMOTE_SYMBOLIC);
            add_protocol_directory ("dav", Files.ICON_FOLDER_REMOTE_SYMBOLIC);
            add_protocol_directory ("davs", Files.ICON_FOLDER_REMOTE_SYMBOLIC);
            add_protocol_directory ("ftp", Files.ICON_FOLDER_REMOTE_SYMBOLIC);
            add_protocol_directory ("sftp", Files.ICON_FOLDER_REMOTE_SYMBOLIC);
            add_protocol_directory ("mtp", Files.ICON_DEVICE_REMOVABLE_MEDIA_SYMBOLIC);
            add_protocol_directory ("gphoto2", Files.ICON_DEVICE_CAMERA_SYMBOLIC);
            add_protocol_directory ("afc", Files.ICON_DEVICE_PHONE_SYMBOLIC);
            add_protocol_directory ("network", Files.ICON_NETWORK_SYMBOLIC);
            add_protocol_directory ("smb", Files.ICON_NETWORK_SERVER_SYMBOLIC);
            add_protocol_directory ("trash", Files.ICON_TRASH_SYMBOLIC);
            add_protocol_directory ("recent", Files.ICON_RECENT_SYMBOLIC);
            add_protocol_directory ("file", Files.ICON_FILESYSTEM_SYMBOLIC, Path.DIR_SEPARATOR_S);

            add_special_directory (Environment.get_user_special_dir (UserDirectory.MUSIC),
                                   Files.ICON_FOLDER_MUSIC_SYMBOLIC, _("Music"));
            add_special_directory (Environment.get_user_special_dir (UserDirectory.PICTURES),
                                   Files.ICON_FOLDER_PICTURES_SYMBOLIC, _("Pictures"));
            add_special_directory (Environment.get_user_special_dir (UserDirectory.VIDEOS),
                                   Files.ICON_FOLDER_VIDEOS_SYMBOLIC, _("Videos"));
            add_special_directory (Environment.get_user_special_dir (UserDirectory.DOWNLOAD),
                                   Files.ICON_FOLDER_DOWNLOADS_SYMBOLIC, _("Downloads"));
            add_special_directory (Environment.get_user_special_dir (UserDirectory.DOCUMENTS),
                                   Files.ICON_FOLDER_DOCUMENTS_SYMBOLIC, _("Documents"));
            add_special_directory (Environment.get_user_special_dir (UserDirectory.TEMPLATES),
                                   Files.ICON_FOLDER_TEMPLATES_SYMBOLIC, _("Templates"));
            add_special_directory (Environment.get_user_special_dir (UserDirectory.PUBLIC_SHARE),
                                   Files.ICON_FOLDER_PUBLICSHARE_SYMBOLIC, _("Public"));
            add_special_directory (PF.UserUtils.get_real_user_home (),
                                   Files.ICON_GO_HOME_SYMBOLIC, _("Home"),
                                   true);
            add_special_directory ("/media",
                                   Files.ICON_FILESYSTEM_SYMBOLIC, _("Media"),
                                   true);

            volume_monitor = VolumeMonitor.get ();
            add_mounted_volumes ();
            volume_monitor.mount_added.connect ((mount) => {
                mount_added (mount);
            });
            volume_monitor.mount_removed.connect ((mount) => {
                mount_removed (mount);
            });
        }

        private void add_protocol_directory (string protocol, string icon, string? override_name = null) {
            var separator = "://" + ((protocol == "mtp" || protocol == "gphoto2") ? "[" : "");
            var info = new BreadcrumbIconInfo (
                icon,
                override_name ?? protocol_to_name (protocol)
            );
            icon_info_map[protocol + separator] = info;
        }

        private void add_special_directory (
            string? dir,
            string icon_name,
            string display_name,
            bool hide_previous = false) {

            if (dir != null) {
                var icon = new BreadcrumbIconInfo (icon_name, display_name, hide_previous);
                icon_info_map[dir] = icon;
            }
        }

        public void add_mounted_volumes () {
            /* Add every mounted volume in our BreadcrumbIcon in order to
             * load them properly in the pathbar if needed */
            GLib.List<GLib.Mount> mount_list = volume_monitor.get_mounts ();
            mount_list.foreach ((mount) => {
                mount_added (mount);
            });
        }

        public void mount_added (Mount mount) {
            var icon_info = new BreadcrumbIconInfo.from_icon (mount.get_icon (), mount.get_name ());
            var path = mount.get_root ().get_path ();
            if (path != null) {
                icon_info_map[path] = icon_info;
            }
        }
        public void mount_removed (Mount mount) {
            var path = mount.get_root ().get_path ();
            if (path != null) {
                icon_info_map[path] = null;
            }
        }

        public bool get_icon_info_for_key (
            string key,
            out Icon? icon,
            out string display_name,
            out bool hide_previous
        ) {
            var iconinfo = icon_info_map[key];
            if (iconinfo != null) {
                display_name = iconinfo.text_displayed;
                icon = iconinfo.gicon;
                hide_previous = iconinfo.hide_previous;
                return true;
            } else {
                display_name = "";
                icon = null;
                hide_previous = false;
                return false;
            }
        }
    }

    public class BreadcrumbIconInfo {
        public GLib.Icon gicon;
        public string text_displayed;
        public bool hide_previous;

        public BreadcrumbIconInfo (
            string icon_name,
            string display_name,
            bool _hide_previous = false
        ) {
            gicon = new GLib.ThemedIcon (icon_name);
            text_displayed = display_name;
            hide_previous = _hide_previous;
        }

        public BreadcrumbIconInfo.from_icon (Icon icon, string display_name) {
            gicon = icon;
            text_displayed = display_name;
            hide_previous = false;
        }
    }
}
