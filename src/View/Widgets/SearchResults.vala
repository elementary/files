/***
    Copyright (c) 2015-2018 elementary LLC <https://elementary.io>

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors :
***/

namespace Files.View.Chrome {
    public class SearchResults : Gtk.Window, Searchable {
        private const string ELLIPSIS_NAME = "ELLIPSIS";
        /* The order of these categories governs the order in which matches appear in the search view.
         * The category represents a first level sort.  Within a category the matches sort alphabetically on name */
        private enum Category {
            CURRENT_HEADER,
            CURRENT_BEGINS,
            CURRENT_CONTAINS,
            CURRENT_ELLIPSIS,
            DEEP_HEADER,
            DEEP_BEGINS,
            DEEP_CONTAINS,
            DEEP_ELLIPSIS,
            ZEITGEIST_HEADER,
            ZEITGEIST_BEGINS,
            ZEITGEIST_CONTAINS,
            ZEITGEIST_ELLIPSIS,
            BOOKMARK_HEADER,
            BOOKMARK_BEGINS,
            BOOKMARK_CONTAINS,
            BOOKMARK_ELLIPSIS;

            /* This function converts a Category enum to a letter which can be prefixed to the match
             * name to form a sort key.  This ensures that the categories appear in the list in the
             * desired order - that is within each class of results (current folder, deep search,
             * zeitgeist search and bookmark search), after the header, the matches appear with the
             * "begins with" ones first, then the "contains" and finally an "ellipsis" pseudo-match
             * appears if MAX_RESULTS is exceeded for that category.
             */
            public string to_string () {
                return CharacterSet.A_2_Z.get_char ((uint)this).to_string ();
            }
        }

        class Match : Object {
            public string name { get; construct; }
            public string mime { get; construct; }
            public string path_string { get; construct; }
            public Icon icon { get; construct; }
            public GLib.File? file { get; construct; }
            public string sortkey { get; construct; }
            public Category category { get; construct; }

            public Match (FileInfo info, string path_string, GLib.File parent, SearchResults.Category category) {
                var _name = info.get_display_name ();
                Object (name: Markup.escape_text (_name),
                        mime: info.get_attribute_string (GLib.FileAttribute.STANDARD_CONTENT_TYPE),
                        icon: info.get_attribute_object (GLib.FileAttribute.STANDARD_ICON) as GLib.Icon,
                        path_string: path_string,
                        file: parent.resolve_relative_path (info.get_name ()),
                        sortkey: category.to_string () + _name);

            }

            public Match.from_bookmark (Bookmark bookmark, SearchResults.Category category) {
                var _name = bookmark.custom_name != "" && bookmark.custom_name != bookmark.basename ?
                    _("%s (%s)").printf (bookmark.custom_name, bookmark.basename) :
                    bookmark.basename;
                Object (
                        name: Markup.escape_text (_name),
                        mime: "inode/directory",
                        icon: bookmark.get_icon (),
                        path_string: "",
                        file: bookmark.get_location (),
                        sortkey: category.to_string () + _name
                );
            }

            public Match.ellipsis (SearchResults.Category category) {
                Object (name: "<b>" + _("More Results …") + "</b>",
                        mime: "",
                        icon: null,
                        path_string: "",
                        file: null,
                        sortkey: category.to_string () + ELLIPSIS_NAME);
            }
        }

        const int MAX_RESULTS = 10;
        const int MAX_DEPTH = 5;
        const int DELAY_ADDING_RESULTS = 150;

        public bool working { get; private set; default = false; }

        private new Gtk.Widget parent;
        protected int n_results { get; private set; default = 0; }

        GLib.File current_root;
        string search_term = "";
        Gee.Queue<GLib.File> directory_queue;
        ulong waiting_handler;

        uint adding_timeout;
        bool allow_adding_results = false;
        Gee.Map<Gtk.TreeIter?,Gee.List> waiting_results;

        Cancellable? current_operation = null;
        Cancellable? file_search_operation = null;

#if HAVE_ZEITGEIST
        Zeitgeist.Index zg_index;
        GenericArray<Zeitgeist.Event> templates;
#endif
        int current_count;
        int deep_count;
        int max_results = MAX_RESULTS;
        int max_depth = MAX_DEPTH;

        bool local_search_finished = false;
        bool global_search_finished = false;

