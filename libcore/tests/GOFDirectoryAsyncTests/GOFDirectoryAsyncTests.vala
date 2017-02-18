/*
* Copyright (c) 2017 elementary LLC
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 59 Temple Place - Suite 330,
* Boston, MA 02111-1307, USA.
*
* Authored by: Jeremy Wootten <jeremy@elementaryos.org>
*/

void add_gof_directory_async_tests () {
    /* loading */
    Test.add_func ("/GOFDirectoryAsync/load_non_existent_local", () => {
        run_load_folder_test (load_non_existent_local_test);
    });
    Test.add_func ("/GOFDirectoryAsync/load_empty_local", () => {
        run_load_folder_test (load_empty_local_test);
    });
    Test.add_func ("/GOFDirectoryAsync/load_populated_local", () => {
        run_load_folder_test (load_populated_local_test);
    });
    Test.add_func ("/GOFDirectoryAsync/load_cached_local", () => {
        run_load_folder_test (load_cached_local_test);
    });
}

delegate GOF.Directory.Async LoadFolderTest (string path, MainLoop loop);
void run_load_folder_test (LoadFolderTest test) {
    var loop = new GLib.MainLoop ();
    string test_dir_path = "/tmp/marlin-test-" + get_real_time ().to_string ();

    GOF.Directory.Async dir = test (test_dir_path, loop);

    dir.init ();
    loop.run ();

    /* Tear down */
    Posix.system ("rm -rf " + test_dir_path);
}

GOF.Directory.Async load_non_existent_local_test (string test_dir_path, MainLoop loop) {
    GLib.File gfile = GLib.File.new_for_commandline_arg (test_dir_path);
    assert (!gfile.query_exists (null));

    GOF.Directory.Async dir = GOF.Directory.Async.from_gfile (gfile);
    dir.done_loading.connect (() => {
        assert (dir.files_count == 0);
        assert (!dir.can_load);
        Test.assert_expected_messages ();
        loop.quit ();
    });

    Test.expect_message (null, GLib.LogLevelFlags.LEVEL_WARNING,"*info*");
    Test.expect_message (null, GLib.LogLevelFlags.LEVEL_WARNING,"*cannot load*");

    return dir;
}

GOF.Directory.Async load_empty_local_test (string test_dir_path, MainLoop loop) {
    var dir = setup_temp_async (test_dir_path, 0);

    dir.done_loading.connect (() => {
        assert (dir.files_count == 0);
        assert (dir.can_load);
        loop.quit ();
    });

    return dir;
}

GOF.Directory.Async load_populated_local_test (string test_dir_path, MainLoop loop) {
    uint n_files = 5;
    uint file_loaded_signal_count = 0;

    var dir = setup_temp_async (test_dir_path, n_files);

    dir.file_loaded.connect (() => {
        file_loaded_signal_count++;
    });

    dir.done_loading.connect (() => {
        assert (dir.files_count == n_files);
        assert (dir.can_load);
        assert (dir.state == GOF.Directory.Async.State.LOADED);
        assert (file_loaded_signal_count == n_files);
        loop.quit ();
    });

    return dir;
}

GOF.Directory.Async load_cached_local_test (string test_dir_path, MainLoop loop) {
    uint n_files = 5;
    bool first_load = true;
    uint file_loaded_signal_count = 0;

    var dir = setup_temp_async (test_dir_path, n_files);

    dir.done_loading.connect (() => {
        if (first_load) {
            first_load = false;
            dir.file_loaded.connect (() => {
                file_loaded_signal_count++;
            });

            Test.expect_message (null, GLib.LogLevelFlags.LEVEL_DEBUG,"*cached*");
            dir.init ();
        } else {
            assert (dir.files_count == n_files);
            assert (dir.can_load);
            assert (dir.state == GOF.Directory.Async.State.LOADED);
            assert (file_loaded_signal_count == n_files);
            Test.assert_expected_messages ();
            loop.quit ();
        }
    });
    return dir;
}

GOF.Directory.Async setup_temp_async (string path, uint n_files, string? extension = null, string? path_to_template = null) {
    assert (extension == null || extension.length > 0 || extension.length < 5);

    Posix.system ("mkdir " + path);
    string extn = "";

    if (extension != null) {
        extn = "." + extension;
    }

    for (int i = 0; i < n_files; i++) {
        string pth = path + Path.DIR_SEPARATOR_S + i.to_string () + extn;
        if (path_to_template == null) {
            /* create empty files */
            Posix.system ("touch " + pth);
        } else {
            Posix.system ("cp --no-dereference --no-clobber " + path_to_template + " " + pth);
        }
    }

    GLib.File gfile = GLib.File.new_for_commandline_arg (path);
    assert (gfile.query_exists (null));

    GOF.Directory.Async dir = GOF.Directory.Async.from_gfile (gfile);
    assert (dir != null);
    return dir;
}

int main (string[] args) {
    Test.init (ref args);

    add_gof_directory_async_tests ();
    return Test.run ();
}
