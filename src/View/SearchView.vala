
namespace Marlin.View
{
    public class SearchView : Gtk.Popover
    {
        class Match : Object
        {
            public string name { get; construct; }
            public string mime { get; construct; }
            public string path_string { get; construct; }
            public Icon icon { get; construct; }
            public File parent { get; construct; }

            public Match (FileInfo info, string path_string, File parent)
            {
                Object (name: info.get_name (),
                        mime: info.get_content_type (),
                        icon: info.get_icon (),
                        path_string: path_string,
                        parent: parent);
            }
        }

        const int MAX_RESULTS = 10;
        const int MAX_DEPTH = 5;

        public signal void file_selected (File file);

        public bool working { get; private set; default = false; }

        File current_root;
        Gee.Queue<File> directory_queue;
        Gee.LinkedList<Match> results;
        ulong waiting_handler;

        Cancellable? current_operation = null;
        Cancellable? file_search_operation = null;

        Gtk.ListStore folder_list;
        Gtk.TreeView folder_container;
        Gtk.ListStore global_list;
        Gtk.TreeView global_container;

        Gtk.TreeView? selected_container = null;

        Zeitgeist.Index zg_index;
        GenericArray<Zeitgeist.Event> templates;

        int display_count;

        bool local_search_finished = false;
        bool global_search_finished = false;

        public SearchView (Gtk.Widget relative_to)
        {
            Object (relative_to: relative_to);
            modal = false;
            position = Gtk.PositionType.BOTTOM;
            width_request = 500;

            Gtk.Label folder_label, global_label;
            get_container (_("In this folder:"), out folder_label, out folder_list, out folder_container);
            get_container (_("Everywhere else:"), out global_label, out global_list, out global_container);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            box.pack_start (folder_label, false);
            box.pack_start (folder_container);
            box.pack_start (global_label, false);
            box.pack_start (global_container);
            add (box);

            var template_subject  = new Zeitgeist.Subject ();
            template_subject.manifestation = Zeitgeist.NFO.FILE_DATA_OBJECT;
            var template = new Zeitgeist.Event ();
            template.add_subject (template_subject);

            templates = new GenericArray<Zeitgeist.Event> ();
            templates.add (template);

            zg_index = new Zeitgeist.Index ();
        }

        public void clear ()
        {
            folder_list.clear ();
            global_list.clear ();
        }

        // TODO include_hidden should be set according to view settings in Files
        public void search (string term, File folder, bool include_hidden = false)
        {
            if (!current_operation.is_cancelled ())
                current_operation.cancel ();

            if (working) {
                if (waiting_handler != 0)
                    SignalHandler.disconnect (this, waiting_handler);

                waiting_handler = notify["working"].connect (() => {
                    SignalHandler.disconnect (this, waiting_handler);
                    waiting_handler = 0;
                    search (term, folder, include_hidden);
                });
                return;
            }

            if (term.strip () == "") {
                clear ();
                return;
            }

            display_count = 0;
            directory_queue = new Gee.LinkedList<File> ();
            results = new Gee.LinkedList<Match> ();
            current_root = folder;

            current_operation = new Cancellable ();
            file_search_operation = new Cancellable ();

            current_operation.cancelled.connect (file_search_operation.cancel);

            clear ();

            working = true;

            directory_queue.add (folder);

            new Thread<void*> (null, () => {
                while (!file_search_operation.is_cancelled () && directory_queue.size > 0) {
                    visit (term.down (), include_hidden, file_search_operation);
                }

                global_search_finished = true;
                Idle.add (send_search_finished);

                return null;
            });

            get_zg_results.begin (term);
        }

        bool send_search_finished ()
        {
            if (!local_search_finished || !global_search_finished)
                return false;

            working = false;

            if (folder_list.iter_n_children (null) > 0)
                selected_container = folder_container;
            else
                selected_container = global_container;

            selected_container.set_cursor (new Gtk.TreePath.from_string ("0"), null, false);

            return false;
        }

        void add_results (Gee.List<Match> new_results, Gtk.ListStore list)
        {
            foreach (var r in new_results) {
                Gdk.Pixbuf? pixbuf = null;
                var icon_info = Gtk.IconTheme.get_default ().lookup_by_gicon (r.icon, 16, 0);
                if (icon_info != null) {
                    try {
                        pixbuf = icon_info.load_icon ();
                    } catch (Error e) {}
                }

                var location = "\t<span color=\"#999\" style=\"italic\">%s</span>".printf (
                    Markup.escape_text (r.path_string));
                var file = r.parent.resolve_relative_path (r.name);

                Gtk.TreeIter iter;
                list.append (out iter);
                list.@set (iter, 0, pixbuf, 1, r.name, 2, location, 3, file);
            }
        }

        public void up ()
        {
            if (selected_container == null)
                return;

            Gtk.TreePath path;
            selected_container.get_cursor (out path, null);

            if (path == null || !path.prev ()) {
                if (selected_container == global_container && folder_list.iter_n_children (null) > 0) {
                    selected_container = folder_container;

                    path = new Gtk.TreePath.from_string ((folder_list.iter_n_children (null) - 1).to_string ());
                    folder_container.set_cursor (path, null, false);
                    global_container.get_selection ().unselect_all ();
                }

                return;
            }

            selected_container.set_cursor (path, null, false);
        }

        public void down ()
        {
            if (selected_container == null)
                return;

            Gtk.TreePath path;
            selected_container.get_cursor (out path, null);

            if (path == null)
                return;

            var current_index = path.get_indices ()[path.get_depth () - 1];
            if (current_index >= selected_container.model.iter_n_children (null) - 1) {
                if (selected_container == folder_container && global_list.iter_n_children (null) > 0) {
                    selected_container = global_container;

                    path = new Gtk.TreePath.from_string ("0");
                    global_container.set_cursor (path, null, false);
                    folder_container.get_selection ().unselect_all ();
                }

                return;
            }

            path.next ();

            selected_container.set_cursor (path, null, false);
        }

