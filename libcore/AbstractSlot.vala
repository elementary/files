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
        public int slot_number;

        protected void init () {
            content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            extra_location_widgets = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            (content_box as Gtk.Box).pack_start (extra_location_widgets, false, false, 0);
            slot_number = -1;
        }

        public  void add_extra_widget (Gtk.Widget widget) {
            extra_location_widgets.pack_start (widget);
        }
    }
}
