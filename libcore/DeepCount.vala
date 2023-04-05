/***
    Copyright (C) 2011 Marlin Developers

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Author: ammonkey <am.monkeyd@gmail.com>
***/

public class Files.DeepCount : Object {

    private GLib.File file;
    private string deep_count_attrs;
    private Cancellable cancellable;
    private List<GLib.File>? directories = null;

    public int file_not_read = 0;
    public uint64 total_size = 0;
    public uint files_count = 0;
    public uint dirs_count = 0;
    public uint directories_count = 0;

    public signal void finished ();

    public DeepCount (GLib.File _file) {
        file = _file;
        deep_count_attrs = string.join (",",
                                        FileAttribute.STANDARD_NAME,
                                        FileAttribute.STANDARD_TYPE,
                                        FileAttribute.STANDARD_SIZE,
                                        FileAttribute.STANDARD_ALLOCATED_SIZE);
        cancellable = new Cancellable ();
        process_directory.begin (file);
    }

    private Mutex mutex;

    private async void process_directory (GLib.File directory) {
        directories.prepend (directory);
        try {
            /*bool exists = yield Utils.query_exists_async (directory);
              if (!exists) return;*/
            var e = yield directory.enumerate_children_async (deep_count_attrs,
                                                              FileQueryInfoFlags.NOFOLLOW_SYMLINKS,
                                                              Priority.LOW, cancellable);

            while (true) {
                var files = yield e.next_files_async (1024, Priority.LOW, cancellable);
                if (files == null) {
                    break;
                }

                foreach (var f in files) {
                    unowned string name = f.get_name ();
                    GLib.File location = directory.get_child (name);
                    if (f.get_file_type () == FileType.DIRECTORY) {
                        yield process_directory (location);
                        dirs_count++;
                    } else {
                        files_count++;
                    }
                    mutex.lock ();
                    uint64 file_size = f.get_size ();
                    uint64 allocated_size = f.get_attribute_uint64 (FileAttribute.STANDARD_ALLOCATED_SIZE);
                    /* Check for sparse file, allocated size will be smaller, for normal files allocated size
                     * includes overhead size so we don't use it for those here
                     */
                    /* Network files may not have allocated size attribute so ignore zero result */
                    if (allocated_size > 0 &&
                        allocated_size < file_size &&
                        f.get_file_type () != FileType.DIRECTORY) {

                        file_size = allocated_size;
                    }

                    total_size += file_size;
                    mutex.unlock ();
                }
            }
        } catch (Error err) {
            if (!(err is IOError.CANCELLED)) {
                mutex.lock ();
                file_not_read ++;
                mutex.unlock ();
                debug ("%s", err.message);
            }
        }

        directories.remove (directory);

        if (directories == null) {
            finished ();
        }
    }

    public void cancel () {
        cancellable.cancel ();
    }
}
