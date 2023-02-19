/* Copyright (c) 2018-20 elementary LLC (https://elementary.io)
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation, Inc.,; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public
 * License along with this program; if not, write to the Free
 * Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 */

public class Files.File : GLib.Object {
    private static GLib.HashTable<GLib.File, Files.File> file_cache;

    public enum IconFlags {
        NONE,
        USE_THUMBNAILS
    }

    public enum ThumbState {
        UNKNOWN,
        NONE,
        READY,
        LOADING
    }

    public const string GIO_DEFAULT_ATTRIBUTES =
        "standard::is-hidden,standard::is-backup,standard::is-symlink,standard::type,standard::name," +
        "standard::display-name,standard::content-type,standard::fast-content-type,standard::size," +
        "standard::symlink-target,standard::target-uri,access::*,time::*,owner::*,trash::*,unix::*,id::filesystem," +
        "thumbnail::*,mountable::*,metadata::marlin-sort-column-id,metadata::marlin-sort-reversed";

    public signal void changed ();
    public signal void icon_changed ();
    public signal void destroy ();

    public bool is_gone;
    public GLib.File location { get; construct; }
    public GLib.File target_location = null;
    public Files.File target_gof = null;
    public GLib.File directory { get; construct; } /* parent directory location */
    public GLib.Icon? icon = null;
    public GLib.List<string>? emblems_list = null;
    public uint n_emblems = 0;
    public GLib.FileInfo? info = null;
    public string basename { get; construct; }
    public string? custom_display_name = null;
    public string uri { get; construct; }
    public uint64 size = 0;
    public string format_size = null;
    public int color = 0;
    public uint64 modified;
    public string formated_modified = null;
    public string formated_type = null;
    public string tagstype = null;
    public Gdk.Pixbuf? pix = null;
    public string? custom_icon_name = null;
    public int pix_size = -1;
    public int pix_scale = -1;
    public int width = 0;
    public int height = 0;
    public int sort_column_id = Files.ListModel.ColumnID.FILENAME;
    public Gtk.SortType sort_order = Gtk.SortType.ASCENDING;
    public GLib.FileType file_type;
    public bool is_hidden = false;
    public bool is_directory = false;
    public bool is_desktop = false;
    public bool is_expanded = false;
    [CCode (cname = "can_unmount")]
    public bool _can_unmount;
    public uint thumbstate = Files.File.ThumbState.UNKNOWN;
    public string thumbnail_path = null;
    public bool is_mounted = true;
    public bool exists = true;
    public uint32 uid;
    public uint32 gid;
    public string owner = null;
    public string group = null;
    public bool has_permissions;
    public uint32 permissions;
    public GLib.Mount? mount = null;
    public bool is_connected = true;
    public string? utf8_collation_key = null;

    public static new Files.File @get (GLib.File location) {
        var parent = location.get_parent ();
        if (parent != null) {
            var dir = Files.Directory.cache_lookup (parent);
            if (dir != null) {
                var file = dir.file_hash_lookup_location (location);
                if (file != null) {
                    return file;
                }
            }
        }

        var file = Files.File.cache_lookup (location);
        if (file == null) {
            file = new Files.File (location, parent);
            lock (file_cache) {
                file_cache.insert (location, file);
            }
        }

        return file;
    }

    public static Files.File? get_by_uri (string uri) {
        var scheme = GLib.Uri.parse_scheme (uri);
        if (scheme == null) {
            return get_by_commandline_arg (uri);
        }

        var location = GLib.File.new_for_uri (uri);
        if (location == null) {
            return null;
        }

        return Files.File.get (location);
    }

    public static Files.File? get_by_commandline_arg (string arg) {
        var location = GLib.File.new_for_commandline_arg (arg);
        return Files.File.get (location);
    }

    public static File cache_lookup (GLib.File file) {
        lock (file_cache) {
            if (file_cache == null) {
                file_cache = new GLib.HashTable<GLib.File, Files.File> (GLib.File.hash, GLib.File.equal);
            }
        }

        return file_cache.lookup (file);
    }

    public static GLib.Mount? get_mount_at (GLib.File location) {
        var volume_monitor = GLib.VolumeMonitor.get ();
        foreach (unowned GLib.Mount mount in volume_monitor.get_mounts ()) {
            if (mount.is_shadowed ()) {
                continue;
            }

            var root = mount.get_root ();
            if (root.equal (location)) {
                return mount;
            }
        }

        return null;
    }

    public File (GLib.File location, GLib.File? dir = null) {
        Object (
            location: location,
            uri: location.get_uri (),
            basename: location.get_basename (),
            directory: dir
        );
    }

    construct {
        icon_changed.connect (() => {
            if (directory != null) {
                var dir = Files.Directory.cache_lookup (directory);
                if (dir != null && (!is_hidden || Files.Preferences.get_default ().show_hidden_files)) {
                    dir.icon_changed (this);
                }
            }
        });
    }

