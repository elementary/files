using GLib;

[CCode (cheader_filename = "gof-file.h", ref_function = "gof_file_ref", unref_function = "gof_file_unref")]
public class GOF.File : GLib.Object {
    [CCode (cheader_filename = "gof-file.h")]
    public enum ThumbState {
      MASK,
      UNKNOWN,
      NONE,
      READY,
      LOADING,
    }

    [CCode (cname = "GOF_FILE_GIO_DEFAULT_ATTRIBUTES")]
    public const string GIO_DEFAULT_ATTRIBUTES;

    [CCode (cheader_filename = "gof-file.h", has_target = false)]
    public delegate void OperationCallback (GOF.File file, GLib.File? result_location, GLib.Error? error, void* callback_data);

    public signal void changed ();
    public signal void info_available ();
    public signal void destroy ();

    public bool is_gone;
    public GLib.File location;
    public GLib.File target_location;
    public GLib.File directory; /* parent directory location */
    public GLib.Icon? icon;
    public GLib.List<string>? emblems_list;
    public GLib.FileInfo? info;
    public string basename;
    public string uri;
    public uint64 size;
    public string format_size;
    public int color;
    public uint64 modified;
    public string formated_modified;
    public string formated_type;
    public string tagstype;
    public Gdk.Pixbuf? pix;
    public int pix_size;
    public int pix_scale;
    public int width;
    public int height;
    public int sort_column_id;
    public Gtk.SortType sort_order;
    public GLib.FileType file_type;
    public bool is_hidden;
    public bool is_directory;
    public bool is_desktop;
    public bool is_expanded;
    [CCode (cname = "can_unmount")]
    public bool _can_unmount;
    public uint flags;
    public string thumbnail_path;
    public bool is_mounted;
    public bool exists;
    public int uid;
    public int gid;
    public string owner;
    public string group;
    public bool has_permissions;
    public uint32 permissions;
    public GLib.Mount? mount;
    public bool is_connected;

    public static GOF.File @get (GLib.File location);
    public static GOF.File? get_by_uri (string uri) {
        var scheme = GLib.Uri.parse_scheme (uri);
        if (scheme == null) {
            return get_by_commandline_arg (uri);
        }

        var location = GLib.File.new_for_uri (uri);
        if (location == null) {
            return null;
        }

        return GOF.File.get (location);
    }

    public static GOF.File? get_by_commandline_arg (string arg) {
        var location = GLib.File.new_for_commandline_arg (arg);
        return GOF.File.get (location);
    }

    public static File cache_lookup (GLib.File file);
    public static void list_free (GLib.List<GOF.File> files);
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

    public File (GLib.File location, GLib.File? dir);
    public void remove_from_caches ();
    public void set_expanded (bool expanded);
    public bool is_folder();
    public bool is_symlink();
    public bool is_desktop_file();
    public bool is_trashed () {
        return PF.FileUtils.location_is_in_trash (get_target_location ());
    }

    public bool is_readable ();
    public bool is_writable ();
    public bool is_executable ();
    public bool is_mountable ();
    public bool link_known_target;
    public bool is_smb_share ();
    public bool is_smb_server ();

    public unowned string get_display_name ();
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

    public unowned string? get_ftype ();
    public string? get_formated_time (string attr);
    public Gdk.Pixbuf get_icon_pixbuf (int size, int scale, FileIconFlags flags);
    public void get_folder_icon_from_uri_or_path ();
    public Marlin.IconInfo get_icon (int size, int scale, FileIconFlags flags);

    public void update ();
    public void update_type ();
    public void update_icon (int size, int scale);
    public void update_desktop_file ();
    public void query_update ();
    public void query_thumbnail_update ();
    public bool ensure_query_info () {
        if (info == null) {
            query_update ();
        }

        return info != null;
    }

    public unowned string? get_thumbnail_path();
    public bool can_set_owner () {
        /* unknown file uid */
        if (uid == -1)
            return false;

        /* root */
        return Posix.geteuid () == 0;
    }

    public bool can_set_group () {
        if (gid == -1)
            return false;

        var user_id = Posix.geteuid ();

        /* Owner is allowed to set group (with restrictions). */
        if (user_id == uid)
            return true;

        /* Root is also allowed to set group. */
        if (user_id == 0)
            return true;

        return false;
    }

    public bool can_set_permissions () {
        if (uid != -1 && location.is_native ()) {
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

    public static int compare_by_display_name (File file1, File file2);

    public bool is_remote_uri_scheme ();
    public bool is_root_network_folder ();
    public bool is_network_uri_scheme ();
    public bool is_smb_uri_scheme ();
    public bool is_recent_uri_scheme ();

    public string get_display_target_uri () {
        string? targ_uri = info.get_attribute_as_string (GLib.FileAttribute.STANDARD_TARGET_URI);
        if (targ_uri != null) {
            return targ_uri;
        }

        return uri;
    }

    public GLib.AppInfo? get_default_handler () {
        unowned string? content_type = get_ftype ();
        bool must_support_uris = (location.get_path () == null);
        if (content_type != null) {
            return GLib.AppInfo.get_default_for_type (content_type, must_support_uris);
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
        if (is_desktop_file ()) {
            try {
                var key_file = PF.FileUtils.key_file_from_file (location, null);
                app_info = new GLib.DesktopAppInfo.from_keyfile (key_file);
                if (app_info == null) {
                    throw new GLib.FileError.INVAL (_("Failed to parse the desktop file"));
                }
            } catch (GLib.Error e) {
                GLib.Error prefixed_error;
                GLib.Error.propagate_prefixed (out prefixed_error, e, _("Failed to parse the desktop file: "));
                throw prefixed_error;
            }
        } else {
            try {
                app_info = GLib.AppInfo.create_from_commandline (location.get_path (), null, GLib.AppInfoCreateFlags.NONE);
            } catch (GLib.Error e) {
                GLib.Error prefixed_error;
                GLib.Error.propagate_prefixed (out prefixed_error, e, _("Failed to create command from file: "));
                throw prefixed_error;
            }
        }

        try {
            app_info.launch (files, null);
        } catch (GLib.Error e) {
            GLib.Error prefixed_error;
            GLib.Error.propagate_prefixed (out prefixed_error, e, _("Unable to Launch Desktop File: "));
            throw prefixed_error;
        }

        return true;
    }

    public void icon_changed ();
}


[CCode (cheader_filename = "gof-file.h")]
public enum GOF.FileIconFlags
{
    NONE,
    USE_THUMBNAILS
}
