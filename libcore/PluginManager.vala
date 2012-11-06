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

public static Marlin.PluginManager plugins;

public class Marlin.PluginManager : GLib.Object
{
    delegate Plugins.Base ModuleInitFunc ();
    Gee.HashMap<string,Plugins.Base> plugin_hash;
    Settings settings;
    string settings_field;
    string plugin_dir;
    Gee.List<string> names;
    bool in_available = false;
    public GLib.List<Gtk.Widget>? menus;

    public PluginManager(Settings settings, string field, string plugin_dir)
    {
        settings_field = field;
        this.settings = settings;
        this.plugin_dir = plugin_dir;
        plugin_hash = new Gee.HashMap<string,Plugins.Base>();
        names = new Gee.ArrayList<string>();
    }
    
    public void load_plugins()
    {
        load_modules_from_dir(plugin_dir + "/core/", true);
        in_available = true;
        load_modules_from_dir(plugin_dir);
        in_available = false;
    } 
    
    private void load_modules_from_dir (string path, bool force = false)
    {
        File dir = File.new_for_path(path);

        string attributes = FileAttribute.STANDARD_NAME + "," +
                            FileAttribute.STANDARD_TYPE;

        FileInfo info;
        FileEnumerator enumerator;

        try
        {
            enumerator = dir.enumerate_children
                                        (attributes,
                                         FileQueryInfoFlags.NONE);

            info = enumerator.next_file ();
        
            while(info != null)
            {
                string file_name = info.get_name ();
                string file_path = Path.build_filename (dir.get_path (), file_name);

                if(file_name.has_suffix(".plug"))
                {
                    load_plugin_keyfile(file_path, dir.get_path (), force);
                }
                info = enumerator.next_file ();
            }
        }
        catch(Error error)
        {
            critical ("Error listing contents of folder '%s': %s",
                      dir.get_path (),
                      error.message);

        }
    }

    void load_module(string file_path)
    {
        Module module = Module.open (file_path, ModuleFlags.BIND_LOCAL);
        if (module == null)
        {
            warning ("Failed to load module from path '%s': %s",
                     file_path,
                     Module.error ());
            return;
        }

        void* function;

        if (!module.symbol("module_init", out function)) {
            warning ("Failed to find entry point function '%s' in '%s': %s",
                     "module_init",
                     file_path,
                     Module.error ());
            return;
        }

        unowned ModuleInitFunc module_init = (ModuleInitFunc) function;
        assert (module_init != null);

        /* We don't want our modules to ever unload */
        module.make_resident ();
        Plugins.Base plug = module_init();

        debug ("Loaded module source: '%s'", module.name());
        //message ("Loaded module source: '%s'", module.name());
        
        if(plug != null)
            plugin_hash.set (file_path, plug);
    }
    
    void load_plugin_keyfile(string path, string parent, bool force)
    {
        var keyfile = new KeyFile();
        try
        {
            keyfile.load_from_file(path, KeyFileFlags.NONE);
            string name = keyfile.get_string("Plugin", "Name");
            if(in_available)
            {
                names.add(name);
            }
            if(force || name in settings.get_strv(settings_field))
            {
                load_module(Path.build_filename(parent, keyfile.get_string("Plugin", "File")));
            }
        }
        catch(Error e)
        {
            warning("Couldn't open thie keyfile: %s, %s", path, e.message);
        }
    }
    
    public void hook_context_menu(Gtk.Widget menu, List<GOF.File> files)
    {
        foreach (var item in menus)
            item.destroy ();
        menus = null;
        foreach(var plugin in plugin_hash.values) plugin.context_menu (menu, files);
    }
    
    public void ui(Gtk.UIManager data)
    {
        foreach(var plugin in plugin_hash.values) plugin.ui(data);
    }
    
    public void directory_loaded(void* path)
    {
        foreach(var plugin in plugin_hash.values) plugin.directory_loaded(path);
    }
    
    public void interface_loaded(Gtk.Widget win)
    {
        foreach(var plugin in plugin_hash.values) plugin.interface_loaded(win);
    }
    
    public void update_sidebar(Gtk.Widget win)
    {
        foreach(var plugin in plugin_hash.values) plugin.update_sidebar(win);
    }
    
    public void update_file_info(GOF.File file)
    {
        foreach(var plugin in plugin_hash.values) 
            /*Idle.add (() => {*/
                plugin.update_file_info(file);
                /*return false;
            });*/
    }

    public void add_plugin(string path)
    {
    }
    
    public void load_plugin(string path)
    {
    }
    
    public Gee.List<string> get_available_plugins()
    {
        return names;
    }
    
    public bool disable_plugin(string path)
    {
        string[] plugs = settings.get_strv(settings_field);
        string[] plugs_ = new string[plugs.length - 1];
        bool found = false;
        int i = 0;
        foreach(var name in plugs)
        {
            if(name != path)
            {
                plugs[i] = name;
            }
            else found = true;
            i++;
        }
        if(found) settings.set_strv(settings_field, plugs_);
        return found;
    }
}
