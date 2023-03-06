/*
* Copyright (c) 2017-2020 elementary LLC <https://elementary.io>
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
        assert (Files.FileUtils.sanitize_path (null, null, false) == "");
    });

    Test.add_func ("/FileUtils/sanitize_zero_length_abs_path", () => {
        assert (Files.FileUtils.sanitize_path ("", null) == "");
    });

    Test.add_func ("/FileUtils/afc_device_root_strip_colon", () => {
        /* Remove extraneous trailing colon-number from afc device name */
        string afc_device = "afc://028fd2b08554adf7c3aaf66e6ecb9af7d40daeeb";
        assert (Files.FileUtils.sanitize_path (afc_device + ":3/") == afc_device);
    });

    Test.add_func ("/FileUtils/afc_device_root_no_colon", () => {
        string afc_device = "afc://028fd2b08554adf7c3aaf66e6ecb9af7d40daeeb";
        assert (Files.FileUtils.sanitize_path (afc_device) == afc_device);
    });

    Test.add_func ("/FileUtils/afc_path_strip_colon", () => {
        /* Remove extraneous trailing colon-number from afc device name, but not from folder name */
        string afc_device = "afc://028fd2b08554adf7c3aaf66e6ecb9af7d40daeeb";
        var path = "/some/path/with/colon:3";
        assert (Files.FileUtils.sanitize_path (afc_device + ":3" + path) == afc_device + path);
    });

    Test.add_func ("/FileUtils/afc_device_do_not_strip_colon", () => {
        /* Do not remove colon-nonnumber from afc device name */
        string afc_device = "afc://028fd2b08554adf7c3aaf66e6ecb9af7d40daeeb:b";
        assert (Files.FileUtils.sanitize_path (afc_device) == afc_device);
    });

    Test.add_func ("/FileUtils/sanitize_null_rel_path", () => {
        string cp = "file:///home";
        assert (Files.FileUtils.sanitize_path (null, cp, true) == cp);
    });

    Test.add_func ("/FileUtils/sanitize_null_rel_path_strip", () => {
        string cp = "file:///home";
        assert (Files.FileUtils.sanitize_path (null, cp, false) == "/home");
    });

    Test.add_func ("/FileUtils/sanitize_tilde", () => {
        string cp = "file:///usr/share";
        /* In this case we will strip off the file:// prefix */
        assert (Files.FileUtils.sanitize_path ("~/", cp, false) == PF.UserUtils.get_real_user_home ());
    });

    Test.add_func ("/FileUtils/sanitize_double_dot", () => {
        string cp = "file:///usr/share";
        assert (Files.FileUtils.sanitize_path ("../", cp) == "file:///usr");
    });

    Test.add_func ("/FileUtils/sanitize_double_dot_remote", () => {
        string cp = "afp://user@server/root/folder/subfolder";
        assert (Files.FileUtils.sanitize_path ("../", cp) == "afp://user@server/root/folder");
    });

    Test.add_func ("/FileUtils/sanitize_single_dot", () => {
        string cp = "file:///usr/share";
        assert (Files.FileUtils.sanitize_path ("./", cp) == "file:///usr/share");
    });

    Test.add_func ("/FileUtils/sanitize_ignore_embedded_single_dot", () => {
        string cp = "";
        assert (Files.FileUtils.sanitize_path ("/home/./user", cp) == "file:///home/./user");
    });

    Test.add_func ("/FileUtils/sanitize_ignore_embedded_double_dot_strip", () => {
        string cp = "";
        assert (Files.FileUtils.sanitize_path ("file:///home/../usr", cp, false) == "/home/../usr");
    });

    Test.add_func ("/FileUtils/sanitize_ignore_remote_embedded_tilde_strip", () => {
        string cp = "";
        assert (Files.FileUtils.sanitize_path ("smb://home/~/usr", cp, false) == "smb://home/~/usr");
    });

    Test.add_func ("/FileUtils/sanitize_network_double_dot", () => {
        string cp = "network://";
        assert (Files.FileUtils.sanitize_path ("../", cp) == "network://");
    });

    Test.add_func ("/FileUtils/sanitize_remove_excess_slash1", () => {
        string cp = "network:///";
        assert (Files.FileUtils.sanitize_path ("", cp) == "network://");
    });

    Test.add_func ("/FileUtils/sanitize_remove_excess_slash2", () => {
        string p = "home//Documents";
        assert (Files.FileUtils.sanitize_path (p, null, false) == "home/Documents");
    });

    Test.add_func ("/FileUtils/sanitize_remove_excess_slash3", () => {
        string p = "file:////home/Documents";
        assert (Files.FileUtils.sanitize_path (p, null) == "file:///home/Documents");
    });

    /* Get file for path */
    Test.add_func ("/FileUtils/file_for_null_path", () => {
        /* For some reason using assert_null does not work */
        assert (Files.FileUtils.get_file_for_path (null) == null);
    });

    Test.add_func ("/FileUtils/file_for_zero_length_path", () => {
        assert (Files.FileUtils.get_file_for_path ("") == null);
    });

    Test.add_func ("/FileUtils/make_filename_valid_null", () => {
        string filename = "Valid:;*?\\<> name";
        string? dest_fs = null;
        bool changed = Files.FileUtils.make_file_name_valid_for_dest_fs (ref filename, dest_fs);
        assert (changed == false);
        assert (filename == "Valid:;*?\\<> name");
    });

    /* Make filename valid for destination fs */
    Test.add_func ("/FileUtils/make_filename_valid_ext", () => {
        string filename = "Valid:;*?\\<> name";
        string dest_fs = "ext3/ext4";
        bool changed = Files.FileUtils.make_file_name_valid_for_dest_fs (ref filename, dest_fs);
        assert (changed == false);
        assert (filename == "Valid:;*?\\<> name");
    });

    Test.add_func ("/FileUtils/make_filename_valid_msdos", () => {
        string filename = "Invalid:;*?\\<> name"; // 8 invalid characters
        string dest_fs = "msdos";
        bool changed = Files.FileUtils.make_file_name_valid_for_dest_fs (ref filename, dest_fs);
        assert (changed == true);
        assert (filename == "Invalid________name");
    });

    /* Format time for progress output */
    Test.add_func ("/FileUtils/format_time_negative", () => {
        int time_unit;
        string formated_time = Files.FileUtils.format_time (-1, out time_unit);
        assert (time_unit == 0);
        assert (formated_time.contains ("0 seconds"));
    });

    Test.add_func ("/FileUtils/format_time_seconds", () => {
        int time_unit;
        string formated_time = Files.FileUtils.format_time (39, out time_unit);
        assert (time_unit > 1);
        assert (formated_time.contains ("39 seconds"));
    });

    Test.add_func ("/FileUtils/format_time_minute", () => {
        int time_unit;
        string formated_time = Files.FileUtils.format_time (60, out time_unit);
        assert (time_unit == 1);
        assert (formated_time.contains ("1 minute"));
    });

    Test.add_func ("/FileUtils/format_time_hours_minutes", () => {
        int time_unit;
        string formated_time = Files.FileUtils.format_time (3720, out time_unit);
        assert (time_unit == 3);
        assert (formated_time.contains ("1 hour, 2 minutes"));
    });

    Test.add_func ("/FileUtils/format_time_approx", () => {
        int time_unit;
        string formated_time = Files.FileUtils.format_time (16000, out time_unit);
        assert (time_unit == 4);
        assert (formated_time.contains ("approximately 4 hours"));
    });

    Test.add_func ("/FileUtils/shorten_utf8_1", () => {
        string result = Files.FileUtils.shorten_utf8_string ("a", 2);
        assert (result == "");
    });

    /* Shorten English strings (1 byte per character) */
    Test.add_func ("/FileUtils/shorten_utf8_2", () => {
        string result = Files.FileUtils.shorten_utf8_string ("abc", 2);
        assert (result == "a");
    });

    /* Shorten Japanese strings (3 bytes per character) */
    Test.add_func ("/FileUtils/shorten_utf8_3", () => {
        string base_string = "試し";
        string result = Files.FileUtils.shorten_utf8_string (base_string, 1);
        assert (result == "試");
    });

    Test.add_func ("/FileUtils/shorten_utf8_4", () => {
        string result = Files.FileUtils.shorten_utf8_string ("試し", 3);
        assert (result == "試");
    });

    Test.add_func ("/FileUtils/shorten_utf8_5", () => {
        string result = Files.FileUtils.shorten_utf8_string ("試し", 4);
        assert (result == "");
    });

    /* Get link names */
    Test.add_func ("/FileUtils/get_link_name_0", () => {
        string target = "path_to_link";
        string result = Files.FileUtils.get_link_name (target, 0);
        assert (result == target);
    });

    Test.add_func ("/FileUtils/get_link_name_1", () => {
        string target = "target";
        string result = Files.FileUtils.get_link_name (target, 1);
        //Does this need to be translated?
        assert (result.contains (Files.FileUtils.LINK_TAG));
        assert (!result.contains ("1"));
    });

    Test.add_func ("/FileUtils/get_link_name_ext_1", () => {
        string target = "Filename.ext";
        string result = Files.FileUtils.get_link_name (target, 1);
        assert (result.contains (".ext"));
        assert (result.contains ("link"));
    });

    Test.add_func ("/FileUtils/get_link_name_ext_11", () => {
        string target = "Filename.ext";
        string result = Files.FileUtils.get_link_name (target, 11);
        assert (result != target);
        assert (result.contains ("11"));
    });

    Test.add_func ("/FileUtils/get_link_name_11", () => {
        string target = "target";
        string result = Files.FileUtils.get_link_name (target, 11);
        assert (result.contains (Files.FileUtils.LINK_TAG));
        assert (result.contains ("11"));
    });

    Test.add_func ("/FileUtils/get_link_to_link", () => {
        string target = "target (link)";
        string result = Files.FileUtils.get_link_name (target, 1);
        var parts = result.split (Files.FileUtils.LINK_TAG);
        assert (parts.length == 3);
    });

    /* Get duplicate names */

    Test.add_func ("/FileUtils/get_duplicate_name_3_ext", () => {
        string name = "Filename.ext";

        var result = Files.FileUtils.get_duplicate_name (name, 1, -1, false);
        assert (result.contains (Files.FileUtils.COPY_TAG));

        result = Files.FileUtils.get_duplicate_name (result, 1, -1, false);
        assert (result.contains ("2"));

        result = Files.FileUtils.get_duplicate_name (result, 2, -1);
        assert (result.contains ("4"));
        var parts = result.split (Files.FileUtils.COPY_TAG);
        assert (parts.length == 2);
        assert (result.has_suffix (".ext"));
        assert (result.has_prefix ("Filename"));
    });

    Test.add_func ("/FileUtils/get_duplicate_4_ext", () => {
        string name = "Filename.mpeg";
        var result = Files.FileUtils.get_duplicate_name (name, 1, -1, false);
        assert (result.has_suffix ("mpeg"));
    });

    Test.add_func ("/FileUtils/get_duplicate_not_an_extension", () => {
        string name = "Filename.not.an.extension";
        var result = Files.FileUtils.get_duplicate_name (name, 1, -1, false);
        assert (!result.has_suffix ("extension"));
    });

    Test.add_func ("/FileUtils/get_duplicate_no_extension", () => {
        string name = "Filename";
        var result = Files.FileUtils.get_duplicate_name (name, 1, -1, false);
        assert (result.has_suffix (Files.FileUtils.CLOSING_COPY_LINK_TAG));
    });

    Test.add_func ("/FileUtils/get_duplicate_no_extension_short", () => {
        string name = "F";
        var result = Files.FileUtils.get_duplicate_name (name, 1, -1, false);
        assert (result.has_suffix (Files.FileUtils.CLOSING_COPY_LINK_TAG));
    });

    Test.add_func ("/FileUtils/get_duplicate_embedded_tag", () => {
        string name = "foo(copy)bar.txt";
        var result = Files.FileUtils.get_duplicate_name (name, 1, -1, false);
        var parts = result.split ("(");
        assert (parts.length == 3);
        assert (result.contains ("foo"));
        assert (result.contains ("bar"));
        assert (result.has_suffix (".txt"));
    });

    Test.add_func ("/FileUtils/get_duplicate_embedded_tag_no_extension", () => {
        string name = "foo(copy)bar(copy 2)";
        var result = Files.FileUtils.get_duplicate_name (name, 1, -1, false);
        var parts = result.split ("(");
        assert (parts.length == 3);
        assert (result.contains ("foo"));
        assert (result.contains ("bar"));
        assert (result.contains ("3"));
    });

    /* Duplicating "Filename (link)" should yield "Filename (link 2)" not "Filename (link) (copy)" */
    Test.add_func ("/FileUtils/get_duplicate_link", () => {
        string name = "Filename ".concat (
             Files.FileUtils.OPENING_COPY_LINK_TAG, Files.FileUtils.LINK_TAG, Files.FileUtils.CLOSING_COPY_LINK_TAG, null
        );
        var result = Files.FileUtils.get_duplicate_name (name, 1, -1, true);
        assert (result.has_suffix (Files.FileUtils.CLOSING_COPY_LINK_TAG));
        assert (result.contains (Files.FileUtils.LINK_TAG));
        assert (!result.contains (Files.FileUtils.COPY_TAG));
        assert (result.contains ("2"));
    });

    Test.add_func ("/FileUtils/get_duplicate_link_embedded_tag", () => {
        string name = "File(link)name ".concat (
             Files.FileUtils.OPENING_COPY_LINK_TAG, Files.FileUtils.LINK_TAG, Files.FileUtils.CLOSING_COPY_LINK_TAG, null
        );
        var result = Files.FileUtils.get_duplicate_name (name, 1, -1, true);
        assert (result.has_suffix (Files.FileUtils.CLOSING_COPY_LINK_TAG));
        assert (result.contains (Files.FileUtils.LINK_TAG));
        assert (!result.contains (Files.FileUtils.COPY_TAG));
        assert (result.contains ("2"));
    });

    Test.add_func ("/FileUtils/disambiguate_path/conflicting", () => {
        var result = Files.FileUtils.disambiguate_uri (
            "/A/B/folder",
            "/A/C/folder"
        );
        assert (result == "B/folder");
    });

    Test.add_func ("/FileUtils/disambiguate_path/different_length", () => {
        var result = Files.FileUtils.disambiguate_uri (
            "/A/B/folder",
            "X/A/B/folder"
        );
        assert (result == "/A/B/folder");

        result = Files.FileUtils.disambiguate_uri (
            "X/A/B/folder",
            "/A/B/folder"
        );
        assert (result == "X/A/B/folder");
    });

    Test.add_func ("/FileUtils/disambiguate_path/not_conflicting", () => {
        var result = Files.FileUtils.disambiguate_uri (
            "/A/B/folder",
            "/A/B/folder2"
        );
        assert (result == "folder");
    });

    Test.add_func ("/FileUtils/disambiguate_path/equivalent", () => {
        var result = Files.FileUtils.disambiguate_uri (
            "/A/B/folder",
            "file:///A/B/folder"
        );
        assert (result == "folder");

        result = Files.FileUtils.disambiguate_uri (
            "file:///A/B/folder",
             "/A/B/folder"
        );
        assert (result == "folder");
    });

    Test.add_func ("/FileUtils/disambiguate_path/different_scheme", () => {
        var result = Files.FileUtils.disambiguate_uri (
            "/A/B/folder",
            "smb:///A/B/folder"
        );
        assert (result == "/A/B/folder");

        result = Files.FileUtils.disambiguate_uri (
            "smb:///A/B/folder",
            "/A/B/folder"
        );
        assert (result == "smb:///A/B/folder");
    });
}

int main (string[] args) {
    Test.init (ref args);

    add_file_utils_tests ();
    return Test.run ();
}