        bool is_grabbing = false;
        Gdk.Device? device = null;

        Gtk.TreeIter? local_results = null;
        Gtk.TreeIter? deep_results = null;
        Gtk.TreeIter? zeitgeist_results = null;
        Gtk.TreeIter? bookmark_results = null;
        string header_markup = "%s";
        string result_location_markup = "%s";

        Gtk.TreeView view;
        Gtk.TreeStore list;
        Gtk.TreeModelFilter filter;
        Gtk.ScrolledWindow scroll;

        public SearchResults (Gtk.Widget parent_widget) {
            Object (resizable: false,
                    type_hint: Gdk.WindowTypeHint.COMBO,
                    type: Gtk.WindowType.POPUP);

            parent = parent_widget;
        }

        construct {
#if HAVE_ZEITGEIST
            var template = new Zeitgeist.Event ();

            var template_subject = new Zeitgeist.Subject () {
                manifestation = Zeitgeist.NFO.FILE_DATA_OBJECT
            };

            template.add_subject (template_subject);

            templates = new GenericArray<Zeitgeist.Event> ();
            templates.add (template);

            zg_index = new Zeitgeist.Index ();
#endif
            view = new Gtk.TreeView () {
                headers_visible = false,
                level_indentation = 12,
                show_expanders = false
            };

            view.get_selection ().set_mode (Gtk.SelectionMode.BROWSE);

            /* Do not select category headers */
            view.get_selection ().set_select_function ((selection, list, path, path_selected) => {
                return path.get_depth () != 0;
            });

            scroll = new Gtk.ScrolledWindow (null, null) {
                child = view,
                hscrollbar_policy = Gtk.PolicyType.NEVER
            };

            get_style_context ().add_class ("completion-popup");

            var column = new Gtk.TreeViewColumn () {
                sizing = Gtk.TreeViewColumnSizing.FIXED
            };

            var cell = new Gtk.CellRendererPixbuf ();
            column.pack_start (cell, false);
            column.set_attributes (cell, "gicon", 1, "visible", 4);

            var cell_name = new Gtk.CellRendererText () {
                ellipsize = Pango.EllipsizeMode.MIDDLE
            };

            column.pack_start (cell_name, true);
            column.set_attributes (cell_name, "markup", 0);

            var cell_path = new Gtk.CellRendererText () {
                xpad = 6,
                ellipsize = Pango.EllipsizeMode.MIDDLE
            };

            column.pack_start (cell_path, false);
            column.set_attributes (cell_path, "markup", 2);

            view.append_column (column);

            list = new Gtk.TreeStore (6,
                                      typeof (string),       /*0 file basename or category name */
                                      typeof (GLib.Icon),    /*1 file icon */
                                      typeof (string?),      /*2 file location */
                                      typeof (GLib.File?),        /*3 file object */
                                      typeof (bool),         /*4 icon is visible */
                                      typeof (string));      /*5 Sort key */

            filter = new Gtk.TreeModelFilter (list, null);

            filter.set_visible_func ((model, iter) => {
                /* hide empty category headers */
                return list.iter_depth (iter) != 0 || list.iter_has_child (iter);
            });

            view.model = filter;

            list.row_changed.connect ((path, iter) => {
                /* If the first match is in the current directory it will be selected */
                if (path.to_string () == "0:0") {
                    GLib.File? file;
                    list.@get (iter, 3, out file);
                    first_match_found (file);
                }
            });

            list.set_sort_column_id (5, Gtk.SortType.ASCENDING);

            list.append (out local_results, null);
            list.append (out deep_results, null);
            list.append (out bookmark_results, null);
#if HAVE_ZEITGEIST
            list.append (out zeitgeist_results, null);
#endif

            child = scroll;

            button_press_event.connect (on_button_press_event);
            view.button_press_event.connect (on_view_button_press_event);
            key_press_event.connect (on_key_press_event);
        }

