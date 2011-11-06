/*  
 * Copyright (C) 2011 Elementary Developers
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * Author: ammonkey <am.monkeyd@gmail.com>
 */

using GLib;

//HashTable<GLib.File,GOF.Directory.Async> directory_cache;
extern HashTable<GLib.File,GOF.Directory.Async> directory_cache;
/*  Mutex mutex = new Mutex ();*/

public class GOF.Directory.Async : Object
{
    public GLib.File location;
    public GOF.File file;
    
    public enum State {
        NOT_LOADED,
        LOADING,
        LOADED
    }
    public State state = State.NOT_LOADED;

    public HashTable<GLib.File,GOF.File> file_hash;
    public HashTable<GLib.File,GOF.File> hidden_file_hash;
    
    public bool show_hidden_files = false;
    public uint files_count = 0;

    private Cancellable cancellable;
    private FileMonitor monitor = null;

    /* signals */
    public signal void file_loaded (GOF.File file);
    public signal void file_added (GOF.File file);
    public signal void file_changed (GOF.File file);
    public signal void file_deleted (GOF.File file);
    public signal void done_loading ();

    private unowned string gio_default_attributes = "standard::is-hidden,standard::is-backup,standard::is-symlink,standard::type,standard::name,standard::display-name,standard::fast-content-type,standard::size,standard::symlink-target,access::*,time::*,owner::*,trash::*,unix::*,id::filesystem,thumbnail::*";

    public Async (GLib.File _file)
    {
        location = _file;
        file = GOF.File.get (location);
        file.exists = true;
        cancellable = new Cancellable ();
        
        query_info_async (file, file_info_available);

        if (directory_cache != null)
           directory_cache.insert (location, this);

        file_hash = new HashTable<GLib.File,GOF.File> (GLib.file_hash, GLib.file_equal);
        hidden_file_hash = new HashTable<GLib.File,GOF.File> (GLib.file_hash, file_equal);

        //list_directory (location);
    }

    public void cancel ()
    {
        cancellable.cancel ();
        cancellable.reset ();
    }

    public bool load ()
    {
        if (state == State.NOT_LOADED) {
            list_directory (location);
            try {
                monitor = location.monitor_directory (0);
            } catch (IOError e) {
                error ("directory monitor failed: %s %s", e.message, file.uri);
            }
            monitor.changed.connect (directory_changed);        
        } else {
            /* even if the directory is currently loading model_add_file manage duplicates */
            debug ("directory %s load cached files", file.uri);
            /* send again the info_available signal for reused directories */
            if (file.info != null)
                file.info_available ();
            foreach (GOF.File gof in file_hash.get_values ())
                file_loaded (gof);
            if (show_hidden_files)
                foreach (GOF.File gof in hidden_file_hash.get_values ())
                    file_loaded (gof);
            done_loading ();
        }

        //FIXME
        return true; 
    }

    //private Mutex mutex = new Mutex ();

    private async void list_directory (GLib.File directory)
    {
        file.exists = true;
        files_count = 0;
        state = State.LOADING;

        debug ("list directory %s", file.uri);
        try {
            //var e = yield directory.enumerate_children_async (gio_default_attributes, FileQueryInfoFlags.NOFOLLOW_SYMLINKS, 0, cancellable);
            var e = yield directory.enumerate_children_async (gio_default_attributes, 0, 0, cancellable);
            while (true) {
                var files = yield e.next_files_async (200, 0, cancellable);
                if (files == null)
                    break;

                foreach (var file_info in files)
                {
                    GLib.File loc = location.get_child ((string) file_info.get_name());
                    //GOF.File gof;
                    GOF.File gof = GOF.File.cache_lookup (loc);
                    if (gof == null)
                        gof = new GOF.File (loc, location);

                    gof.info = file_info;
                    gof.update ();
                    //debug ("file: %s", gof.name);

                    add_to_hash_cache (gof);
                    if (!gof.is_hidden) {
                        file_loaded (gof);
                    } else {
                        if (show_hidden_files)
                            file_loaded (gof);
                    }

                    //mutex.lock ();
                    files_count++;
                    //mutex.unlock ();
                }
            }
            state = State.LOADED;
        } catch (Error err) {
            warning ("%s %s", err.message, file.uri);
            if (err is IOError.NOT_FOUND || err is IOError.NOT_DIRECTORY)
                file.exists = false;
            if (err is IOError.NOT_MOUNTED)
                file.is_mounted = false;
            state = State.NOT_LOADED;
        }

        //TODO send err code
        done_loading ();
    }

