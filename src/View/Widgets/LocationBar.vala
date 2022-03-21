/*
* Copyright (c) 2018 elementary LLC <https://elementary.io>
*               2011 Lucas Baudin <xapantu@gmail.com>
*               2010 mathijshenquet
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*/

namespace Files.View.Chrome {
    public class LocationBar : BasicLocationBar {
        private BreadcrumbsEntry bread;
        private SearchResults search_results;
        private GLib.File? search_location = null;

        public bool search_mode {
            get {
                return bread.search_mode;
            }

            private set {
                bread.search_mode = value; //Ensure no path change requests from entry while searching
            }
        }

        public new bool sensitive {
            set {
                bread.sensitive = value;
            }

            get {
                return bread.sensitive;
            }
        }

        uint focus_timeout_id = 0;

        public signal void reload_request ();
        public signal void focus_file_request (GLib.File? file);
        public signal void escape ();

        public LocationBar () {
            var _bread = new BreadcrumbsEntry ();
            base (_bread as Navigatable);
            bread = _bread;
            search_results = new SearchResults (bread);
            connect_additional_signals ();
            show_refresh_icon ();
        }

        private void connect_additional_signals () {
            bread.open_with_request.connect (on_bread_open_with_request);
            search_results.file_selected.connect (on_search_results_file_selected);
            search_results.file_activated.connect (on_search_results_file_activated);
            search_results.cursor_changed.connect (on_search_results_cursor_changed);
            search_results.first_match_found.connect (on_search_results_first_match_found);
            search_results.realize.connect (on_search_results_realize);
            search_results.exit.connect (on_search_results_exit);
            search_results.notify["working"].connect (on_search_results_working_changed);
        }

        private void on_search_results_file_selected (GLib.File file) {
            /* Search result widget ensures it has closed and released grab */
            /* Returned result might be a link or a server */
            var gof = new Files.File (file, null);
            gof.ensure_query_info ();

            path_change_request (gof.get_target_location ().get_uri ());
        }
        private void on_search_results_file_activated (GLib.File file) {
            AppInfo? app = MimeActions.get_default_application_for_glib_file (file);
            MimeActions.open_glib_file_request (file, this, app);
            on_search_results_exit ();
        }

        private void on_search_results_first_match_found (GLib.File? file) {
            focus_file_request (file);
        }

        private void on_search_results_cursor_changed (GLib.File? file) {
            if (file != null) {
                schedule_focus_file_request (file);
            }
        }

        private void on_search_results_realize () {
            /*Is this necessary every popup? */
            ((Gtk.Window)get_toplevel ()).get_group ().add_window (search_results);
        }
        private void on_search_results_exit (bool exit_navigate = true) {
            /* Search result widget ensures it has closed and released grab */
            bread.reset_im_context ();
            if (focus_timeout_id > 0) {
                GLib.Source.remove (focus_timeout_id);
            }
            if (exit_navigate) {
                escape ();
            } else {
                bread.set_entry_text (bread.get_breadcrumbs_path (false));
                enter_navigate_mode ();
            }
        }

        private void on_search_results_working_changed () {
            if (search_results.working) {
                show_working_icon ();
            } else {
                hide_working_icon ();
            }
        }

        protected override bool after_bread_focus_out_event (Gdk.EventFocus event) {
            base.after_bread_focus_out_event (event);
            search_mode = false;
            hide_search_icon ();
            show_refresh_icon ();
            focus_out_event (event);
            check_home ();
            return true;
        }
        protected override bool after_bread_focus_in_event (Gdk.EventFocus event) {
            base.after_bread_focus_in_event (event);
            focus_in_event (event);
            search_location = FileUtils.get_file_for_path (bread.get_breadcrumbs_path ());
            show_navigate_icon ();
            return true;
        }

        private void on_bread_open_with_request (GLib.File file, AppInfo? app) {
            Files.MimeActions.open_glib_file_request (file, this, app);
        }

        protected override void on_bread_action_icon_press () {
            if (has_focus) {
                bread.activate ();
            } else {
                reload_request ();
            }
        }

