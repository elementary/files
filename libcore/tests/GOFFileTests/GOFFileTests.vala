/***
    Copyright (c) 2017-2018 elementary LLC <https://elementary.io>

    This file is part of Pantheon Files.

    Pantheon Files is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with Pantheon Files. If not, see <http://www.gnu.org/licenses/>.

    Authored by: Jeremy Wootten <jeremy@elementaryos.org>
***/

void add_gof_file_tests () {
    /* loading */
    Test.add_func ("/GOFFile/new_existing_local_folder", existing_local_folder_test);
    Test.add_func ("/GOFFile/gof_file_cache", gof_file_cache_test);
    Test.add_func ("/GOFFile/new_non_existent_local", new_non_existent_local_test);
    Test.add_func ("/GOFFile/new_hidden_local", new_hidden_local_test);
    Test.add_func ("/GOFFile/new_symlink_local", new_symlink_local_test);
}

void existing_local_folder_test () {
    string parent_path = "/usr";
    string basename = "share";
    string path = Path.build_filename (parent_path, basename);
    string uri = "file://" + path;

    /* Check that "get_by_uri copes correctly with missing scheme in uri" */
    Files.File? file = Files.File.get_by_uri (path);

    assert_true (file != null);
    assert_true (file.location != null);
    /* File is assumed to exist, to be mounted and be accessible when created */
    assert_true (file.exists);
    assert_true (file.is_connected);
    assert_true (file.is_mounted);

    file.query_update ();
    assert_true (file.exists);
    assert_true (file.is_connected);
    /* file.is_mounted only true of the file is associated with a mount */
    assert_false (file.is_mounted);
    assert_true (file.basename == basename);
    assert_true (file.is_directory);
    assert_false (file.is_hidden);
    assert_true (file.get_ftype () == "inode/directory");
    assert_false (file.is_symlink ());
    assert_true (file.location.get_uri () == uri);
    assert_true (file.uri == uri);

    assert_true (file.info != null);
    FileInfo info = file.info;
    assert_true (info.get_name () == basename);
    assert_true (info.get_display_name () == basename);
}

void gof_file_cache_test () {
    string parent_path = "/usr";
    string basename = "share";
    string path = Path.build_filename (parent_path, basename);
    string uri = "file://" + path;

    Files.File? file = Files.File.get_by_commandline_arg (path);
    assert_true (file.ref_count == 2);

    Files.File? file2 = Files.File.get_by_uri (uri);
    assert_true (file == file2);
    assert_true (file.ref_count == 3);
    assert_true (file2.ref_count == 3);

    file.remove_from_caches ();
    assert_true (file.ref_count == 2);
    assert_true (file2.ref_count == 2);

    file2.remove_from_caches ();
    assert_true (file.ref_count == 2);
    assert_true (file2.ref_count == 2);

    Files.File? file3 = Files.File.get_by_uri (uri);
    assert_true (file != file3);
    assert_true (file.ref_count == 2);
    assert_true (file3.ref_count == 2);

    file3.remove_from_caches ();
    assert_true (file3.ref_count == 1);
}

void new_non_existent_local_test () {
    string basename = get_real_time ().to_string ();
    string path = Path.build_filename ("/", "tmp", "marlin-test", basename);
    Files.File? file = Files.File.get_by_commandline_arg (path);
    assert_true (file != null);
    assert_true (file.location != null);
    assert_true (file.exists);

    file.query_update ();
    assert_true (file.info == null);
    assert_false (file.exists); /* is_mounted and is_connected undefined if !exists */
}

void new_hidden_local_test () {
    string basename = ".hidden_test";
    string parent_path = Path.build_filename ("/", "tmp", "marlin-test" + get_real_time ().to_string ());
    string path = Path.build_filename (parent_path, basename);

    Posix.system ("mkdir " + parent_path);
    Posix.system ("touch " + path);

    Files.File? file = Files.File.get_by_commandline_arg (path);
    assert_true (file != null);
    assert_true (file.location != null);
    /* File is assumed to exist and be accessible when created */
    assert_true (file.exists == true);
    assert_true (file.is_connected == true);
    assert_true (file.is_mounted);

    file.query_update ();
    assert_true (file.info != null);
    assert_true (file.exists);
    assert_true (file.is_connected);
    assert_false (file.is_mounted);

    assert_false (file.is_directory);
    assert_true (file.is_hidden);
    assert_true (file.size == 0);

    Posix.system ("rm -rf " + parent_path);
}

void new_symlink_local_test () {
    string basename = "target";
    string linkname = "link";
    string parent_path = Path.build_filename ("/", "tmp", "marlin-test" + get_real_time ().to_string ());
    string path = Path.build_filename (parent_path, basename);
    string link_path = Path.build_filename (parent_path, linkname);

    Posix.system ("mkdir " + parent_path);
    Posix.system ("touch " + path);
    Posix.system ("ln -s " + path + " " + link_path);

    Files.File? file = Files.File.get_by_commandline_arg (link_path);
    assert_true (file != null);
    assert_true (file.location != null);
    assert_true (file.exists);

    file.query_update ();
    assert_true (file.info != null);
    assert_true (file.get_symlink_target () == path);
    assert_true (file.is_symlink ());
    assert_false (file.is_directory);
    assert_false (file.is_hidden);

    Posix.system ("rm -rf " + parent_path);
}

int main (string[] args) {
    Test.init (ref args);

    add_gof_file_tests ();
    return Test.run ();
}