    public void remove_from_caches () {
        /* remove from file_cache */
        if (file_cache != null && file_cache.remove (location)) {
            debug ("remove from file_cache %s", uri);
        }

        is_gone = true;
    }

    public void set_expanded (bool expanded) {
        GLib.return_if_fail (is_directory);
        is_expanded = expanded;
    }

    public bool is_folder () {
        /* TODO check this works for non-local files and other uri schemes */
        if (is_directory && !is_root_network_folder ()) {
            return true;
        }

        if (is_smb_share ()) {
            return true;
        }

        if (file_type == GLib.FileType.MOUNTABLE &&
            info != null && info.get_attribute_boolean (GLib.FileAttribute.MOUNTABLE_CAN_MOUNT)) {

            return true;
        }

        if (target_gof != null && target_gof.is_directory && target_gof.is_network_uri_scheme ()) {
            return true;
        }

        return false;
    }

    public bool is_symlink () {
        if (info == null) {
            return false;
        }

        return info.get_is_symlink ();
    }

    public bool is_desktop_file () {
        if (info == null) {
            return false;
        }

        bool is_desktop_file = false;
        unowned string? content_type = get_ftype ();
        if (content_type != null) {
            is_desktop_file = GLib.ContentType.is_mime_type (content_type, "application/x-desktop");
        }

        return is_desktop_file && !basename.has_suffix (".directory");
    }

    public bool is_image () {
        if (info == null) {
            return false;
        }

        bool is_image = false;
        unowned string? content_type = get_ftype ();
        if (content_type != null) {
            is_image = GLib.ContentType.is_mime_type (content_type, "image/*");
        }

        return is_image;
    }

    public bool is_trashed () {
        return FileUtils.location_is_in_trash (get_target_location ());
    }

    public bool is_readable () {
        if (target_gof != null && !location.equal (target_gof.location)) {
            return target_gof.is_readable ();
        } else if (info != null && info.has_attribute (GLib.FileAttribute.ACCESS_CAN_READ)) {
            return info.get_attribute_boolean (GLib.FileAttribute.ACCESS_CAN_READ);
        } else if (has_permissions) {
            return (permissions & Posix.S_IROTH) != 0 ||
                   (permissions & Posix.S_IRUSR) != 0 && (uid < 0 || uid == Posix.geteuid ()) ||
                   (permissions & Posix.S_IRGRP) != 0 && PF.UserUtils.user_in_group (group);
        } else {
            return true; /* We will just have to assume we can read the file */
        }
    }

    public bool is_writable () {
        if (target_gof != null && !location.equal (target_gof.location)) {
            return target_gof.is_writable ();
        }

        if (info != null && info.has_attribute (GLib.FileAttribute.ACCESS_CAN_WRITE)) {
            return info.get_attribute_boolean (GLib.FileAttribute.ACCESS_CAN_WRITE);
        }

        if (has_permissions) {
            return (permissions & Posix.S_IWOTH) > 0 ||
                   (permissions & Posix.S_IWUSR) > 0 && (uid < 0 || uid == Posix.geteuid ()) ||
                   (permissions & Posix.S_IWGRP) > 0 && PF.UserUtils.user_in_group (group);
        } else {
            /* We will just have to assume we can write to the file */
            return true;
        }
    }

    public bool is_executable () {
        if (target_gof != null) {
            return target_gof.is_executable ();
        }

        if (info == null) {
            return false;
        }

        if (info.get_attribute_boolean (GLib.FileAttribute.ACCESS_CAN_EXECUTE)) {
            unowned string? content_type = get_ftype ();
            if (content_type != null && GLib.ContentType.is_a (content_type, "application/x-executable")) {
                return true;
            }
        }

        return false;
    }

    public bool is_mountable () {
        GLib.return_val_if_fail (info != null, false);
        return info.get_file_type () == GLib.FileType.MOUNTABLE;
    }

    public bool link_known_target;
    public bool is_smb_share () {
        if (is_smb_uri_scheme () || is_network_uri_scheme ()) {
            return get_number_of_uri_parts () == 3;
        }

        return false;
    }

    public bool is_smb_server () {
        if (is_smb_uri_scheme () || is_network_uri_scheme ()) {
            return get_number_of_uri_parts () == 2;
        }

        return false;
    }

    public unowned string get_display_name () {
        return custom_display_name ?? basename;
    }

    public unowned GLib.File get_target_location () {
        if (target_location != null) {
            return target_location;
        }

        return location;
    }

    public unowned string? get_symlink_target () {
        if (info == null) {
            return null;
        }

        return info.get_symlink_target ();
    }

