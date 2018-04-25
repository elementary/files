/* Copyright (c) 2018 elementary LLC (https://elementary.io)
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

namespace PF.UserUtils {
    [CCode (cname="NGROUPS_MAX")]
    public extern const int NGROUPS_MAX;

    public GLib.List<string> get_user_names () {
        var list = new GLib.List<string> ();

        Posix.setpwent ();
        for (unowned Posix.Passwd? user = Posix.getpwent (); user != null; user = Posix.getpwent ()) {
            list.prepend (user.pw_name);
        }

        Posix.endpwent ();
        list.sort (string.collate);
        return list;
    }

    public GLib.List<string> get_group_names_for_user () {
        var list = new GLib.List<string> ();
        var gid_list = new Posix.gid_t[NGROUPS_MAX + 1];
        var group_number = Linux.getgroups (gid_list);
        for (int i = 0; i < group_number; i++) {
            unowned Posix.Group? group = Posix.getgrgid (gid_list[i]);
            if (group == null) {
                break;
            }

            list.prepend (group.gr_name);
        }

        list.sort (string.collate);
        return list;
    }

    public GLib.List<string> get_all_group_names () {
        var list = new GLib.List<string> ();

        Posix.setgrent ();
        for (unowned Posix.Group? group = Posix.getgrent (); group != null; group = Posix.getgrent ()) {
            list.prepend (group.gr_name);
        }

        Posix.endgrent ();
        list.sort (string.collate);
        return list;
    }

    public bool user_in_group (string group_name) {
        var gid_list = new Posix.gid_t[NGROUPS_MAX + 1];
        var group_number = Linux.getgroups (gid_list);
        for (int i = 0; i < group_number; i++) {
            unowned Posix.Group? group = Posix.getgrgid (gid_list[i]);
            if (group == null) {
                break;
            }

            if (group.gr_name == group_name) {
                return true;
            }
        }

        return false;
    }

    public Posix.uid_t? get_group_id_from_group_name (string group_name) {
        unowned Posix.Group? group = Posix.getgrnam (group_name);
        if (group == null) {
            return null;
        }

        Posix.uid_t? uid = group.gr_gid;
        return uid;
    }

    public Posix.uid_t? get_user_id_from_user_name (string user_name) {
        unowned Posix.Passwd? password_info = Posix.getpwnam (user_name);
        if (password_info == null) {
            return null;
        }

        Posix.uid_t? uid = password_info.pw_uid;
        return uid;
    }

    public unowned string? get_user_home_from_user_uid (Posix.uid_t uid) {
        unowned Posix.Passwd? password_info = Posix.getpwuid (uid);
        if (password_info == null) {
            return null;
        }

        return password_info.pw_dir;
    }

    public Posix.uid_t? get_id_from_digit_string (string digit_string) {
        char c;
        long id;
        /*
         * Only accept string if it has one integer with nothing
         * afterwards.
         */
        if (digit_string.scanf ("%ld%c", out id, out c) != 1) {
            return null;
        }

        Posix.uid_t? uid = id;
        return uid;
    }

    public string get_real_user_home () {
        unowned string? real_uid_s = GLib.Environ.get_variable (GLib.Environ.get (), "PKEXEC_UID");

        if (real_uid_s != null) {
            Posix.uid_t? scanned_id = get_id_from_digit_string (real_uid_s);
            if (scanned_id != null) {
                return get_user_home_from_user_uid (scanned_id);
            }
        }

        return GLib.Environment.get_home_dir ();
    }
}
