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

namespace GOF.Directory {
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
    Test.add_func ("/GOFDirectoryAsync/reload_populated_local", () => {
        run_load_folder_test (reload_populated_local_test);
    });
}

delegate Async LoadFolderTest (string path, MainLoop loop);
void run_load_folder_test (LoadFolderTest test) {
    var loop = new GLib.MainLoop ();
    string test_dir_path = "/tmp/marlin-test-" + get_real_time ().to_string ();

    var dir = test (test_dir_path, loop);
    dir.allow_user_interaction = false;

    assert (dir.state == Async.State.NOT_LOADED);

    dir.init ();
    loop.run ();

    /* Tear down test folder*/
    tear_down_folder (test_dir_path);
}

/*** Test functions ***/
Async load_non_existent_local_test (string test_dir_path, MainLoop loop) {
    GLib.File gfile = GLib.File.new_for_commandline_arg (test_dir_path);
    assert (!gfile.query_exists (null));

    var dir = Async.from_gfile (gfile);
    dir.done_loading.connect (() => {
        assert (dir.displayed_files_count == 0);
        assert (!dir.can_load);
        assert (!dir.file.is_connected);
        assert (!dir.file.is_mounted);
        assert (!dir.file.exists);
        assert (dir.state == Async.State.NOT_LOADED);
        loop.quit ();
    });

    return dir;
}

Async load_empty_local_test (string test_dir_path, MainLoop loop) {
    var dir = setup_temp_async (test_dir_path, 0);

    dir.done_loading.connect (() => {
        assert (dir.displayed_files_count == 0);
        assert (dir.can_load);
        assert (dir.file.is_connected);
        assert (!dir.file.is_mounted);
        assert (dir.file.exists);
        assert (dir.state == Async.State.LOADED);
        loop.quit ();
    });

    return dir;
}

Async load_populated_local_test (string test_dir_path, MainLoop loop) {
    uint n_files = 5;
    uint file_loaded_signal_count = 0;

    var dir = setup_temp_async (test_dir_path, n_files);

    assert (dir.ref_count == 1); //Extra ref from pending cache;

    dir.file_loaded.connect (() => {
        file_loaded_signal_count++;
    });

    dir.done_loading.connect (() => {
        assert (dir.displayed_files_count == n_files);
        assert (dir.can_load);
        assert (dir.state == Async.State.LOADED);
        assert (file_loaded_signal_count == n_files);

        loop.quit ();
    });

    return dir;
}

Async load_cached_local_test (string test_dir_path, MainLoop loop) {
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

            assert (!dir.loaded_from_cache);
            dir.init ();
        } else {
            assert (dir.displayed_files_count == n_files);
            assert (dir.can_load);
            assert (dir.state == Async.State.LOADED);
            assert (file_loaded_signal_count == n_files);
            assert (dir.loaded_from_cache);
            loop.quit ();
        }
    });
    return dir;
}

Async reload_populated_local_test (string test_dir_path, MainLoop loop) {
    uint n_files = 50;
    uint n_loads = 5; /* Number of times to reload the directory */
    uint loads = 0;
    uint ref_count_before_reload = 0;
    string tmp_pth = get_text_template_path ();

    var dir = setup_temp_async (test_dir_path, n_files, "txt", tmp_pth);

    dir.done_loading.connect (() => {
        assert (!dir.loaded_from_cache);

        if (loads == 0) {
            ref_count_before_reload = dir.ref_count;
        }

        if (loads < n_loads) {
            loads++;
            dir.cancel ();
            dir.reload ();
        } else {
            assert (dir.displayed_files_count == n_files);
            assert (dir.can_load);
            assert (dir.state == Async.State.LOADED);
            assert (dir.ref_count == ref_count_before_reload);

            tear_down_file (tmp_pth);

            /* Test for problem with toggle ref after reloading (lp:1665620) */
            dir.cancel ();
            dir = null;

            loop.quit ();
        }
    });

    return dir;
}

/*** Helper functions ***/
Async setup_temp_async (string path, uint n_files, string? extension = null, string? path_to_template = null) {
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

    Async dir = Async.from_gfile (gfile);
    assert (dir != null);
    return dir;
}

string get_text_template_path () {
    string test_template_path = "/tmp/marlin-template-" + get_real_time ().to_string () + "txt";
    Posix.system ("env > " + test_template_path);
    return test_template_path;
}

void tear_down_folder (string path) {
    Posix.system ("rm -rf " + path);
}

void tear_down_file (string path) {
    Posix.system ("rm -f " + path);
}
}


int main (string[] args) {
    Test.init (ref args);

    GOF.Directory.add_gof_directory_async_tests ();
    return Test.run ();
}