    public unowned string? get_ftype () {
        if (info == null || is_location_uri_default ()) {
            return null;
        }

        if (is_directory) {
            return "inode/directory";
        }

        if (info.has_attribute (GLib.FileAttribute.STANDARD_CONTENT_TYPE)) {
            return info.get_attribute_string (GLib.FileAttribute.STANDARD_CONTENT_TYPE);
        }

        unowned string ftype = null;
        if (info.has_attribute (GLib.FileAttribute.STANDARD_FAST_CONTENT_TYPE)) {
            ftype = info.get_attribute_string (GLib.FileAttribute.STANDARD_FAST_CONTENT_TYPE);
        }

        /* If octet-stream then check tagtype */
        if (ftype == "application/octet-stream" && tagstype != null) {
            return tagstype;
        }

        return ftype;
    }

    public string? get_formated_time (string attr) {
        return FileUtils.get_formatted_time_attribute_from_info (info, attr);
    }

    public Gdk.Pixbuf? get_icon_pixbuf (int size, int scale, Files.File.IconFlags flags) {
        GLib.return_val_if_fail (size >= 1, null);

        var nicon = get_icon (size, scale, flags);
        return nicon != null ? nicon.get_pixbuf_nodefault () : null;
    }

    public void get_folder_icon_from_uri_or_path () {
        if (icon != null) {
            return;
        }

        if (!is_hidden && uri != null) {
            try {
                var path = GLib.Filename.from_uri (uri);
                icon = get_icon_user_special_dirs (path);
            } catch (Error e) {
                debug (e.message);
            }
        }

        if (icon == null && !location.is_native () && is_remote_uri_scheme ()) {
            icon = new GLib.ThemedIcon ("folder-remote");
        }

        if (icon == null) {
            icon = new GLib.ThemedIcon ("folder");
        }
    }

    public Files.IconInfo? get_icon (int size, int scale, Files.File.IconFlags flags) {
        GLib.return_val_if_fail (size >= 1, null);

        Files.IconInfo? icon = get_special_icon (size, scale, flags);
        if (icon != null && !icon.is_fallback ()) {
            return icon;
        }

        GLib.Icon? gicon = null;
        if (Files.File.IconFlags.USE_THUMBNAILS in flags && this.thumbstate == Files.File.ThumbState.LOADING) {
            gicon = new GLib.ThemedIcon ("image-loading");
        } else {
            gicon = this.icon;
        }

        if (gicon != null) {
            icon = Files.IconInfo.lookup (gicon, size, scale);
            if (icon == null || icon.is_fallback ()) {
                icon = Files.IconInfo.get_generic_icon (size, scale);
            }
        } else {
            icon = Files.IconInfo.get_generic_icon (size, scale);
        }

        return icon;
    }