        private void update_category_headers () {
            /* Sets pango markup for headers and results to match the current placeholder color */
            Gdk.RGBA rgba;
            string color = "";
            string header_markup_start = "<span weight = 'bold' %s>";
            string result_location_markup_start = "<span %s>";
            var colored = get_style_context ().lookup_color ("placeholder_text_color", out rgba);

            if (colored) {
                color = "color='#%2x%2x%2x%2x'".printf ((uint)(rgba.red * 255),
                                                        (uint)(rgba.green * 255),
                                                        (uint)(rgba.blue * 255),
                                                        (uint)(rgba.alpha * 255));
            }

            header_markup = header_markup_start.printf (color) + "%s</span>";
            result_location_markup = result_location_markup_start.printf (color) + "%s</span>";

            /* Update the headers */
            list.@set (local_results,
                        0, header_markup.printf (_("In This Folder")),
                        5, Category.CURRENT_HEADER.to_string ());

            list.@set (deep_results,
                        0, header_markup.printf (_("Below This Folder")),
                        5, Category.CURRENT_HEADER.to_string ());

            list.@set (bookmark_results,
                        0, header_markup.printf (_("Bookmarks")),
                        5, Category.CURRENT_HEADER.to_string ());

#if HAVE_ZEITGEIST
            list.@set (zeitgeist_results,
                        0, header_markup.printf (_("Recently Used")),
                        5, Category.CURRENT_HEADER.to_string ());
#endif
        }

        /** Search interface functions **/
        public void cancel () {
            /* popdown first to avoid unwanted cursor change signals */
            popdown ();
            if (current_operation != null) {
                current_operation.cancel ();
            }

            clear ();
        }

        public void search (string term, GLib.File folder) {
            update_category_headers (); // Ensure category header color matches theme.

            device = Gtk.get_current_event_device ();
            if (term.normalize ().casefold () != search_term) {
                search_term = term.normalize ().casefold ();
                max_results = MAX_RESULTS;
                max_depth = MAX_DEPTH;
            }

            if (device != null && device.input_source == Gdk.InputSource.KEYBOARD) {
                device = device.associated_device;
            }

            if (!current_operation.is_cancelled ()) {
                current_operation.cancel ();
            }

            if (adding_timeout != 0) {
                Source.remove (adding_timeout);
                adding_timeout = 0;
                allow_adding_results = true;

                /* we need to catch the case when we were only waiting for the timeout
                 * to be finished and the actual search was already done. Otherwise the next
                 * condition will never be reached.
                 */

                if (global_search_finished && local_search_finished) {
                    working = false;
                }
            }

            if (working) {
                if (waiting_handler != 0) {
                    SignalHandler.disconnect (this, waiting_handler);
                }
                waiting_handler = notify["working"].connect (() => {
                    SignalHandler.disconnect (this, waiting_handler);
                    waiting_handler = 0;
                    search (search_term, folder);
                });

                return;
            }

            var include_hidden = Files.Preferences.get_default ().show_hidden_files;
            current_count = 0;
            deep_count = 0;
            directory_queue = new Gee.LinkedList<GLib.File> ();
            waiting_results = new Gee.HashMap<Gtk.TreeIter?,Gee.List> ();
            current_root = folder;

            current_operation = new Cancellable ();
            file_search_operation = new Cancellable ();

            current_operation.cancelled.connect (file_search_operation.cancel);

            clear ();

            working = true;
            n_results = 0;

            directory_queue.add (folder);

            allow_adding_results = false;
            adding_timeout = Timeout.add (DELAY_ADDING_RESULTS, () => {
                adding_timeout = 0;
                allow_adding_results = true;

                var it = waiting_results.map_iterator ();

                while (it.next ()) {
                    add_results (it.get_value (), it.get_key ());
                }

                send_search_finished ();
                return GLib.Source.REMOVE;
            });

            new Thread<void*> (null, () => {
                local_search_finished = false;
                while (!file_search_operation.is_cancelled () && directory_queue.size > 0) {
                    visit (search_term, include_hidden, file_search_operation, folder);
                }

                local_search_finished = true;
                Idle.add (send_search_finished);

                return null;
            });

#if HAVE_ZEITGEIST
            get_zg_results.begin (search_term);
#else
            global_search_finished = true;
#endif
            var bookmarks_matched = new Gee.LinkedList<Match> ();
            var begins_with = false;
            foreach (var bookmark in BookmarkList.get_instance ().list) {
                if (term_matches (search_term, bookmark.basename + bookmark.custom_name, out begins_with)) {
                    var category = begins_with ? Category.BOOKMARK_BEGINS : Category.BOOKMARK_CONTAINS;
                    bookmarks_matched.add (new Match.from_bookmark (bookmark, category));
                }
            }

            add_results (bookmarks_matched, bookmark_results);
        }

