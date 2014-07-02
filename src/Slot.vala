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

namespace GOF {
    namespace Window {
    public class Slot : AbstractSlot {

        public GOF.Directory.Async directory;
        public GLib.File location;
        public Marlin.View.ViewContainer ctab;

        public FM.Directory.View view_box;
        public Gtk.Box colpane;
        public Granite.Widgets.ThinPaned hpane;
        //public Gtk.Paned hpane;

        //public int slot_number = 0;
        public int width = 0;
        //public bool ready_to_autosize = false;

        public signal void active ();
        public signal void inactive ();
        public signal void frozen (bool freeze);



        public Slot (GLib.File location, Marlin.View.ViewContainer ctab) {
            base.init ();
            this.location = location;
            this.ctab = ctab;
            this.directory = GOF.Directory.Async.from_gfile (location);
        }

        public Gtk.Widget make_icon_view () {
            make_view (Marlin.View.ViewMode.ICON);
            return content_box as Gtk.Widget;
        }
        public Gtk.Widget make_list_view () {
            make_view (Marlin.View.ViewMode.LIST);
            return content_box as Gtk.Widget;
        }
        public void make_column_view () {
            /* Only called by mwcols, which returns the content to ViewContainer */
            make_view (Marlin.View.ViewMode.MILLER);
        }

        public void make_view (Marlin.View.ViewMode view_mode) {
            if (view_box != null)
                view_box.destroy ();

            switch (view_mode) {
                case Marlin.View.ViewMode.MILLER:
                    //view_box = new FM.Column.View ();
                    view_box = GLib.Object.@new (FM.Columns.View.get_type (),
                                               "window-slot", this, null) as FM.Directory.View;
                    //view_box.set_slot (this);
                    return;
                case Marlin.View.ViewMode.LIST:
                    //view_box = new FM.List.View ();
                    view_box = GLib.Object.@new (FM.List.View.get_type (),
                                               "window-slot", this, null) as FM.Directory.View;
                    //view_box.set_slot (this);
                    break;
                case Marlin.View.ViewMode.ICON:
                default:
                    //view_box = new FM.Icon.View ();
                    view_box = GLib.Object.@new (FM.Icon.View.get_type (),
                                               "window-slot", this, null) as FM.Directory.View;
                    //view_box.set_slot (this);
                    break;
            }

            //(view_box as FM.Directory.View).set_slot (this);
            content_box.pack_start (view_box, true, true, 0);
            //ctab.content = content_box;
            directory.track_longest_name = false;
            directory.load ();
        }

        public void autosize (int handle_size, int preferred_column_width) {
message ("Slot.autosize");
            if (this.slot_number < 0)
                return;

            Pango.Layout layout = view_box.create_pango_layout (null);

            if (directory.is_empty ())
                layout.set_markup (view_box.empty_message, -1);
            else
                layout.set_markup (GLib.Markup.escape_text (directory.longest_file_name), -1);

            Pango.Rectangle extents;
            layout.get_extents (null, out extents);

            width = (int) Pango.units_to_double (extents.width)
                  + 2 * directory.icon_size
                  + 2 * handle_size
                  + 12;

            /* TODO make min and max width to be properties of mwcols */
            width.clamp (preferred_column_width / 2, preferred_column_width * 2);
message ("Slot: width assigned %i", width);
            hpane.set_position (width);
        }

        public void freeze_updates () {
            directory.freeze_update = true;
            frozen (true);
        }
        public void unfreeze_updates () {
            directory.freeze_update = false;
            frozen (false);
        }

    }
    }
}