    public void update () {
        GLib.return_if_fail (info != null);

        /* free previously allocated */
        clear_info ();
        is_hidden = info.get_is_hidden () || info.get_is_backup ();
        size = info.get_size ();
        file_type = info.get_file_type ();
        is_directory = (file_type == GLib.FileType.DIRECTORY);
        modified = info.get_attribute_uint64 (GLib.FileAttribute.TIME_MODIFIED);

        /* metadata */
        if (is_directory) {
            if (info.has_attribute ("metadata::marlin-sort-column-id")) {
                sort_column_id = Files.ListModel.ColumnID.from_string (
                                     info.get_attribute_string ("metadata::marlin-sort-column-id")
                                 );
            }

            if (info.has_attribute ("metadata::marlin-sort-reversed")) {
                sort_order = info.get_attribute_string ("metadata::marlin-sort-reversed") == "true" ?
                                                        Gtk.SortType.DESCENDING : Gtk.SortType.ASCENDING;
            }
        }

        if (info.has_attribute (GLib.FileAttribute.STANDARD_ICON)) {
            icon = info.get_attribute_object (GLib.FileAttribute.STANDARD_ICON) as GLib.Icon;
        }

        /* Any location or target on a mount will now have the file->mount and file->is_mounted set */
        unowned string target_uri = info.get_attribute_string (GLib.FileAttribute.STANDARD_TARGET_URI);
        if (target_uri != null) {
            if (Uri.parse_scheme (target_uri) == "afp") {
                target_location = GLib.File.new_for_uri (FileUtils.get_afp_target_uri (target_uri, uri));
            } else {
                target_location = GLib.File.new_for_uri (target_uri);
            }

            target_location_update ();

            try {
                mount = target_location.find_enclosing_mount ();
                is_mounted = (mount != null);
            } catch (Error e) {
                is_mounted = false;
                debug (e.message);
            }
        } else {
            try {
                mount = location.find_enclosing_mount ();
                is_mounted = (mount != null);
            } catch (Error e) {
                is_mounted = false;
                debug (e.message);
            }
        }

        /* TODO the key-files could be loaded async.
        <lazy>The performance gain would not be that great</lazy>*/
        is_desktop = is_desktop_file ();
        if (is_desktop) {
            try {
                var key_file = FileUtils.key_file_from_file (location);
                custom_icon_name = key_file.get_string (GLib.KeyFileDesktop.GROUP, GLib.KeyFileDesktop.KEY_ICON);
                /* drop any suffix (e.g. '.png') from themed icons */
                if (!GLib.Path.is_absolute (custom_icon_name)) {
                    custom_icon_name = custom_icon_name.split (".", 2)[0];
                }
            } catch (Error e) {
                debug (e.message);
            }

            /* Do not show name from desktop file as this can be used as an exploit (lp:1660742) */
            try {
                var key_file = FileUtils.key_file_from_file (location);
                var type = key_file.get_string (GLib.KeyFileDesktop.GROUP, GLib.KeyFileDesktop.KEY_TYPE);
                if (type == GLib.KeyFileDesktop.TYPE_LINK) {
                    var url = key_file.get_string (GLib.KeyFileDesktop.GROUP, GLib.KeyFileDesktop.KEY_URL);
                    target_location = GLib.File.new_for_uri (url);
                    target_location_update ();
                }
            } catch (Error e) {
                debug (e.message);
            }
        }

        /* Use custom_display_name to store default display name if there is no custom name */
        if (custom_display_name == null && info != null) {
            unowned string disp_name = info.get_display_name ();
            string? target_uri_scheme = target_location != null ? target_location.get_uri_scheme () : null;
            if (directory != null && directory.get_uri_scheme () == "network" && target_uri_scheme != "smb") {
                /* Show protocol after server name (lp:1184606) */
                custom_display_name = "%s (%s)".printf (disp_name, (string)target_uri_scheme.to_utf8 ());
            } else {
                custom_display_name = disp_name;
            }
        }

        /* sizes */
        update_size ();
        /* modified date */
        if (info.has_attribute (GLib.FileAttribute.TIME_MODIFIED)) {
            formated_modified = get_formated_time (GLib.FileAttribute.TIME_MODIFIED);
        } else {
            formated_modified = _("Inaccessible");
        }

        /* icon */
        if (is_directory) {
            get_folder_icon_from_uri_or_path ();
        } else if (info.get_file_type () == GLib.FileType.MOUNTABLE) {
            icon = new GLib.ThemedIcon.with_default_fallbacks ("folder-remote");
        } else {
            unowned string? ftype = get_ftype ();
            if (ftype != null && icon == null) {
                icon = GLib.ContentType.get_icon (ftype);
            }
        }

        utf8_collation_key = get_display_name ().collate_key_for_filename ();
        /* mark the thumb flags as state none, we'll load the thumbs once the directory
         * would be loaded on a thread */
        if (get_thumbnail_path () != null) {
            thumbstate = Files.File.ThumbState.UNKNOWN;  /* UNKNOWN means thumbnail not known to be unobtainable */
        }

        /* formated type */
        update_formated_type ();

        /* permissions */
        has_permissions = info.has_attribute (GLib.FileAttribute.UNIX_MODE);
        permissions = info.get_attribute_uint32 (GLib.FileAttribute.UNIX_MODE);
        owner = info.get_attribute_string (GLib.FileAttribute.OWNER_USER);
        group = info.get_attribute_string (GLib.FileAttribute.OWNER_GROUP);
        if (info.has_attribute (GLib.FileAttribute.UNIX_UID)) {
            uid = info.get_attribute_uint32 (GLib.FileAttribute.UNIX_UID);
            if (owner == null) {
                owner = uid.to_string ();
            }
        } else if (owner != null) { /* e.g. ftp info yields owner but not uid */
            uid = int.parse (owner);
        } else {
            owner = null;
        }

        if (info.has_attribute (GLib.FileAttribute.UNIX_GID)) {
            gid = info.get_attribute_uint32 (GLib.FileAttribute.UNIX_GID);
            if (group == null) {
                group = gid.to_string ();
            }
        } else if (group != null) { /* e.g. ftp info yields owner but not uid */
            gid = int.parse (group);
        } else {
            group = null;
        }

        if (info.has_attribute (GLib.FileAttribute.MOUNTABLE_CAN_UNMOUNT)) {
            _can_unmount = info.get_attribute_boolean (GLib.FileAttribute.MOUNTABLE_CAN_UNMOUNT);
        }

        update_emblem ();
    }

    public void update_type () {
        update_formated_type ();

        unowned string? ftype = get_ftype ();
        if (ftype != null) {
            icon = GLib.ContentType.get_icon (ftype);
        }

        if (pix_size > 1 && pix_scale > 0) {
            update_icon (pix_size, pix_scale);
            icon_changed ();
        }
    }

