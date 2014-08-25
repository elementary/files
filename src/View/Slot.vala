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
        private Marlin.View.ViewContainer ctab;
        private Marlin.ViewMode mode;
        //public GOF.Directory.Async directory;
        public FM.DirectoryView? dir_view = null;
        public Gtk.Box colpane;
        public Granite.Widgets.ThinPaned hpane;
        public Marlin.View.Window window {
            get {return ctab.window;}
        }
        //public int width = 0;
        public bool updates_frozen = false;
        public bool is_active = true;

        public signal bool horizontal_scroll_event (double delta_x); //Listeners: Miller
        public signal void frozen_changed (bool freeze); //Listeners: Miller
        public signal void folder_deleted (GOF.File file, GOF.Directory.Async parent);

        public signal void miller_slot_request (GLib.File file, bool make_root);
        public string empty_message = "<span size='x-large'>" +
                                _("This folder is empty.") +
                               "</span>";

        public signal void autosize ();

        public Slot (GLib.File _location, Marlin.View.ViewContainer _ctab, Marlin.ViewMode _mode) {
//message ("New slot location %s", _location.get_uri ());
            base.init ();
            ctab = _ctab;
            mode = _mode;
            set_up_directory (_location);
            connect_slot_signals ();
            make_view ();
        }

        private void connect_slot_signals () {
//message ("connect slot signals");
            active.connect (() => {
                this.dir_view.grab_focus ();
                if (!this.is_active) {
                    ctab.refresh_slot_info (directory.location);
                    this.is_active = true;
                }
            });

//message ("Slot connect signals - inactive");
            inactive.connect (() => {
                if (this.is_active) {
//message ("Slot -> inactive");
                    this.is_active = false;
                    this.dir_view.unselect_all ();
                }
            });
        }

        private void autosize_me () {
//message ("autosize me");
            autosize ();
        }

        private void connect_dir_view_signals () {
//message ("Connect DV to slot signals - path_change_request");
            dir_view.path_change_request.connect ((loc, flag, make_root) => {
                /* Avoid race conditions in signal processing TODO identify and prevent race condition*/
                schedule_path_change_request (loc, flag, make_root);
            });
        }

        private void set_up_directory (GLib.File loc) {
            directory = GOF.Directory.Async.from_gfile (loc);
            assert (directory != null);
            directory.done_loading.connect (autosize_me);
            directory.track_longest_name = (mode == Marlin.ViewMode.MILLER_COLUMNS);
        }

        private void schedule_path_change_request (GLib.File loc, int flag, bool make_root) {
            GLib.Timeout.add (20, () => {
                on_path_change_request (loc, flag, make_root);
                return false;
            });
        }

        private void on_path_change_request (GLib.File loc, int flag, bool make_root) {
            if (flag == 0) {
                if (dir_view is FM.ColumnView) {
                    miller_slot_request (loc, make_root);
                } else {
                    user_path_change_request (loc);
                }
            } else
                ctab.new_container_request (loc, flag);
        }

        public override void user_path_change_request (GLib.File loc) {
//message ("Slot received path change signal to loc %s", loc.get_uri ());
            assert (loc != null);

            if (location != loc) {
                var old_dir = directory;
                set_up_directory (loc);
                dir_view.change_directory (old_dir, directory);

            } else
                assert_not_reached ();

            /* View Container takes care of updating appearance */
            ctab.slot_path_changed (loc);
        }

        protected override Gtk.Widget make_view () {
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

            if (mode != Marlin.ViewMode.MILLER_COLUMNS) {
                content_box.pack_start (dir_view, true, true, 0);
            } /* Miller takes care of packing the dir_view otherwise */

            connect_dir_view_signals ();

            return content_box as Gtk.Widget;
        }


        public void set_updates_frozen (bool freeze) {
            directory.freeze_update = freeze;
            updates_frozen = freeze;
            frozen_changed (freeze);
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

        public override GOF.AbstractSlot get_current_slot () {
            return this as GOF.AbstractSlot;
        }

        public override void zoom_in () {dir_view.zoom_in ();}
        public override void zoom_out () {dir_view.zoom_out ();}
        public override void zoom_normal () {dir_view.zoom_normal ();}
        public override void grab_focus () {dir_view.grab_focus ();}
        public override void reload () {dir_view.reload ();}

    }
}
