/*
* Copyright (c) 2017 elementary LLC
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

    /** Sanitize should (at least) unescape archive path **/
    Test.add_func ("/FileUtils/sanitize_archive_path", () => {
        /* Expect only remove special escaping */
        string res = PF.FileUtils.sanitize_path ("archive://file%3A%2F%2F%2Fhome%2F%252523test.zip");
        assert (res == "archive://file:///home/#test.zip");
    });

    /** Test construction of difficult archive path **/
    Test.add_func ("/FileUtils/construct_archive_path", () => {
        /* Expect only remove special escaping */
        string res = PF.FileUtils.construct_archive_uri ("archive://file:///home/#test.zip", "folder/file.txt");
        message ("res %s", res);
        assert (res == "archive://file%253A%252F%252F%252Fhome%252F%252523test.zip/folder/file.txt");
    });
}

int main (string[] args) {
    Test.init (ref args);

    add_file_utils_tests ();
    return Test.run ();
}
