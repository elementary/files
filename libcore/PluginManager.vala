/***
    Copyright (C) 2011 Lucas Baudin <xapantu@gmail.com>

    Author: Zeeshan Ali (Khattak) <zeeshanak@gnome.org> (from Rygel)

    This file is part of Files.

    Marlin is free software: you can redistribute it and/or modify it
    under the terms of the GNU General Public License as published by the
    Free Software Foundation, Inc.,, either version 3 of the License, or
    (at your option) any later version.

    Marlin is distributed in the hope that it will be useful, but
    WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
    See the GNU General Public License for more details.

    You should have received a copy of the GNU General Public License along
    with this program.  If not, see <http://www.gnu.org/licenses/>.
***/

public static Files.PluginManager plugins;

public class Files.PluginManager : Object {

    delegate Plugins.Base ModuleInitFunc ();
    Gee.HashMap<string,Plugins.Base> plugin_hash;
    Gee.List<string> names;
    bool in_available = false;
    bool update_queued = false;
    bool is_admin = false;

    [Version (deprecated = true, deprecated_since = "0.2", replacement = "Files.PluginManager.menuitem_references")]
    public GLib.List<Gtk.Widget>? menus; /* this doesn't manage GObject references properly */

    public Gee.List<Gtk.Widget> menuitem_references { get; private set; }

    private string[] plugin_dirs;

    public PluginManager (string plugin_dir, uint user_id) {
        is_admin = (user_id == 0);
        plugin_hash = new Gee.HashMap<string,Plugins.Base> ();
        names = new Gee.ArrayList<string> ();
        menuitem_references = new Gee.LinkedList<Gtk.Widget> ();
        plugin_dirs = new string[0];

        if (!is_admin) {
            plugin_dirs += Path.build_filename (plugin_dir, "gtk4");
            plugin_dirs += plugin_dir;

            load_plugins ();

            /* Monitor plugin dirs */
            foreach (string path in plugin_dirs) {
                set_directory_monitor (path);
            }
        }
    }

    private void load_plugins () {
        load_modules_from_dir (plugin_dirs[0]);
        in_available = true;
        load_modules_from_dir (plugin_dirs[1]);
        in_available = false;
    }

    private void set_directory_monitor (string path) {
        var dir = GLib.File.new_for_path (path);

        try {
            var monitor = dir.monitor_directory (FileMonitorFlags.NONE, null);
            monitor.changed.connect (on_plugin_directory_change);
            monitor.ref (); /* keep alive */
        } catch (IOError e) {
            critical ("Could not setup monitor for '%s': %s", dir.get_path (), e.message);
        }
    }

    private async void on_plugin_directory_change (GLib.File file, GLib.File? other_file, FileMonitorEvent event) {
        if (update_queued) {
            return;
        }

        update_queued = true;

        Idle.add_full (Priority.LOW, on_plugin_directory_change.callback);
        yield;

        load_plugins ();
        update_queued = false;
    }

    private void load_modules_from_dir (string path) {
        string attributes = FileAttribute.STANDARD_NAME + "," +
                            FileAttribute.STANDARD_TYPE;

        FileInfo info;
        FileEnumerator enumerator;

        try {
            var dir = GLib.File.new_for_path (path);

            enumerator = dir.enumerate_children
                                        (attributes,
                                         FileQueryInfoFlags.NONE);

            info = enumerator.next_file ();

            while (info != null) {
                string file_name = info.get_name ();
                var plugin_file = dir.get_child_for_display_name (file_name);

                if (file_name.has_suffix (".plug")) {
                    load_plugin_keyfile (plugin_file.get_path (), path);
                }

                info = enumerator.next_file ();
            }
        } catch (Error error) {
            critical ("Error listing contents of folder '%s': %s", path, error.message);
        }
    }

    void load_module (string file_path, string name) {
        if (plugin_hash.has_key (file_path)) {
            debug ("plugin for %s already loaded. Not adding again", file_path);
            return;
        }

        debug ("Loading plugin for %s", file_path);

        Module module = Module.open (file_path, ModuleFlags.LOCAL);
        if (module == null) {
            warning ("Failed to load module from path '%s': %s",
                     file_path,
                     Module.error ());
            return;
        }

        void* function;

        if (!module.symbol ("module_init", out function)) {
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
        Plugins.Base plug = module_init ();

        debug ("Loaded module source: '%s'", module.name ());

        if (plug != null) {
            plugin_hash.set (file_path, plug);
        }

        if (in_available) {
            names.add (name);
        }
    }

    void load_plugin_keyfile (string path, string parent) {
        var keyfile = new KeyFile ();
        try {
            keyfile.load_from_file (path, KeyFileFlags.NONE);
            string name = keyfile.get_string ("Plugin", "Name");

            load_module (Path.build_filename (parent, keyfile.get_string ("Plugin", "File")), name);
        } catch (Error e) {
            warning ("Couldn't open the keyfile '%s': %s", path, e.message);
        }
    }

    public void hook_context_menu (Gtk.PopoverMenu menu, List<Files.File> files) {
        // drop_menu_references (menu);

        // if (menu is Gtk.Menu) {
        //     drop_plugin_menuitems ();
        // }

        foreach (var plugin in plugin_hash.values) {
            plugin.context_menu (menu, files);
        }
    }

    // private void drop_plugin_menuitems () {
    //     foreach (var menu_item in menuitem_references) {
    //         menu_item.unparent ();
    //     }

    //     menuitem_references.clear ();
    // }

    // [Version (deprecated = true, deprecated_since = "0.2", replacement = "Files.PluginManager.drop_plugin_menuitems")]
    // private void drop_menu_references (Gtk.Widget menu) {
    //     if (menus == null) {
    //         return;
    //     }

    //     foreach (var item in menus) {
    //         item.destroy ();
    //     }

    //     menus = null;
    // }

    public void directory_loaded (Files.SlotContainerInterface multi_slot, Files.File directory) {
        foreach (var plugin in plugin_hash.values) {
            plugin.directory_loaded (multi_slot, directory);
        }
    }

    public void interface_loaded (Gtk.Widget win) {
        foreach (var plugin in plugin_hash.values) {
            plugin.interface_loaded (win);
        }
    }

    public void sidebar_loaded (Gtk.Widget widget) {
        foreach (var plugin in plugin_hash.values) {
            plugin.sidebar_loaded (widget);
        }
    }

    public void update_sidebar (Gtk.Widget widget) {
        foreach (var plugin in plugin_hash.values) {
            plugin.update_sidebar (widget);
        }
    }

    public void update_file_info (Files.File file) {
        foreach (var plugin in plugin_hash.values) {
            plugin.update_file_info (file);
        }
    }

    public Gee.List<string> get_available_plugins () {
        return names;
    }
}
