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
        File? file = File.new_for_commandline_arg (path);
        string parent_path = path;
        if (file != null) {
            File? parent = file.get_parent ();
            if (parent != null) {
                parent_path = parent.get_path ();
            } else {
                parent_path = construct_parent_path (path);
            }
        }
        if (parent_path == Marlin.FTP_URI ||
            parent_path == Marlin.MTP_URI ||
            parent_path == Marlin.SFTP_URI) {

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
        return parent_path;
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
        new_path = path;

        string[] explode_protocol = new_path.split ("://");
        if (explode_protocol.length > 2) {
            new_path = "";
            return;
        }
        if (explode_protocol.length > 1) {
            if (explode_protocol[0] == "mtp") {
                string[] explode_path = explode_protocol[1].split ("]", 2);
                protocol = (explode_protocol[0] + "://" + explode_path[0] + "]").replace ("///", "//");
                /* If path is being manually edited there may not be "]" so explode_path[1] may be null*/
                new_path = explode_path [1] ?? "";
            } else {
                protocol = explode_protocol[0] + "://";
                new_path = explode_protocol[1];
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
}