    private void add_to_hash_cache (GOF.File gof) {
        if (!gof.is_hidden) {
            if (file_hash != null)
                file_hash.insert (gof.location, gof);
        } else {
            if (hidden_file_hash != null)
                hidden_file_hash.insert (gof.location, gof);
        }
    }

    /* TODO move this to GOF.File */
    private delegate void func_query_info (GOF.File gof);

    private async void query_info_async (GOF.File gof, func_query_info? f = null) {
        try {
            gof.info = yield gof.location.query_info_async (gio_default_attributes, 
                                                            FileQueryInfoFlags.NONE, 
                                                            Priority.DEFAULT);
            if (f != null)
                f (gof);
        } catch (Error err) {
            warning ("query info failed, %s %s", err.message, gof.uri);
            if (err is IOError.NOT_FOUND)
                gof.exists = false;
        }
    }

    private void changed_and_refresh (GOF.File gof) {
        gof.update ();
        file_changed (gof);
    }

    private void add_and_refresh (GOF.File gof) {
        if (gof.info == null)
            critical ("FILE INFO null");
        gof.update ();
        add_to_hash_cache (gof);
        file_added (gof);
    }
    
    private void file_info_available (GOF.File gof) {
        gof.update ();
        gof.info_available ();
    }

    private void directory_changed (GLib.File _file, GLib.File? other_file, FileMonitorEvent event)
    {
        GOF.File gof = GOF.File.get (_file);

        switch (event) {
        case FileMonitorEvent.ATTRIBUTE_CHANGED:
        case FileMonitorEvent.CHANGES_DONE_HINT:
            //message ("file changed %s", gof.uri);
            query_info_async (gof, changed_and_refresh);
            break;
        case FileMonitorEvent.DELETED:
            //message ("file deleted %s", gof.uri);
            file_deleted (gof);
            gof.remove_from_caches ();
            break;
        case FileMonitorEvent.CREATED:
            //message ("file added %s", gof.uri);
            query_info_async (gof, add_and_refresh);
            break;            
        }
    }

    public static Async from_gfile (GLib.File file)
    {
        Async dir;

        dir = cache_lookup (file);
        if (dir == null)
            dir = new Async (file);

        return dir;
    }

    public static Async from_file (GOF.File gof)
    {
        return from_gfile (gof.location);
    }
    
    public static Async? cache_lookup (GLib.File *file)
    {
        Async? cached_dir = null;

        if (directory_cache == null) {
            directory_cache = new HashTable<GLib.File,GOF.Directory.Async> (GLib.file_hash, GLib.file_equal);
        }
       
        if (directory_cache != null)
            cached_dir = directory_cache.lookup (file);
        if (cached_dir != null)
            debug ("found cached dir %s", cached_dir.file.uri);

        return cached_dir;
    }

    public bool remove_from_cache (GOF.File gof)
    {
        bool val = false;

        if (!gof.is_hidden) {
            if (file_hash != null)
                val = file_hash.remove (gof.location);
        } else {
            if (hidden_file_hash != null)
                val = hidden_file_hash.remove (gof.location);
        }

        return val;
    }

    /*public bool remove_directory_from_cache ()
    {
        return directory_cache.remove (location);
    }*/
    
    public bool has_parent ()
    {
        return (file.directory != null);
    }
    
    public GLib.File get_parent ()
    {
        return file.directory;
    }

    public bool is_empty ()
    {
        uint file_hash_count = 0;
        uint hidden_file_hash_count = 0;

        if (file_hash != null)
            file_hash_count = file_hash.size ();
        if (hidden_file_hash != null)
            hidden_file_hash_count = hidden_file_hash.size ();

        //debug ("is_empty hash sizes file: %u  hidden: %u", file_hash_count, hidden_file_hash_count);
        if (state == State.LOADED && file_hash_count == 0 && hidden_file_hash_count == 0)
            return true;

        return false;
    }
}

