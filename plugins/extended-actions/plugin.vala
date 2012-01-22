/*
 * Authors:
 *      Lucas Baudin <xapantu@gmail.com>
 *      ammonkey <am.monkeyd@gmail.com>
 *      
 * Copyright (C) Lucas Baudin 2011 <xapantu@gmail.com>
 * 
 * Marlin is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the
 * Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * Marlin is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;
using Gee;

[DBus (name = "org.magma.ExtendedActions")]
public interface ExtendedActionsService : Object
{
    //public abstract GLib.HashTable<string,string>[] GetServicesByMime (string mime) throws IOError;
    public abstract GLib.HashTable<string,string>[] GetServicesByLocation (string strlocation, string? file_mime="")    throws IOError;
    public abstract GLib.HashTable<string,string>[] GetServicesByLocationsList (GLib.HashTable<string, string>[] locations)  throws IOError;
}

public class Marlin.Plugins.ExtendedActions : Marlin.Plugins.Base
{
    UIManager ui_manager;
    Gtk.Menu menu;
    GOF.File current_directory = null;
    unowned GLib.List<GOF.File> selection;
    GLib.HashTable<string,string>[] services = null;
    
    private ExtendedActionsService service_eactions;
    
    public ExtendedActions ()
    {
        try {
            service_eactions = Bus.get_proxy_sync (BusType.SESSION,
                                                   "org.magma.ExtendedActions",
                                                   "/org/magma/ExtendedActions");
        } catch (IOError e) {
            stderr.printf ("%s\n", e.message);
        }
    }

    private string get_app_display_name (GLib.HashTable<string,string> app__)
    {
        return app__.lookup ("Description");
    }

    private GLib.HashTable<string,string> add_location_entry (GOF.File file)
    {
        GLib.HashTable<string,string> entry;
                
        entry = new GLib.HashTable<string,string> (str_hash, str_equal);
        entry.insert ("uri", file.uri);
        var ftype = file.get_ftype ();
        if (ftype == "application/octet-stream" || ftype == null)
            entry.insert ("mimetype", "");
        else
            entry.insert ("mimetype", ftype);

        return entry;
    }

    private GLib.HashTable<string, string>[] build_hash_from_list_selection ()
    {
        GLib.HashTable<string,string>[] locations = null;

        foreach (GOF.File file in selection) {
            if (file != null)
                locations += add_location_entry (file);
            //message ("file %s", file.name);
        }
        if (selection == null && current_directory != null) {
            locations += add_location_entry (current_directory);
        }

        return locations;
    }

    public void action_activated ()
    {
        Gtk.MenuItem menuitem;
        GLib.HashTable<string,string> app__;
                
        menuitem = (Gtk.MenuItem) menu.get_active ();
        app__ = menuitem.get_data<GLib.HashTable<string,string>> ("app");

        if (app__ != null) {
            var cmd = app__.lookup ("Exec");
            //message ("test exec %s", cmd);
            try {
                GLib.Process.spawn_command_line_async (cmd);
            } catch (SpawnError e) {
                stderr.printf ("error spawn command line %s: %s", cmd, e.message);
            }
        }
    }

    public override void context_menu (Gtk.Widget? widget)
    {
        menu = widget as Gtk.Menu;
        
        try {
            services = service_eactions.GetServicesByLocationsList (build_hash_from_list_selection ());
        
            uint i = 0;
            foreach(var app__ in services)
            {
                /* insert separator if we got at least 1 action */
                if (i == 0) {
                    var item = new Gtk.SeparatorMenuItem ();
                    menu.append (item);
                    item.show ();
                    plugins.menus.prepend (item);
                }
                var menuitem = new Gtk.MenuItem.with_label(get_app_display_name(app__));
                menu.append (menuitem);
                menuitem.set_data<GLib.HashTable<string,string>> ("app", app__);
                menuitem.show ();
                menuitem.activate.connect (action_activated);
                plugins.menus.prepend (menuitem);
                i++;
            }
        } catch (IOError e) {
            stderr.printf ("%s\n", e.message);
        }
    }

    public override void ui (Gtk.UIManager? widget)
    {
        ui_manager = widget;
        menu = (Gtk.Menu)ui_manager.get_widget("/selection");
    }
    
    public override void file (GLib.List<Object> files)
    {
        selection = (GLib.List<GOF.File>) files;
    }

    public override void directory_loaded (void* user_data)
    {
        current_directory = ((Object[])user_data)[2] as GOF.File;
    }
}

public Marlin.Plugins.Base module_init ()
{
    return new Marlin.Plugins.ExtendedActions ();
}

