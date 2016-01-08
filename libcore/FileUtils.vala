/***
    Copyright (C) 2015 Elementary Developers

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/
namespace PF.FileUtils {
    const string reserved_chars = (GLib.Uri.RESERVED_CHARS_GENERIC_DELIMITERS + GLib.Uri.RESERVED_CHARS_SUBCOMPONENT_DELIMITERS + " ");

    /**
     * Gets a properly escaped GLib.File for the given path
     **/
    public File? get_file_for_path (string? path) {
        File? file = null;
        string new_path = sanitize_path (path);
        if (path.length > 0) {
            file = File.new_for_commandline_arg (new_path);
        }
        return file;
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
        reserved_chars.replace("#", "");
        return Uri.escape_string ((Uri.unescape_string (uri) ?? uri), reserved_chars, allow_utf8);
    }

    /** Produce a valid unescaped path **/
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
                sb.prepend (Environment.get_home_dir ());
            }
        }

        path = sb.str;
        do {
            path = path.replace ("//", "/");
        } while (path.contains ("//"));

        string new_path = (scheme + path).replace("////", "///");

        if (new_path.length > 0) {
            if (scheme != Marlin.ROOT_FS_URI && path != "/") {
                new_path = new_path.replace ("///", "//");
            }
            new_path = new_path.replace("ssh:", "sftp:");
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

    /* Signature must be compatible with MarlinUndoStackManager undo and redo functions */
    public delegate void RenameCallbackFunc (GLib.File old_location, GLib.File? new_location, GLib.Error? error);

    public void set_file_display_name (GLib.File old_location, string new_name, PF.FileUtils.RenameCallbackFunc? f) {

        /** TODO Check validity of new name, make cancellable **/

        GLib.File? new_location = null;
        GOF.Directory.Async? dir = GOF.Directory.Async.cache_lookup_parent (old_location);
        string original_name = old_location.get_basename ();

        old_location.set_display_name_async (new_name, 0, null, (obj, res) => {
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
}

namespace Marlin {
    public const string ROOT_FS_URI = "file://";
    public const string TRASH_URI = "trash:///";
    public const string NETWORK_URI = "network:///";
    public const string RECENT_URI = "recent:///";
    public const string AFP_URI = "afp://";
    public const string DAV_URI = "dav://";
    public const string DAVS_URI = "davs://";
    public const string SFTP_URI = "sftp://";
    public const string FTP_URI = "ftp://";
    public const string SMB_URI = "smb://";
    public const string MTP_URI = "mtp://";
}
