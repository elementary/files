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
      private Gtk.Image icon_image;

      public IconPopover (Gtk.ToggleButton relative_to, GOF.File goffile) {
          Object (modal: true,
                  position: Gtk.PositionType.BOTTOM,
                  relative_to: relative_to);
          icon_image = (Gtk.Image) relative_to.get_image ();
          file = goffile;
          load ();
      }

      construct {
          icon_entry = new Gtk.Entry ();
          icon_entry.placeholder_text = _("Custom icon name");

          icon_entry.activate.connect (() => {
              change_icon (icon_entry.get_text ());
          });

          icon_entry.focus_out_event.connect (() => {
              change_icon (icon_entry.get_text ());
              return false;
          });

          var browse_button = new Gtk.Button.with_label (_("Browse"));
          browse_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
          browse_button.grab_focus ();

          var button_grid = new Gtk.Grid ();
          button_grid.margin = 6;
          button_grid.column_spacing = 5;
          button_grid.column_homogeneous = false;
          button_grid.add (icon_entry);
          button_grid.add (new Gtk.Label (_("or")));
          button_grid.add (browse_button);

          add (button_grid);

          browse_button.clicked.connect (browse_icon);
      }

      private void load () {
          icon_entry.set_text (file.custom_icon_name);
      }

      private void change_icon (string new_custom_icon) {
          file.custom_icon_name = new_custom_icon;
          file.update_icon (48, get_scale_factor ());
          var file_pix = file.get_icon_pixbuf (48, get_scale_factor (), GOF.File.IconFlags.NONE);
          icon_image.set_from_gicon (file_pix, Gtk.IconSize.DIALOG);
          popdown ();
      }

      private void browse_icon () {
           var file_dialog = new Gtk.FileChooserNative (
                _("Select an icon"),
                get_parent_window () as Gtk.Window?,
                Gtk.FileChooserAction.OPEN,
                _("Open"),
                _("Cancel")
            );

            if (file_dialog.run () == Gtk.ResponseType.ACCEPT) {
                var path = file_dialog.get_file ().get_path ();
                file_dialog.hide ();
                file_dialog.destroy ();
                icon_entry.set_text (path);
                change_icon (path);
                popdown ();
            } else {
                file_dialog.destroy ();
            }
      }
  }
}
