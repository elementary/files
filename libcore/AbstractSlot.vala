/***
  Copyright (C) 2014 elementary Developers and Jeremy Wootten

  This program is free software: you can redistribute it and/or modify it
  under the terms of the GNU Lesser General Public License version 3, as published
  by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranties of
  MERCHANTABILITY, SATISFACTORY QUALITY, or FITNESS FOR A PARTICULAR
  PURPOSE. See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License along
  with this program. If not, see <http://www.gnu.org/licenses/>.

 Authors : Lucas Baudin <xapantu@gmail.com>
           Jeremy Wootten <jeremywootten@gmail.com>
***/

namespace GOF {
    public abstract class AbstractSlot : GLib.Object {

        protected Gtk.Box extra_location_widgets;
        protected Gtk.Box content_box;
        public GOF.Directory.Async directory;
        public GLib.File location  {
            get { return directory.location;}
        }
        public int slot_number;
        public int width = 0;

        public signal void active (); //Listeners: this, Miller
        public signal void inactive (); //Listeners: this

        protected void init () {
            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            extra_location_widgets = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            (content_box as Gtk.Box).pack_start (extra_location_widgets, false, false, 0);
            slot_number = -1;
        }

        public  void add_extra_widget (Gtk.Widget widget) {
            extra_location_widgets.pack_start (widget);
        }

        public virtual void select_first_for_empty_selection () {}
        public abstract unowned GLib.List<unowned GOF.File>? get_selected_files ();
        public virtual void select_glib_files (GLib.List<GLib.File> locations) {}
        public abstract Gtk.Widget make_view (int mode);
        public abstract void set_active_state (bool set_active);
        public abstract AbstractSlot get_current_slot ();
        public virtual string? get_root_uri () {
message ("AS get_root_uri is %s", directory.file.uri);
            return directory.file.uri;
        }
        public virtual string? get_tip_uri () {return null;}
        protected virtual void on_tab_path_changed (GLib.File? loc, int flag, AbstractSlot? host) {}
        public virtual void zoom_in () {}
        public virtual void zoom_out () {}
        public virtual void zoom_normal () {}
        public abstract void grab_focus ();
        public virtual bool set_all_selected (bool all_selected) {return false;}
        public abstract void reload ();
    }
}
