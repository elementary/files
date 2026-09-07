/*
 * SPDX-FileCopyrightText: 2015-2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: GPL-3.0-or-later
 *
 * Authors : Lucas Baudin <xapantu@gmail.com>
 *           Jeremy Wootten <jeremywootten@gmail.com>
 */

 public class Files.FileOperations.Manager : Object {
        public static Manager get_instance () {
            return instance.once (() => new Manager ());
        }

        private static Once<Manager> instance;
        private List<CommonJob> jobs;

        construct {
            jobs = new List<CommonJob> ();
        }

        public async void @delete (
            List<GLib.File> files,
            uint n_files,
            Gtk.Window parent_window,
            bool try_trash,
            Cancellable? cancellable = null
        ) throws GLib.Error {

            if (files == null || n_files == 0) {
                return;
            }

            var job = new DeleteJob (parent_window, files, try_trash);
            var common = (CommonJob) job;


            jobs.append (job);
            yield job.delete_files (cancellable);
            jobs.remove (job);
        }


 }