        public void select_current ()
        {
            if (selected_container == null)
                return;

            Gtk.TreePath path;
            Gtk.TreeIter iter;
            File file;

            selected_container.get_cursor (out path, null);
            if (path == null)
                return;

            selected_container.model.get_iter (out iter, path);

            selected_container.model.@get (iter, 3, out file);
            file_selected (file);
        }

        string ATTRIBUTES = FileAttribute.STANDARD_NAME + "," +
                            FileAttribute.STANDARD_CONTENT_TYPE + "," +
                            FileAttribute.STANDARD_IS_HIDDEN + "," +
                            FileAttribute.STANDARD_TYPE + "," +
                            FileAttribute.STANDARD_ICON;

        void visit (string term, bool include_hidden, Cancellable cancel)
        {
            FileEnumerator enumerator;

            var folder = directory_queue.poll ();
            if (folder == null)
                return;

            var depth = 0;

            File f = folder;
            var path_string = "";
            while (!f.equal (current_root)) {
                path_string = f.get_basename () + (path_string == "" ? "" : " > " + path_string);
                f = f.get_parent ();
                depth++;
            }

            if (depth > MAX_DEPTH)
                return;

            try {
                enumerator = folder.enumerate_children (ATTRIBUTES, 0, cancel);
            } catch (Error e) {
                return;
            }

            var new_results = new Gee.LinkedList<Match> ();

            FileInfo info = null;
            try {
                while (!cancel.is_cancelled () && (info = enumerator.next_file (null)) != null) {
                    if (info.get_is_hidden () && !include_hidden)
                        continue;

                    if (info.get_file_type () == FileType.DIRECTORY) {
                        directory_queue.add (folder.resolve_relative_path (info.get_name ()));
                    }

                    if (term_matches (term, info.get_name ()))
                        new_results.add (new Match (info, path_string, folder));
                }
            } catch (Error e) {}

            if (!cancel.is_cancelled ()) {
                var new_count = display_count + new_results.size;
                if (new_count > MAX_RESULTS) {
                    cancel.cancel ();

                    var num_ok = MAX_RESULTS - display_count;
                    if (num_ok < new_results.size) {
                        var count = 0;
                        var it = new_results.iterator ();
                        while (it.next ()) {
                            count++;
                            if (count > num_ok)
                                it.remove ();
                        }
                    } else if (num_ok == 0)
                        return;

                    display_count = MAX_RESULTS;
                } else
                    display_count = new_count;

                // use a closure here to get vala to pass the userdata that we actually want
                Idle.add (() => {
                    add_results (new_results, folder_list);
                    return false;
                });
            }
        }

        async void get_zg_results (string term)
        {
            Zeitgeist.ResultSet results;
            try {
                results = yield zg_index.search (term,
                                                 new Zeitgeist.TimeRange.anytime (),
                                                 templates,
                                                 0, // offset
                                                 MAX_RESULTS,
                                                 Zeitgeist.ResultType.MOST_POPULAR_SUBJECTS,
                                                 current_operation);
            } catch (IOError.CANCELLED e) {
                return;
            } catch (Error e) {
                warning ("Fetching results for term '%s' from zeitgeist failed: %s", term, e.message);
                return;
            }

            var matches = new Gee.LinkedList<Match> ();
            var home = File.new_for_path (Environment.get_home_dir ());
            while (results.has_next () && !current_operation.is_cancelled ()) {
                var result = results.next_value ();
                foreach (var subject in result.subjects.data) {
                    try {
                        var file = File.new_for_uri (subject.uri);
                        var path_string = "";
                        var parent = file;
                        while ((parent = parent.get_parent ()) != null) {
                            if (parent.equal (current_root))
                                break;

                            if (parent.equal (home)) {
                                path_string = "~ > " + path_string;
                                break;
                            }

                            if (path_string == "")
                                path_string = parent.get_basename ();
                            else
                                path_string = parent.get_basename () + " > " + path_string;
                        }

                        var info = yield file.query_info_async (ATTRIBUTES, 0, Priority.DEFAULT, current_operation);
                        // TODO improve path_string
                        matches.add (new Match (info, path_string, file.get_parent ()));
                    } catch (Error e) {}
                }
            }

            if (!current_operation.is_cancelled ())
                add_results (matches, global_list);

            local_search_finished = true;
            Idle.add (send_search_finished);
        }

        bool term_matches (string term, string name)
        {
            // TODO improve.

            // term is assumed to be down
            var res = name.down ().contains (term);
            return res;
        }

        void get_container (string text, out Gtk.Label label, out Gtk.ListStore list, out Gtk.TreeView container)
        {
            label = new Gtk.Label (text);
            label.xalign = 0;
            label.margin = 6;

            list = new Gtk.ListStore (4, typeof (Gdk.Pixbuf), typeof (string), typeof (string), typeof (File));

            container = new Gtk.TreeView.with_model (list);
            container.headers_visible = false;
            container.insert_column_with_attributes (-1, null, new Gtk.CellRendererPixbuf (), "pixbuf", 0);
            container.insert_column_with_attributes (-1, null, new Gtk.CellRendererText (), "text", 1);
            container.insert_column_with_attributes (-1, null, new Gtk.CellRendererText (), "markup", 2);

            container.button_press_event.connect (() => { return true; });
            container.button_release_event.connect_after (() => {
                select_current ();

                return false;
            });
        }
    }
}