        /** Signal handlers **/
        void on_cursor_changed () {
            Gtk.TreeIter iter;
            Gtk.TreePath? path = null;
            var selected_paths = view.get_selection ().get_selected_rows (null);

            if (selected_paths != null) {
                path = selected_paths.data;
            }

            if (path != null) {
                filter.get_iter (out iter, path);
                filter.convert_iter_to_child_iter (out iter, iter);
                cursor_changed (get_file_at_iter (iter));
            }
        }

        bool on_button_press_event (Gdk.EventButton e) {
            if (e.x >= 0 && e.y >= 0 && e.x < get_allocated_width () && e.y < get_allocated_height ()) {
                view.event (e);
                return true;
            } else {
                cancel ();
                exit ();
                return false;
            }
        }

        bool on_view_button_press_event (Gdk.EventButton e) {
            Gtk.TreePath path;
            Gtk.TreeIter iter;

            view.get_path_at_pos ((int) e.x, (int) e.y, out path, null, null, null);
            if (path != null && path.get_depth () > 1) {
                filter.get_iter (out iter, path);
                filter.convert_iter_to_child_iter (out iter, iter);
                accept (iter, e.button > 1); /* This will call cancel () */
            } else {
                Gdk.beep ();
            }

            return true;
        }

        bool on_key_press_event (Gdk.EventKey event) {
            if (event.is_modifier == 1) {
                return true;
            }

            uint keyval;
            event.get_keyval (out keyval);
            Gdk.ModifierType state;
            event.get_state (out state);
            var mods = state & Gtk.accelerator_get_default_mod_mask ();
            bool only_control_pressed = (mods == Gdk.ModifierType.CONTROL_MASK);
            bool shift_pressed = ((mods & Gdk.ModifierType.SHIFT_MASK) != 0);
            bool alt_pressed = ((mods & Gdk.ModifierType.MOD1_MASK) != 0);
            bool only_shift_pressed = shift_pressed && ((mods & ~Gdk.ModifierType.SHIFT_MASK) == 0);
            bool only_alt_pressed = alt_pressed && ((mods & ~Gdk.ModifierType.MOD1_MASK) == 0);

            if (mods != 0 && !only_shift_pressed) {
                if (only_control_pressed) {
                    if (keyval == Gdk.Key.l) {
                        cancel (); /* release any grab */
                        exit (false); /* Do not exit navigate mode */
                        return true;
                    } else {
                        return parent.key_press_event (event);
                    }
                } else if (only_alt_pressed &&
                           keyval == Gdk.Key.Return ||
                           keyval == Gdk.Key.KP_Enter ||
                           keyval == Gdk.Key.ISO_Enter) {

                    accept (null, true); // Open the selected file in default app
                } else {
                    return parent.key_press_event (event);
                }
            }

            switch (keyval) {
                case Gdk.Key.Return:
                case Gdk.Key.KP_Enter:
                case Gdk.Key.ISO_Enter:
                    accept (null, false); // Navigate to the selected file
                    return true;
                case Gdk.Key.Up:
                case Gdk.Key.Down:
                case Gdk.Key.Tab:
                case Gdk.Key.ISO_Left_Tab:
                    if (list_empty ()) {
                        Gdk.beep ();
                        return true;
                    }

                    var up = (keyval == Gdk.Key.Up) ||
                             (keyval == Gdk.Key.ISO_Left_Tab);

                    if (view.get_selection ().count_selected_rows () < 1) {
                        if (up) {
                            select_last ();
                        } else {
                            select_first ();
                        }

                        return true;
                    }

                    select_adjacent (up);
                    return true;
                case Gdk.Key.Escape:
                    cancel (); /* release any grab */
                    exit ();
                    return true;
                default:
                    break;
            }
            return parent.key_press_event (event);
        }

        void select_first () {
            Gtk.TreeIter iter;
            list.get_iter_first (out iter);

            do {
                if (!list.iter_has_child (iter)) {
                    continue;
                }

                list.iter_nth_child (out iter, iter, 0);
                select_iter (iter);
                break;
            } while (list.iter_next (ref iter));

            /* make sure we actually scroll all the way back to the unselectable header */
            scroll.vadjustment.@value = 0;
        }

