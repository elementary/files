/*
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


public void receive_all_hook(void* user_data, int hook)
{
    switch(hook)
    {
    case 1:
        /* context menu */
        break;
    case 2: /* ui */
        break;
    case 5:
        break;
    case 7:
        break;
    default:
        print("Contractor doesn't know this hook: %d\n", hook);
        break;
    }
}
public class Marlin.Plugins.Contractor : Marlin.Plugins.Base
{
    ArrayList<MenuItem>? menus = null;
    UIManager ui_manager;
    Menu menu;
    /*string uri;*/
    GLib.HashTable<string, string>[] locations;
    public Contractor()
    {
    }

    string get_app_display_name(GLib.HashTable<string,string> app__)
    {
        return app__.lookup("Description");
    }

    void print_apps(Menu menu)
    {
        /*if (menu != _menu)
            return;*/
        if (menus == null)
            menus = new ArrayList<MenuItem>();
        foreach(var _menu in menus)
        {
            _menu.destroy();
        }
        menus.clear();
        var cont = new Contracts();
      
        uint i = 0;
        foreach(var app__ in cont.get_selection_contracts(locations))
        {
            /* insert separator if we got at least 1 contract */
            if (i == 0) {
                var item = new SeparatorMenuItem ();
                menu.append(item);
                item.show();
                menus.add(item);
            }
            var menuitem = new MenuItem.with_label(get_app_display_name(app__));
            menu.append(menuitem);
            menuitem.show();
            menuitem.activate.connect(contract_activated);
            menus.add(menuitem);
            i++;
        }
    }

    private GLib.HashTable<string,string> add_location_entry (GOF.File file)
    {
        GLib.HashTable<string,string> entry;
                
        entry = new GLib.HashTable<string,string> (str_hash, str_equal);
        entry.insert ("uri", file.uri);
        if (file.ftype == "application/octet-stream")
            entry.insert ("mimetype", "");
        else
            entry.insert ("mimetype", file.ftype);

        return entry;
    }

    private GLib.HashTable<string, string>[] build_hash_from_list (GLib.List<GOF.File> selection)
    {
        GLib.HashTable<string,string>[] locations = null;

        foreach (GOF.File file in selection) {
            if (file != null)
                locations += add_location_entry (file);
            //message ("file %s", file.name);
        }

        return locations;
    }

    public void contract_activated()
    {
        MenuItem menuitem = (MenuItem)menu.get_active();
        string app_menu = menuitem.get_label();
        print(app_menu + "\n");
        var cont = new Contracts();
        
        foreach(var app__ in cont.get_selection_contracts(locations))
        {
            if(app_menu == get_app_display_name(app__))
            {
                var cmd = app__.lookup("Exec");
                try {
                    GLib.Process.spawn_command_line_async(cmd);
                } catch (SpawnError e) {
                    stderr.printf ("error spawn command line %s: %s", cmd, e.message);
                }

                break;
            }
        }
    }

    public override void context_menu(Gtk.Widget? widget)
    {
        print_apps(widget as Menu);
    }
    public override void ui(Gtk.UIManager? widget)
    {
        ui_manager = widget;
        menu = (Menu)ui_manager.get_widget("/selection");
    }
    public override void file(GLib.List<Object> files)
    {
        if(files != null)
        {
            unowned GLib.List<GOF.File> selection = (GLib.List<GOF.File>) files;
            locations = build_hash_from_list (selection);
        }
    }
}

public Marlin.Plugins.Base module_init()
{
    return new Marlin.Plugins.Contractor();
}

[DBus (name = "org.elementary.contractor")]
public interface Contractor : Object
{
    //public abstract GLib.HashTable<string,string>[] GetServicesByMime (string mime) throws IOError;
    public abstract GLib.HashTable<string,string>[] GetServicesByLocation (string strlocation, string? file_mime="")    throws IOError;
    public abstract GLib.HashTable<string,string>[] GetServicesByLocationsList (GLib.HashTable<string,string>[] locations)  throws IOError;
}

public class Contracts : Object
{

    private Contractor contract;

    public Contracts()
    {
        try
        {
            contract = Bus.get_proxy_sync (BusType.SESSION,
                                           "org.elementary.contractor",
                                           "/org/elementary/contractor");
        }
        catch (IOError e)
        {
            stderr.printf ("%s\n", e.message);
        }
    }

    public GLib.HashTable<string,string>[] get_contract(string uri, string mime)
    {
        GLib.HashTable<string,string>[] contracts = null;

        try {
            contracts = contract.GetServicesByLocation(uri, mime);
        }catch (IOError e) {
            stderr.printf ("%s\n", e.message);
        }

        return contracts;
    }

    public GLib.HashTable<string,string>[] get_selection_contracts (GLib.HashTable<string, string>[] locations)
    {
        GLib.HashTable<string,string>[] contracts = null;

        try {
            contracts = contract.GetServicesByLocationsList (locations);
        }catch (IOError e) {
            stderr.printf ("%s\n", e.message);
        }
        
        return contracts;
    }
}