    public void update_icon (int size, int scale) {
        if (size <= 1) {
            return;
        }

        if (pix != null && pix_size == size && pix_scale == scale) {
            return;
        }

        update_icon_internal (size, scale);
    }

    public void update_desktop_file () {
        utf8_collation_key = get_display_name ().collate_key_for_filename ();
        update_formated_type ();
        update_size ();
        icon_changed ();
    }

    public void query_update () {
        var _info = query_info ();
        if (_info != null) {
            info = _info;
            update ();
        }
    }

    public void query_thumbnail_update () {
        /* Silently ignore invalid requests */
        if (pix_size <= 1 || pix_scale <= 0) {
            return;
        }
        if (get_thumbnail_path () == null && thumbstate == ThumbState.READY) {
            var md5_hash = GLib.Checksum.compute_for_string (GLib.ChecksumType.MD5, uri);
            var base_name = "%s.png".printf (md5_hash);

            /* Use $XDG_CACHE_HOME specified thumbnail directory instead of hard coding */
            unowned string folder_size = "normal";
            if (pix_size * pix_scale > 128) {
                folder_size = "large";
            }

            thumbnail_path = GLib.Path.build_filename (
                GLib.Environment.get_user_cache_dir (),
                "thumbnails",
                folder_size,
                base_name
            );
        }

        update_icon_internal (pix_size, pix_scale);
    }

    public bool ensure_query_info () {
        if (info == null) {
            query_update ();
        }

        return info != null;
    }

    public unowned string? get_thumbnail_path () {
        unowned string? path = null;
        if (thumbnail_path != null) {
            path = thumbnail_path;
        } else if (info != null && info.has_attribute (GLib.FileAttribute.THUMBNAIL_PATH)) {
            path = info.get_attribute_byte_string (GLib.FileAttribute.THUMBNAIL_PATH);
        }

        return path;
    }

    public bool can_set_owner () {
        /* unknown file uid */
        if (uid == -1 ||
            owner == null ||
            uid == uint.parse (owner) ||
            is_trashed ()) {

            return false;
        }
        /* root */
        return Posix.geteuid () == 0;
    }

    public bool can_set_group () {
        if (gid == -1 ||
            group == null ||
            gid == uint.parse (group) ||
            is_trashed ()) {

            return false;
        }

        var user_id = Posix.geteuid ();
        /* Owner is allowed to set group (with restrictions). */
        if (user_id == uid) {
            return true;
        }

        /* Root is also allowed to set group. */
        if (user_id == 0)
            return true;

        return false;
    }

    public bool can_set_permissions () {
        if (uid == -1 ||
            owner == null ||
            uid == uint.parse (owner) ||
            is_trashed ()) {

            return false;
        }

        if (location.is_native ()) {
            /* Check the user. */
            Posix.uid_t user_id = Posix.geteuid ();
            /* Owner is allowed to set permissions. */
            if (user_id == uid) {
                return true;
            }

            /* Root is also allowed to set permissions. */
            if (user_id == 0) {
                return true;
            }

            /* Nobody else is allowed. */
            return false;
        }

        /* pretend to have full chmod rights when no info is available, relevant when
         * the FS can't provide ownership info, for instance for FTP */
        return true;
    }

    public bool can_unmount () {
        return _can_unmount || (mount != null && mount.can_unmount ());
    }

    public string get_permissions_as_string () {
        bool is_link = is_symlink ();

        /* We use ls conventions for displaying these three obscure flags */
        bool suid = (permissions & Posix.S_ISUID) != 0;
        bool sgid = (permissions & Posix.S_ISGID) != 0;
        bool sticky = (permissions & Posix.S_ISVTX) != 0;

        return "%c%c%c%c%c%c%c%c%c%c".printf (
            is_link ? 'l' : is_directory ? 'd' : '-',
            (permissions & Posix.S_IRUSR) != 0 ? 'r' : '-',
            (permissions & Posix.S_IWUSR) != 0 ? 'w' : '-',
            (permissions & Posix.S_IXUSR) != 0 ? (suid ? 's' : 'x') : (suid ? 'S' : '-'),
            (permissions & Posix.S_IRGRP) != 0 ? 'r' : '-',
            (permissions & Posix.S_IWGRP) != 0 ? 'w' : '-',
            (permissions & Posix.S_IXGRP) != 0 ? (sgid ? 's' : 'x') : (sgid ? 'S' : '-'),
            (permissions & Posix.S_IROTH) != 0 ? 'r' : '-',
            (permissions & Posix.S_IWOTH) != 0 ? 'w' : '-',
            (permissions & Posix.S_IXOTH) != 0 ? (sticky ? 't' : 'x') : (sticky ? 'T' : '-')
        );
    }