        void select_last () {
            Gtk.TreeIter iter;

            list.iter_nth_child (out iter, null, filter.iter_n_children (null) - 1);

            do {
                if (!list.iter_has_child (iter)) {
                    continue;
                }

                list.iter_nth_child (out iter, iter, list.iter_n_children (iter) - 1);

                select_iter (iter);
                break;
            } while (list.iter_previous (ref iter));
        }

        // Assume that each category only contains valid file entries and maybe an ellipsis
        void select_adjacent (bool up) {
            Gtk.TreeIter iter, parent;
            get_iter_at_cursor (out iter);
            // If another child in same category adjacent then select it
            if (up ? list.iter_previous (ref iter) : list.iter_next (ref iter)) {
                select_iter (iter);
                return;
            }
            // Go back to last currently selected iter
            get_iter_at_cursor (out iter);
            // Find next/previous category with matches, with wrap around
            list.iter_parent (out parent, iter);
            do {
                if (up ? !list.iter_previous (ref parent) : !list.iter_next (ref parent)) {
                    if (up) {
                        select_last ();
                    } else {
                        select_first ();
                    }

                    return;
                }
            } while (!list.iter_has_child (parent));

            // Get first/last child
            list.iter_nth_child (out iter, parent, up ? list.iter_n_children (parent) - 1 : 0);
            select_iter (iter);
            return;
        }

        bool list_empty () {
            Gtk.TreeIter iter;
            for (var valid = list.get_iter_first (out iter); valid; valid = list.iter_next (ref iter)) {
                if (list.iter_has_child (iter)) {
                    return false;
                }
            }

            return true;
        }

        int n_matches (out int n_headers = null) {
            var matches = 0;
            n_headers = 0;

            Gtk.TreeIter iter;
            for (var valid = list.get_iter_first (out iter); valid; valid = list.iter_next (ref iter)) {
                var n_children = list.iter_n_children (iter);
                if (n_children > 0) {
                    n_headers++;
                }

                matches += n_children;
            }

            return matches;
        }

        void resize_popup () {
            var parent_window = parent.get_window ();
            if (parent_window == null) {
                return;
            }

            int items, headers = 0;
            items = n_matches (out headers);

            if (visible && items + headers <= 1 && !working) {
                hide ();
            } else if (!visible && items + headers > 1 && !working) {
                popup (); /* On first call view gets realized after a delay */
            }

            if (!visible) {
                return; /* No need to resize */
            }

            /* Should only reach here if view has been realized  or is being realized but is not yet realized */
            if (!view.get_realized ()) { /* Need to recall resize_popup to get correct cell height */
                Idle.add (() => {
                    resize_popup ();
                    return GLib.Source.REMOVE;
                });

                return;
            }

            /* Ensure window remains fully on screen */
            var workarea = Gdk.Display.get_default ()
                                      .get_monitor_at_window (parent_window)
                                      .get_workarea ();

            int x, y;
            Gtk.Allocation parent_alloc;
            parent_window.get_origin (out x, out y);
            parent.get_allocation (out parent_alloc);

            x = (x + parent_alloc.x).clamp (workarea.x, workarea.x + workarea.width - width_request);
            y += parent_alloc.y + parent_alloc.height;

            int separator_height;
            Gdk.Rectangle cell_area;
            view.style_get ("vertical-separator", out separator_height);
            view.get_cell_area (new Gtk.TreePath.from_indices (0), null, out cell_area);
            var total = int.max ((items + headers), 2);
            var height = total * (cell_area.height + separator_height);
            height = height.clamp (0, workarea.y + workarea.height - y - 12);

            scroll.set_min_content_height (height);
            set_size_request (int.min (parent_alloc.width, workarea.width), height);
            move (x, y);
            resize (width_request, height_request);
        }

        bool get_iter_at_cursor (out Gtk.TreeIter iter) {
            Gtk.TreePath? path = null;
            Gtk.TreeIter filter_iter = Gtk.TreeIter ();
            iter = Gtk.TreeIter ();

            view.get_cursor (out path, null);
            if (path == null || !filter.get_iter (out filter_iter, path)) {
                return false;
            }

            filter.convert_iter_to_child_iter (out iter, filter_iter);
            return true;
        }

        void select_iter (Gtk.TreeIter iter) {
            filter.convert_child_iter_to_iter (out iter, iter);
            var path = filter.get_path (iter);
            view.set_cursor (path, null, false);
        }

