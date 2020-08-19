/***
    Copyright (c) 2015-2020 elementary LLC <https://elementary.io>

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
    const string RESERVED_CHARS = (GLib.Uri.RESERVED_CHARS_GENERIC_DELIMITERS +
                                   GLib.Uri.RESERVED_CHARS_SUBCOMPONENT_DELIMITERS + " ");

    public GLib.List<GLib.File> files_from_uris (string uris) {
        var result = new GLib.List<GLib.File> ();
        var uri_list = GLib.Uri.list_extract_uris (uris);
        foreach (unowned string uri in uri_list) {
            result.append (GLib.File.new_for_uri (uri));
        }

        return result;
    }

    public GLib.KeyFile key_file_from_file (GLib.File file, GLib.Cancellable? cancellable = null) throws GLib.Error {
        var keyfile = new GLib.KeyFile ();
        try {
            uint8[] contents;
            string etag_out;
            file.load_contents (cancellable, out contents, out etag_out);
            keyfile.load_from_data ((string)contents, -1,
                                    GLib.KeyFileFlags.KEEP_COMMENTS | GLib.KeyFileFlags.KEEP_TRANSLATIONS);
        } catch (Error e) {
            throw e;
        }

        return keyfile;
    }

    public File? get_file_for_path (string? path) {
        string? new_path = sanitize_path (path);

        if (new_path != null && new_path.length > 0) {
            return File.new_for_commandline_arg (new_path);
        } else {
            return null;
        }
    }

    public string get_parent_path_from_path (string path, bool include_file_protocol = true) {
        /* We construct the parent path rather than use File.get_parent () as the latter gives odd
         * results for some gvfs files.
         */
        string parent_path = construct_parent_path (path, include_file_protocol);
        if (parent_path == Marlin.FTP_URI ||
            parent_path == Marlin.SFTP_URI) {

            parent_path = path;
        }

        if ((parent_path.has_prefix (Marlin.MTP_URI) || parent_path.has_prefix (Marlin.PTP_URI)) &&
            !valid_mtp_uri (parent_path)) {

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
            PF.Dialogs.show_warning_dialog (message, _("The item cannot be restored from trash"),
                                            (widget is Gtk.Window) ? widget as Gtk.Window : null );
        }

        original_dirs_hash.foreach ((original_dir, dir_files) => {
                Marlin.FileOperations.copy_move_link.begin (dir_files,
                                                            original_dir,
                                                            Gdk.DragAction.MOVE,
                                                            widget,
                                                            null);
        });
    }

    private GLib.HashTable<GLib.File, GLib.List<GLib.File>>
    get_trashed_files_original_directories (GLib.List<GOF.File> files, out GLib.List<GOF.File> unhandled_files) {

        var directories = new GLib.HashTable<GLib.File, GLib.List<GLib.File>> (File.hash, File.equal);
        unhandled_files = null;

        foreach (unowned GOF.File goffile in files) {
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
                    GLib.List<GLib.File>? dir_files = directories.take (original_dir);
                    dir_files.prepend (goffile.location);
                    directories.insert (original_dir, (owned)dir_files);
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
                    info = file.location.query_info (GLib.FileAttribute.TRASH_ORIG_PATH,
                                                     GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null);
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

    private string construct_parent_path (string path, bool include_file_protocol) {
        if (path.length < 2) {
            return Path.DIR_SEPARATOR_S;
        }
        StringBuilder sb = new StringBuilder (path);
        if (path.has_suffix (Path.DIR_SEPARATOR_S)) {
            sb.erase (sb.str.length - 1, -1);
        }
        int last_separator = sb.str.last_index_of (Path.DIR_SEPARATOR_S);
        if (last_separator < 0) {
            last_separator = 0;
        }
        sb.erase (last_separator, -1);
        string parent_path = sb.str + Path.DIR_SEPARATOR_S;
        return sanitize_path (parent_path, null, include_file_protocol);
    }

    public bool path_has_parent (string new_path) {
        var file = File.new_for_commandline_arg (new_path);
        return file.get_parent () != null;
    }

    public string? escape_uri (string uri, bool allow_utf8 = true, bool allow_single_quote = true) {
        string rc = RESERVED_CHARS.replace ("#", "").replace ("*", "");
        if (!allow_single_quote) {
            rc = rc.replace ("'", "");
        }

        return Uri.escape_string ((Uri.unescape_string (uri) ?? uri), rc , allow_utf8);
    }

    /** Produce a valid unescaped path.  A current path can be provided and is used to get the scheme and
      * to interpret relative paths where necessary.
      **/

    public string sanitize_path (string? input_uri,
                                 string? input_current_uri = null,
                                 bool include_file_protocol = true) {
        string unsanitized_uri;
        string unsanitized_current_uri;
        string path = "";
        string scheme = "";
        string? current_path = null;
        string? current_scheme = null;

        if (input_uri == null || input_uri == "") {
            unsanitized_uri = input_current_uri; /* Sanitize current path */
            unsanitized_current_uri = "";
        } else {
            unsanitized_uri = input_uri;
            unsanitized_current_uri = input_current_uri;
        }

        if (unsanitized_uri == null || unsanitized_uri == "") {
            return "";
        }

        string? unescaped_uri = Uri.unescape_string (unsanitized_uri, null);
        if (unescaped_uri == null) {
            unescaped_uri = unsanitized_uri;
        }

        split_protocol_from_path (unescaped_uri, out scheme, out path);

        path = path.strip ().replace ("//", "/");
        // special case for empty path, adjust as root path
        if (path.length == 0) {
            path = "/";
        }

        StringBuilder sb = new StringBuilder (path);
        if (unsanitized_current_uri != null) {
            split_protocol_from_path (unsanitized_current_uri, out current_scheme, out current_path);
            /* current_path is assumed already sanitized */

            if ((scheme == "" || scheme == Marlin.ROOT_FS_URI) && path.length > 0) {
                string [] paths = path.split ("/", 2);
                switch (paths[0]) {
                    // ignore home documents
                    case "~":
                    // ignore path with root
                    case "":
                        break;
                    // process special parent dir
                    case "..":
                        if (current_scheme != "" && current_scheme != Marlin.ROOT_FS_URI) {
                            /* We need to append the current scheme later */
                            scheme = current_scheme;
                        }

                        /* We do not want the file:// prefix returned */
                        sb.assign (get_parent_path_from_path (current_path, false));

                        if (paths.length > 1) {
                            sb.append (Path.DIR_SEPARATOR_S);
                            sb.append (paths[1]);
                        }

                        break;
                    // process current dir
                    case ".":
                        sb.assign (current_path); //We do not want the scheme at this point
                        if (paths.length > 1) {
                            sb.append (Path.DIR_SEPARATOR_S);
                            sb.append (paths[1]);
                        }
                        break;
                    // process directory without root
                    default:
                        sb.assign (current_path); //We do not want the scheme at this point
                        sb.append (Path.DIR_SEPARATOR_S);
                        sb.append (paths[0]);
                        if (paths.length > 1) {
                            sb.append (Path.DIR_SEPARATOR_S);
                            sb.append (paths[1]);
                        }
                        break;
                }
            }
        }

        if (path.length > 0) {
            if ((scheme == "" || scheme == Marlin.ROOT_FS_URI) &&
                (path.has_prefix ("~/") || path.has_prefix ("/~") || path == "~")) {

                if (path.has_prefix ("/")) {
                    sb.erase (0, 1);
                }

                sb.erase (0, 1);
                sb.prepend (PF.UserUtils.get_real_user_home ());
            }
        }

        path = sb.str;

        do {
            path = path.replace ("//", "/");
        } while (path.contains ("//"));

        string new_path = (scheme + path).replace ("////", "///");
        if (new_path.length > 0) {
            /* ROOT_FS, TRASH and RECENT must have 3 separators after protocol, other protocols have 2 */
            if (!scheme.has_prefix (Marlin.ROOT_FS_URI) &&
                !scheme.has_prefix (Marlin.TRASH_URI) &&
                !scheme.has_prefix (Marlin.RECENT_URI)) {

                new_path = new_path.replace ("///", "//");
            }

            new_path = new_path.replace ("ssh:", "sftp:");

            if (path == "/" && !can_browse_scheme (scheme)) {
                new_path = "";
            }
        }

        if (!include_file_protocol && new_path.has_prefix (Marlin.ROOT_FS_URI)) {
            new_path = new_path.slice (Marlin.ROOT_FS_URI.length, new_path.length);
        }

        return new_path;
    }

    /** Splits the path into a protocol ending in '://"  and a path beginning "/". **/
    public void split_protocol_from_path (string path, out string protocol, out string new_path) {
        protocol = "";
        new_path = path.dup ();
        string[] explode_protocol = new_path.split ("://");

        if (explode_protocol.length > 2) {
            new_path = "";
            return;
        }
        if (explode_protocol.length > 1) {
            if (explode_protocol[0] == "mtp" || explode_protocol[0] == "gphoto2" ) {
                string[] explode_path = explode_protocol[1].split ("]", 2);
                if (explode_path[0] != null && explode_path[0].has_prefix ("[")) {
                    protocol = (explode_protocol[0] + "://" + explode_path[0] + "]").replace ("///", "//");
                    /* If path is being manually edited there may not be "]" so explode_path[1] may be null*/
                    new_path = explode_path [1] ?? "";
                } else {
                    critical ("Invalid mtp or ptp path %s", path);
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

        /* Ensure a protocol is returned so file.get_path () always works on sanitized paths*/
        if (Marlin.ROOT_FS_URI.has_prefix (protocol)) {
            protocol = Marlin.ROOT_FS_URI;
        }

        /* Consistently remove any remove trailing separator so that paths can be reliably compared */
        if (new_path.has_suffix (Path.DIR_SEPARATOR_S) && path != Path.DIR_SEPARATOR_S) {
            new_path = new_path.slice (0, new_path.length - 1);
        }
    }

    private bool valid_mtp_uri (string uri) {
        if (!uri.contains (Marlin.MTP_URI) && !uri.contains (Marlin.PTP_URI)) {
            return false;
        }
        string[] explode_protocol = uri.split ("://", 2);
        if (explode_protocol.length != 2 ||
            !explode_protocol[1].has_prefix ("[") ||
            !explode_protocol[1].contains ("]")) {
            return false;
        }
        return true;
    }

    public string get_smb_share_from_uri (string uri) {
        if (!(Uri.parse_scheme (uri) == "smb")) {
            return (uri);
        }

        string [] uri_parts = uri.split (Path.DIR_SEPARATOR_S);

        if (uri_parts.length < 4) {
            return uri;
        } else {
            var sb = new StringBuilder ();
            for (int i = 0; i < 4; i++) {
                sb.append (uri_parts [i] + Path.DIR_SEPARATOR_S);
            }

            return sb.str;
        }
    }

    /* Lists of compression only and archive only extensions from Wikipedia */
    private const string COMPRESSION_EXTENSIONS = "bz2 F gz tz lz lzma lzo rz sfark sz xz z Z ";
    private const string ARCHIVE_EXTENSIONS = "a cpio shar LBR iso lbr mar sbx tar";
    private string strip_extension (string filename) {
        string[] parts = filename.reverse ().split (".", 3);
        var n_parts = parts.length;

        switch (n_parts) {
            case 1:
                break;
            case 2:
                return parts[1].reverse ();
            case 3:
                if (COMPRESSION_EXTENSIONS.reverse ().contains (parts[0]) &&
                    ARCHIVE_EXTENSIONS.reverse ().contains (parts[1])) {

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

    public async GLib.File? set_file_display_name (GLib.File old_location,
                                                   string new_name,
                                                   GLib.Cancellable? cancellable = null) throws GLib.Error {

        /** TODO Check validity of new name **/


        GLib.File? new_location = null;
        GOF.Directory.Async? dir = GOF.Directory.Async.cache_lookup_parent (old_location);
        string? original_name = old_location.get_basename ();

        try {
            new_location = yield old_location.set_display_name_async (new_name, GLib.Priority.DEFAULT, cancellable);

            if (dir != null) {
                /* Notify directory of change.
                 * Since only a single file is changed we bypass MarlinFileChangesQueue */
                /* Appending OK here since only one file */
                var added_files = new GLib.List<GLib.File> ();
                added_files.append (new_location);
                var removed_files = new GLib.List<GLib.File> ();
                removed_files.append (old_location);
                GOF.Directory.Async.notify_files_removed (removed_files);
                GOF.Directory.Async.notify_files_added (added_files);
            } else {
                warning ("Renamed file has no GOF.Directory.Async");
            }

            Marlin.UndoManager.instance ().add_rename_action (new_location, original_name);
        } catch (Error e) {
            warning ("Rename error");
            PF.Dialogs.show_error_dialog (_("Could not rename to '%s'").printf (new_name),
                                          e.message,
                                          null);

            if (dir != null) {
                /* We emit this signal anyway so callers can know rename failed and disconnect */
                dir.file_added (null);
            }

            throw e;
        }

        return new_location;
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
                ///TRANSLATORS '%s' is a placeholder for the time. It may be moved but not changed.
                format_string = _("Today at %s").printf (
                                    Granite.DateTime.get_default_time_format (!clock_is_24h, false)
                                );

                break;
            case 1:
            case -6: /* Yesterday is Sunday */
                ///TRANSLATORS '%s' is a placeholder for the time. It may be moved but not changed.
                format_string = _("Yesterday at %s").printf (
                                    Granite.DateTime.get_default_time_format (!clock_is_24h, false)
                                );

                break;

            default:
                ///TRANSLATORS '%%A' is a placeholder for the day name, '%s' is a placeholder for the time. These may be moved and reordered but not changed.
                format_string = _("%%A at %s").printf (Granite.DateTime.get_default_time_format (!clock_is_24h, false));

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
            case Marlin.PTP_URI:
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

    public bool location_is_in_trash (GLib.File location) {
        var uri = location.get_uri ();
        var scheme = Uri.parse_scheme (uri);

        return (scheme != null && scheme.has_prefix ("trash") ||
                uri.contains (GLib.Path.DIR_SEPARATOR_S + ".Trash-") ||
                (uri.contains (GLib.Path.DIR_SEPARATOR_S + ".local") &&
                 uri.contains (GLib.Path.DIR_SEPARATOR_S + "Trash" + GLib.Path.DIR_SEPARATOR_S)));
    }

    public Gdk.DragAction file_accepts_drop (GOF.File dest,
                                             GLib.List<GLib.File> drop_file_list, // read-only
                                             Gdk.DragContext context,
                                             out Gdk.DragAction suggested_action_return) {

        var actions = context.get_actions ();
        var suggested_action = context.get_suggested_action ();
        var target_location = dest.get_target_location ();

        suggested_action_return = Gdk.DragAction.PRIVATE;

        if (drop_file_list == null || drop_file_list.data == null) {
            return Gdk.DragAction.DEFAULT;
        }

        if (dest.is_folder ()) {
            if (!dest.is_writable ()) {
                actions = Gdk.DragAction.DEFAULT;
            } else {
                /* Modify actions and suggested_action according to source files */
                actions &= valid_actions_for_file_list (target_location,
                                                        drop_file_list,
                                                        ref suggested_action);
            }
        } else if (dest.is_executable ()) {
            actions |= (Gdk.DragAction.COPY |
                       Gdk.DragAction.MOVE |
                       Gdk.DragAction.LINK |
                       Gdk.DragAction.PRIVATE);
        } else {
            actions = Gdk.DragAction.DEFAULT;
        }

        if (actions == Gdk.DragAction.DEFAULT) { // No point asking if no other valid actions
            return Gdk.DragAction.DEFAULT;
        } else if (location_is_in_trash (target_location)) { // cannot copy or link to trash
            actions &= ~(Gdk.DragAction.COPY | Gdk.DragAction.LINK);
        }

        if (suggested_action in actions) {
            suggested_action_return = suggested_action;
        } else if (Gdk.DragAction.ASK in actions) {
            suggested_action_return = Gdk.DragAction.ASK;
        } else if (Gdk.DragAction.COPY in actions) {
            suggested_action_return = Gdk.DragAction.COPY;
        } else if (Gdk.DragAction.LINK in actions) {
            suggested_action_return = Gdk.DragAction.LINK;
        } else if (Gdk.DragAction.MOVE in actions) {
            suggested_action_return = Gdk.DragAction.MOVE;
        }

        return actions;
    }

    private const uint MAX_FILES_CHECKED = 100; // Max checked copied from gof_file.c version
    private Gdk.DragAction valid_actions_for_file_list (GLib.File target_location,
                                                        GLib.List<GLib.File> drop_file_list,
                                                        ref Gdk.DragAction suggested_action) {

        var valid_actions = Gdk.DragAction.DEFAULT |
                            Gdk.DragAction.COPY |
                            Gdk.DragAction.MOVE |
                            Gdk.DragAction.LINK;

        /* Check the first MAX_FILES_CHECKED and let
         * the operation fail for file the same as target if it is
         * buried in a large selection.  We can normally assume that all source files
         * come from the same folder, but drops from outside Files could be from multiple
         * folders. The valid actions are the lowest common denominator.
         */
        uint count = 0;
        bool from_trash = false;

        foreach (var drop_file in drop_file_list) {

            if (location_is_in_trash (drop_file)) {
                from_trash = true;

                if (location_is_in_trash (target_location)) {
                    valid_actions = Gdk.DragAction.DEFAULT; // No DnD within trash
                }
            }

            var parent = drop_file.get_parent ();

            if (parent != null && parent.equal (target_location)) {
                valid_actions &= Gdk.DragAction.LINK; // Only LINK is valid
            }

            var scheme = drop_file.get_uri_scheme ();
            if (!scheme.has_prefix ("file")) {
                valid_actions &= ~(Gdk.DragAction.LINK); // Can only LINK local files
            }

            if (++count > MAX_FILES_CHECKED ||
                valid_actions == Gdk.DragAction.DEFAULT) {

                break;
            }
        }

        /* Modify Gtk suggested COPY action to MOVE if source is trash or dest is in
         * same filesystem and if MOVE is a valid action.  We assume that it is not possible
         * to drop files both from remote and local filesystems simultaneously
         */
        if ((Gdk.DragAction.COPY in valid_actions && Gdk.DragAction.MOVE in valid_actions) &&
             suggested_action == Gdk.DragAction.COPY &&
             (from_trash || same_file_system (drop_file_list.first ().data, target_location))) {

            suggested_action = Gdk.DragAction.MOVE;
        }

        if (valid_actions != Gdk.DragAction.DEFAULT) {
            valid_actions |= Gdk.DragAction.ASK; // Allow ASK if there is a possible action
        }

        return valid_actions;
    }

    private bool same_file_system (GLib.File a, GLib.File b) {
        GLib.FileInfo info_a;
        GLib.FileInfo info_b;

        try {
            info_a = a.query_info (GLib.FileAttribute.ID_FILESYSTEM, 0, null);
            info_b = b.query_info (GLib.FileAttribute.ID_FILESYSTEM, 0, null);
        } catch (GLib.Error e) {
            return false;
        }

        var filesystem_a = info_a.get_attribute_string (GLib.FileAttribute.ID_FILESYSTEM);
        var filesystem_b = info_b.get_attribute_string (GLib.FileAttribute.ID_FILESYSTEM);

        return (filesystem_a != null && filesystem_b != null &&
                filesystem_a == filesystem_b);

    }

    public int compare_modification_dates (GLib.File a, GLib.File b) {
        GLib.FileInfo info_a;
        GLib.FileInfo info_b;

        try {
            info_a = a.query_info (GLib.FileAttribute.TIME_MODIFIED, 0, null);
            info_b = b.query_info (GLib.FileAttribute.TIME_MODIFIED, 0, null);
        } catch (GLib.Error e) {
            return 0;
        }

        var mod_a = info_a.get_attribute_uint64 (GLib.FileAttribute.TIME_MODIFIED);
        var mod_b = info_b.get_attribute_uint64 (GLib.FileAttribute.TIME_MODIFIED);

        return mod_a == mod_b ? 0 : mod_a > mod_b ? 1 : -1;
    }

    public void remove_thumbnail_paths_for_uri (string uri) {
        string hash = GLib.Checksum.compute_for_string (ChecksumType.MD5, uri);
        string base_name = "%s.png".printf (hash);
        string cache_dir = Environment.get_user_cache_dir ();
        GLib.FileUtils.unlink (Path.build_filename (cache_dir, "thumbnails", "normal", base_name));
        GLib.FileUtils.unlink (Path.build_filename (cache_dir, "thumbnails", "large", base_name));
    }

    public bool same_location (string uri_a, string uri_b) {
        string protocol_a, protocol_b;
        string path_a, path_b;

        split_protocol_from_path (Uri.unescape_string (uri_a), out protocol_a, out path_a);
        split_protocol_from_path (Uri.unescape_string (uri_b), out protocol_b, out path_b);

        if (protocol_a == protocol_b && path_a == path_b) {
            return true;
        }

        return false;
    }

    public uint64 get_file_modification_time (GLib.File file) {
        try {
            var info = file.query_info (
                                GLib.FileAttribute.TIME_MODIFIED, GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, null
                            );
            return info.get_attribute_uint64 (GLib.FileAttribute.TIME_MODIFIED);
        } catch (Error e) {
            critical (e.message);
            return -1;
        }
    }

    /* Returns true if a valid filename could be constructed (or already valid) */
    public bool make_file_name_valid_for_dest_fs (ref string filename, string? dest_fs_type) {
        if (dest_fs_type != null) {
            switch (dest_fs_type) {
                case "fat":
                case "vfat":
                case "msdos":
                case "msdosfs":
                    const string CHARS_TO_REPLACE = "/:;*?\\<> ";
                    char replacement = '_';
                    filename = filename.delimit (CHARS_TO_REPLACE, replacement);
                    break;

                default:
                    break;
            }
        }

        return filename.validate ();
    }

    public string format_time (int seconds, out int time_unit) {
        int minutes, hours;
        string result;

        if (seconds < 0) {
            seconds = 0;
        }

        if (seconds < 60) { //less than one minute
            time_unit = seconds;
            result = ngettext ("%'d second", "%'d seconds", seconds).printf (seconds);
        } else if (seconds < 3600) { // less than one hour
            minutes = seconds / 60;
            time_unit = minutes;
            result = ngettext ("%'d minute", "%'d minutes", minutes).printf (minutes);
        } else {
            hours = seconds / 3600;
            if (hours < 4) {
                minutes = (seconds - hours * 3600) / 60;
                time_unit = minutes + hours;
                ///TRANSLATORS The %s will be translated into "x hours, y minutes"
                result = _("%s, %s").printf (ngettext ("%'d hour", "%'d hours", hours).printf (hours),
                                             ngettext ("%'d minute", "%'d minutes", minutes).printf (minutes));
            } else {
                time_unit = hours;
                result = ngettext ("approximately %'d hour", "approximately %'d hours", hours).printf (hours);
            }
        }

        return result;
    }

    /* Returns a valid file for the destination named after src if possible (not guaranteed to be unique) */
    private File get_target_file (GLib.File src, GLib.File dest_dir, string? dest_fs_type, bool same_fs) {
        File target_file;
        string? target_name = null;
        if (!same_fs) {
            try {
                FileInfo info = src.query_info (
                    FileAttribute.STANDARD_COPY_NAME,
                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                    null
                );
                if (info != null && info.has_attribute (FileAttribute.STANDARD_COPY_NAME)) {
                    target_name = info.get_attribute_string (FileAttribute.STANDARD_COPY_NAME);
                }
            } catch (Error e) {}
        } else {
            try {
                FileInfo info = src.query_info (
                    FileAttribute.STANDARD_EDIT_NAME,
                    FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                    null
                );
                if (info != null && info.has_attribute (FileAttribute.STANDARD_EDIT_NAME)) {
                    target_name = info.get_attribute_string (FileAttribute.STANDARD_EDIT_NAME);
                }
            } catch (Error e) {}
        }

        if (target_name == null) {
            target_name = src.get_basename ();
        }

        if (!make_file_name_valid_for_dest_fs (ref target_name, dest_fs_type)) {
            target_name = _("Invalid name - please rename");  //hould this be translatable - must be guaranteed valid?
        }

        try {
            target_file = dest_dir.get_child_for_display_name (target_name);
        } catch (Error e) {
            target_file = dest_dir.get_child (target_name);
        }

        return target_file;
    }



    /* @base_path - path excluding any extension;
     * @tag - characteristic string preceding the duplicate count (not including digits)
     */
    private int parse_duplicate_count (ref string base_path) {
        var tag = _(DUPLICATE_START);
        if (!base_path.contains (tag)) {
            return 0;
        }

        int index_of_opening = base_path.last_index_of (tag);
        string name_base = base_path.slice (index_of_opening, base_path.length);
        base_path = base_path.slice (0, index_of_opening);

        /* Duplicate count must be the last number in the name (excluding suffix)
         * If there are no digits this is regarded as count = 1. */

        //Its easier to use reverse string
        var reverse_base = name_base.reverse ();
        unichar chr = reverse_base.get_char ();
        int index = 0;
        int count = 0;
        while (reverse_base.get_next_char (ref index, out chr) && !chr.isdigit ()) {}
        count += chr.digit_value ();
        int multiplier = 1;
        while (reverse_base.get_next_char (ref index, out chr) && chr.isdigit ()) {
            count += chr.digit_value () * multiplier;
            //Number is reversed so each subsequent digit represents another factor of ten
            multiplier *= 10;
        }

        if (count == 0) {
            count = 1;
        }

        return count;
    }

    /* We assume all these translations will be valid for filenames in all filesystems */
    ///TRANSLATORS Translate the word "copy" (noun) and leave the placeholders (%s) in their current positions
    public const string COPY_FORMAT_SINGLE = N_("%s%scopy%s%s");

    ///TRANSLATORS Translate the word "copy " (noun) and the space. Leave the placeholders (%s, %i) in their current positions
    public const string COPY_FORMAT_MULTIPLE = N_("%s%scopy %i%s%s");

    ///TRANSLATORS Translate the word "link" (a symbolic link to a file) and leave the placeholders (%s) in their current positions
    public const string LINK_FORMAT_SINGLE = N_("%s%slink%s%s");

    ///TRANSLATORS Translate the word "link " (a symbolic link to a file) and the space. Leave the placeholders (%s, %i) in their current positions
    public const string LINK_FORMAT_MULTPLE = N_("%s%slink %i%s%s");

    ///TRANSLATORS Separator between the basename of a file from the "copy"/"link" duplicate indications.
    public const string DUPLICATE_START = N_(" (");

    ///TRANSLATORS Separator between the "copy"/"link" duplicate indication from the extension or end of a filename.
    public const string DUPLICATE_END = N_(")");

    /* Returns a suitably named file that does not already exist (unless @overwrite is TRUE) */
    public File make_next_link_copy_target_file (GLib.File src,
                                                 GLib.File dest_dir,
                                                 string? dest_fs_type,
                                                 bool link,
                                                 bool same_fs = true,
                                                 bool overwrite = false) {

        File target_file = get_target_file (src, dest_dir, dest_fs_type, same_fs);

        if (overwrite || !target_file.query_exists ()) {
            return target_file;
        }

        var old_path = target_file.get_path ();
        int extension_index = old_path.last_index_of (".");
        string base_path = old_path;
        string extension = "";
        if (extension_index > 0 && extension_index < old_path.length - 1) {
            base_path = old_path.slice (0, extension_index);
            extension = old_path.slice (extension_index, old_path.length);
        }

        string format;
        int count;
        if (link) {//Linking to a link does not duplicate the link
            count = 1;
        } else {// Copying a copy does duplicate the file.
            count = parse_duplicate_count (ref base_path) + 1; // Count is at least 1
        }
        if (count == 1) { //Not duplicating a duplicate
            format = link ? _(LINK_FORMAT_SINGLE) : _(COPY_FORMAT_SINGLE);
            target_file = File.new_for_path (
                format.printf (base_path, _(DUPLICATE_START), _(DUPLICATE_END), extension)
            );
        } else {
            format = link ? _(LINK_FORMAT_MULTPLE) : _(COPY_FORMAT_MULTIPLE);
            target_file = File.new_for_path (
                format.printf (base_path, _(DUPLICATE_START), count, _(DUPLICATE_END), extension)
            );
        }

        format = link ? _(LINK_FORMAT_MULTPLE) : _(COPY_FORMAT_MULTIPLE); //Subsequent duplicates must be multiple
        while (target_file.query_exists ()) {
            count++;
            target_file = File.new_for_path (
                format.printf (base_path, _(DUPLICATE_START), count, _(DUPLICATE_END), extension)
            );
        }

        return target_file;
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
    public const string PTP_URI = "gphoto2://";
}
