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
        assert (PF.FileUtils.sanitize_path (null, null) == "");
    });

    Test.add_func ("/FileUtils/sanitize_zero_length_abs_path", () => {
        assert (PF.FileUtils.sanitize_path ("", null) == "");
    });

    Test.add_func ("/FileUtils/afc_device_root_strip_colon", () => {
        /* Remove extraneous trailing colon-number from afc device name */
        string afc_device = "afc://028fd2b08554adf7c3aaf66e6ecb9af7d40daeeb";
        assert (PF.FileUtils.sanitize_path (afc_device + ":3/") == afc_device);
    });

    Test.add_func ("/FileUtils/afc_device_root_no_colon", () => {
        string afc_device = "afc://028fd2b08554adf7c3aaf66e6ecb9af7d40daeeb";
        assert (PF.FileUtils.sanitize_path (afc_device) == afc_device);
    });

    Test.add_func ("/FileUtils/afc_path_strip_colon", () => {
        /* Remove extraneous trailing colon-number from afc device name, but not from folder name */
        string afc_device = "afc://028fd2b08554adf7c3aaf66e6ecb9af7d40daeeb";
        var path = "/some/path/with/colon:3";
        assert (PF.FileUtils.sanitize_path (afc_device + ":3" + path) == afc_device + path);
    });

    Test.add_func ("/FileUtils/afc_device_do_not_strip_colon", () => {
        /* Do not remove colon-nonnumber from afc device name */
        string afc_device = "afc://028fd2b08554adf7c3aaf66e6ecb9af7d40daeeb:b";
        assert (PF.FileUtils.sanitize_path (afc_device) == afc_device);
    });

    Test.add_func ("/FileUtils/sanitize_null_rel_path", () => {
        string cp = "file://home";
        assert (PF.FileUtils.sanitize_path (null, cp) == cp);
    });

    /* Get file for path */
    Test.add_func ("/FileUtils/file_for_null_path", () => {
        /* For some reason using assert_null does not work */
        assert (PF.FileUtils.get_file_for_path (null) == null);
    });

    Test.add_func ("/FileUtils/file_for_zero_length_path", () => {
        assert (PF.FileUtils.get_file_for_path ("") == null);
    });
}

int main (string[] args) {
    Test.init (ref args);

    add_file_utils_tests ();
    return Test.run ();
}