        void popup () {
            if (get_mapped ()) {
                return;
            }

            set_screen (parent.get_screen ());
            show_all ();
            view.grab_focus ();

            /* Ensure device grab and ungrab are paired */
            if (!is_grabbing && device != null) {
                Gtk.device_grab_add (this, device, true);
                device.get_seat ().grab (get_window (), Gdk.SeatCapabilities.ALL_POINTING,
                                         true, null, null, null);

                is_grabbing = true;
            }
            /* Paired with disconnect function in popdown () */
            connect_view_cursor_changed_signal ();
        }

        void popdown () {
            /* Paired with connect function in popup () */
            disconnect_view_cursor_changed_signal ();
            if (is_grabbing) {
                if (device == null) {
                    /* 'device' can become null during searching for reasons as yet unidentified. This ensures
                     * that grab and ungrab are matched (else interface freezes after some searches)
                     */
                    device = Gtk.get_current_event_device ();
                    debug ("Reference to device was lost while grabbing - should not happen");
                }

                device.get_seat ().ungrab ();
                Gtk.device_grab_remove (this, device);
                is_grabbing = false;
            }

            hide ();
        }

        void add_results (Gee.List<Match> new_results, Gtk.TreeIter parent) {
            if (current_operation.is_cancelled ()) {
                return;
            }

            if (!allow_adding_results) {
                Gee.List list;

                if ((list = waiting_results.@get (parent)) == null) {
                    list = new Gee.LinkedList<Match> ();
                    waiting_results.@set (parent, list);
                }

                list.insert_all (list.size, new_results);
                return;
            }

            foreach (var match in new_results) {
                Gtk.TreeIter? iter = null;
                GLib.File file;
                /* do not add global result if already in local results */
                if (parent == zeitgeist_results) {
                    var already_added = false;

                    for (var valid = list.iter_nth_child (out iter, local_results, 0);
                         valid;
                         valid = list.iter_next (ref iter)) {

                        list.@get (iter, 3, out file);

                        if (file != null && match.file != null && file.equal (match.file)) {
                            already_added = true;
                            break;
                        }
                    }

                    if (!already_added) {
                        for (var valid = list.iter_nth_child (out iter, deep_results, 0);
                             valid;
                             valid = list.iter_next (ref iter)) {

                            list.@get (iter, 3, out file);

                            if (file != null && match.file != null && file.equal (match.file)) {
                                already_added = true;
                                break;
                           }
                        }
                    }

                    if (already_added) {
                        continue;
                    }
                } else if (parent == local_results) {
                    /* remove current search result from global if in global results */
                    for (var valid = list.iter_nth_child (out iter, zeitgeist_results, 0);
                         valid;
                         valid = list.iter_next (ref iter)) {

                        list.@get (iter, 3, out file);

                        if (file != null && match.file != null && file.equal (match.file)) {
                            list.remove (ref iter);
                            break;
                        }
                    }
                } else if (parent == deep_results) {
                    /* remove deep search result from from global if in global results */
                    for (var valid = list.iter_nth_child (out iter, zeitgeist_results, 0);
                         valid;
                         valid = list.iter_next (ref iter)) {

                        list.@get (iter, 3, out file);

                        if (file != null && match.file != null && file.equal (match.file)) {
                            list.remove (ref iter);
                             break;
                         }
                     }
                 }

                var location = result_location_markup.printf (Markup.escape_text (match.path_string));

                list.append (out iter, parent);
                list.@set (iter, 0, match.name, 1, match.icon, 2, location, 3, match.file, 4, true, 5, match.sortkey);
                n_results++;

                view.expand_all ();
            }

            if (!working) {
                resize_popup ();
            }
        }

        void accept (Gtk.TreeIter? accepted, bool activate) {
            if (accepted == null && !get_iter_at_cursor (out accepted)) {
                Gdk.beep ();
                return;
            }

            GLib.File? file = null;
            string sortkey = "";
            // Check whether file match or ellipsis activated
            list.@get (accepted, 3, out file);
            list.@get (accepted, 5, out sortkey);
            if (file == null) {
                if (sortkey.has_suffix (ELLIPSIS_NAME)) {
                    max_results += MAX_RESULTS;
                    max_depth += 1;
                    search (search_term, current_root);
                } else {
                    critical ("Search match with no associated file and not an ellipsis");
                    Gdk.beep ();
                }

                return;
            }

            cancel ();

            if (activate) {
                file_activated (file);
            } else {
                file_selected (file);
            }
        }

