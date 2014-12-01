/*
 Copyright (C) 2014 ELementary Developers

 This program is free software: you can redistribute it and/or modify it
 under the terms of the GNU Lesser General Public License version 3, as published
 by the Free Software Foundation.

 This program is distributed in the hope that it will be useful, but
 WITHOUT ANY WARRANTY; without even the implied warranties of
 MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
 PURPOSE. See the GNU General Public License for more details.

 You should have received a copy of the GNU General Public License along
 with this program. If not, see <http://www.gnu.org/licenses/>.

 Authors : Jeremy Wootten <jeremy@elementary.org>
*/


namespace Marlin.View {
    public class Slot : GOF.AbstractSlot {
        private unowned Marlin.View.ViewContainer ctab;
        private Marlin.ViewMode mode;
        private int preferred_column_width;
        private FM.AbstractDirectoryView? dir_view = null;

        protected bool updates_frozen = false;
        public bool has_autosized = false;

        public bool is_active {get; protected set;}

        public unowned Marlin.View.Window window {
            get {return ctab.window;}
        }

        public string empty_message = "<span size='x-large'>" + _("This folder is empty.") + "</span>";
        public string denied_message = "<span size='x-large'>" + _("Access denied") + "</span>";

        public signal bool horizontal_scroll_event (double delta_x);
        public signal void frozen_changed (bool freeze); 
        public signal void folder_deleted (GOF.File file, GOF.Directory.Async parent);
        public signal void active (bool scroll = true); 
        public signal void inactive ();

        /* Support for multi-slot view (Miller)*/
        public Gtk.Box colpane;
        public Granite.Widgets.ThinPaned hpane;
        public signal void miller_slot_request (GLib.File file, bool make_root);
        public signal void size_change ();


        public Slot (GLib.File _location, Marlin.View.ViewContainer _ctab, Marlin.ViewMode _mode) {
            base.init ();
            ctab = _ctab;
            mode = _mode;
            is_active = true;
            preferred_column_width = Preferences.marlin_column_view_settings.get_int ("preferred-column-width");
            width = preferred_column_width;

            set_up_directory (_location);
            connect_slot_signals ();
            make_view ();
            connect_dir_view_signals ();
        }

        private void connect_slot_signals () {
            active.connect (() => {
                if (is_active)
                    return;

                ctab.refresh_slot_info (this);
                is_active = true;
                dir_view.grab_focus ();
            });

            inactive.connect (() => {
                is_active = false;
            });
        }

        private void connect_dir_view_signals () {
            dir_view.path_change_request.connect ((loc, flag, make_root) => {
                /* Avoid race conditions in signal processing
                 *  TODO identify and prevent race condition */
                schedule_path_change_request (loc, flag, make_root);
            });

            dir_view.size_allocate.connect ((alloc) => {
                width = alloc.width;
            });
        }

        private void set_up_directory (GLib.File loc) {
            directory = GOF.Directory.Async.from_gfile (loc);
            assert (directory != null);

            has_autosized = false;
            directory.done_loading.connect (() => {
                ctab.directory_done_loading (this);

                if (mode == Marlin.ViewMode.MILLER_COLUMNS)
                    autosize_slot ();
            });

            if (mode == Marlin.ViewMode.MILLER_COLUMNS)
                directory.track_longest_name = true;

            directory.need_reload.connect (ctab.reload);
        }

        private void schedule_path_change_request (GLib.File loc, int flag, bool make_root) {
            GLib.Timeout.add (20, () => {
                on_path_change_request (loc, flag, make_root);
                return false;
            });
        }

        private void on_path_change_request (GLib.File loc, int flag, bool make_root) {
message ("SLOT on_path_change_req %s", loc.get_uri ());
            if (flag == 0) {
                if (dir_view is FM.ColumnView)
                    miller_slot_request (loc, make_root);
                else
                    user_path_change_request (loc);
            } else
                ctab.new_container_request (loc, flag);
        }

