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
    public class BreadcrumbIconInfo {
        public string path;
        public bool protocol;
        public GLib.Icon gicon;
        public Gdk.Pixbuf icon;
        public string[] exploded;
        public bool break_loop;
        public string? text_displayed;
        public int icon_width;
        public int icon_height;

        public BreadcrumbIconInfo.special_directory (string path, string icon_name) {
            set_path (path);
            protocol = false;
            gicon = new GLib.ThemedIcon (icon_name);
            break_loop = false;
            text_displayed = Filename.display_basename (path);
        }

        public BreadcrumbIconInfo.protocol_directory (string scheme, string icon_name, string display_name) {
            path = scheme;
            protocol = true;
            gicon = new GLib.ThemedIcon (icon_name);
            break_loop = true;
            text_displayed = display_name;
        }

        public BreadcrumbIconInfo.from_mount (GLib.Mount mount) {
            GLib.File root = mount.get_root ();
            set_path (root.get_path ());
            protocol = false;
            gicon = mount.get_icon ();
            break_loop = true;
            text_displayed = mount.get_name ();
        }

        public void render_icon (Gtk.StyleContext context) throws GLib.Error {
            weak Gtk.IconTheme theme = Gtk.IconTheme.get_default ();
            Gtk.IconInfo? gtk_icon_info = null;
            var scale = context.get_scale ();
            if (gicon != null) {
                gtk_icon_info = theme.lookup_by_gicon_for_scale (gicon, 16, scale, Gtk.IconLookupFlags.FORCE_SYMBOLIC);
            } else {
                throw new GLib.IOError.NOT_INITIALIZED ("the gicon field is empty!");
            }

            if (gtk_icon_info != null) {
                try {
                    icon = gtk_icon_info.load_symbolic_for_context (context);
                    icon_width = icon.get_width () / scale;
                    icon_height = icon.get_height () / scale;
                } catch (Error e) {
                    throw e;
                }
            } else {
                throw new GLib.IOError.NOT_FOUND ("Unable to find the given icon!");
            }
        }

        public void set_path (string path) {
            this.path = path;
            if (path != null && path != Path.DIR_SEPARATOR_S) {
                if (path == Path.DIR_SEPARATOR_S) {
                    exploded = { Path.DIR_SEPARATOR_S };
                } else {
                    exploded = path.split (Path.DIR_SEPARATOR_S);
                    exploded[0] = Path.DIR_SEPARATOR_S;
                }
            }
        }
    }


    public class BreadcrumbIconList : Object {
        private Gee.ArrayList<BreadcrumbIconInfo> icon_info_list;
        public unowned Gtk.StyleContext context { get; set construct; }

        public BreadcrumbIconList (Gtk.StyleContext context) {
            Object (context: context);
            make_icons ();
        }

        public int scale {
            get {
                return context.get_scale ();
            }
            set {
                context.set_scale (value);
                make_icons ();
            }
        }

        construct {
            icon_info_list = new Gee.ArrayList<BreadcrumbIconInfo> ();

            /* FIXME the string split of the path url is kinda too basic, we should use the Gile to split our uris and determine the protocol (if any) with g_uri_parse_scheme or g_file_get_uri_scheme */
            icon_info_list.add (new BreadcrumbIconInfo.protocol_directory ("afp://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, Marlin.PROTOCOL_NAME_AFP));
            icon_info_list.add (new BreadcrumbIconInfo.protocol_directory ("dav://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, Marlin.PROTOCOL_NAME_DAV));
            icon_info_list.add (new BreadcrumbIconInfo.protocol_directory ("davs://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, Marlin.PROTOCOL_NAME_DAVS));
            icon_info_list.add (new BreadcrumbIconInfo.protocol_directory ("ftp://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, Marlin.PROTOCOL_NAME_FTP));
            icon_info_list.add (new BreadcrumbIconInfo.protocol_directory ("network://", Marlin.ICON_NETWORK_SYMBOLIC, Marlin.PROTOCOL_NAME_NETWORK));
            icon_info_list.add (new BreadcrumbIconInfo.protocol_directory ("sftp://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, Marlin.PROTOCOL_NAME_SFTP));
            icon_info_list.add (new BreadcrumbIconInfo.protocol_directory ("smb://", Marlin.ICON_NETWORK_SERVER_SYMBOLIC, Marlin.PROTOCOL_NAME_SMB));
            icon_info_list.add (new BreadcrumbIconInfo.protocol_directory ("trash://", Marlin.ICON_TRASH_SYMBOLIC, Marlin.PROTOCOL_NAME_TRASH));
            icon_info_list.add (new BreadcrumbIconInfo.protocol_directory ("recent://", Marlin.ICON_RECENT_SYMBOLIC, Marlin.PROTOCOL_NAME_RECENT));
            icon_info_list.add (new BreadcrumbIconInfo.protocol_directory ("mtp://[", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, Marlin.PROTOCOL_NAME_MTP));


            /* music */
            string? dir;
            dir = Environment.get_user_special_dir (UserDirectory.MUSIC);
            if (dir != null && dir.contains (Path.DIR_SEPARATOR_S)) {
                var icon = new BreadcrumbIconInfo.special_directory (dir, Marlin.ICON_FOLDER_MUSIC_SYMBOLIC);
                icon_info_list.add (icon);
            }

            /* image */
            dir = Environment.get_user_special_dir (UserDirectory.PICTURES);
            if (dir != null && dir.contains (Path.DIR_SEPARATOR_S)) {
                var icon = new BreadcrumbIconInfo.special_directory (dir, Marlin.ICON_FOLDER_PICTURES_SYMBOLIC);
                icon_info_list.add (icon);
            }

            /* movie */
            dir = Environment.get_user_special_dir (UserDirectory.VIDEOS);
            if (dir != null && dir.contains (Path.DIR_SEPARATOR_S)) {
                var icon = new BreadcrumbIconInfo.special_directory (dir, Marlin.ICON_FOLDER_VIDEOS_SYMBOLIC);
                icon_info_list.add (icon);
            }

            /* downloads */
            dir = Environment.get_user_special_dir (UserDirectory.DOWNLOAD);
            if (dir != null && dir.contains (Path.DIR_SEPARATOR_S)) {
                var icon = new BreadcrumbIconInfo.special_directory (dir, Marlin.ICON_FOLDER_DOWNLOADS_SYMBOLIC);
                icon_info_list.add (icon);
            }

            /* documents */
            dir = Environment.get_user_special_dir (UserDirectory.DOCUMENTS);
            if (dir != null && dir.contains (Path.DIR_SEPARATOR_S)) {
                var icon = new BreadcrumbIconInfo.special_directory (dir, Marlin.ICON_FOLDER_DOCUMENTS_SYMBOLIC);
                icon_info_list.add (icon);
            }

            /* templates */
            dir = Environment.get_user_special_dir (UserDirectory.TEMPLATES);
            if (dir != null && dir.contains (Path.DIR_SEPARATOR_S)) {
                var icon = new BreadcrumbIconInfo.special_directory (dir, Marlin.ICON_FOLDER_TEMPLATES_SYMBOLIC);
                icon_info_list.add (icon);
            }

            /* home */
            dir = Eel.get_real_user_home ();
            if (dir.contains (Path.DIR_SEPARATOR_S)) {
                var icon = new BreadcrumbIconInfo.special_directory (dir, Marlin.ICON_GO_HOME_SYMBOLIC);
                icon.break_loop = true;
                icon_info_list.add (icon);
            }

            /* media mounted volumes */
            dir = "/media";
            if (dir.contains (Path.DIR_SEPARATOR_S)) {
                var icon = new BreadcrumbIconInfo.special_directory (dir, Marlin.ICON_FILESYSTEM_SYMBOLIC);
                icon.break_loop = true;
                icon_info_list.add (icon);
            }

            /* filesystem */
            var icon = new BreadcrumbIconInfo.special_directory (Path.DIR_SEPARATOR_S, Marlin.ICON_FILESYSTEM_SYMBOLIC);
            icon_info_list.add (icon);
        }

        private void make_icons() {
            context.save ();
            context.set_state (Gtk.StateFlags.NORMAL);

            foreach (var icon_info in icon_info_list) {
                try {
                    icon_info.render_icon (context);
                } catch (Error e) {
                    critical (e.message);
                }
            }

            context.restore ();
        }

        public void add_mounted_volumes () {
            context.save ();
            context.set_state (Gtk.StateFlags.NORMAL);

            /* Add every mounted volume in our BreadcrumbIcon in order to load them properly in the pathbar if needed */
            var volume_monitor = VolumeMonitor.get ();
            GLib.List<GLib.Mount> mount_list = volume_monitor.get_mounts ();

            mount_list.foreach ((mount) => {
                var icon_info = new BreadcrumbIconInfo.from_mount (mount);
                if (icon_info.path != null) {
                    try {
                        icon_info.render_icon (context);
                        icon_info_list.add (icon_info);
                    } catch (Error e) {
                        critical (e.message);
                    }
                }
            });

            context.restore ();
        }

        public void truncate_to_length (int new_length) {
            for (int i = icon_info_list.size - 1; i >= new_length; i--) {
                icon_info_list.remove_at (i);
            }
        }

        public int length () {
            return icon_info_list.size;
        }

        public unowned Gee.ArrayList<BreadcrumbIconInfo> get_list () {
            return icon_info_list;
        }
    }
}