        protected override void after_bread_text_changed (string txt) {
            if (txt.length < 1) {
                if (search_mode) {
                    switch_to_navigate_mode ();
                }
                show_placeholder ();
                return;
            }
            hide_placeholder ();
            if (search_mode) {
                if (txt.contains (Path.DIR_SEPARATOR_S)) {
                    switch_to_navigate_mode ();
                } else {
                    show_search_icon ();
                    search_results.search (txt, search_location);
                }
            } else {
                if (!txt.contains (Path.DIR_SEPARATOR_S)) {
                    switch_to_search_mode ();
                } else {
                    base.after_bread_text_changed (txt);
                    bread.completion_needed (); /* delegate to bread to decide whether completion really needed */
                }
            }
        }

        protected override void show_navigate_icon () {
            show_search_icon ();
            base.show_navigate_icon ();
        }

        protected void show_search_icon () {
            bread.get_style_context ().remove_class ("spin");
            bread.set_primary_icon_name (Files.ICON_PATHBAR_PRIMARY_FIND_SYMBOLIC);
        }

        protected void hide_search_icon () {
            bread.set_primary_icon_name (null);
        }

        protected void show_refresh_icon () {
            bread.get_style_context ().remove_class ("spin");
            bread.action_icon_name = Files.ICON_PATHBAR_SECONDARY_REFRESH_SYMBOLIC;
            bread.set_action_icon_tooltip (Granite.markup_accel_tooltip ({"F5", "<Ctrl>R"}, _("Reload this folder")));
        }

        private void show_placeholder () {
            bread.set_placeholder (_("Search or Type Path"));
        }

        private void hide_placeholder () {
            bread.set_placeholder ("");
        }

        private void show_working_icon () {
            bread.action_icon_name = Files.ICON_PATHBAR_SECONDARY_WORKING_SYMBOLIC;
            bread.set_action_icon_tooltip (_("Searching…"));
            bread.get_style_context ().add_class ("spin");
        }

        private void hide_working_icon () {
            bread.get_style_context ().remove_class ("spin");
            bread.action_icon_name = null;
        }

        public bool enter_search_mode (string term = "") {
            if (!sensitive) {
                return false;
            }

            if (!search_mode) {
                /* Initialise search mode but do not search until first character has been received */
                if (set_focussed ()) {
                    bread.set_entry_text (term);
                } else {
                    return false;
                }
            } else {
                /* repeat search with new settings */
                search_results.search (bread.get_entry_text (), search_location);
            }
            return true;
        }

        public virtual bool enter_navigate_mode (string? current = null) {
            if (sensitive && set_focussed ()) {
                show_navigate_icon ();
                return true;
            } else {
                return false;
            }
        }

        private void switch_to_navigate_mode () {
            search_mode = false;
            cancel_search ();
            hide_search_icon ();
            show_navigate_icon ();
        }

        private void switch_to_search_mode () {
            search_mode = true;
            hide_navigate_icon ();
            hide_search_icon ();
            show_search_icon ();
            /* Next line ensures that the pathbar not lose focus when the mouse if over the sidebar,
             * which would normally grab the focus */
            after_bread_text_changed (bread.get_entry_text ());
        }

        private void cancel_search () {
            search_results.cancel ();
        }

        public void cancel () {
            cancel_search ();
            on_search_results_exit (); /* Exit navigation mode as well */
        }

        private void schedule_focus_file_request (GLib.File? file) {
            if (focus_timeout_id > 0) {
                GLib.Source.remove (focus_timeout_id);
            }

            focus_timeout_id = GLib.Timeout.add (300, () => {
                focus_file_request (file);
                focus_timeout_id = 0;
                return GLib.Source.REMOVE;
            });
        }

        public override void set_display_path (string uri) {
            base.set_display_path (uri);
            check_home ();
        }

        private void check_home () {
            if (!((Gtk.Window)(get_toplevel ())).has_toplevel_focus) {
                return;
            }

            try {
                bread.hide_breadcrumbs = GLib.Filename.from_uri (displayed_path) == Environment.get_home_dir ();
            } catch (Error e) {
                bread.hide_breadcrumbs = false;
            }

            if (bread.hide_breadcrumbs) {
                show_placeholder ();
                show_search_icon ();
            } else {
                hide_placeholder ();
                hide_search_icon ();
            }
        }
    }
}