    public GLib.List<string>? get_settable_group_names () {
        if (!can_set_group ()) {
            return null;
        }

        var user_id = Posix.geteuid ();
        if (user_id == 0) {
            return PF.UserUtils.get_all_group_names ();
        } else if (user_id == uid) {
            return PF.UserUtils.get_group_names_for_user ();
        } else {
            warning ("unhandled case");
        }

        return null;
    }

    public bool is_remote_uri_scheme () {
        return (is_root_network_folder () || is_other_uri_scheme ());
    }

    public bool is_root_network_folder () {
        return (is_network_uri_scheme () || is_smb_server ());
    }

    public bool is_network_uri_scheme () {
        if (!(location is GLib.File)) {
            return true;
        }

        return location.has_uri_scheme ("network");
    }

    public bool is_smb_uri_scheme () {
        if (!(location is GLib.File)) {
            return true;
        }

        return location.has_uri_scheme ("smb");
    }

    public bool is_recent_uri_scheme () {
        if (!(location is GLib.File)) {
            return true;
        }

        return location.has_uri_scheme ("recent");
    }

    public bool is_other_uri_scheme () {
        if (!(location is GLib.File)) {
            return true;
        }

        return location.has_uri_scheme ("ftp") ||
               location.has_uri_scheme ("sftp") ||
               location.has_uri_scheme ("afp") ||
               location.has_uri_scheme ("dav") ||
               location.has_uri_scheme ("davs");
    }

    public string get_display_target_uri () {
        string? targ_uri = info.get_attribute_as_string (GLib.FileAttribute.STANDARD_TARGET_URI);
        if (targ_uri != null) {
            return targ_uri;
        }

        return uri;
    }

    public GLib.AppInfo? get_default_handler () {
        unowned string? content_type = get_ftype ();
        if (content_type != null) {
            return GLib.AppInfo.get_default_for_type (content_type, location.get_path () == null);
        }

        if (target_location != null) {
            try {
                return target_location.query_default_handler ();
            } catch (GLib.Error e) {
                GLib.critical (e.message);
                return null;
            }
        }

        try {
            return location.query_default_handler ();
        } catch (GLib.Error e) {
            GLib.critical (e.message);
            return null;
        }
    }

    public bool execute (GLib.List<GLib.File>? files) throws GLib.Error {
        if (!location.is_native ()) {
            return false;
        }

        GLib.AppInfo app_info = null;
        var context = Gdk.Display.get_default ().get_app_launch_context ();
        context.set_timestamp (Gdk.CURRENT_TIME);

        if (is_desktop_file ()) { // Desktop files never executed in practice?
            try {
                var key_file = FileUtils.key_file_from_file (location, null);
                app_info = new GLib.DesktopAppInfo.from_keyfile (key_file);
                if (app_info == null) {
                    throw new GLib.FileError.INVAL (_("Failed to parse the desktop file"));
                }
            } catch (GLib.Error e) {
                GLib.Error prefixed_error;
                GLib.Error.propagate_prefixed (out prefixed_error, e, _("Failed to parse the desktop file: "));
                throw prefixed_error;
            }

            try {
                app_info.launch (files, context);
            } catch (GLib.Error e) {
                GLib.Error prefixed_error;
                GLib.Error.propagate_prefixed (out prefixed_error, e, _("Unable to Launch Desktop File: "));
                throw prefixed_error;
            }
        } else { // Always launch scripts etc in terminal so can see any output
            try {
                var path = location.get_path ();
                /* While io.elementary.terminal does not deal with spaces in the command (and removes escaping)
                 * we have to double escape them */
                var command = "io.elementary.terminal --working-directory=%s --commandline=%s".printf (
                    FileUtils.get_parent_path_from_path (path).replace ("file://", "").replace (" ", "\\\\ "),
                    path.replace (" ", "\\\\ ")
                );

                app_info = GLib.AppInfo.create_from_commandline (
                    command, this.basename, GLib.AppInfoCreateFlags.NONE
                );

                context.setenv ("PWD", Shell.quote (FileUtils.get_parent_path_from_path (path)));
                app_info.launch (null, context);
            } catch (GLib.Error e) {
                GLib.Error prefixed_error;
                GLib.Error.propagate_prefixed (out prefixed_error, e, _("Failed to create command from file: "));
                throw prefixed_error;
            }
        }

        return true;
    }

