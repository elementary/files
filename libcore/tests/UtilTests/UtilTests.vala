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

    Test.add_func ("/FileUtils/limited_length_path", test_limited_length_path);
}

int main (string[] args) {
    Test.init (ref args);

    add_file_utils_tests ();
    return Test.run ();
}

void test_limited_length_path () {
    const int DEFAULT_LENGTH = 10;

    // Test empty string
    assert (PF.FileUtils.limited_length_path ("", DEFAULT_LENGTH) == "");

    //  Test path
    var path = "/foo/bar/baz/abc.txt";
    var file_length = 7;
    var baz_length = 11;
    var bar_length = 15;
    var foo_length = 19;
    assert (PF.FileUtils.limited_length_path (path, foo_length) == "/foo/bar/baz/abc.txt");
    assert (PF.FileUtils.limited_length_path (path, bar_length+1) == "…/foo/bar/baz/abc.txt");
    assert (PF.FileUtils.limited_length_path (path, bar_length) == "…/bar/baz/abc.txt");
    assert (PF.FileUtils.limited_length_path (path, baz_length+1) == "…/bar/baz/abc.txt");
    assert (PF.FileUtils.limited_length_path (path, baz_length) == "…/baz/abc.txt");
    assert (PF.FileUtils.limited_length_path (path, file_length+1)  == "…/baz/abc.txt");
    assert (PF.FileUtils.limited_length_path (path, file_length)  == "…/abc.txt");
    assert (PF.FileUtils.limited_length_path (path, 1)  == "…/abc.txt");
    assert (PF.FileUtils.limited_length_path (path, 0)  == "…/abc.txt");

    //  Test path smaller than limit
    var res1 = PF.FileUtils.limited_length_path (path, 20);
    var res2 = PF.FileUtils.limited_length_path (path, 50);
    var res3 = PF.FileUtils.limited_length_path (path, 100);
    assert (res1 == res2 && res2 == res3);

    //  Test non-path
    assert (PF.FileUtils.limited_length_path ("abc.txt", DEFAULT_LENGTH) == "abc.txt");

    //  Test wrong path
    var wrong_path = "abc.txt/foo";
    assert (PF.FileUtils.limited_length_path ("abc.txt/foo", wrong_path.length+1) == "abc.txt/foo");
}
