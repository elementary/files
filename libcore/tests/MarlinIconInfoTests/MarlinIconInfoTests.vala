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

    Authored by: Jeremy Wootten <jeremywootten@gmail.com>
***/

void add_icon_info_tests () {
    Test.add_func ("/MarlinIconInfo/goffile_icon_update", goffile_icon_update_test);
    Test.add_func ("/MarlinIconInfo/themed_cache_and_ref", themed_cache_and_ref_test);
    Test.add_func ("/MarlinIconInfo/loadable_cache_and_ref_local", loadable_cache_and_ref_test_local);
    Test.add_func ("/MarlinIconInfo/loadable_cache_and_ref_remote", loadable_cache_and_ref_test_remote);
}

void goffile_icon_update_test () {
    string test_file_path = Path.build_filename (Config.TESTDATA_DIR, "images", "testimage.png");
    Files.File file = Files.File.get_by_uri (test_file_path);
    assert (file != null);
    stderr.printf ("\n\rquery update file %s\n\r", file.uri);
    file.query_update ();
    assert (file.pix == null);
    file.update_icon (128, 1);
    assert (file.pix != null);
    assert (file.pix_size == 128);
    file.update_icon (32, 1);
    assert (file.pix_size == 32);
}

void themed_cache_and_ref_test () {
    Files.IconInfo.clear_caches ();
    uint reap_time_msec = 20; //Must be higher than 10.
    Files.IconInfo.set_reap_time (reap_time_msec);

    string test_file_path = Path.build_filename (Config.TESTDATA_DIR, "images", "testimage.png");
    Files.File file = Files.File.get_by_uri (test_file_path);
    assert (file != null);
    file.query_update ();
    /* file.pix might exist if tests run while Files instance also recently runn and displayed test image */
    file.pix = null;
    file.update_icon (128, 1);
    assert (file.pix != null);
    assert (file.pix.ref_count == 1); //themed icons are not cached

    file.update_icon (32, 1);
}

void loadable_cache_and_ref_test_local () {
    Files.IconInfo.clear_caches ();
    uint reap_time_msec = 20; //Must be higher than 10.
    Files.IconInfo.set_reap_time (reap_time_msec);

    string test_file_path = Path.build_filename (Config.TESTDATA_DIR, "images", "testimage.jpg");
    Files.File file = Files.File.get_by_uri (test_file_path);
    /* file.pix might exist if tests run while Files instance was recently run and displayed test image */
    file.pix = null;
    file.is_remote = false;
    file.query_update ();
    file.thumbstate = Files.File.ThumbState.READY;
    /* We need to provide our own thumbnail and path for CI */
    file.thumbnail_path = Path.build_filename (Config.TESTDATA_DIR, "images", "testimage.jpg.thumb.png");
    file.update_icon (128, 1);
    assert (file.pix != null);
    assert (file.pix.ref_count == 1); //Local thumbnails not cached

    file.update_icon (32, 1);
}

void loadable_cache_and_ref_test_remote () {
    Files.IconInfo.clear_caches ();
    uint reap_time_msec = 20; //Must be higher than 10.
    Files.IconInfo.set_reap_time (reap_time_msec);

    string test_file_path = Path.build_filename (Config.TESTDATA_DIR, "images", "testimage.jpg");
    Files.File file = Files.File.get_by_uri (test_file_path);
    /* file.pix might exist if tests run while Files instance was recently run and displayed test image */
    file.pix = null;
    file.is_remote = true;
    file.query_update ();
    file.thumbstate = Files.File.ThumbState.READY;
    /* We need to provide our own thumbnail and path for CI */
    file.thumbnail_path = Path.build_filename (Config.TESTDATA_DIR, "images", "testimage.jpg.thumb.png");
    file.update_icon (128, 1);
    assert (file.pix != null);
    assert (file.pix.ref_count == 2); //Remote thumbnail is cached so an extra ref
    assert (Files.IconInfo.loadable_icon_cache_info () == 1);

    file.update_icon (32, 1);

    /* A new cache entry is made for different size */
    assert (Files.IconInfo.loadable_icon_cache_info () == 2);

    /* IconInfo should remain in case for 6 * reap_time_msec */
    var loop = new MainLoop ();
    Timeout.add (reap_time_msec * 2, () => {
        /* Icons should NOT be reaped yet */
        assert (Files.IconInfo.loadable_icon_cache_info () == 1);
        loop.quit ();
        return GLib.Source.REMOVE;
    });
    loop.run ();

     file.pix = null;

    loop = new MainLoop ();
    Timeout.add (reap_time_msec * 12, () => {
        /* Icon should be reaped by now */
        assert (Files.IconInfo.loadable_icon_cache_info () == 0);
        loop.quit ();
        return GLib.Source.REMOVE;
    });
    loop.run ();
}

int main (string[] args) {
    Test.init (ref args);

    add_icon_info_tests ();

    return Test.run ();
}
