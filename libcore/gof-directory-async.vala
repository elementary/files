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

    private Cancellable cancellable;
    private bool show_hidden_files = false;


    public uint files_count = 0;

    /* signals */
    public signal void file_loaded (GOF.File file);
    public signal void file_added (GOF.File file);
    public signal void file_changed (GOF.File file);
    public signal void file_deleted (GOF.File file);
    public signal void done_loading ();
    public signal void info_available ();

    private unowned string gio_default_attributes = "standard::is-hidden,standard::is-backup,standard::is-symlink,standard::type,standard::name,standard::display-name,standard::fast-content-type,standard::size,standard::symlink-target,access::*,time::*,owner::*,trash::*,unix::*,id::filesystem,thumbnail::*";

    public Async (GLib.File _file)
    {
        location = _file;
        file = GOF.File.get (location);
        file.exists = true;
        cancellable = new Cancellable ();

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
        } else {
            /* even if the directory is currently loading model_add_file manage duplicates */
            warning ("directory %s load cached files", file.uri);
            foreach (GOF.File gof in file_hash.get_values ())
                file_loaded (gof);
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
            var e = yield directory.enumerate_children_async (gio_default_attributes, FileQueryInfoFlags.NOFOLLOW_SYMLINKS, 0, cancellable);
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

                    if (!gof.is_hidden) {
                        if (file_hash != null)
                            file_hash.insert (loc, gof);
                        file_loaded (gof);
                    } else {
                        if (hidden_file_hash != null)
                            hidden_file_hash.insert (loc, gof);
                        if (show_hidden_files)
                            file_loaded (gof);
                    }

                    //mutex.lock ();
                    files_count++;
                    //mutex.unlock ();
                }
            }
        } catch (Error err) {
            warning ("%s %s", err.message, file.uri);
            if (err is IOError.NOT_FOUND || err is IOError.NOT_DIRECTORY)
                file.exists = false;
        }

        state = State.LOADED;
        //TODO send err code
        done_loading ();
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
    
    public static Async cache_lookup (GLib.File *file)
    {
        Async cached_dir;

        if (directory_cache == null) {
            directory_cache = new HashTable<GLib.File,GOF.Directory.Async> (GLib.file_hash, GLib.file_equal);
        }
        //return directory_cache.lookup (file);
        //return null;
        
        cached_dir = directory_cache.lookup (file);
        if (cached_dir != null)
            debug ("found cached dir %s", cached_dir.file.uri);

        return cached_dir;
    }
    
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

        if (state == State.LOADED && file_hash_count == 0 && hidden_file_hash_count == 0)
            return true;

        return false;
    }
}