        public void autosize_slot () {
            if (dir_view == null ||
                !colpane.get_realized () ||
                has_autosized)

                return;

            Pango.Layout layout = dir_view.create_pango_layout (null);

            /* get size of message - message actually drawn by AbstractDirectoryView */
            if (directory.is_empty ())
                layout.set_markup (empty_message, -1);
            else if (directory.permission_denied)
                layout.set_markup (denied_message, -1);
            else
                layout.set_markup (GLib.Markup.escape_text (directory.longest_file_name), -1);

            Pango.Rectangle extents;
            layout.get_extents (null, out extents);

            width = (int) Pango.units_to_double (extents.width)
                  + dir_view.icon_size
                  + 64; /* allow some extra room for icon padding and right margin*/

            width = width.clamp (preferred_column_width, preferred_column_width * 3);

            size_change ();
            hpane.set_position (width);
            colpane.show_all ();
            colpane.queue_draw ();
            has_autosized = true;
        }

        public override void user_path_change_request (GLib.File loc, bool allow_mode_change = true) {
            assert (loc != null);
message ("SLot user path change request %s", loc.get_uri ());
            if (!location.equal (loc)) {
                var old_dir = directory;
                set_up_directory (loc);
                dir_view.change_directory (old_dir, directory);
                /* ViewContainer takes care of updating appearance
                 * If allow_mode_change is false View Container will not automagically
                 * switch to icon view for icon folders (needed for Miller View) */
                ctab.slot_path_changed (loc, allow_mode_change);
            } else {
                ctab.reload ();
            }
        }

        protected override void make_view () {
            assert (dir_view == null);

            switch (mode) {
                case Marlin.ViewMode.MILLER_COLUMNS:
                    dir_view = new FM.ColumnView (this);
                    break;

                case Marlin.ViewMode.LIST:;
                    dir_view = new FM.ListView (this);
                    break;

                case Marlin.ViewMode.ICON:
                    dir_view = new FM.IconView (this);
                    break;

                default:
                    break;
            }

            if (mode != Marlin.ViewMode.MILLER_COLUMNS)
                content_box.pack_start (dir_view, true, true, 0);
        }

        public void set_view_updates_frozen (bool freeze) {
            dir_view.set_updates_frozen (freeze);
        }

        public override bool set_all_selected (bool select_all) {
            if (dir_view != null) {
                if (select_all)
                    dir_view.select_all ();
                else
                    dir_view.unselect_all ();

                return true;
            } else
                return false;
        }

        public override unowned GLib.List<unowned GOF.File>? get_selected_files () {
            if (dir_view != null)
                return dir_view.get_selected_files ();
            else
                return null;
        }

        public override void select_glib_files (GLib.List<GLib.File> files, GLib.File? focus_location) {
            if (dir_view != null)
                dir_view.select_glib_files (files, focus_location);
        }

        public override void select_first_for_empty_selection () {
            if (dir_view != null)
                dir_view.select_first_for_empty_selection ();
        }

        public override void set_active_state (bool set_active) {
            if (set_active)
                active ();
            else
                inactive ();
        }

        public override unowned GOF.AbstractSlot? get_current_slot () {
            return this as GOF.AbstractSlot;
        }

        public unowned FM.AbstractDirectoryView? get_directory_view () {
            return dir_view;
        }

        public override void grab_focus () {
            if (dir_view != null)
                dir_view.grab_focus ();
        }

        public override void zoom_in () {
            if (dir_view != null)
                dir_view.zoom_in ();
        }

        public override void zoom_out () {
            if (dir_view != null)
                dir_view.zoom_out ();
        }

        public override void zoom_normal () {
            if (dir_view != null)
                dir_view.zoom_normal ();
        }

        public override void reload () {
            if (dir_view != null)
                dir_view.reload ();
        }

        public override void cancel () {
            if (dir_view != null)
                dir_view.cancel ();
        }
    }
}
