/*
* Copyright (c) 2011 Marlin Developers (http://launchpad.net/marlin)
* Copyright (c) 2015-2018 elementary LLC <https://elementary.io>
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation, Inc.,; either
* version 3 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1335 USA.
*
*/

namespace Marlin.View {
  public class IconPopover : Gtk.Popover {
      public signal void create_selection_dialog ();

      private GOF.File file;
      private Gtk.Entry icon_entry;

      public IconPopover (Gtk.Widget relative_to, GOF.File goffile) {
          Object (modal: true,
                  position: Gtk.PositionType.BOTTOM,
                  relative_to: relative_to);
          file = goffile;
          load ();
      }

      construct {
          icon_entry = new Gtk.Entry ();
          icon_entry.placeholder_text = "Custom icon name";

          var set_button = new Gtk.Button.with_label (_("Set Icon"));
          set_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
          set_button.grab_focus ();

          var button_grid = new Gtk.Grid ();
          button_grid.margin = 6;
          button_grid.column_spacing = 5;
          button_grid.column_homogeneous = false;
          button_grid.add (icon_entry);
          button_grid.add (set_button);

          add (button_grid);

          set_button.clicked.connect (change_icon);
      }

      private void load () {
        if (file.custom_icon_name != null) {
            icon_entry.text = file.custom_icon_name;
        }
      }

      private void change_icon () {
        file.custom_icon_name = icon_entry.text;
        file.update_icon (48, get_scale_factor ());
        popdown ();
      }
  }
}
