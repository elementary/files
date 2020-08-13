/*
* Copyright (c) 2017-2018 elementary LLC <https://elementary.io>
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
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
* MA 02110-1335 USA.
*
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

void add_file_utils_tests () {
    /* Sanitize path */
    Test.add_func ("/FileUtils/sanitize_null_abs_path", () => {
        assert (PF.FileUtils.sanitize_path (null, null, false) == "");
    });

    Test.add_func ("/FileUtils/sanitize_zero_length_abs_path", () => {
        assert (PF.FileUtils.sanitize_path ("", null, false) == "");

    });

    Test.add_func ("/FileUtils/sanitize_null_rel_path", () => {
        string cp = "file:///home";
        assert (PF.FileUtils.sanitize_path (null, cp, true) == cp);
    });

    Test.add_func ("/FileUtils/sanitize_null_rel_path_strip", () => {
        string cp = "file:///home";
        assert (PF.FileUtils.sanitize_path (null, cp, false) == "/home");
    });

    Test.add_func ("/FileUtils/sanitize_tilde", () => {
        string cp = "file:///usr/share";
        /* In this case we will strip off the file:// prefix */
        assert (PF.FileUtils.sanitize_path ("~/", cp, false) == PF.UserUtils.get_real_user_home ());
    });

    Test.add_func ("/FileUtils/sanitize_double_dot", () => {
        string cp = "file:///usr/share";
        assert (PF.FileUtils.sanitize_path ("../", cp) == "file:///usr");
    });

    Test.add_func ("/FileUtils/sanitize_double_dot_remote", () => {
        string cp = "afp://user@server/root/folder/subfolder";
        assert (PF.FileUtils.sanitize_path ("../", cp) == "afp://user@server/root/folder");
    });

    Test.add_func ("/FileUtils/sanitize_single_dot", () => {
        string cp = "file:///usr/share";
        assert (PF.FileUtils.sanitize_path ("./", cp) == "file:///usr/share");
    });

    Test.add_func ("/FileUtils/sanitize_ignore_embedded_single_dot", () => {
        string cp = "";
        assert (PF.FileUtils.sanitize_path ("/home/./user", cp) == "file:///home/./user");
    });

    Test.add_func ("/FileUtils/sanitize_ignore_embedded_double_dot_strip", () => {
        string cp = "";
        assert (PF.FileUtils.sanitize_path ("file:///home/../usr", cp, false) == "/home/../usr");
    });

    Test.add_func ("/FileUtils/sanitize_ignore_remote_embedded_tilde_strip", () => {
        string cp = "";
        assert (PF.FileUtils.sanitize_path ("smb://home/~/usr", cp, false) == "smb://home/~/usr");
    });

    Test.add_func ("/FileUtils/sanitize_network_double_dot", () => {
        string cp = "network://";
        assert (PF.FileUtils.sanitize_path ("../", cp) == "network://");
    });

    Test.add_func ("/FileUtils/sanitize_remove_excess_slash1", () => {
        string cp = "network:///";
        assert (PF.FileUtils.sanitize_path ("", cp) == "network://");
    });

    Test.add_func ("/FileUtils/sanitize_remove_excess_slash2", () => {
        string p = "home//Documents";
        assert (PF.FileUtils.sanitize_path (p, null, false) == "home/Documents");
    });

    Test.add_func ("/FileUtils/sanitize_remove_excess_slash3", () => {
        string p = "file:////home/Documents";
        assert (PF.FileUtils.sanitize_path (p, null) == "file:///home/Documents");
    });

    /* Get file for path */
    Test.add_func ("/FileUtils/file_for_null_path", () => {
        /* For some reason using assert_null does not work */
        assert (PF.FileUtils.get_file_for_path (null) == null);
    });

    Test.add_func ("/FileUtils/file_for_zero_length_path", () => {
        assert (PF.FileUtils.get_file_for_path ("") == null);
    });

    Test.add_func ("/FileUtils/format_time_negative", () => {
        int time_unit;
        string formated_time = PF.FileUtils.format_time (-1, out time_unit);
        assert (time_unit == 0);
        assert (formated_time.contains ("0 seconds"));
    });

    Test.add_func ("/FileUtils/format_time_seconds", () => {
        int time_unit;
        string formated_time = PF.FileUtils.format_time (39, out time_unit);
        assert (time_unit > 1);
        assert (formated_time.contains ("39 seconds"));
    });

    Test.add_func ("/FileUtils/format_time_minute", () => {
        int time_unit;
        string formated_time = PF.FileUtils.format_time (60, out time_unit);
        assert (time_unit == 1);
        assert (formated_time.contains ("1 minute"));
    });

    Test.add_func ("/FileUtils/format_time_hours_minutes", () => {
        int time_unit;
        string formated_time = PF.FileUtils.format_time (3720, out time_unit);
        assert (time_unit == 3);
        assert (formated_time.contains ("1 hour, 2 minutes"));
    });

    Test.add_func ("/FileUtils/format_time_approx", () => {
        int time_unit;
        string formated_time = PF.FileUtils.format_time (16000, out time_unit);
        assert (time_unit == 4);
        assert (formated_time.contains ("approximately 4 hours"));
    });
}

int main (string[] args) {
    Test.init (ref args);

    add_file_utils_tests ();
    return Test.run ();
}
