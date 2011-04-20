/*
 *  Marlin
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU General Public License as
 *  published by the Free Software Foundation; either version 2 of the
 *  License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this library; if not, write to the Free Software
 *  Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 *
 *  Authors : Lucas Baudin <xapantu@gmail.com>
 *
 */


namespace Marlin.View
{
    public class SettingsDialog : Gtk.Dialog
    {
        public SettingsDialog(Window win)
        {
            set_title(N_("Marlin Settings"));
            /*height_request = 600;*/
            width_request = 500;
            set_resizable(false);

            var main_notebook = new Gtk.Notebook();

            var first_vbox = new Gtk.VBox(false, 3);
            first_vbox.border_width = 5;


            /* Single click */
            var hbox_single_click = new Gtk.HBox(false, 0);
            var checkbox = new Gtk.Switch();

            Preferences.settings.bind("single-click", checkbox , "active", SettingsBindFlags.DEFAULT);

            var label = new Gtk.Label(N_("Single click to open:"));
            label.set_alignment(0, 0.5f);

            hbox_single_click.pack_start(label);
            hbox_single_click.pack_start(checkbox, false, false);

            first_vbox.pack_start(hbox_single_click, false);

            /* Mouse selection speed */
            var spin_click_speed = new Gtk.HScale.with_range(50, 1000, 1);

            hbox_single_click = new Gtk.HBox(false, 0);

            label = new Gtk.Label(N_("Mouse selection speed:"));
            label.set_alignment(0, 0.5f);

            hbox_single_click.pack_start(label);
            hbox_single_click.pack_start(spin_click_speed, true, true);

            Preferences.settings.bind("single-click", hbox_single_click, "sensitive", SettingsBindFlags.DEFAULT);

            Preferences.settings.bind("single-click-timeout", spin_click_speed.get_adjustment(), "value", SettingsBindFlags.DEFAULT);
            
            first_vbox.pack_start(hbox_single_click, false);
            
            
            main_notebook.append_page(first_vbox, new Gtk.Label(N_("Behavior")));

            first_vbox = new Gtk.VBox(false, 3);
            first_vbox.border_width = 5;

            
            /* Sidebar icon size */
            var spin_icon_size = new Gtk.SpinButton.with_range(4, 128, 1);

            hbox_single_click = new Gtk.HBox(false, 0);

            label = new Gtk.Label(N_("Sidebar icon size:"));
            label.set_alignment(0, 0.5f);

            hbox_single_click.pack_start(label);
            hbox_single_click.pack_start(spin_icon_size, false, false);

            Preferences.settings.bind("sidebar-icon-size", spin_icon_size, "value", SettingsBindFlags.DEFAULT);
            
            first_vbox.pack_start(hbox_single_click, false);

            main_notebook.append_page(first_vbox, new Gtk.Label(N_("Display")));

            ((Gtk.HBox)get_content_area()).pack_start(main_notebook);

            this.show_all();

            this.delete_event.connect(() => { destroy(); return true; });

            add_buttons("gtk-close", Gtk.ResponseType.DELETE_EVENT);
            
            run();
        }

        public override void response(int id)
        {
            switch(id)
            {
            case Gtk.ResponseType.DELETE_EVENT:
                destroy();
                break;
            }
        }
    }
}
