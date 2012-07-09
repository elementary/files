/*
 * Copyright (C) 2011 Marlin Developers
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
 *  Authors :   Lucas Baudin <xapantu@gmail.com>
 *              ammonkey <am.monkeyd@gmail.com>
 *
 */

using Granite.Widgets;

namespace Marlin.View
{
    public class SettingsDialog : Gtk.Dialog
    {
        Gtk.Scale spi_click_speed = new Gtk.Scale.with_range(Gtk.Orientation.HORIZONTAL, 1, 1000, 1);
        Gtk.Switch swi_click_speed = new Gtk.Switch ();
        
        public SettingsDialog(Window win)
        {
            set_title(_("Files Preferences"));
            set_resizable(false);
            
            /* Set proper spacing */
            get_content_area ().margin_left = 12;;
            get_content_area ().margin_right = 12;
            get_content_area ().margin_top = 12;
            get_content_area ().margin_bottom = 12;
            
            var mai_notebook = new Granite.Widgets.StaticNotebook();
            set_size_request (360, -1);
            
            // General
            var behavior = new Gtk.Label(_("General"));
            mai_notebook.append_page(get_general_box(), behavior);

            // Extensions
            var first_vbox = new Gtk.Box(Gtk.Orientation.VERTICAL, 3);
            
            var view = new Gtk.TreeView();
            
            Gdk.RGBA color = Gdk.RGBA();
            first_vbox.get_style_context ().get_background_color (Gtk.StateFlags.NORMAL);
            view.override_background_color (Gtk.StateFlags.NORMAL, color);

            var listmodel = new Gtk.ListStore (2, typeof (string), typeof (bool));
            view.set_model (listmodel);
            view.set_headers_visible (false);
            var column = new Gtk.TreeViewColumn();

            var text_renderer = new Gtk.CellRendererText();
            column.pack_start(text_renderer, true);
            column.set_attributes(text_renderer, "text", 0);
            var toggle = new Gtk.CellRendererToggle();
            toggle.toggled.connect_after ((toggle, path) => 
            {
                var tree_path = new Gtk.TreePath.from_string (path);
                Gtk.TreeIter iter;
                listmodel.get_iter (out iter, tree_path);
                var name = Value(typeof(string));
                var active = Value(typeof(bool));
                listmodel.get_value(iter, 0, out name);
                listmodel.get_value(iter, 1, out active);
                listmodel.set (iter, 1, !active.get_boolean());
                if(active.get_boolean() == false)
                {
                    enable_plugin(name.get_string());
                }
                else
                {
                    disable_plugin(name.get_string());
                }
            });
            column.pack_start(toggle, false);
            column.set_attributes(toggle, "active", 1);
            
            view.insert_column(column, -1);

            Gtk.TreeIter iter;

            foreach(var plugin_name in (plugins.get_available_plugins()))
            {
                listmodel.append (out iter);
                listmodel.set (iter, 0, plugin_name, 1, plugin_name in Preferences.settings.get_strv("plugins-enabled"));
            }

            first_vbox.pack_start(view);

            mai_notebook.append_page(first_vbox, new Gtk.Label(_("Extensions")));
            
            ((Gtk.Box)get_content_area()).pack_start(mai_notebook);

            this.show_all();

            add_buttons("gtk-close", Gtk.ResponseType.CLOSE);
        }
        
        void disable_plugin(string name)
        {
            if(!plugins.disable_plugin(name))
            {
                critical("Can't properly disable the plugin %s!", name);
            }
        }
        
        void add_option (Gtk.Grid grid, Gtk.Widget label, Gtk.Widget switcher, ref int row) {
            label.hexpand = true;
            label.halign = Gtk.Align.END;
            label.margin_left = 20;
            switcher.halign = Gtk.Align.FILL;
            switcher.hexpand = true;
            
            if (switcher is Gtk.Switch || switcher is Gtk.CheckButton
                || switcher is Gtk.Entry) { /* then we don't want it to be expanded */
                switcher.halign = Gtk.Align.START;
            }
            
            grid.attach (label, 0, row, 1, 1);
            grid.attach_next_to (switcher, label, Gtk.PositionType.RIGHT, 3, 1);
            row ++;
        }
        
