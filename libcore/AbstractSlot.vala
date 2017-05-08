/***
    Copyright (c) 2015-2017 elementary LLC (http://launchpad.net/elementary)

    This program is free software: you can redistribute it and/or modify it
    under the terms of the GNU Lesser General Public License version 3, as published
    by the Free Software Foundation, Inc.,.

    This program is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranties of
    MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
    PURPOSE. See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program. If not, see <http://www.gnu.org/licenses/>.

    Authors : Lucas Baudin <xapantu@gmail.com>
              Jeremy Wootten <jeremy@elementaryos.org>
***/

namespace GOF {
    public abstract class AbstractSlot : GLib.Object {

        GOF.Directory.Async _directory;
        public GOF.Directory.Async? directory {
            get {
                AbstractSlot? current = get_current_slot ();
                if (current != null)
                    return current._directory;
                else
                    return null;
            }

            protected set {_directory = value;}
        }

        public GOF.File file {
            get {return directory.file;}
        }
        public GLib.File location  {
            get {return directory.location;}
        }
        public string uri {
            get {return directory.file.uri;}
        }
        public bool can_create {get {return directory != null && !directory.is_trash;}}
        public virtual bool locked_focus {
            get {
                return false;
            }
        }

        public virtual bool is_frozen {get; set; default = true;}

        protected Gtk.Box extra_location_widgets;
        protected Gtk.Box content_box;
        protected int slot_number;
        protected int width;

        public signal void active (bool scroll = true, bool animate = true);
        public signal void inactive ();
        public signal void path_changed (bool change_mode_to_icons = true);

        public  void add_extra_widget (Gtk.Widget widget) {
            extra_location_widgets.pack_start (widget);
        }

        protected void init () {
            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            extra_location_widgets = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            (content_box as Gtk.Box).pack_start (extra_location_widgets, false, false, 0);
            slot_number = -1;
        }

        public abstract void initialize_directory ();
        public abstract unowned GLib.List<unowned GOF.File>? get_selected_files ();
        public abstract void set_active_state (bool set_active, bool animate = true);
        public abstract unowned AbstractSlot? get_current_slot ();
        public abstract void reload (bool non_local_only = false);
        public abstract void grab_focus ();
        public abstract void user_path_change_request (GLib.File loc, bool allow_mode_change, bool make_root);

        public abstract void select_first_for_empty_selection ();
        public abstract void select_glib_files (GLib.List<GLib.File> locations, GLib.File? focus_location);
        protected abstract void make_view ();
        public abstract void cancel ();
        public abstract void close ();
        public abstract FileInfo? lookup_file_info (GLib.File loc);

        public virtual void zoom_out () {}
        public virtual void zoom_in () {}
        public virtual void zoom_normal () {}
        public virtual bool set_all_selected (bool all_selected) {return false;}
        public virtual Gtk.Widget get_content_box () {
            return content_box as Gtk.Widget;
        }
        public virtual string? get_root_uri () {return directory.file.uri;}
        public virtual string? get_tip_uri () {return null;}
        public virtual bool get_realized () {return content_box.get_realized ();}

    }
}