        GLib.File? get_file_at_iter (Gtk.TreeIter? iter) {
            if (iter == null) {
                get_iter_at_cursor (out iter);
            }

            GLib.File? file = null;
            if (iter != null) {
                list.@get (iter, 3, out file);
            }

            return file;
        }

        protected void clear () {
            /* Disconnect the cursor-changed signal so that it does not get emitted when entries removed
             * causing incorrect files to get selected in icon view */
            bool was_popped_up = has_popped_up ();
            if (was_popped_up) {
                disconnect_view_cursor_changed_signal ();
            }

            Gtk.TreeIter parent, iter;
            for (var valid = list.get_iter_first (out parent);
                 valid;
                 valid = list.iter_next (ref parent)) {

                if (!list.iter_nth_child (out iter, parent, 0)) {
                    continue;
                }

                while (list.remove (ref iter));
            }

            resize_popup ();
            if (was_popped_up && has_popped_up ()) {
                /* Reconnect signal only if remained popped up */
                connect_view_cursor_changed_signal ();
            }
        }

        bool send_search_finished () {
            if (!local_search_finished || !global_search_finished || !allow_adding_results) {
                return false;
            }

            working = false;

            if (current_operation.is_cancelled ()) {
                return false;
            }

            filter.refilter ();

            if (local_search_finished && global_search_finished) {
                if (list_empty ()) {
                    view.get_selection ().unselect_all ();
                    first_match_found (null);
                } else {
                    /* Select first after popped up else cursor change signal not connected */
                    resize_popup ();
                    select_first ();
                }
            }

            return false;
        }

        const string ATTRIBUTES = FileAttribute.STANDARD_NAME + "," +
                                  FileAttribute.STANDARD_DISPLAY_NAME + "," +
                                  FileAttribute.STANDARD_CONTENT_TYPE + "," +
                                  FileAttribute.STANDARD_IS_HIDDEN + "," +
                                  FileAttribute.STANDARD_TYPE + "," +
                                  FileAttribute.STANDARD_ICON;

