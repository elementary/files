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

void add_icon_info_tests () {
    Test.add_func ("/MarlinIconInfo/goffile_icon_update", goffile_icon_update_test);
}

void goffile_icon_update_test () {
    string test_file_path = Path.build_filename (Config.TESTDATA_DIR, "images", "testimage.png");
    GOF.File file = GOF.File.get_by_uri (test_file_path);
    assert (file != null);
    file.query_update ();
    assert (file.pix == null);
    file.update_icon (128);
    assert (file.pix != null);
    assert (file.pix_size == 128);

    file.update_icon (32);
    assert (file.pix_size == 32);
}

int main (string[] args) {
    Test.init (ref args);

    add_icon_info_tests ();

    return Test.run ();
}