    public int compare_for_sort (Files.File other, int sort_type, bool directories_first, bool reversed) {
        if (other == this) {
            return 0;
        }

        if (directories_first) {
            /* When comparing files of different type, need to cancel out the native sorting of the TreeView
             * so directories always come first. */
            if (is_folder () && !other.is_folder ()) {
                return reversed ? 1 : -1;
            } else if (other.is_folder () && !is_folder ()) {
                return reversed ? -1 : 1;
            }
        }

        //Always sort files of same type in ASCENDING order as the TreeView will reverse them if needed
        int result = 0;
        switch (sort_type) {
            case Files.ListModel.ColumnID.FILENAME:
                result = compare_by_display_name (other);
                break;
            case Files.ListModel.ColumnID.SIZE:
                result = compare_by_size (other);
                if (result == 0) {
                    result = compare_by_display_name (other);
                }

                break;
            case Files.ListModel.ColumnID.TYPE:
                result = compare_by_type (other);
                if (result == 0) {
                    result = compare_by_display_name (other);
                }

                break;
            case Files.ListModel.ColumnID.MODIFIED:
                result = compare_files_by_time (other);
                if (result == 0) {
                    result = compare_by_display_name (other);
                }

                break;
            default:
                assert_not_reached ();
        }

        return result;
    }

    public int compare_by_display_name (Files.File other) {
        /* We want files starting with these characters to be last */
        const char SORT_LAST_CHAR1 = '.';
        const char SORT_LAST_CHAR2 = '#';

        unowned string name1 = get_display_name ();
        unowned string name2 = other.get_display_name ();

        bool sort_last1 = ((name1[0] == SORT_LAST_CHAR1) || (name1[0] == SORT_LAST_CHAR2));
        bool sort_last2 = ((name2[0] == SORT_LAST_CHAR1) || (name2[0] == SORT_LAST_CHAR2));


        if (sort_last1 && !sort_last2) {
            return 1;
        } else if (!sort_last1 && sort_last2) {
            return -1;
        } else {
            return GLib.strcmp (utf8_collation_key, other.utf8_collation_key);
        }
    }

    public void update_emblem () {
        /* Do not try to add emblems to network and remote files (except smb)
         * can cause blocking io */
        if (is_other_uri_scheme () || is_network_uri_scheme ()) {
            return;
        }

        /* Do not try to add emblems to smb shares either */
        if (is_smb_share ()) {
            return;
        }

        /* erase previous stored emblems */
        if (emblems_list != null) {
            emblems_list = null;
            n_emblems = 0;
        }

        if (is_symlink () || (is_desktop && target_gof != null)) {
            add_emblem ("emblem-symbolic-link");
        }

        /* We hide lock emblems if in Recents, because files here are not
         * real files and emblems would always shown. */
        if (!is_writable () && !is_recent_uri_scheme ()) {
            if (is_readable ()) {
                add_emblem ("emblem-readonly");
            } else {
                add_emblem ("emblem-unreadable");
            }
        }
    }

    public void add_emblem (string emblem) {
        if (emblems_list != null) {
            foreach (unowned string emblem_item in emblems_list) {
                if (emblem_item == emblem) {
                    return;
                }
            }
        } else {
            emblems_list = new GLib.List<string> ();
        }

        emblems_list.append (emblem);
        n_emblems++;
        icon_changed ();
    }

    private void target_location_update () {
        if (target_location == null) {
            return;
        }

        target_gof = Files.File.get (target_location);
        target_gof.query_update ();
    }

    private void clear_info () {
        target_location = null;
        mount = null;
        utf8_collation_key = null;
        formated_type = null;
        format_size = null;
        formated_modified = null;
        icon = null;
        custom_display_name = null;
        custom_icon_name = null;

        uid = -1;
        gid = -1;
        has_permissions = false;
        permissions = 0;
        owner = null;
        group = null;
        _can_unmount = false;
    }

    private GLib.FileInfo? query_info () {
        if (!(location is GLib.File) || location.get_uri ().has_prefix (Files.NETWORK_URI)) {
            return null;
        }

        is_mounted = true;
        exists = true;
        is_connected = true;
        try {
            return location.query_info ("*", GLib.FileQueryInfoFlags.NONE);
        } catch (GLib.IOError.NOT_MOUNTED e) {
            is_mounted = false;
            debug (e.message);
        } catch (GLib.IOError.NOT_FOUND e) {
            exists = false;
            debug (e.message);
        } catch (GLib.IOError.NOT_DIRECTORY e) {
            exists = false;
            debug (e.message);
        } catch (GLib.IOError.TIMED_OUT e) {
            is_connected = false;
            debug (e.message);
        } catch (GLib.Error e) {
            debug (e.message);
        }

        return null;
    }

    private void update_size () {
        if (is_folder () || is_root_network_folder ()) {
            format_size = item_count ();
        } else if (info.has_attribute (GLib.FileAttribute.STANDARD_SIZE)) {
            format_size = GLib.format_size (size);
        } else {
            format_size = _("Inaccessible");
        }
    }

    private string item_count () {
        if (is_mounted && location.is_native ()) {
            try {
                var f_enum = location.enumerate_children ("", FileQueryInfoFlags.NONE, null);
                var count = 0;
                while (f_enum.next_file () != null) {
                    count++;
                }

                if (count == 0) {
                    return _("Empty");
                } else {
                    return ngettext ("%i item", "%i items", count).printf (count);
                }
            } catch (Error e) {
                return _("Inaccessible");
            }
        }

        return _("----");
    }

