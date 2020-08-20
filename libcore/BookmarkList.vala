/***
    Copyright (c)  1999, 2000 Eazel, Inc.
                   2015-2018 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation, Inc.,.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : John Sullivan <sullivan@eazel.com>
              ammonkey <am.monkeyd@gmail.com>
              Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace Marlin {

    public class BookmarkList : GLib.Object {

        enum JobType {
            LOAD = 1,
            SAVE = 2
        }

        public unowned GLib.List<Marlin.Bookmark> list { get; private set; }

        private GLib.FileMonitor monitor;
        private GLib.Queue<JobType> pending_ops;
        private static GLib.File bookmarks_file;
        private GOF.CallWhenReady call_when_ready;

        private static BookmarkList instance = null;

        public signal void contents_changed ();
        public signal void loaded ();
        public signal void deleted ();

        private BookmarkList () {
            list = new GLib.List<Marlin.Bookmark> ();
            pending_ops = new GLib.Queue<JobType> ();

            /* Get the user config directory
             * When running under pkexec determine real user from PKEXEC_UID
             */
            string? user_home = PF.UserUtils.get_real_user_home ();
            string config_dir;

            if (user_home != null) {
                config_dir = GLib.Path.build_filename (user_home, ".config");
            } else {
                config_dir = GLib.Environment.get_user_config_dir ();
            }

            /*Check bookmarks file exists and in right place */
            string filename = GLib.Path.build_filename (config_dir,
                                                        "gtk-3.0",
                                                        "bookmarks",
                                                        null);

            var file = GLib.File.new_for_path (filename);
            if (!file.query_exists (null)) {
                /* Bookmarks file does not exist in right place  ... create a new one */
                try {
                    file.get_parent ().make_directory_with_parents (null);
                }
                catch (GLib.Error error) {
                    /* Probably already exists */
                    warning ("Could not create bookmarks directory: %s", error.message);
                }

                try {
                    file.create (GLib.FileCreateFlags.NONE, null);
                }
                catch (GLib.Error error) {
                    critical ("Could not create bookmarks file: %s", error.message);
                }

                /* load existing bookmarks from the old location if it exists */
                var old_filename = GLib.Path.build_filename (GLib.Environment.get_home_dir (),
                                                            ".gtk-bookmarks",
                                                            null);

                var old_file = GLib.File.new_for_path (old_filename);
                if (old_file.query_exists (null)) {
                    /* If there is a legacy bookmark file we copy it to the new location */
                    Marlin.BookmarkList.bookmarks_file = old_file;
                    load_bookmarks_file ();
                    Marlin.BookmarkList.bookmarks_file = file;
                } else {
                    /* Else populate the new file with default bookmarks */
                    Marlin.BookmarkList.bookmarks_file = file;
                    add_special_directories ();
                }
                save_bookmarks_file ();
            } else {
                Marlin.BookmarkList.bookmarks_file = file;
                load_bookmarks_file ();
            }
        }

        private void add_special_directories () {
            const GLib.UserDirectory[] DIRECTORIES = {
                GLib.UserDirectory.DOCUMENTS,
                GLib.UserDirectory.DOWNLOAD,
                GLib.UserDirectory.MUSIC,
                GLib.UserDirectory.PUBLIC_SHARE,
                GLib.UserDirectory.PICTURES,
                GLib.UserDirectory.TEMPLATES,
                GLib.UserDirectory.VIDEOS
            };

            foreach (GLib.UserDirectory directory in DIRECTORIES) {
                unowned string? dir_s = GLib.Environment.get_user_special_dir (directory);
                if (dir_s != null) {
                    var gof_file = GOF.File.get (GLib.File.new_for_path (dir_s));
                    var bookmark = new Bookmark (gof_file);
                    append_internal (bookmark);
                }
            }

            save_bookmarks_file ();
        }

        public static BookmarkList get_instance () {
            if (instance == null) {
                instance = new BookmarkList ();
            }

            return instance;
        }

        public void insert_uri (string uri, uint index, string? label = null) {
            insert_item_internal (new Bookmark.from_uri (uri, label), index);
            save_bookmarks_file ();
        }

        public void insert_uri_at_end (string uri, string? label = null) {
            append_internal (new Bookmark.from_uri (uri, label));
            save_bookmarks_file ();
        }

        public void insert_uris (GLib.List<string> uris, uint index) {
            if (index > list.length ()) { // Can be assumed to be limited in length
                critical ("Bookmarklist: Attempt to insert uri at out of range index");
                return;
            }
            uris.@foreach ((uri) => {
                insert_item_internal (new Bookmark.from_uri (uri, null), index);
                index++;
            });
            save_bookmarks_file ();
        }

        public bool contains (Marlin.Bookmark bm) {
            return (list.find_custom (bm, Marlin.Bookmark.compare_with) != null);
        }

        public void delete_item_at (uint index) {
            assert (index < list.length ()); // Can be assumed to be limited in length
            unowned GLib.List<Marlin.Bookmark> node = list.nth (index);
            list.remove_link (node);
            stop_monitoring_bookmark (node.data);
            save_bookmarks_file ();
        }

        public void delete_items_with_uri (string uri) {
            bool list_changed = false;
            unowned GLib.List<Marlin.Bookmark> node = list;
            unowned GLib.List<Marlin.Bookmark> next = node.next;

            for (node = list; node != null; node = next) {
                next = node.next;
                if (uri == node.data.uri) {
                    list.remove_link (node);
                    stop_monitoring_bookmark (node.data);
                    list_changed = true;
                }
            }

            if (list_changed) {
                save_bookmarks_file ();
            }
        }

        public uint length () {
            return list.length (); // Can be assumed to be limited in length
        }

        public unowned Marlin.Bookmark? item_at (uint index) {
            assert (index < list.length ()); // Can be assumed to be limited in length
            return list.nth_data (index);
        }

        public void move_item (uint index, uint destination) {
            if (index > list.length ()) { // Can be assumed to be limited in length
                critical ("Bookmarklist: Attempt to move bookmark from out of range index");
                return;
            }

            if (destination > list.length ()) { // Can be assumed to be limited in length
                critical ("Bookmarklist: Attempt to move bookmark to out of range index");
                return;
            }

            if (index == destination) {
                return;
            }

            unowned GLib.List<Marlin.Bookmark> link = list.nth (index);
            list.remove_link (link);
            list.insert (link.data, (int)destination);
            save_bookmarks_file ();
        }

        private void append_internal (Marlin.Bookmark bookmark) {
            insert_item_internal (bookmark, -1);
        }

        private void insert_item_internal (Marlin.Bookmark bm, uint index) {
            if (this.contains (bm)) {
                return;
            }
            /* Do not insert bookmark for home or filesystem root (already have builtins) */
            var path = bm.gof_file.location.get_path ();

            if ((path == PF.UserUtils.get_real_user_home () || path == Path.DIR_SEPARATOR_S)) {
                return;
            }

            list.insert (bm, (int)index);
            start_monitoring_bookmark (bm);
        }

        private void load_bookmarks_file () {
            schedule_job (JobType.LOAD);
        }

        private void save_bookmarks_file () {
            schedule_job (JobType.SAVE);
        }

        private void schedule_job (JobType job) {
            pending_ops.push_head (job);
            if (pending_ops.length == 1) {
                process_next_op ();
            }
        }

        private void load_bookmarks_file_async () {
            GLib.File file = get_bookmarks_file ();
            file.load_contents_async.begin (null, (obj, res) => {
                try {
                    uint8[] contents;
                    file.load_contents_async.end (res, out contents, null);
                    if (contents != null) {
                        bookmark_list_from_string ((string)contents);
                        this.call_when_ready = new GOF.CallWhenReady (get_gof_file_list (), files_ready);
                        loaded (); /* Call now to ensure sidebar is updated even if call_when_ready blocks */
                    }
                }
                catch (GLib.Error error) {
                    critical ("Error loadinging bookmark file %s", error.message);
                }
                op_processed_call_back ();
            });
        }

        private GLib.List<GOF.File> get_gof_file_list () {
            GLib.List<GOF.File> files = null;
            list.@foreach ((bm) => {
                files.prepend (bm.gof_file);
            });
            return (owned) files;
        }

        private void files_ready (GLib.List<GOF.File> files) {
            /* Sidebar does not use file.info when updating display so do not signal contents changed */
            call_when_ready = null;
        }

        private void bookmark_list_from_string (string contents) {
            list.@foreach (stop_monitoring_bookmark);

            uint count = 0;
            string [] lines = contents.split ("\n");
            foreach (string line in lines) {
                if (line[0] == '\0' || line[0] == ' ') {
                    continue; /* ignore blank lines */
                }

                string [] parts = line.split (" ", 2);
                if (parts.length == 2) {
                    append_internal (new Marlin.Bookmark.from_uri (parts [0], parts [1]));
                } else {
                    append_internal (new Marlin.Bookmark.from_uri (parts [0]));
                }

                count++;
            }

            list.@foreach (start_monitoring_bookmark);

            if (list.length () > count) { // Can be assumed to be limited in length
                /* renew bookmark that was deleted when bookmarks file was changed externally */
                save_bookmarks_file ();
            }
        }

        private void save_bookmarks_file_async () {
            GLib.File file = get_bookmarks_file ();
            StringBuilder sb = new StringBuilder ();

            list.@foreach ((bookmark) => {
                sb.append (bookmark.uri);
                sb.append (" " + bookmark.label);
                sb.append ("\n");
            });

            file.replace_contents_async.begin (sb.data,
                                               null,
                                               false,
                                               GLib.FileCreateFlags.NONE,
                                               null,
                                               (obj, res) => {
                try {
                    file.replace_contents_async.end (res, null);
                    contents_changed ();
                }
                catch (GLib.Error error) {
                    warning ("Error replacing bookmarks file contents %s", error.message);
                }
                op_processed_call_back ();
            });
        }

        private static GLib.File get_bookmarks_file () {
            return Marlin.BookmarkList.bookmarks_file;
        }


        private void bookmarks_file_changed_call_back (GLib.File file,
                                                       GLib.File? other_file,
                                                       GLib.FileMonitorEvent event_type) {

            if (event_type == GLib.FileMonitorEvent.CHANGED ||
                event_type == GLib.FileMonitorEvent.CREATED) {

                load_bookmarks_file ();
            }
        }

        private void bookmark_in_list_changed_callback (Marlin.Bookmark bookmark) {
            save_bookmarks_file ();
        }

        private void bookmark_in_list_to_be_deleted_callback (Marlin.Bookmark bookmark) {
            delete_items_with_uri (bookmark.uri);
        }

        private void start_monitoring_bookmarks_file () {
            GLib.File file = get_bookmarks_file ();
            try {
                monitor = file.monitor (GLib.FileMonitorFlags.SEND_MOVED, null);
                monitor.set_rate_limit (1000);
                monitor.changed.connect (bookmarks_file_changed_call_back);
            }
            catch (GLib.Error error) {
                warning ("Error starting to monitor bookmarks file: %s", error.message);
            }
        }

        private void stop_monitoring_bookmarks_file () {
            if (monitor == null) {
                return;
            }

            monitor.cancel ();
            monitor.changed.disconnect (bookmarks_file_changed_call_back);
            monitor = null;
        }

        private void start_monitoring_bookmark (Marlin.Bookmark bookmark) {
            bookmark.contents_changed.connect (bookmark_in_list_changed_callback);
            bookmark.deleted.connect (bookmark_in_list_to_be_deleted_callback);

        }
        private void stop_monitoring_bookmark (Marlin.Bookmark bookmark) {
            bookmark.contents_changed.disconnect (bookmark_in_list_changed_callback);
            bookmark.deleted.disconnect (bookmark_in_list_to_be_deleted_callback);
        }

        private void process_next_op () {
            stop_monitoring_bookmarks_file ();
            var pending = pending_ops.pop_tail ();
            /* if job is SAVE then subsequent pending saves and loads are redundant
             * if job is LOAD then any pending changes requiring saving will be lost
             * so we can clear pending jobs */
            pending_ops.clear ();
            /* block queue until job processed */
            pending_ops.push_head (pending);

            switch (pending) {
                case JobType.LOAD:
                    load_bookmarks_file_async ();
                    break;
                case JobType.SAVE:
                    save_bookmarks_file_async ();
                    break;
                default:
                    warning ("Invalid booklist operation");
                    op_processed_call_back ();
                    break;
            }
        }

        private void op_processed_call_back () {
            pending_ops.pop_tail (); /* remove job just completed */
            if (!pending_ops.is_empty ()) {
                process_next_op ();
            } else {
                start_monitoring_bookmarks_file ();
            }
        }
    }
}
