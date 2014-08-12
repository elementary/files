/***
  Copyright (C)  

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

namespace Marlin.View {
    public class Slot : GOF.AbstractSlot {

        public GOF.Directory.Async directory;
        public GLib.File location;
        public ViewContainer ctab;

        public FM.DirectoryView? view_box = null;
        public Gtk.Box colpane;
        public Granite.Widgets.ThinPaned hpane;

        public int width = 0;
        public bool updates_frozen = false;
        public bool is_active = false;

        public signal void active (); //Listeners: this, MillerView
        public signal bool horizontal_scroll_event (double delta_x); //Listeners: MillerView
        public signal void inactive (); //Listeners: this
        public signal void frozen_changed (bool freeze); //Listeners: MillerView
        public signal void folder_deleted (GOF.File file, GOF.Directory.Async parent);
        //public signal void autosize ();

        public string empty_message = "<span size='x-large'>" +
                                _("This folder is empty.") +
                               "</span>";

        public Slot (GLib.File _location, Marlin.View.ViewContainer _ctab) {
message ("New slot location %s", _location.get_uri ());
            base.init ();
            location = _location;
            ctab = _ctab;
            directory = GOF.Directory.Async.from_gfile (_location);
            assert (directory != null);
            active.connect (() => {
//message ("Slot directory location %s is activated", directory.location.get_uri ());
                if (!this.is_active) {
//message ("Slot directory location %s is activated", directory.location.get_uri ());
                    ctab.refresh_slot_info (directory.file);
//message ("Slot: merge");
                    //this.view_box.merge_menus ();
                    this.is_active = true;
                    /* Ensure this slot gets the keypress events */
message ("Slot grab focus");
                    this.view_box.grab_focus ();
                }
            });
            inactive.connect (() => {
//message ("Slot directory location %s is inactivated", directory.location.get_uri ());
                if (this.is_active) {
//message ("Slot directory location %s is inactivated", directory.location.get_uri ());
//message ("Slot: unmerge");
                    //this.view_box.unmerge_menus ();
                    this.is_active = false;
                }
            });

        }

        ~Slot () {
message ("In slot %s destruct", directory.file.uri);
            this.view_box = null;
            this.directory = null;
            this.ctab = null;
        }

        public Gtk.Widget make_icon_view () {
            make_view (Marlin.ViewMode.ICON);
            return content_box as Gtk.Widget;
        }

        public Gtk.Widget make_list_view () {
            make_view (Marlin.ViewMode.LIST);
            return content_box as Gtk.Widget;
        }

        /** Only called by Miller, which returns the content to ViewContainer */
        public void make_column_view () {
//message ("Slot make column view");
            make_view (Marlin.ViewMode.MILLER_COLUMNS);
        }

        public void make_view (Marlin.ViewMode view_mode) {
//message ("Slot make view");
            switch (view_mode) {
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

            directory.load ();
        }


        public void set_updates_frozen (bool freeze) {
            directory.freeze_update = freeze;
            updates_frozen = freeze;
            frozen_changed (freeze);
        }

        public bool select_all (bool all) {
message ("Slot select_all?");
            if (view_box != null) {
                if (all)
                    view_box.select_all ();
                else
                    view_box.unselect_all ();

                return true;
            } else
                return false;
        }
    }
}
