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

        //public GOF.Directory.Async directory;
        public ViewContainer ctab;

        public FM.DirectoryView? view_box = null;
        public Gtk.Box colpane;
        public Granite.Widgets.ThinPaned hpane;

        //public int width = 0;
        public bool updates_frozen = false;
        public bool is_active = false;

        public signal bool horizontal_scroll_event (double delta_x); //Listeners: Miller
        public signal void frozen_changed (bool freeze); //Listeners: Miller
        public signal void folder_deleted (GOF.File file, GOF.Directory.Async parent);

        public string empty_message = "<span size='x-large'>" +
                                _("This folder is empty.") +
                               "</span>";

        public Slot (GLib.File _location, Marlin.View.ViewContainer _ctab) {
message ("New slot location %s", _location.get_uri ());
            base.init ();
            ctab = _ctab;
            directory = GOF.Directory.Async.from_gfile (_location);
            assert (directory != null);
            connect_signals ();
        }

        ~Slot () {
            this.view_box = null;
            this.directory = null;
            this.ctab = null;
        }

        private void connect_signals () {
message ("Slot connect signals");
            active.connect (() => {
                if (!this.is_active) {
                    ctab.refresh_slot_info (directory.location);
                    this.is_active = true;
                    this.view_box.grab_focus ();
                }
            });

            inactive.connect (() => {
                if (this.is_active) {
message ("Slot inactive");
                    this.is_active = false;
                    this.view_box.unselect_all ();
                }
            });

            ctab.path_changed.connect ((loc, flags, host) => {
message ("Slot received path change signal");
                if (view_box is FM.ColumnView) {
                    /* Handled by Miller */
                    return;
                } else
                    on_tab_path_changed (loc, flags, host);
            });

        }

//        public Gtk.Widget make_icon_view () {
//            make_view (Marlin.ViewMode.ICON);
//            return content_box as Gtk.Widget;
//        }

//        public Gtk.Widget make_list_view () {
//            make_view (Marlin.ViewMode.LIST);
//            return content_box as Gtk.Widget;
//        }

//        /** Only called by Miller, which returns the content to ViewContainer */
//        public void make_column_view () {
//message ("Slot make column view");
//            make_view (Marlin.ViewMode.MILLER_COLUMNS);
//        }

        public override Gtk.Widget make_view (int view_mode) {
message ("Slot make view");
            switch ((Marlin.ViewMode)view_mode) {
                case Marlin.ViewMode.MILLER_COLUMNS:
                    view_box = new FM.ColumnView (this);
                    break;

                case Marlin.ViewMode.LIST:;
                    view_box = new FM.ListView (this);
                    break;

                case Marlin.ViewMode.ICON:
                    view_box = new FM.IconView (this);
                    break;

                default:
                    break;
            }

            if (view_mode != Marlin.ViewMode.MILLER_COLUMNS) {
                content_box.pack_start (view_box, true, true, 0);
                directory.track_longest_name = false;
            }
            /* Miller takes care of packing the view_box otherwise */

            return content_box as Gtk.Widget;
        }


        public void set_updates_frozen (bool freeze) {
            directory.freeze_update = freeze;
            updates_frozen = freeze;
            frozen_changed (freeze);
        }

        public override bool set_all_selected (bool select_all) {
message ("Slot all selected is %s", select_all ? "true" : "false");
            if (view_box != null) {
                if (select_all)
                    view_box.select_all ();
                else
                    view_box.unselect_all ();

                return true;
            } else
                return false;
        }

        public override unowned GLib.List<unowned GOF.File>? get_selected_files () {
            if (view_box != null)
                return view_box.get_selected_files ();
            else
                return null;
        }

        public override void select_glib_files (GLib.List<GLib.File> files) {
            if (view_box != null)
                view_box.select_glib_files (files);

        }

        public override void select_first_for_empty_selection () {
            if (view_box != null)
                view_box.select_first_for_empty_selection ();

        }

        //protected override void on_tab_path_changed (GLib.File? loc, int flag, Slot? source_slot) {
        protected override void on_tab_path_changed (GLib.File? loc, int flag, GOF.AbstractSlot? source_slot = null) {
message ("SLot - on tab changed");
            if (flag == Marlin.OpenFlag.DEFAULT && loc != null) {
                if (location != loc) {
                    var new_dir = GOF.Directory.Async.from_gfile (loc);
                    view_box.change_directory (directory, new_dir);
                    directory = new_dir;
                } else
warning ("Already at this location!");
            }
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

        public override void zoom_in () {view_box.zoom_in ();}
        public override void zoom_out () {view_box.zoom_out ();}
        public override void zoom_normal () {view_box.zoom_normal ();}
        public override void grab_focus () {view_box.grab_focus ();}
        public override void reload () {view_box.reload ();}

    }
}
