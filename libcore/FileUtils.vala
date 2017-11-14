/***
    Copyright (c) 2015-2017 elementary LLC (http://launchpad.net/elementary)

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation, Inc.,.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/
namespace PF.FileUtils {
    /**
     * Gets a properly escaped GLib.File for the given path
     **/
    const string reserved_chars = (GLib.Uri.RESERVED_CHARS_GENERIC_DELIMITERS + GLib.Uri.RESERVED_CHARS_SUBCOMPONENT_DELIMITERS + " ");

    public File? get_file_for_path (string? path) {
        string? new_path = sanitize_path (path);

        if (new_path != null && new_path.length > 0) {
            return  File.new_for_commandline_arg (new_path);
        } else {
            return null;
        }
    }

    public string get_parent_path_from_path (string path) {
        /* We construct the parent path rather than use File.get_parent () as the latter gives odd
         * results for some gvfs files.
         */
        string parent_path = construct_parent_path (path);
        if (parent_path == Marlin.FTP_URI ||
            parent_path == Marlin.SFTP_URI) {

            parent_path = path;
        }

        if (parent_path.has_prefix (Marlin.MTP_URI) && !valid_mtp_uri (parent_path)) {
            parent_path = path;
        }

        if (parent_path == Marlin.SMB_URI) {
            parent_path = parent_path + Path.DIR_SEPARATOR_S;
        }
        return parent_path;
    }

    public void restore_files_from_trash (GLib.List<GOF.File> files, Gtk.Widget? widget) {
        GLib.List<GOF.File>? unhandled_files = null;
        var original_dirs_hash = get_trashed_files_original_directories (files, out unhandled_files);

        foreach (GOF.File goffile in unhandled_files) {
            var message = _("Could not determine original location of \"%s\" ").printf (goffile.get_display_name ());
            Eel.show_warning_dialog (message, _("The item cannot be restored from trash"),
                                     (widget is Gtk.Window) ? widget as Gtk.Window : null );
        }

        original_dirs_hash.foreach ((original_dir, dir_files) => {
                Marlin.FileOperations.copy_move_link (dir_files,
                                                      null,
                                                      original_dir,
                                                      Gdk.DragAction.MOVE,
                                                      widget,
                                                      null,
                                                      null);
        });
    }

    private GLib.HashTable<GLib.File, GLib.List<GLib.File>> get_trashed_files_original_directories (GLib.List<GOF.File> files, out GLib.List<GOF.File> unhandled_files) {
        var directories = new GLib.HashTable<GLib.File, GLib.List<GLib.File>> (File.hash, File.equal);
        unhandled_files = null;

        foreach (GOF.File goffile in files) {
            /* Check it is a valid file (e.g. not a dummy row from list view) */
            if (goffile == null || goffile.location == null) {
                continue;
            }

            /* Check that file is in root of trash.  If not, do not try to restore
             * (it will be restored with its parent anyway) */
            if (Path.get_dirname (goffile.uri) == "trash:") {
                /* We are in trash root */
                var original_dir = get_trashed_file_original_folder (goffile);
                if (original_dir != null) {
                    unowned GLib.List<GLib.File>? dir_files = null;
                    dir_files = directories.lookup (original_dir); /* get list of files being restored to this original dir */
                    if (dir_files != null) {
                        directories.steal (original_dir);
                    }
                    dir_files.prepend (goffile.location);
                    directories.insert (original_dir, dir_files.copy ());
                } else {
                    unhandled_files.prepend (goffile);
                }
            }
        }

        return directories;
   }

    private GLib.File? get_trashed_file_original_folder (GOF.File file) {
        GLib.FileInfo? info = null;
        string? original_path = null;

        if (file.info == null) {
            if (file.location != null) {
                try {
                    info = file.location.query_info (GLib.FileAttribute.TRASH_ORIG_PATH, GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
                } catch (GLib.Error e) {
                    debug ("Error querying info of trashed file %s - %s", file.uri, e.message);
                    return null;
                }
            }
        } else {
            info = file.info.dup ();
        }

        if (info != null && info.has_attribute (GLib.FileAttribute.TRASH_ORIG_PATH)) {
            original_path = file.info.get_attribute_byte_string (GLib.FileAttribute.TRASH_ORIG_PATH);
        }

        if (original_path != null) {
            debug ("Original path of trashed file %s was %s", file.uri, original_path);
            return get_file_for_path (get_parent_path_from_path (original_path));
        } else {
            debug ("Could not get original path for trashed file %s", file.uri);
            return null;
        }
    }

    private string construct_parent_path (string path) {
        if (path.length < 2) {
            return Path.DIR_SEPARATOR_S;
        }
        StringBuilder sb = new StringBuilder (path);
        if (path.has_suffix (Path.DIR_SEPARATOR_S)) {
            sb.erase (sb.str.length - 1,-1);
        }
        int last_separator = sb.str.last_index_of (Path.DIR_SEPARATOR_S);
        if (last_separator < 0) {
            last_separator = 0;
        }
        sb.erase (last_separator, -1);
        string parent_path = sb.str + Path.DIR_SEPARATOR_S;
        return sanitize_path (parent_path);
    }

    public bool path_has_parent (string new_path) {
        var file = File.new_for_commandline_arg (new_path);
        return file.get_parent () != null;
    }

    public string? escape_uri (string uri, bool allow_utf8 = true) {
        string rc = reserved_chars.replace("#", "").replace ("*","");
        return Uri.escape_string ((Uri.unescape_string (uri) ?? uri), rc , allow_utf8);
    }

    /** Produce a valid unescaped path.  A current path can be provided and is used to get the scheme and
      * to interpret relative paths where necessary.
      **/
    public string sanitize_path (string? p, string? cp = null) {
        string path = "";
        string scheme = "";
        string? current_path = null;
        string? current_scheme = null;

        if (p == null || p == "") {
            return cp ?? "";
        }

        string? unescaped_p = Uri.unescape_string (p, null);
        if (unescaped_p == null) {
            unescaped_p = p;
        }

        split_protocol_from_path (unescaped_p, out scheme, out path);
        path = path.strip ().replace ("//", "/");
        StringBuilder sb = new StringBuilder (path);
        if (cp != null) {
            split_protocol_from_path (cp, out current_scheme, out current_path);
            /* current_path is assumed already sanitized */
                if (scheme == "" && path.has_prefix ("/./")) {
                    sb.erase (0, 2);
                    sb.prepend (cp);
                    split_protocol_from_path (sb.str , out scheme, out path);
                    sb.assign (path);
                } else if (path.has_prefix ("/../")) {
                    sb.erase (0, 3);
                    sb.prepend (get_parent_path_from_path (current_path));
                    sb.prepend (current_scheme);
                    split_protocol_from_path (sb.str , out scheme, out path);
                    sb.assign (path);
                }
        }

        if (path.length > 0) {
            if (scheme == "" && path.has_prefix ("/~/")) {
                sb.erase (0, 2);
                sb.prepend (Eel.get_real_user_home ());
            }
        }

        path = sb.str;

        do {
            path = path.replace ("//", "/");
        } while (path.contains ("//"));

        string new_path = (scheme + path).replace("////", "///");
        if (new_path.length > 0) {
            /* ROOT_FS, TRASH and RECENT must have 3 separators after protocol, other protocols have 2 */
            if (!scheme.has_prefix (Marlin.ROOT_FS_URI) &&
                !scheme.has_prefix (Marlin.TRASH_URI) &&
                !scheme.has_prefix (Marlin.RECENT_URI)) {

                new_path = new_path.replace ("///", "//");
            }
            new_path = new_path.replace("ssh:", "sftp:");

            if (path == "/" && !can_browse_scheme (scheme)) {
                new_path = "";
            }
        }

        return new_path;
    }

    /** Splits the path into a protocol ending in '://" (unless it is file:// which is replaced by "")
      * and a path beginning "/".
    **/
    public void split_protocol_from_path (string path, out string protocol, out string new_path) {
        protocol = "";
        new_path = path.dup ();
        string[] explode_protocol = new_path.split ("://");

        if (explode_protocol.length > 2) {
            new_path = "";
            return;
        }
        if (explode_protocol.length > 1) {
            if (explode_protocol[0] == "mtp") {
                string[] explode_path = explode_protocol[1].split ("]", 2);
                if (explode_path[0] != null && explode_path[0].has_prefix ("[")) {
                    protocol = (explode_protocol[0] + "://" + explode_path[0] + "]").replace ("///", "//");
                    /* If path is being manually edited there may not be "]" so explode_path[1] may be null*/
                    new_path = explode_path [1] ?? "";
                } else {
                    warning ("Invalid mtp path");
                    protocol = new_path.dup ();
                    new_path = "/";
                }
            } else {
                protocol = explode_protocol[0] + "://";
                new_path = explode_protocol[1] ?? "";
            }
        } else {
            protocol = Marlin.ROOT_FS_URI;
        }

        if (Marlin.ROOT_FS_URI.has_prefix (protocol)) {
            protocol = "";
        }

        if (!new_path.has_prefix (Path.DIR_SEPARATOR_S)) {
            new_path = Path.DIR_SEPARATOR_S + new_path;
        }
    }

    private bool valid_mtp_uri (string uri) {
        if (!uri.contains (Marlin.MTP_URI)) {
            return false;
        }
        string[] explode_protocol = uri.split ("://",2);
        if (explode_protocol.length != 2 ||
            !explode_protocol[1].has_prefix ("[") ||
            !explode_protocol[1].contains ("]")) {
            return false;
        }
        return true;
    }

    public string get_smb_share_from_uri (string uri) {
        if (!(Uri.parse_scheme (uri) == "smb"))
            return (uri);

        string [] uri_parts = uri.split (Path.DIR_SEPARATOR_S);

        if (uri_parts.length < 4)
            return uri;
        else {
            var sb = new StringBuilder ();
            for (int i = 0; i < 4; i++)
                sb.append (uri_parts [i] + Path.DIR_SEPARATOR_S);

            return sb.str;
        }
    }

    /* Lists of compression only and archive only extensions from Wikipedia */
    private const string compression_extensions = "bz2 F gz tz lz lzma lzo rz sfark sz xz z Z ";
    private const string archive_extensions = "a cpio shar LBR iso lbr mar sbx tar";
    private string strip_extension (string filename) {
        string[] parts = filename.reverse ().split (".", 3);
        var n_parts = parts.length;

        switch (n_parts) {
            case 1:
                break;
            case 2:
                return parts[1].reverse ();
            case 3:
                if (compression_extensions.reverse ().contains (parts[0]) &&
                    archive_extensions.reverse ().contains (parts[1])) {

                        return parts[2].reverse ();
                }

                return string.join (".", parts[1], parts[2]).reverse ();


            default:
                break;
        }

        return filename;
    }

    public void get_rename_region (string filename, out int start_offset, out int end_offset, bool select_all) {

        start_offset = 0;

        if (select_all) {
            end_offset = -1;
        } else {
            end_offset = strip_extension (filename).char_count ();
        }
    }

    /* Signature must be compatible with MarlinUndoStackManager undo and redo functions */
    public delegate void RenameCallbackFunc (GLib.File old_location, GLib.File? new_location, GLib.Error? error);

    public void set_file_display_name (GLib.File old_location, string new_name, PF.FileUtils.RenameCallbackFunc? f) {

        /** TODO Check validity of new name, make cancellable **/

        GLib.File? new_location = null;
        GOF.Directory.Async? dir = GOF.Directory.Async.cache_lookup_parent (old_location);
        string original_name = old_location.get_basename ();

        old_location.set_display_name_async.begin (new_name, 0, null, (obj, res) => {
            try {
                assert (obj is GLib.Object);
                GLib.File? n = old_location.set_display_name_async.end (res);
                /* Unless we decouple the new_file from the object returned by set_display_name_async
                 * it can get corrupted when this thread exits when working with remote files, presumably
                 * due to a bug in gvfs backend. This leads to obscure bugs in Files.
                 */
                new_location= GLib.File.new_for_uri (n.get_uri ());

                if (dir != null) {
                    /* Notify directory of change.  Since only a single file is changed we bypass MarlinFileChangesQueue */
                    /* Appending OK here since only one file */
                    GLib.List<GLib.File>added_files = null;
                    added_files.append (new_location);
                    GLib.List<GLib.File>removed_files = null;
                    removed_files.append (old_location);
                    GOF.Directory.Async.notify_files_removed (removed_files);
                    GOF.Directory.Async.notify_files_added (added_files);
                } else {
                    warning ("Renamed file has no GOF.Directory.Async");
                }

                /* Register the change with the undo manager */
                Marlin.UndoManager.instance ().add_rename_action (new_location,
                                                                  original_name);
            } catch (Error e) {
                warning ("Rename error");
                Eel.show_error_dialog (_("Could not rename to '%s'").printf (new_name),
                                       e.message,
                                       null);
                new_location = null;

                if (dir != null) {
                    /* We emit this signal anyway so callers can know rename failed and disconnect */
                    dir.file_added (null);
                }
            }
            /* PropertiesWindow also calls this function with a different callback */
            if (f != null) {
                f (old_location, new_location, null);
            }
        });
    }

    public string get_formatted_time_attribute_from_info (GLib.FileInfo info, string attr) {
        DateTime? dt = null;

        switch (attr) {
            case FileAttribute.TIME_MODIFIED:
            case FileAttribute.TIME_CREATED:
            case FileAttribute.TIME_ACCESS:
            case FileAttribute.TIME_CHANGED:
                uint64 t = info.get_attribute_uint64 (attr);
                if (t > 0) {
                    dt = new DateTime.from_unix_local ((int64)t);
                }

                break;

            case FileAttribute.TRASH_DELETION_DATE:
                var deletion_date = info.get_attribute_string (attr);
                var tv = TimeVal ();
                if (deletion_date != null && !tv.from_iso8601 (deletion_date)) {
                    dt = new DateTime.from_timeval_local (tv);
                }

                break;

            default:
                break;
        }

        return get_formatted_date_time (dt);
    }

    public string get_formatted_date_time (DateTime? dt) {
        if (dt == null) {
            return "";
        }

        switch (GOF.Preferences.get_default ().date_format.down ()) {
            case "locale":
                return dt.format ("%c");
            case "iso" :
                return dt.format ("%Y-%m-%d %H:%M:%S");
            default:
                return get_informal_date_time (dt);
        }
    }

    private string get_informal_date_time (DateTime dt) {
        DateTime now = new DateTime.now_local ();
        int now_year = now.get_year ();
        int disp_year = dt.get_year ();

        string default_date_format = Granite.DateTime.get_default_date_format (false, true, true);

        if (disp_year < now_year) {
            return dt.format (default_date_format);
        }

        int now_day = now.get_day_of_year ();
        int disp_day = dt.get_day_of_year ();

        if (disp_day < now_day - 6) {
            return dt.format (default_date_format);
        }

        int now_weekday = now.get_day_of_week ();
        int disp_weekday = dt.get_day_of_week ();

        bool clock_is_24h = GOF.Preferences.get_default ().clock_format.has_prefix ("24");

        string format_string = "";

        switch (now_weekday - disp_weekday) {
            case 0:
                if (clock_is_24h) {
                    format_string = _("Today at %-H:%M"); ///TRANSLATORS Used when 24h clock has been selected
                } else {
                    format_string = _("Today at %-I:%M %p"); ///TRANSLATORS Used when 12h clock has been selected (if available))
                }

                break;
            case 1:
                if (clock_is_24h) {
                    format_string = _("Yesterday at %-H:%M"); ///TRANSLATORS Used when 24h clock has been selected
                } else {
                    format_string = _("Yesterday at %-I:%M %p"); ///TRANSLATORS Used when 12h clock has been selected (if available))
                }

                break;

            default:
                if (clock_is_24h) {
                    format_string = _("%A at %-H:%M"); ///TRANSLATORS Used when 24h clock has been selected
                } else {
                    format_string = _("%A at %-I:%M %p"); ///TRANSLATORS Used when 12h clock has been selected (if available))
                }

                break;
        }

        return dt.format (format_string);
    }

    private bool can_browse_scheme (string scheme) {
        switch (scheme) {
            case Marlin.AFP_URI:
            case Marlin.DAV_URI:
            case Marlin.DAVS_URI:
            case Marlin.SFTP_URI:
            case Marlin.FTP_URI:
            case Marlin.MTP_URI:
                return false;
            default:
                return true;
        }
    }

    public uint16 get_default_port_for_protocol (string protocol) {
        var ptcl = protocol.down ();
        switch (ptcl) {
            case "sftp":
                return 22;
            case "ftp":
                return 21;
            case "afp" :
                return 548;
            case "dav" :
                return 80;
            case "davs" :
                return 443;
            default :
                return 0;
        }
    }

    public bool get_is_tls_for_protocol (string protocol) {
        var ptcl = protocol.down ();
        switch (ptcl) {
            case "sftp":
                return false;
            case "ssh":
                return true;
            case "ftp":
                return false;
            case "afp" :
                return false;
            case "dav" :
                return false;
            case "davs" :
                return true;
            default :
                return false;
        }
    }

    public bool is_icon_path (string path) {
        return "/icons" in path || "/.icons" in path;
    }
}

namespace Marlin {
    public const string ROOT_FS_URI = "file://";
    public const string TRASH_URI = "trash://";
    public const string NETWORK_URI = "network://";
    public const string RECENT_URI = "recent://";
    public const string AFP_URI = "afp://";
    public const string DAV_URI = "dav://";
    public const string DAVS_URI = "davs://";
    public const string SFTP_URI = "sftp://";
    public const string FTP_URI = "ftp://";
    public const string SMB_URI = "smb://";
    public const string MTP_URI = "mtp://";
}
