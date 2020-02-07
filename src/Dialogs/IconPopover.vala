/*
* Copyright 2020 elementary, Inc. (https://elementary.io)
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

public class Marlin.View.IconPopover : Gtk.Popover {

  private GOF.File file;
  private Gtk.Image icon_image;
  private IconListBox icon_list_box;
  private Gtk.SearchEntry search_entry;
  private Gtk.Button choose_button;

  public IconPopover (Gtk.ToggleButton relative_to, GOF.File goffile) {
      Object (modal: true,
              position: Gtk.PositionType.BOTTOM,
              relative_to: relative_to);
      icon_image = (Gtk.Image) relative_to.get_image ();
      file = goffile;
  }

  construct {
      expand = true;
      var cancel_button = new Gtk.Button.with_label (_("Cancel"));
      cancel_button.clicked.connect (on_cancel_pressed);

      choose_button = new Gtk.Button.with_label (_("Choose"));
      choose_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
      choose_button.clicked.connect (on_accept_pressed);
      choose_button.sensitive = false;

      var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
      button_box.margin = 10;
      button_box.pack_end (choose_button);
      button_box.pack_end (cancel_button);

      icon_list_box = new IconListBox ();
      icon_list_box.row_selected.connect (on_row_selected);
      icon_list_box.row_activated.connect (on_row_activated);

      var scrolled = new Gtk.ScrolledWindow (null, null);
      scrolled.expand = true;
      scrolled.add (icon_list_box);
      scrolled.edge_overshot.connect (on_edge_overshot);

      search_entry = new Gtk.SearchEntry ();
      search_entry.placeholder_text = _("Search icons…");
      search_entry.hexpand = true;
      search_entry.search_changed.connect (on_search_entry_changed);

      var browse_button = new Gtk.Button.with_label (_("Browse"));
      browse_button.clicked.connect (browse_icon);

      var search_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 2);
      search_box.margin = 5;
      search_box.pack_start (search_entry, false, true, 5);
      search_box.pack_end (browse_button, false, false, 2);
      search_box.pack_end (new Gtk.Label ("or"), false, false, 5);

      var content_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
      content_area.pack_start (search_box, false, true, 5);
      content_area.pack_start (scrolled, true, true, 0);
      content_area.pack_start (button_box, false, false, 5);
      add(content_area);
  }

  private void on_row_selected (Gtk.ListBoxRow? row) {
      choose_button.sensitive = row != null;
  }

  private void on_row_activated (Gtk.ListBoxRow row) {
      on_accept_pressed ();
  }

  private void on_edge_overshot (Gtk.PositionType position) {
      if (position == Gtk.PositionType.BOTTOM) {
          icon_list_box.load_next_icons ();
      }
  }

  private void on_search_entry_changed () {
      icon_list_box.search (search_entry.text);
      icon_list_box.invalidate_filter ();
  }

  private void on_cancel_pressed () {
      popdown ();
  }

  private void on_accept_pressed () {
      string? icon_name = icon_list_box.get_selected_icon_name ();
      if (icon_name != null) {
          change_icon (icon_name);
      }
  }

  private void change_icon (string new_custom_icon) {
      file.set_custom_icon_name (new_custom_icon);
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
            change_icon (path);
        } else {
            file_dialog.destroy ();
        }
  }
}