        void enable_plugin(string name)
        {
            string[] plugs = new string[Preferences.settings.get_strv("plugins-enabled").length + 1];
            string[] current_plugins = Preferences.settings.get_strv("plugins-enabled");

            for(int i = 0; i < current_plugins.length; i++)
            {
                plugs[i] = current_plugins[i];
            }
            plugs[plugs.length - 1] = name;
            Preferences.settings.set_strv("plugins-enabled", plugs);

            plugins.load_plugin(name);
        }

        private void date_format_changed(Gtk.Widget widget)
        {
            int value = 2; /* informal */
            switch(((Gtk.Label)widget).get_text())
            {
            case "iso":
                value = 0;
                break;
            case "locale":
                value = 1;
                break;
            case "informal":
                value = 2;
                break;
            }
            Preferences.settings.set_enum ("date-format", value);
        }

        private void use_mouse_selection_toggle()
        {
            // Activate auto-selection
            if (swi_click_speed.active)
            {
                int value = Preferences.settings.get_int ("single-click-timeout-old");
                Preferences.settings.set_int ("single-click-timeout", value);
            // Deactivate auto-selection
            }else{
                int value = Preferences.settings.get_int ("single-click-timeout");
                Preferences.settings.set_int ("single-click-timeout-old", value);
                Preferences.settings.set_int ("single-click-timeout", 0);
            }
        }

        public override void response(int id)
        {
            switch(id)
            {
            case Gtk.ResponseType.CLOSE:
                destroy();
                break;
            }
        }

        private Gtk.Widget get_general_box()
        {
            var grid = new Gtk.Grid();
            grid.row_spacing = 5;
            grid.column_spacing = 5;
            grid.margin_left = 15;
            grid.margin_right = 5;
            grid.margin_top = 15;
            grid.margin_bottom = 15;
            
            int row = 0;

            // Single click
            var label = new Gtk.Label(_("Single click to open:"));
            var checkbox = new Gtk.Switch();
            Preferences.settings.bind("single-click", checkbox , "active", SettingsBindFlags.DEFAULT);

            add_option(grid, label, checkbox, ref row);
            
            // Mouse selection speed
            label = new Gtk.Label(_("Mouse auto-selection speed:"));
            spi_click_speed.sensitive = swi_click_speed.active;
            spi_click_speed.set_draw_value (false);

            swi_click_speed.notify["active"].connect (use_mouse_selection_toggle);
            
            Preferences.settings.bind("single-click-timeout", spi_click_speed.get_adjustment(),
                                      "value", SettingsBindFlags.DEFAULT);

            Preferences.settings.bind ("single-click-timeout-enabled", swi_click_speed,
                                       "active", SettingsBindFlags.DEFAULT);
            Preferences.settings.bind ("single-click-timeout-enabled", spi_click_speed,
                                       "sensitive", SettingsBindFlags.DEFAULT);
            
            Preferences.settings.bind ("single-click-timeout-enabled", label,
                                       "sensitive", SettingsBindFlags.DEFAULT);

            var hbox = new Gtk.HBox(false, 0);
            
            Gtk.Label slow = new Gtk.Label(_("Slow"));
            Gtk.Label fast = new Gtk.Label(_("Fast"));
            
            hbox.pack_start (swi_click_speed, false, false, 0);
            hbox.pack_start (slow, false, false, 0);
            hbox.pack_start (spi_click_speed, true, true, 0);
            hbox.pack_start (fast, false, false, 0);
            
            add_option(grid, label, hbox, ref row);
            
            // Date format
            label = new Gtk.Label(_("Date format:"));

            var mode_date_format = new ModeButton();
            mode_date_format.append(new Gtk.Label(_("iso")));
            mode_date_format.append(new Gtk.Label(_("locale")));
            mode_date_format.append(new Gtk.Label(_("informal")));
            mode_date_format.selected = (int)Preferences.settings.get_enum ("date-format");

            mode_date_format.mode_changed.connect(date_format_changed);

            add_option(grid, label, mode_date_format, ref row);
            
            return grid;
        }
    }
}
