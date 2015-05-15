// -*- Mode: vala; indent-tabs-mode: nil; tab-width: 4 -*-
/*-
 * Copyright (c) 2015 Pantheon Developers (http://launchpad.net/elementary)
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this library; if not, write to the
 * Free Software Foundation, Inc., 59 Temple Place - Suite 330,
 * Boston, MA 02111-1307, USA.
 *
 * Authored by: Corentin Noël <tintou@mailoo.org>
 */

namespace Marlin {
    private const string ICON_FILESYSTEM_SYMBOLIC = "drive-harddisk-symbolic";
    private const string ICON_FOLDER_DOCUMENTS_SYMBOLIC = "folder-documents-symbolic";
    private const string ICON_FOLDER_DOWNLOADS_SYMBOLIC = "folder-download-symbolic";
    private const string ICON_FOLDER_MUSIC_SYMBOLIC = "folder-music-symbolic";
    private const string ICON_FOLDER_PICTURES_SYMBOLIC = "folder-pictures-symbolic";
    private const string ICON_FOLDER_REMOTE = "folder-remote";
    private const string ICON_FOLDER_REMOTE_SYMBOLIC = "folder-remote-symbolic";
    private const string ICON_FOLDER_TEMPLATES_SYMBOLIC = "folder-templates-symbolic";
    private const string ICON_FOLDER_VIDEOS_SYMBOLIC = "folder-videos-symbolic";
    private const string ICON_GO_HOME_SYMBOLIC = "go-home-symbolic";
    private const string ICON_NETWORK = "network-workgroup";
    private const string ICON_NETWORK_SERVER = "network-server";
    private const string ICON_TRASH = "user-trash";
    private const string ICON_TRASH_FULL = "user-trash-full";
    private const string ICON_TRASH_SYMBOLIC = "user-trash-symbolic";

    private const string PROTOCOL_NAME_AFP = "AFP";
    private const string PROTOCOL_NAME_DAV =  "DAV";
    private const string PROTOCOL_NAME_DAVS = "DAVS";
    private const string PROTOCOL_NAME_FTP = "FTP";
    private const string PROTOCOL_NAME_NETWORK = "Network";
    private const string PROTOCOL_NAME_SFTP = "SFTP";
    private const string PROTOCOL_NAME_SMB = "SMB";
    private const string PROTOCOL_NAME_TRASH = "Trash";
}

namespace Marlin.View.Chrome {
    public class LocationBar : Gtk.Box {
        public Breadcrumbs bread;

        private string _path;
        public new string path {
            set {
                var new_path = GLib.Uri.unescape_string (value);
                if (new_path != null) {
                    _path = new_path;

                    if (!bread.is_focus) {
                        bread.text = "";
                        bread.change_breadcrumbs (new_path);
                    }
                } else
                    warning ("Tried to set null path\n");
            }

            get {
                return _path;
            }
        }

        public new signal void activate (GLib.File file);
        public signal void escape ();
        public signal void change_to_file (string filename);

        public override void get_preferred_width (out int minimum_width, out int natural_width) {
            minimum_width = -1;
            natural_width = 3000;
        }

        public LocationBar (Gtk.Widget parent) {
            bread = new Breadcrumbs ();
            bread.escape.connect (() => { escape (); });
            bread.activate_alternate.connect ((file) => {
                path = "file://" + file.get_path ();
                change_to_file (file.get_path ());            
            });
            
            bread.path_changed.connect ((file) => {
                path = "file://" + file.get_path ();
                change_to_file (file.get_path ());

                parent.grab_focus ();
            });
            
            margin_top = 4;
            margin_bottom = 4;
            margin_left = 3;
            pack_start (bread, true, true, 0);
        }
    }

    public class Breadcrumbs : BasePathBar {
        Gtk.Menu menu;

        private bool drop_data_ready = false;
        private bool drop_occurred = false;
        private GLib.List<GLib.File> drop_file_list = null;

        Gdk.DragAction current_suggested_action = 0;
        Gdk.DragAction current_actions = 0;

