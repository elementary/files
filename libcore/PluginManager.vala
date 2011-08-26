/*
 * Copyright (C) 2011 Lucas Baudin <xapantu@gmail.com>
 *
 * Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org> (from Rygel)
 *
 * This file is part of Marlin.
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

public class Marlin.PluginManager : GLib.Object
{
    delegate Plugins.Base ModuleInitFunc ();
    Gee.HashMap<string,Plugins.Base> plugin_hash;
    public PluginManager()
    {
        plugin_hash = new Gee.HashMap<string,Plugins.Base>();
    }
    
    public void load_plugins()
    {
        load_modules_from_dir("/usr/local/lib/marlin/gioplugins/");
    } 
    
    private async void load_modules_from_dir (string path)
    {
        File dir = File.new_for_path(path);

        string attributes = FILE_ATTRIBUTE_STANDARD_NAME + "," +
                            FILE_ATTRIBUTE_STANDARD_TYPE + "," +
                            FILE_ATTRIBUTE_STANDARD_CONTENT_TYPE;

        GLib.List<FileInfo> infos;
        FileEnumerator enumerator;

        try
        {
            enumerator = yield dir.enumerate_children_async
                                        (attributes,
                                         FileQueryInfoFlags.NONE,
                                         Priority.DEFAULT,
                                         null);

            infos = yield enumerator.next_files_async (int.MAX,
                                                       Priority.DEFAULT,
                                                       null);
        }
        catch(Error error)
        {
            critical ("Error listing contents of folder '%s': %s",
                      dir.get_path (),
                      error.message);

            return;
        }

        foreach(var info in infos)
        {
            string file_name = info.get_name ();
            string file_path = Path.build_filename (dir.get_path (), file_name);

            File file = File.new_for_path (file_path);

            if(file_name.has_suffix(".plug"))
            {
                print("%s\n", file_name);
                load_plugin_keyfile(file_path, dir.get_path ());
            }
        }
    }

    Plugins.Base load_module(string file_path)
    {
        Module? module = Module.open (file_path, ModuleFlags.BIND_LOCAL);
        if (module == null)
        {
            warning ("Failed to load module from path '%s': %s",
                     file_path,
                     Module.error ());

            return null;
        }

        void* function;

        if (!module.symbol("module_init", out function)) {
            warning ("Failed to find entry point function '%s' in '%s': %s",
                     "module_init",
                     file_path,
                     Module.error ());

            return null;
        }

        unowned ModuleInitFunc module_init = (ModuleInitFunc) function;
        assert (module_init != null);

        debug ("Loaded module source: '%s'", module.name());

        Plugins.Base base_ = module_init();
        assert(base_ != null);
        return base_;
    }
    
    void load_plugin_keyfile(string path, string parent)
    {
        var keyfile = new KeyFile();
        try
        {
            keyfile.load_from_file(path, KeyFileFlags.NONE);
            string name = keyfile.get_string("Plugin", "Name");
            Plugins.Base plug = load_module(Path.build_filename(parent, keyfile.get_string("Plugin", "File")));
            if(plug != null)
            {
                plugin_hash[name] = plug;
                plug.interface_loaded(null);
            }
        }
        catch(Error e)
        {
            warning("Couldn't open thie keyfile: %s, %s", path, e.message);
        }
    }
    
    public void hook_context_menu(Gtk.Widget win)
    {
    }
    
    public void directory_loaded(void* path)
    {
    }
    
    public void interface_loaded(Gtk.Widget win)
    {
    }
    
    public void hook_send(void* user_data, int hook)
    {
    }
    
    public void add_plugin(string path)
    {
    }
    
    public void load_plugin(string path)
    {
    }
    
    public static List<string> get_available_plugins()
    {
        return new List<string>();
    }
    
    public bool disable_plugin(string path)
    {
        return false;
    }
}