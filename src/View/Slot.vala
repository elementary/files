/***
    Copyright (C) 2015 ELementary Developers

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Jeremy Wootten <jeremy@elementaryos.org>
***/


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

        public string empty_message = _("This Folder Is Empty");
        public string empty_trash_message = _("Trash Is Empty");
        public string empty_recents_message = _("There Are No Recent Files");
        public string denied_message = _("Access Denied");

        public override bool locked_focus {
            get {
                return dir_view.renaming;
            }
        }

        public signal bool horizontal_scroll_event (double delta_x);
        public signal void frozen_changed (bool freeze);
        public signal void folder_deleted (GOF.File file, GOF.Directory.Async parent);
        public signal void active (bool scroll = true);
        public signal void inactive ();

        /* Support for multi-slot view (Miller)*/
        public Gtk.Box colpane;
        public Gtk.Paned hpane;
        public signal void miller_slot_request (GLib.File file, bool make_root);
        public signal void size_change ();

        public Slot (GLib.File _location, Marlin.View.ViewContainer _ctab, Marlin.ViewMode _mode) {
            base.init ();
            ctab = _ctab;
            mode = _mode;
            is_active = false;
            preferred_column_width = Preferences.marlin_column_view_settings.get_int ("preferred-column-width");
            width = preferred_column_width;

            set_up_directory (_location);
            connect_slot_signals ();
            make_view ();
            connect_dir_view_signals ();
        }

        ~Slot () {
            debug ("Slot destruct");
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

            folder_deleted.connect ((file, dir) => {
               ((Marlin.Application)(window.application)).folder_deleted (file.location);
            });
        }

        private void connect_dir_view_signals () {
            dir_view.path_change_request.connect (schedule_path_change_request);
            dir_view.size_allocate.connect (on_dir_view_size_allocate);
            dir_view.item_hovered.connect (on_dir_view_item_hovered);
        }

        private void disconnect_dir_view_signals () {
            dir_view.path_change_request.disconnect (schedule_path_change_request);
            dir_view.size_allocate.disconnect (on_dir_view_size_allocate);
            dir_view.item_hovered.disconnect (on_dir_view_item_hovered);
        }

        private void on_dir_view_size_allocate (Gtk.Allocation alloc) {
                width = alloc.width;
        }

        private void on_dir_view_item_hovered (GOF.File? file) {
            ctab.on_item_hovered (file);
        }

        private void connect_dir_signals () {
            directory.done_loading.connect (on_directory_done_loading);
            directory.need_reload.connect (on_directory_need_reload);
        }

        private void disconnect_dir_signals () {
            directory.done_loading.disconnect (on_directory_done_loading);
            directory.need_reload.disconnect (on_directory_need_reload);
        }

        private void on_directory_done_loading (GOF.Directory.Async dir) {
            ctab.directory_done_loading (this);

            if (mode == Marlin.ViewMode.MILLER_COLUMNS)
                autosize_slot ();

            set_view_updates_frozen (false);
        }

        private void on_directory_need_reload (GOF.Directory.Async dir) {
            dir_view.change_directory (directory, directory);
            ctab.load_slot_directory (this);
        }

        private void set_up_directory (GLib.File loc) {
            if (directory != null)
                disconnect_dir_signals ();

            directory = GOF.Directory.Async.from_gfile (loc);
            assert (directory != null);

            connect_dir_signals ();
            has_autosized = false;

            if (mode == Marlin.ViewMode.MILLER_COLUMNS)
                directory.track_longest_name = true;
        }

        private void schedule_path_change_request (GLib.File loc, int flag, bool make_root) {
            GLib.Timeout.add (20, () => {
                on_path_change_request (loc, flag, make_root);
                return false;
            });
        }

        private void on_path_change_request (GLib.File loc, int flag, bool make_root) {
            if (flag == 0) { /* make view in existing container */
                if (dir_view is FM.ColumnView)
                    miller_slot_request (loc, make_root);
                else
                    user_path_change_request (loc);
            } else
                ctab.new_container_request (loc, flag);
        }

        public void autosize_slot () {
            if (dir_view == null || has_autosized)
                return;

            Pango.Layout layout = dir_view.create_pango_layout (null);

            if (directory.is_empty ()) {
                if (directory.is_trash)
                    layout.set_markup (empty_trash_message, -1);
                else if (directory.is_recent)
                    layout.set_markup (empty_recents_message, -1);
                else
                    layout.set_markup (empty_message, -1);
            } else if (directory.permission_denied)
                layout.set_markup (denied_message, -1);
            else
                layout.set_markup (GLib.Markup.escape_text (directory.longest_file_name), -1);

            Pango.Rectangle extents;
            layout.get_extents (null, out extents);

            width = (int) Pango.units_to_double (extents.width)
                  + dir_view.icon_size
                  + 64; /* allow some extra room for icon padding and right margin*/

            /* Allow extra room for MESSAGE_CLASS styling of special messages */
            if (directory.is_empty () || directory.permission_denied)
                width += width;

            width = width.clamp (preferred_column_width, preferred_column_width * 3);

            size_change ();
            hpane.set_position (width);
            colpane.show_all ();

            if (colpane.get_realized ())
                colpane.queue_draw ();

            has_autosized = true;
        }

        public override void user_path_change_request (GLib.File loc, bool allow_mode_change = true) {
            assert (loc != null);
            var old_dir = directory;
            old_dir.cancel ();
            set_up_directory (loc);
            dir_view.change_directory (old_dir, directory);
            /* ViewContainer takes care of updating appearance
             * If allow_mode_change is false View Container will not automagically
             * switch to icon view for icon folders (needed for Miller View) */
            ctab.slot_path_changed (directory.location, allow_mode_change);
        }

        public override void reload (bool non_local_only = false) {
            if (!(non_local_only && directory.is_local)) {
                directory.clear_directory_info ();
                directory.need_reload (); /* Signal will propagate to any other slot showing this directory */
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

            set_view_updates_frozen (true);
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

        public override void cancel () {
            if (directory != null)
                directory.cancel ();

            if (dir_view != null)
                dir_view.cancel ();
        }

        public override void close () {
            cancel ();

            if (directory != null)
                disconnect_dir_signals ();

            if (dir_view != null)
                disconnect_dir_view_signals ();
        }
    }
}
