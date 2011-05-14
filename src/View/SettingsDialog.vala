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
            set_title(_("Marlin Settings"));
            /*height_request = 600;*/
            width_request = 500;
            set_resizable(false);

            var mai_notebook = new Gtk.Notebook();

            var first_vbox = new Gtk.VBox(false, 3);
            first_vbox.border_width = 5;


            /* Single click */
            var hbox_single_click = new Gtk.HBox(false, 0);
            var checkbox = new Gtk.Switch();

            Preferences.settings.bind("single-click", checkbox , "active", SettingsBindFlags.DEFAULT);

            var label = new Gtk.Label(_("Single click to open:"));
            label.set_alignment(0, 0.5f);

            hbox_single_click.pack_start(label);
            hbox_single_click.pack_start(checkbox, false, false);

            first_vbox.pack_start(hbox_single_click, false);

            /* Mouse selection speed */
            var spi_click_speed = new Gtk.HScale.with_range(0, 1000, 1);

            hbox_single_click = new Gtk.HBox(false, 0);

            label = new Gtk.Label(_("Mouse auto-selection speed:"));
            label.set_alignment(0, 0.5f);

            hbox_single_click.pack_start(label);
            hbox_single_click.pack_start(spi_click_speed, true, true);

            Preferences.settings.bind("single-click", hbox_single_click, "sensitive", SettingsBindFlags.DEFAULT);

            Preferences.settings.bind("single-click-timeout", spi_click_speed.get_adjustment(), "value", SettingsBindFlags.DEFAULT);
            
            first_vbox.pack_start(hbox_single_click, false);
            
            
            mai_notebook.append_page(first_vbox, new Gtk.Label(_("Behavior")));

            first_vbox = new Gtk.VBox(false, 3);
            first_vbox.border_width = 5;

            
            /* Sidebar icon size */
            var spin_icon_size = new Chrome.ModeButton();
            spin_icon_size.append(new Gtk.Label(_("small")));
            spin_icon_size.append(new Gtk.Label(_("medium")));
            spin_icon_size.append(new Gtk.Label(_("large")));
            spin_icon_size.append(new Gtk.Label(_("extra-large")));
            switch((int)Preferences.settings.get_value("sidebar-icon-size"))
            {
            case 16:
                spin_icon_size.selected = 0;
                break;
            case 24:
                spin_icon_size.selected = 1;
                break;
            case 32:
                spin_icon_size.selected = 2;
                break;
            case 48:
                spin_icon_size.selected = 3;
                break;
            }

            spin_icon_size.mode_changed.connect(spin_icon_size_changed);

            hbox_single_click = new Gtk.HBox(false, 0);

            label = new Gtk.Label(_("Sidebar icon size:"));
            label.set_alignment(0, 0.5f);

            hbox_single_click.pack_start(label);
            hbox_single_click.pack_start(spin_icon_size, false, false);
            
            first_vbox.pack_start(hbox_single_click, false);

            
            /* Date format */
            var mode_date_format = new Chrome.ModeButton();
            mode_date_format.append(new Gtk.Label(_("locale")));
            mode_date_format.append(new Gtk.Label(_("iso")));
            mode_date_format.append(new Gtk.Label(_("informal")));
            switch((string)Preferences.settings.get_value("date-format"))
            {
            case "locale":
                mode_date_format.selected = 0;
                break;
            case "iso":
                mode_date_format.selected = 1;
                break;
            case "informal":
                mode_date_format.selected = 2;
                break;
            }

            mode_date_format.mode_changed.connect(date_format_changed);

            mode_date_format.set_visible_window(true);
            hbox_single_click = new Gtk.HBox(false, 0);

            label = new Gtk.Label(_("Date format:"));
            label.set_alignment(0, 0.5f);

            hbox_single_click.pack_start(label);
            hbox_single_click.pack_start(mode_date_format, false, false);
            
            first_vbox.pack_start(hbox_single_click, false);
            
            
            /* Show text in the sidebar */
            hbox_single_click = new Gtk.HBox(false, 0);
            checkbox = new Gtk.Switch();

            Preferences.settings.bind("show-open-with-text", checkbox , "active", SettingsBindFlags.DEFAULT);

            label = new Gtk.Label(_("Show applications names in the context pane:"));
            label.set_alignment(0, 0.5f);

            hbox_single_click.pack_start(label);
            hbox_single_click.pack_start(checkbox, false, false);

            first_vbox.pack_start(hbox_single_click, false);

            mai_notebook.append_page(first_vbox, new Gtk.Label(_("Display")));

            first_vbox = new Gtk.VBox(false, 3);
            first_vbox.border_width = 5;
            
           var view = new Gtk.TreeView(); 
        var listmodel = new Gtk.ListStore (2, typeof (string), typeof (bool));
        view.set_model (listmodel);

        view.insert_column_with_attributes (-1, "Plugin Name", new Gtk.CellRendererText (), "text", 0);
        var toggle = new Gtk.CellRendererToggle();
        toggle.toggled.connect ((toggle, path) => {
            var tree_path = new Gtk.TreePath.from_string (path);
            Gtk.TreeIter iter;
            listmodel.get_iter (out iter, tree_path);
            listmodel.set (iter, 1, !toggle.active);
            if(toggle.active == true)
            {
                string[] plugs = new string[Preferences.settings.get_strv("plugins-enabled").length - 1];
                string[] current_plugins = Preferences.settings.get_strv("plugins-enabled");

                int offset = 0;
                for(int i = 0; i <= plugs.length; i++)
                {
                    print(current_plugins[i] + "\n");
                    var name = new Value(typeof(string));
                    listmodel.get_value(iter, 0, out name);
                    if(current_plugins[i] == (string)name)
                    {
                        print("to remove\n");
                        offset ++;
                    }
                    else
                    {
                        plugs[i - offset] = current_plugins[i];
                        print("add plugin: %s\n", current_plugins[i]);
                    }
                }
                Preferences.settings.set_strv("plugins-enabled", plugs);
            }
            else
            {
                string[] plugs = new string[Preferences.settings.get_strv("plugins-enabled").length + 1];
                string[] current_plugins = Preferences.settings.get_strv("plugins-enabled");

                for(int i = 0; i < current_plugins.length; i++)
                {
                    plugs[i] = current_plugins[i];
                }
                var name = new Value(typeof(string));
                listmodel.get_value(iter, 0, out name);
                plugs[plugs.length - 1] = name.get_string();
                Preferences.settings.set_strv("plugins-enabled", plugs);

            }
        }); 
        view.insert_column_with_attributes (-1, "Active", toggle, "active", 1);

        Gtk.TreeIter iter;

            foreach(string plugin_name in Marlin.PluginManager.get_available_plugins())
            {
                print(plugin_name + "\n");
                        listmodel.append (out iter);
        listmodel.set (iter, 0, plugin_name, 1, plugin_name in Preferences.settings.get_strv("plugins-enabled"));

            }

            first_vbox.pack_start(view);


            mai_notebook.append_page(first_vbox, new Gtk.Label(_("Plugins")));

            ((Gtk.Box)get_content_area()).pack_start(mai_notebook);

            this.show_all();

            this.delete_event.connect(() => { destroy(); return true; });

            add_buttons("gtk-close", Gtk.ResponseType.DELETE_EVENT);

            run();
        }

        private void spin_icon_size_changed(Gtk.Widget widget)
        {
            int value = 16;
            switch(((Gtk.Label)widget).get_text())
            {
            case "small":
                value = 16;
                break;
            case "medium":
                value = 24;
                break;
            case "large":
                value = 32;
                break;
            case "extra-large":
                value = 48;
                break;
            }
            Preferences.settings.set_value("sidebar-icon-size", value);
        }

        private void date_format_changed(Gtk.Widget widget)
        {
            string value = "iso";
            switch(((Gtk.Label)widget).get_text())
            {
            case "locale":
                value = "locale";
                break;
            case "iso":
                value = "iso";
                break;
            case "informal":
                value = "informal";
                break;
            }
            Preferences.settings.set_value("date-format", value);
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
