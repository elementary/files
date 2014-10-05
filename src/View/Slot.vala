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

        protected bool updates_frozen = false;
        public bool is_active {get; protected set;}

        private FM.DirectoryView? dir_view = null;
        public unowned Marlin.View.Window window {
            get {return ctab.window;}
        }

        public string empty_message = "<span size='x-large'>" + _("This folder is empty.") + "</span>";
        public string loading_message = "<span size='x-large'>" + _("Loading ...") + "</span>";
        public string denied_message = "<span size='x-large'>" + _("Access denied") + "</span>";
        public signal bool horizontal_scroll_event (double delta_x);
        public signal void frozen_changed (bool freeze); 
        public signal void folder_deleted (GOF.File file, GOF.Directory.Async parent);
        public signal void active (); 
        public signal void inactive ();

        /* Support for multi-slot view (Miller)*/
        public Gtk.Box colpane;
        public Granite.Widgets.ThinPaned hpane;
        public signal void miller_slot_request (GLib.File file, bool make_root);
        public signal void size_change (int change);


        public Slot (GLib.File _location, Marlin.View.ViewContainer _ctab, Marlin.ViewMode _mode) {
//message ("New slot location %s", _location.get_uri ());
            base.init ();
            ctab = _ctab;
            mode = _mode;
            is_active = true;
            preferred_column_width = Preferences.marlin_column_view_settings.get_int ("preferred-column-width");
            width = preferred_column_width;
            set_up_directory (_location);

            connect_slot_signals ();
            make_view ();
        }

        ~Slot () {
//message ("Slot destructor");
        }

        private void connect_slot_signals () {
//message ("connect slot signals");
            active.connect (() => {
//message ("Slot %s active", location.get_uri ());
                //ctab.refresh_slot_info (directory.location);
                ctab.refresh_slot_info (this);
                is_active = true;
                dir_view.grab_focus ();
            });

            inactive.connect (() => {
//message ("Slot %s inactive", location.get_uri ());
                is_active = false;
                //dir_view.unselect_all (); /* Is this desirable? */
            });
        }

        private void connect_dir_view_signals () {
            dir_view.path_change_request.connect ((loc, flag, make_root) => {
                /* Avoid race conditions in signal processing TODO identify and prevent race condition*/
                schedule_path_change_request (loc, flag, make_root);
            });
        }

        private void set_up_directory (GLib.File loc) {
//message ("set up directory");
            directory = GOF.Directory.Async.from_gfile (loc);
            assert (directory != null);

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
//message ("schedule path change request");
            GLib.Timeout.add (20, () => {
                on_path_change_request (loc, flag, make_root);
                return false;
            });
        }

        private void on_path_change_request (GLib.File loc, int flag, bool make_root) {
//message ("on_path change request - make root is %s", make_root ? "true" : "false");
            if (flag == 0) {
                if (dir_view is FM.ColumnView)
                    miller_slot_request (loc, make_root);
                else
                    user_path_change_request (loc);
            } else
                ctab.new_container_request (loc, flag);
        }

        public void autosize_slot () {
            if (dir_view == null)
                return;

//message ("autosize_slot");
            Pango.Layout layout = dir_view.create_pango_layout (null);

            if (directory.is_loading ())
                layout.set_markup (loading_message, -1);
            else if (directory.is_empty ())
                layout.set_markup (empty_message, -1);
            else if (directory.permission_denied)
                layout.set_markup (denied_message, -1);
            else
                layout.set_markup (GLib.Markup.escape_text (directory.longest_file_name), -1);

            Pango.Rectangle extents;
            layout.get_extents (null, out extents);


            int old_width = width;
            width = (int) Pango.units_to_double (extents.width)
                  + dir_view.icon_size * 2;

            width = width.clamp (preferred_column_width / 2, preferred_column_width * 3);

//message ("new width %i, old width %i, icon size %i", width, old_width, directory.icon_size);
            size_change (width - old_width);
            hpane.set_position (width);
            colpane.show_all ();
            colpane.queue_draw ();
        }

        public override void user_path_change_request (GLib.File loc) {
//message ("Slot received user path change signal to loc %s, current location is %s", loc.get_uri (), location.get_uri ());
            assert (loc != null);

            if (!location.equal (loc)) {
                var old_dir = directory;
                set_up_directory (loc);
                dir_view.change_directory (old_dir, directory);
                /* View Container takes care of updating appearance */
                ctab.slot_path_changed (loc);
            } else {
                ctab.reload ();
            }
        }

        protected override void make_view () {
//message ("Slot make view");
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

            connect_dir_view_signals ();
        }

        public void set_view_updates_frozen (bool freeze) {
            dir_view.set_updates_frozen (freeze);
        }

        public override bool set_all_selected (bool select_all) {
//message ("Slot all selected is %s", select_all ? "true" : "false");
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

        public override void select_glib_files (GLib.List<GLib.File> files) {
//message ("SLot: select_glib_files");
            if (dir_view != null)
                dir_view.select_glib_files (files);

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

        public unowned FM.DirectoryView? get_directory_view () {
            return dir_view;
        }

        public override void grab_focus () {
//message ("SLot grab focus");
            dir_view.grab_focus ();
        }
        public override void zoom_in () {dir_view.zoom_in ();}
        public override void zoom_out () {dir_view.zoom_out ();}
        public override void zoom_normal () {dir_view.zoom_normal ();}

        public override void reload () {dir_view.reload ();}

    }
}