    private void update_formated_type () {
        unowned string? ftype = get_ftype ();
        if (ftype != null) {
            if (is_symlink ()) {
                formated_type = _("link to %s").printf (GLib.ContentType.get_description (ftype));
            } else {
                formated_type = GLib.ContentType.get_description (ftype);
            }
        } else {
            formated_type = "";
        }
    }

    public GLib.Icon? get_icon_user_special_dirs (string path) {
        if (path == GLib.Environment.get_home_dir ()) {
            return new GLib.ThemedIcon ("user-home");
        } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.DESKTOP)) {
            return new GLib.ThemedIcon ("user-desktop");
        } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.DOCUMENTS)) {
            return new GLib.ThemedIcon ("folder-documents");
        } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.DOWNLOAD)) {
            return new GLib.ThemedIcon ("folder-download");
        } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.MUSIC)) {
            return new GLib.ThemedIcon ("folder-music");
        } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.PICTURES)) {
            return new GLib.ThemedIcon ("folder-pictures");
        } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.PUBLIC_SHARE)) {
            return new GLib.ThemedIcon ("folder-publicshare");
        } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.TEMPLATES)) {
            return new GLib.ThemedIcon ("folder-templates");
        } else if (path == GLib.Environment.get_user_special_dir (GLib.UserDirectory.VIDEOS)) {
            return new GLib.ThemedIcon ("folder-videos");
        }

        return null;
    }

    private uint get_number_of_uri_parts () {
        unowned string target_uri = null;
        if (info != null) {
            target_uri = info.get_attribute_string (GLib.FileAttribute.STANDARD_TARGET_URI);
        }

        if (target_uri == null) {
            target_uri = uri;
        }

        return target_uri.split ("/", 6).length;
    }

    private bool is_location_uri_default () {
        GLib.return_val_if_fail (info != null, false);
        unowned string? target_uri = info.get_attribute_string (GLib.FileAttribute.STANDARD_TARGET_URI);
        if (target_uri == null) {
            target_uri = uri;
        }

        var split = target_uri.split ("/", 4);
        return split[3] == null || split[3] == "";
    }

    // We want date to sort in reverse order by default
    private int compare_files_by_time (Files.File other) {
        if (modified < other.modified)
            return 1;
        else if (modified > other.modified)
            return -1;

        return 0;
    }

    private int compare_by_type (Files.File other) {
        /* Directories go first. Then, if mime types are identical,
         * don't bother getting strings (for speed). This assumes
         * that the string is dependent entirely on the mime type,
         * which is true now but might not be later.
         */
        if (is_folder () && other.is_folder ()) {
            return 0;
        } else if (is_folder ()) {
            return -1;
        } else if (other.is_folder ()) {
            return 1;
        }

        return formated_type.collate (other.formated_type);
    }

    private int compare_files_by_size (Files.File other) {
        if (size < other.size) {
            return -1;
        } else if (size > other.size) {
            return 1;
        }

        return 0;
    }

    private int compare_by_size (Files.File other) {
        /* As folder files have a fixed standard size (4K) assign them a virtual size of -1 for now
         * so always sorts first. */

        /* TODO Sort folders according to number of files inside like Dolphin? */
        if (is_folder () && !other.is_folder ()) {
            return -1;
        }

        if (other.is_folder () && !is_folder ()) {
            return 1;
        }

        if (is_folder () && other.is_folder ()) {
            return 0;
        }

        /* Only compare sizes for regular files */
        return compare_files_by_size (other);
    }

    private void update_icon_internal (int size, int scale) {
        GLib.return_if_fail (size >= 1);
        pix = get_icon_pixbuf (size, scale, Files.File.IconFlags.USE_THUMBNAILS);
        pix_size = size;
        pix_scale = scale;
    }

    private Files.IconInfo? get_special_icon (int size, int scale, Files.File.IconFlags flags) {
        GLib.return_val_if_fail (size >= 1, null);

        if (custom_icon_name != null) {
            if (GLib.Path.is_absolute (custom_icon_name)) {
                return Files.IconInfo.lookup_from_path (custom_icon_name, size, scale);
            } else {
                return Files.IconInfo.lookup_from_name (custom_icon_name, size, scale);
            }
        }

        if (Files.File.IconFlags.USE_THUMBNAILS in flags && this.thumbstate == Files.File.ThumbState.READY) {
            unowned string? thumb_path = get_thumbnail_path ();
            if (thumb_path != null) {
                return Files.IconInfo.lookup_from_path (thumb_path, size, scale);
            }
        }

        return null;
    }
}
