/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

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
    const string reserved_chars = (GLib.Uri.RESERVED_CHARS_GENERIC_DELIMITERS +
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

    public const string ELLIPSIS = "…";
    public string limited_length_path (string full_path, int max_length) {
        if (full_path.length < max_length) {
            return full_path;
        }

        string path, protocol;
        split_protocol_from_path (full_path, out protocol, out path);

        string[] tokens = path.strip ().split (Path.DIR_SEPARATOR_S, 10);
        int n_tokens = tokens.length;
        bool has_protocol = protocol.length > 0;

        if (has_protocol) {
            if (max_length - protocol.length < 12) {
                has_protocol = false;
            } else {
                max_length -= protocol.length;
            }
        }

        var basename = tokens[n_tokens - 1];
        var current_length = basename.length;
        var sb = new StringBuilder (basename);

        for (int i = n_tokens - 2; i >= 0; i--) {
            if (tokens[i].length == 0) {
                continue;
            }
            var chunk = tokens[i] + Path.DIR_SEPARATOR_S;
            current_length += chunk.length;
            if (current_length > max_length) {
                current_length -= chunk.length;
                break;
            } else {
                sb.prepend (chunk);
            }
        }

        sb.prepend (Path.DIR_SEPARATOR_S);

        if (current_length + 1 < path.length) {
            sb.prepend (ELLIPSIS);
        }

        if (has_protocol) {
            sb.prepend (protocol);
        }

        return sb.str.replace ("///", "//");
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
                Marlin.FileOperations.copy_move_link (dir_files,
                                                      null,
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
        string rc = reserved_chars.replace ("#", "").replace ("*","");
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
        // special case for empty path, adjust as root path
        if (path.length == 0) {
            path = "/";
        }

        StringBuilder sb = new StringBuilder (path);
        if (cp != null) {
            split_protocol_from_path (cp, out current_scheme, out current_path);
            /* current_path is assumed already sanitized */
            if (scheme == "" && path.length > 0) {
                string [] paths = path.split ("/", 2);
                switch (paths[0]) {
                    // ignore home documents
                    case "~":
                    // ignore path with root
                    case "":
                        break;
                    // process special parent dir
                    case "..":
                        sb.assign (current_scheme);
                        sb.append (Path.DIR_SEPARATOR_S);
                        sb.append (get_parent_path_from_path (current_path));
                        if (paths.length > 1) {
                            sb.append (Path.DIR_SEPARATOR_S);
                            sb.append (paths[1]);
                        }
                        break;
                    // process current dir
                    case ".":
                        sb.assign (cp);
                        if (paths.length > 1) {
                            sb.append (Path.DIR_SEPARATOR_S);
                            sb.append (paths[1]);
                        }
                        break;
                    // process directory without root
                    default:
                        sb.assign (cp);
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
            if (scheme == "" && (path.has_prefix ("~/") || path == "~")) {
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

    public async GLib.File? set_file_display_name (GLib.File old_location, string new_name, GLib.Cancellable? cancellable = null) throws GLib.Error {

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

            /* Register the change with the undo manager */
            Marlin.UndoManager.instance ().add_rename_action (new_location,
                                                              original_name);
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
                if (clock_is_24h) {
                    format_string = _("Today at %-H:%M"); ///TRANSLATORS Used when 24h clock has been selected
                } else {
                    format_string = _("Today at %-I:%M %p"); ///TRANSLATORS Used when 12h clock has been selected
                }

                break;
            case 1:
                if (clock_is_24h) {
                    format_string = _("Yesterday at %-H:%M"); ///TRANSLATORS Used when 24h clock has been selected
                } else {
                    format_string = _("Yesterday at %-I:%M %p"); ///TRANSLATORS Used when 12h clock has been selected
                }

                break;

            default:
                if (clock_is_24h) {
                    format_string = _("%A at %-H:%M"); ///TRANSLATORS Used when 24h clock has been selected
                } else {
                    format_string = _("%A at %-I:%M %p"); ///TRANSLATORS Used when 12h clock has been selected
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
