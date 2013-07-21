/*
 * Copyright (C) 2011 Marlin Developers
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author: ammonkey <am.monkeyd@gmail.com>
 */

public class Marlin.DeepCount : Object {
    private File file;
    private string deep_count_attrs;
    private Cancellable cancellable;
    private List<File>? directories = null;

    public uint64 total_size = 0;
    public uint files_count = 0;
    public uint dirs_count = 0;
    public uint directories_count = 0;

    public signal void finished ();

    public DeepCount (File _file) {
        file = _file;
        deep_count_attrs = FileAttribute.STANDARD_NAME + "," + FileAttribute.STANDARD_TYPE + "," + FileAttribute.STANDARD_SIZE;
        cancellable = new Cancellable ();

        process_directory.begin (file);
    }

    private Mutex mutex;

    private async void process_directory (File directory) {
        directories.prepend (directory);
        try {
            /*bool exists = yield Utils.query_exists_async (directory);
              if (!exists) return;*/
            var e = yield directory.enumerate_children_async (deep_count_attrs, FileQueryInfoFlags.NOFOLLOW_SYMLINKS, Priority.LOW, cancellable);

            while (true) {
                var files = yield e.next_files_async (1024, Priority.LOW, cancellable);
                if (files == null)
                    break;

                foreach (var f in files) {
                    unowned string name = f.get_name ();
                    File location = directory.get_child (name);
                    if (f.get_file_type () == FileType.DIRECTORY) {
                        //message ("found: %s", name);
                        yield process_directory (location);
                        dirs_count++;
                    } else {
                        //message ("file: %s %s", name, location.get_uri ());
                        files_count++;
                    }
                    mutex.lock ();
                    total_size += f.get_size();
                    mutex.unlock ();
                }
            }
        } catch (Error err) {
            if (!(err is IOError.CANCELLED))
                warning ("%s", err.message);
        }

        directories.remove (directory);
        /*message ("----------------");
          foreach (var dir in directories)
          message ("dir %s", dir.get_uri ());*/
        if (directories == null) {
            //message ("DEEP COUNT dir %s size %s", file.get_uri (), format_size_for_display ((int64) total_size));
            finished ();
        }
    }

    public void cancel ()  {
        cancellable.cancel ();
    }
}