        void visit (string term, bool include_hidden, Cancellable cancel, GLib.File root_folder) {
            var folder = directory_queue.poll ();

            if (folder == null) {
                return;
            }

            bool in_root = folder.equal (root_folder);
            var category_count = in_root ? current_count : deep_count;

            var depth = 0;

            GLib.File f = folder;
            var path_string = "";

            while (f != null && !f.equal (current_root)) {
                path_string = f.get_basename () + (path_string == "" ? "" : Path.DIR_SEPARATOR_S + path_string);
                f = f.get_parent ();
                depth++;
            }

            if (depth > max_depth) {
                return;
            }

            FileEnumerator enumerator;
            try {
                enumerator = folder.enumerate_children (ATTRIBUTES, 0, cancel);
            } catch (Error e) {
                return;
            }

            var new_results = new Gee.LinkedList<Match> ();

            FileInfo info = null;
            Category cat;

            try {
                while (!cancel.is_cancelled () &&
                       (info = enumerator.next_file (null)) != null &&
                       category_count < max_results) {

                    if (info.get_attribute_boolean (GLib.FileAttribute.STANDARD_IS_HIDDEN) && !include_hidden) {
                        continue;
                    }

                    if (info.get_file_type () == FileType.DIRECTORY) {
                        directory_queue.add (folder.resolve_relative_path (info.get_name ()));
                    }

                    bool begins_with;
                    if (term_matches (term, info.get_display_name (), out begins_with)) {
                        if (in_root) {
                            cat = begins_with ? Category.CURRENT_BEGINS : Category.CURRENT_CONTAINS;
                        } else {
                            cat = begins_with ? Category.DEEP_BEGINS : Category.DEEP_CONTAINS;
                        }
                        new_results.add (new Match (info, path_string, folder, cat));
                        category_count++;
                     }
                }
            } catch (Error e) {warning ("Error enumerating in visit");}

            if (new_results.size < 1) {
                cat = in_root ? Category.CURRENT_ELLIPSIS : Category.DEEP_ELLIPSIS;
                new_results.add (new Match.ellipsis (cat));
                return;
            } else if (!cancel.is_cancelled ()) {
                if (in_root) {
                    current_count = category_count;
                } else {
                    deep_count = category_count;
                }

                /* use a closure here to get vala to pass the userdata that we actually want */
                Idle.add (() => {
                    add_results (new_results, in_root ? local_results : deep_results);
                    return GLib.Source.REMOVE;
                });

                if (category_count >= max_results) {
                    cat = in_root ? Category.CURRENT_ELLIPSIS : Category.DEEP_ELLIPSIS;
                    new_results.add (new Match.ellipsis (cat));
                    return;
                }

                if (current_count >= max_results && deep_count >= max_results) {
                    cancel.cancel ();
                }
            }
        }

#if HAVE_ZEITGEIST
        async void get_zg_results (string term) {
            global_search_finished = false;

            Zeitgeist.ResultSet results;
            try {
                results = yield zg_index.search ("name:" + term + "*",
                                                 new Zeitgeist.TimeRange.anytime (),
                                                 templates,
                                                 0, /* offset */
                                                 max_results * 3,
                                                 Zeitgeist.ResultType.MOST_POPULAR_SUBJECTS,
                                                 current_operation);
            } catch (IOError.CANCELLED e) {
                global_search_finished = true;
                Idle.add (send_search_finished);
                return;
            } catch (Error e) {
                warning ("Fetching results for term '%s' from zeitgeist failed: %s", term, e.message);
                global_search_finished = true;
                Idle.add (send_search_finished);
                return;
            }

            var matches = new Gee.LinkedList<Match> ();
            var home = GLib.File.new_for_path (Environment.get_home_dir ());
            Category cat;
            var i = 0;

            while (results.has_next () && !current_operation.is_cancelled () && !global_search_finished) {
                var result = results.next_value ();
                foreach (var subject in result.subjects.data) {
                    if (i == max_results) {
                        matches.add (new Match.ellipsis (Category.ZEITGEIST_ELLIPSIS));
                        global_search_finished = true;
                        break;
                    }

                    try {
                        var file = GLib.File.new_for_uri (subject.uri);
                        /* Zeitgeist search finds search term anywhere in path.  We are only interested
                         * when the search term is in the basename */
                        while (file != null && !file.get_basename ().contains (term)) {
                            file = file.get_parent ();
                        }

                        if (file != null) {
                            var path_string = "";
                            var parent = file;
                            while ((parent = parent.get_parent ()) != null) {
                                if (parent.equal (current_root)) {
                                    break;
                                }

                                if (parent.equal (home)) {
                                    path_string = "~/" + path_string;
                                    break;
                                }

                                if (path_string == "") {
                                    path_string = parent.get_basename ();
                                } else {
                                    path_string = Path.build_path (Path.DIR_SEPARATOR_S, parent.get_basename (),
                                                                   path_string);
                                }
                            }

                            /* Eliminate duplicate matches */
                            bool found = false;
                            foreach (Match m in matches) {
                                if (m.path_string == path_string) {
                                    found = true;
                                    break;
                                }
                            }

                            if (!found) {
                                var info = yield file.query_info_async (ATTRIBUTES, 0, Priority.DEFAULT,
                                                                        current_operation);
                                var name = info.get_display_name ();
                                cat = name.has_prefix (term) ? Category.ZEITGEIST_BEGINS : Category.ZEITGEIST_CONTAINS;
                                matches.add (new Match (info, path_string, file.get_parent (), cat));
                                i++;
                           }
                        }
                    } catch (Error e) {}
                }
            }

            if (!current_operation.is_cancelled ()) {
                add_results (matches, zeitgeist_results);
            }

            global_search_finished = true;
            Idle.add (send_search_finished);
        }
#endif

        bool term_matches (string term, string name, out bool begins_with ) {
            /* term is assumed to be down */
            var n = name.normalize ().casefold ();
            begins_with = n.has_prefix (term);
            return n.contains (term);
        }

        public bool has_popped_up () {
            return is_grabbing;
        }

        private void connect_view_cursor_changed_signal () {
            view.cursor_changed.connect (on_cursor_changed);
        }
        private void disconnect_view_cursor_changed_signal () {
            view.cursor_changed.disconnect (on_cursor_changed);
        }
    }
}
