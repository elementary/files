/* Copyright (c) 2015-2017 elementary LLC (http://launchpad.net/pantheon-files)
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

namespace Marlin.View.Chrome {
    public struct BreadcrumbIconInfo {
        string path;
        string icon_name;
        bool protocol;
        GLib.Icon gicon;
        Gdk.Pixbuf icon;
        string[] exploded;
        bool break_loop;
        string? text_displayed;
    }


    public class BreadcrumbIconList : Object {

        private GLib.List<BreadcrumbIconInfo?> icon_info_list = null;
        private Granite.Services.IconFactory icon_factory;
        Gtk.StyleContext context;

        public BreadcrumbIconList (Gtk.StyleContext _context) {
            context = _context;
            icon_factory = Granite.Services.IconFactory.get_default ();

            /* FIXME the string split of the path url is kinda too basic, we should use the Gile to split our uris and determine the protocol (if any) with g_uri_parse_scheme or g_file_get_uri_scheme */
            add_icon ({ "afp://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, Marlin.PROTOCOL_NAME_AFP});
            add_icon ({ "dav://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, Marlin.PROTOCOL_NAME_DAV});
            add_icon ({ "davs://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true,Marlin.PROTOCOL_NAME_DAVS});
            add_icon ({ "ftp://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, Marlin.PROTOCOL_NAME_FTP});
            add_icon ({ "network://", Marlin.ICON_NETWORK_SYMBOLIC, true, null, null, null, true, Marlin.PROTOCOL_NAME_NETWORK});
            add_icon ({ "sftp://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, Marlin.PROTOCOL_NAME_SFTP});
            add_icon ({ "smb://", Marlin.ICON_NETWORK_SERVER_SYMBOLIC, true, null, null, null, true,Marlin.PROTOCOL_NAME_SMB});
            add_icon ({ "trash://", Marlin.ICON_TRASH_SYMBOLIC, true, null, null, null, true, Marlin.PROTOCOL_NAME_TRASH});
            add_icon ({ "recent://", Marlin.ICON_RECENT_SYMBOLIC, true, null, null, null, true, Marlin.PROTOCOL_NAME_RECENT});
            add_icon ({ "mtp://[", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, Marlin.PROTOCOL_NAME_MTP});


            /* music */
            string? dir;
            dir = Environment.get_user_special_dir (UserDirectory.MUSIC);
            if (dir != null && dir.contains (Path.DIR_SEPARATOR_S)) {
                BreadcrumbIconInfo icon = {dir, Marlin.ICON_FOLDER_MUSIC_SYMBOLIC, false, null, null, dir.split (Path.DIR_SEPARATOR_S), false, Filename.display_basename (dir)};
                icon.exploded[0] = Path.DIR_SEPARATOR_S;
                add_icon (icon);
            }

            /* image */
            dir = Environment.get_user_special_dir (UserDirectory.PICTURES);
            if (dir != null && dir.contains (Path.DIR_SEPARATOR_S)) {
                BreadcrumbIconInfo icon = {dir, Marlin.ICON_FOLDER_PICTURES_SYMBOLIC, false, null, null, dir.split (Path.DIR_SEPARATOR_S), false, Filename.display_basename (dir)};
                icon.exploded[0] = Path.DIR_SEPARATOR_S;
                add_icon (icon);
            }

            /* movie */
            dir = Environment.get_user_special_dir (UserDirectory.VIDEOS);
            if (dir != null && dir.contains (Path.DIR_SEPARATOR_S)) {
                BreadcrumbIconInfo icon = {dir, Marlin.ICON_FOLDER_VIDEOS_SYMBOLIC, false, null, null, dir.split (Path.DIR_SEPARATOR_S), false, Filename.display_basename (dir)};
                icon.exploded[0] = Path.DIR_SEPARATOR_S;
                add_icon (icon);
            }

            /* downloads */
            dir = Environment.get_user_special_dir (UserDirectory.DOWNLOAD);
            if (dir != null && dir.contains (Path.DIR_SEPARATOR_S)) {
                BreadcrumbIconInfo icon = {dir, Marlin.ICON_FOLDER_DOWNLOADS_SYMBOLIC, false, null, null, dir.split (Path.DIR_SEPARATOR_S), false, Filename.display_basename (dir)};
                icon.exploded[0] = Path.DIR_SEPARATOR_S;
                add_icon (icon);
            }

            /* documents */
            dir = Environment.get_user_special_dir (UserDirectory.DOCUMENTS);
            if (dir != null && dir.contains (Path.DIR_SEPARATOR_S)) {
                BreadcrumbIconInfo icon = {dir, Marlin.ICON_FOLDER_DOCUMENTS_SYMBOLIC, false, null, null, dir.split (Path.DIR_SEPARATOR_S), false, Filename.display_basename (dir)};
                icon.exploded[0] = Path.DIR_SEPARATOR_S;
                add_icon (icon);
            }

            /* templates */
            dir = Environment.get_user_special_dir (UserDirectory.TEMPLATES);
            if (dir != null && dir.contains (Path.DIR_SEPARATOR_S)) {
                BreadcrumbIconInfo icon = {dir, Marlin.ICON_FOLDER_TEMPLATES_SYMBOLIC, false, null, null, dir.split (Path.DIR_SEPARATOR_S), false, Filename.display_basename (dir)};
                icon.exploded[0] = Path.DIR_SEPARATOR_S;
                add_icon (icon);
            }

            /* home */
            dir = Eel.get_real_user_home ();
            if (dir.contains (Path.DIR_SEPARATOR_S)) {
                BreadcrumbIconInfo icon = {dir, Marlin.ICON_GO_HOME_SYMBOLIC, false, null, null, dir.split (Path.DIR_SEPARATOR_S), true, null};
                icon.exploded[0] = Path.DIR_SEPARATOR_S;
                add_icon (icon);
            }

            /* media mounted volumes */
            dir = "/media";
            if (dir.contains (Path.DIR_SEPARATOR_S)) {
                BreadcrumbIconInfo icon = {dir, Marlin.ICON_FILESYSTEM_SYMBOLIC, false, null, null, dir.split (Path.DIR_SEPARATOR_S), true, null};
                icon.exploded[0] = Path.DIR_SEPARATOR_S;
                add_icon (icon);
            }

            /* filesystem */
            BreadcrumbIconInfo icon = {Path.DIR_SEPARATOR_S, Marlin.ICON_FILESYSTEM_SYMBOLIC, false, null, null, null, false, null};
            icon.exploded = {Path.DIR_SEPARATOR_S};
            add_icon (icon);

        }

        private void add_icon (BreadcrumbIconInfo icon_info) {
            if (icon_info.gicon != null)
                icon_info.icon = icon_factory.load_symbolic_icon_from_gicon (context, icon_info.gicon, 16);
            else
                icon_info.icon = icon_factory.load_symbolic_icon (context, icon_info.icon_name, 16);

            icon_info_list.append (icon_info);
        }

        public void add_mounted_volumes () {
            /* Add every mounted volume in our BreadcrumbIcon in order to load them properly in the pathbar if needed */
            var volume_monitor = VolumeMonitor.get ();
            var mount_list = volume_monitor.get_mounts ();

            foreach (var mount in mount_list) {
                BreadcrumbIconInfo icon_info = { mount.get_root ().get_path (),
                                                 null, false,
                                                 mount.get_icon (),
                                                 null, mount.get_root ().get_path ().split (Path.DIR_SEPARATOR_S),
                                                 true, mount.get_name () };

                if (mount.get_root ().get_path () != null) {
                    icon_info.exploded[0] = Path.DIR_SEPARATOR_S;
                    add_icon (icon_info);
                }
            }
        }

        public void truncate_to_length (uint new_length) {
            for (uint i = icon_info_list.length () - 1; i >= new_length; i--) {
                icon_info_list.remove (icon_info_list.nth_data (i));
            }
        }

        public uint length () {
            return icon_info_list.length ();
        }

        public unowned GLib.List<BreadcrumbIconInfo?> get_list () {
            return icon_info_list;
        }
    }
}