        public Breadcrumbs ()
        {
            /* The string split of the path url is kinda too basic,
             * we should use the GFile to split our uris and determine the protocol (if any) with g_uri_parse_scheme or g_file_get_uri_scheme */
            add_icon ({ "afp://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, Marlin.PROTOCOL_NAME_AFP});
            add_icon ({ "dav://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, Marlin.PROTOCOL_NAME_DAV});
            add_icon ({ "davs://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true,Marlin.PROTOCOL_NAME_DAVS});
            add_icon ({ "ftp://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, Marlin.PROTOCOL_NAME_FTP});
            add_icon ({ "network://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, Marlin.PROTOCOL_NAME_NETWORK});
            add_icon ({ "sftp://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true, Marlin.PROTOCOL_NAME_SFTP});
            add_icon ({ "smb://", Marlin.ICON_FOLDER_REMOTE_SYMBOLIC, true, null, null, null, true,Marlin.PROTOCOL_NAME_SMB});
            add_icon ({ "trash://", Marlin.ICON_TRASH_SYMBOLIC, true, null, null, null, true, Marlin.PROTOCOL_NAME_TRASH});

            string dir;
            dir = Environment.get_user_special_dir (UserDirectory.MUSIC);
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_FOLDER_MUSIC_SYMBOLIC, false, null, null, dir.split ("/"), false, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }


            dir = Environment.get_user_special_dir (UserDirectory.PICTURES);
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_FOLDER_PICTURES_SYMBOLIC, false, null, null, dir.split ("/"), false, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }


            dir = Environment.get_user_special_dir (UserDirectory.VIDEOS);
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_FOLDER_VIDEOS_SYMBOLIC, false, null, null, dir.split ("/"), false, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }

            dir = Environment.get_user_special_dir (UserDirectory.DOWNLOAD);
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_FOLDER_DOWNLOADS_SYMBOLIC, false, null, null, dir.split ("/"), false, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }

            dir = Environment.get_user_special_dir (UserDirectory.DOCUMENTS);
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_FOLDER_DOCUMENTS_SYMBOLIC, false, null, null, dir.split ("/"), false, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }

            dir = Environment.get_user_special_dir (UserDirectory.TEMPLATES);
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_FOLDER_TEMPLATES_SYMBOLIC, false, null, null, dir.split ("/"), false, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }

            dir = Environment.get_home_dir ();
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_GO_HOME_SYMBOLIC, false, null, null, dir.split ("/"), true, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }


            dir = "/media";
            if (dir.contains ("/")) {
                IconDirectory icon = {dir, Marlin.ICON_FILESYSTEM_SYMBOLIC, false, null, null, dir.split ("/"), true, null};
                icon.exploded[0] = "/";
                add_icon (icon);
            }

            IconDirectory icon = {"/", Marlin.ICON_FILESYSTEM_SYMBOLIC, false, null, null, null, false, null};
            icon.exploded = {"/"};
            add_icon (icon);

            menu = new Gtk.Menu ();
            menu.show_all ();
        }

        protected override void load_right_click_menu (double x, double y) {

        }

        protected override bool on_drag_motion (Gdk.DragContext context, int x, int y, uint time) {
            Gtk.drag_unhighlight (this);

            foreach (BreadcrumbsElement element in elements)
                element.pressed = false;

            var el = get_element_from_coordinates (x, y);

            if (el != null)
                el.pressed = true;
            else
                /* No action taken on drop */
                Gdk.drag_status (context, 0, time);

            queue_draw ();

            return false;
        }

        protected override bool on_drag_drop (Gdk.DragContext context,
                                   int x,
                                   int y,
                                   uint timestamp) {
            Gtk.TargetList list = null;
            bool ok_to_drop = false;

            Gdk.Atom target = Gtk.drag_dest_find_target  (this, context, list);

            ok_to_drop = (target != Gdk.Atom.NONE);

            if (ok_to_drop) {
                drop_occurred = true;
                Gtk.drag_get_data (this, context, target, timestamp);
            }

            return ok_to_drop;
        }

        protected override void on_drag_data_received (Gdk.DragContext context,
                                            int x,
                                            int y,
                                            Gtk.SelectionData selection_data,
                                            uint info,
                                            uint timestamp) {
            bool success = false;

            if (!drop_data_ready) {
                drop_file_list = null;
                foreach (var uri in selection_data.get_uris ()) {
                    debug ("Path to move: %s\n", uri);
                    drop_file_list.append (File.new_for_uri (uri));
                    drop_data_ready = true;
                }
            }

            if (drop_data_ready && drop_occurred && info == TargetType.TEXT_URI_LIST) {
                drop_occurred = false;
                current_actions = 0;
                current_suggested_action = 0;

                Gtk.drag_finish (context, success, false, timestamp);
                on_drag_leave (context, timestamp);
            }
        }

        protected override void on_drag_leave (Gdk.DragContext drag_context, uint time) {
            foreach (BreadcrumbsElement element in elements) {
                if (element.pressed) {
                    element.pressed = false;
                    break;
                }
            }

            drop_occurred = false;
            drop_data_ready = false;
            drop_file_list = null;

            queue_draw ();
        }
    }
}
