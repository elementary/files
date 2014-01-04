/***
  Copyright (C)  1999, 2000 Eazel, Inc.
                 2013 Jeremy Wootten <jeremywootten@gmail.com>

  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE. See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program. If not, see <http://www.gnu.org/licenses/>.

 Authors :    John Sullivan <sullivan@eazel.com>
              ammonkey <am.monkeyd@gmail.com>
              Jeremy Wootten <jeremywootten@gmail.com>
***/

namespace Marlin {

    public class BookmarkList : GLib.Object{

        enum JobType {
            LOAD = 1,
            SAVE = 2
        }

        private GLib.List<Marlin.Bookmark> list;
        private GLib.FileMonitor monitor;
        private GLib.Queue<JobType> pending_ops;

        private static BookmarkList instance = null;

        public signal void contents_changed ();
        public signal void deleted ();

        private BookmarkList () {
            list = new GLib.List<Marlin.Bookmark> ();
            pending_ops = new GLib.Queue<JobType> ();
            load_bookmarks_file ();
        }

        public static BookmarkList get_instance () {
            if (instance == null)
                instance = new BookmarkList ();

            return instance;
        }

        public void insert_uri (string uri, uint index) {
            insert_item_internal (new Bookmark.from_uri (uri, null), index);
            save_bookmarks_file ();
        }

        public void insert_uris (GLib.List<string> uris, uint index) {
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
            assert (index < list.length ());
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
                if (uri == node.data.get_uri ()) {
                    list.remove_link (node);
                    stop_monitoring_bookmark (node.data);
                    list_changed = true;
                }
            }

            if (list_changed)
                save_bookmarks_file ();
        }

        public uint length () {
            return list.length ();
        }

        public unowned Marlin.Bookmark? item_at (uint index) {
            assert (index < list.length ());
            return list.nth_data (index);
        }

        public void move_item (uint index, uint destination) {
            assert (index < list.length ());
            if (destination > list.length ())
                destination = list.length ();

            if (index == destination)
                return;

            unowned GLib.List<Marlin.Bookmark> link = list.nth (index);
            list.remove_link (link);

            if (destination > index)
                destination--;

            list.insert (link.data, (int)destination);
            save_bookmarks_file ();
        }

        private void append_internal (Marlin.Bookmark bookmark) {
            insert_item_internal (bookmark,-1);
        }

        private void insert_item_internal (Marlin.Bookmark bm, uint index) {
            if (this.contains (bm))
                return;

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
            if (pending_ops.length == 1)
                process_next_op ();
        }

        private void load_bookmarks_file_async () {
            GLib.File file = get_bookmarks_file ();

            file.load_contents_async.begin (null, (obj, res) => {
                try {
                    uint8[] contents;
                    file.load_contents_async.end (res, out contents, null);
                    if (contents != null) {
                        bookmark_list_from_string ((string)contents);
//                        new GOF.CallWhenReady (get_gof_file_list (),
//                                               (files) => {contents_changed ();}
//                                              );
                    }
                }
                catch (GLib.Error error) {
                    critical ("Error loadinging bookmark file %s", error.message);
                }
                op_processed_call_back ();
            });
        }

        private void bookmark_list_from_string (string contents) {
            list.@foreach (stop_monitoring_bookmark);

            uint count = 0;
            string [] lines = contents.split ("\n");
            foreach (string line in lines) {
                if (line[0] == '\0' || line[0] == ' ')
                    continue; /* ignore blank lines */

                string [] parts = line.split (" ", 2);
                if (parts.length == 2)
                    append_internal (new Marlin.Bookmark.from_uri (parts [0], parts [1]));
                else
                    append_internal (new Marlin.Bookmark.from_uri (parts [0]));

                count++;
            }

            list.@foreach (start_monitoring_bookmark);

            if (list.length () > count)
                /* renew bookmark that was deleted when bookmarks file was changed externally */
                save_bookmarks_file ();
        }

//        private GLib.List<GOF.File> get_gof_file_list () {
//             GLib.List<GOF.File> gof_file_list = new GLib.List<GOF.File> ();
//            list.@foreach ((bm) => {
//                gof_file_list.prepend (bm.gof_file);
//            });
//            return gof_file_list.copy ();
//        }

        private void save_bookmarks_file_async () {

            GLib.File file = get_bookmarks_file ();
            StringBuilder sb = new StringBuilder ();

            list.@foreach ((bookmark) => {
                sb.append (bookmark.get_uri ());
                if (bookmark.has_custom_name)
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
                    message ("Error replacing bookmarks file contents %s", error.message);
                }
                op_processed_call_back ();
            });
        }

        private static GLib.File get_bookmarks_file () {
            string filename = GLib.Path.build_filename (GLib.Environment.get_home_dir (),
                                                        ".gtk-bookmarks",
                                                        null);
            return GLib.File.new_for_path (filename);
        }


        private void bookmarks_file_changed_call_back (GLib.File file,
                                                       GLib.File? other_file,
                                                       GLib.FileMonitorEvent event_type) {

            if (event_type == GLib.FileMonitorEvent.CHANGED
                || event_type == GLib.FileMonitorEvent.CREATED)
                load_bookmarks_file ();
        }

        private void bookmark_in_list_changed_callback (Marlin.Bookmark bookmark) {
            save_bookmarks_file ();
        }

        private void bookmark_in_list_to_be_deleted_callback (Marlin.Bookmark bookmark) {
            delete_items_with_uri (bookmark.get_uri ());
        }

        private  void start_monitoring_bookmarks_file () {
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
            if (monitor == null)
                return;

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
            /* if job is SAVE then subsequent pending saves and loads are redundant */
            /* if job is LOAD then any pending changes requiring saving will be lost */
            pending_ops.clear();
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
                    warning (@"Invalid booklist operation");
                    op_processed_call_back ();
                    break;
            }
        }

        private void op_processed_call_back () {
            pending_ops.pop_tail (); /* remove job just completed */
            if (!pending_ops.is_empty ())
                process_next_op ();
            else
                start_monitoring_bookmarks_file ();
        }
    }
}
