/*  
 * Copyright (C) 2011 Marlin Developers
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

public HashTable<GLib.File,GOF.Directory.Async> directory_cache;
//extern HashTable<GLib.File,GOF.Directory.Async> directory_cache;
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
    
    public uint files_count = 0;

    private Cancellable cancellable;
    private FileMonitor? monitor = null;
    
    private List<GOF.File>? sorted_dirs = null;

    /* signals */
    public signal void file_loaded (GOF.File file);
    public signal void file_added (GOF.File file);
    public signal void file_changed (GOF.File file);
    public signal void file_deleted (GOF.File file);
    public signal void icon_changed (GOF.File file);
    public signal void done_loading ();
    public signal void thumbs_loaded ();

    private uint idle_consume_changes_id = 0;

    private unowned string gio_attrs {
        get {
            var scheme = location.get_uri_scheme ();
            if (scheme == "network" || scheme == "computer" || scheme == "smb")
                return "*";
            else
                return GOF.File.GIO_DEFAULT_ATTRIBUTES;
        }
    }

    public Async (GLib.File _file)
    {
        location = _file;
        file = GOF.File.get (location);
        file.exists = true;
        cancellable = new Cancellable ();
        
        //query_info_async (file, file_info_available);
        if (file.info == null)
            file.query_update ();
        file.info_available ();

        if (directory_cache != null)
           directory_cache.insert (location, this);

        //warning ("dir ref_count %u", this.ref_count);
        this.add_toggle_ref ((ToggleNotify) toggle_ref_notify);
        this.unref ();
        warning ("dir %s ref_count %u", this.file.uri, this.ref_count);
        file_hash = new HashTable<GLib.File,GOF.File> (GLib.file_hash, GLib.file_equal);

        //list_directory (location);
    }

    /*~Async () {
        warning ("Async finalize %s", this.file.uri);
    }*/

    private static void toggle_ref_notify(void* data, GLib.Object object, bool is_last)
    {
        if (is_last) {
            warning ("Async toggle_ref_notify %s", (object as Async).file.uri);
            directory_cache.remove (((Async) object).file.location);
            /*object.remove_toggle_ref ((ToggleNotify) toggle_ref_notify);*/
        }
    }

    public void cancel ()
    {
        cancellable.cancel ();
    }

    private void clear_directory_info ()
    {
        if (idle_consume_changes_id != 0)
            Source.remove((uint) idle_consume_changes_id);
        monitor = null;
        sorted_dirs = null;
        file_hash.remove_all ();
        files_count = 0;
    }

    private uint launch_id = 0;

    public void load ()
    {
        cancellable.reset ();
        if (state != State.LOADED) {
            /* clear directory info if it's not fully loaded */
            if (state == State.LOADING) 
                clear_directory_info ();
            if (!file.is_mounted) {
                mount_mountable ();
                return;
            }

            if (launch_id != 0)
                Source.remove (launch_id);
            launch_id = Idle.add (() => { list_directory (location); return false; });
            //list_directory (location);
            try {
                monitor = location.monitor_directory (0);
                monitor.changed.connect (directory_changed);  
            } catch (IOError e) {
                if (!(e is IOError.NOT_MOUNTED)) {
                    warning ("directory monitor failed: %s %s", e.message, file.uri);
                    //remove_directory_from_cache ();
                }
            }
        } else {
            /* even if the directory is currently loading model_add_file manage duplicates */
            debug ("directory %s load cached files", file.uri);
            /* send again the info_available signal for reused directories */
            if (file.info != null)
                file.info_available ();
            foreach (GOF.File gof in file_hash.get_values ()) {
                //if (gof != null  && gof.info != null && (!gof.is_hidden || Preferences.get_default ().pref_show_hidden_files))
                if (gof.info != null && (!gof.is_hidden || Preferences.get_default ().pref_show_hidden_files))
                    file_loaded (gof);
            }
            done_loading ();
        }
    }

    public void load_hiddens () 
    {
        if (state != State.LOADED) {
            load ();
        } else {
            foreach (GOF.File gof in file_hash.get_values ()) {
                if (gof != null  && gof.info != null && gof.is_hidden)
                    file_loaded (gof);
            }
        }
    }

    public void update_desktop_files () 
    {
        foreach (GOF.File gof in file_hash.get_values ()) {
            if (gof != null && gof.info != null 
                && (!gof.is_hidden || Preferences.get_default ().pref_show_hidden_files)
                && gof.is_desktop)
                gof.update_desktop_file ();
        }
    }

    private async void mount_mountable ()
    {
        debug ("mount_mountable %s", file.uri);

        /* TODO pass GtkWindow *parent to Gtk.MountOperation */
        var mount_op = new Gtk.MountOperation (null);
        try {
            if (file.file_type != FileType.MOUNTABLE) {
                yield location.mount_enclosing_volume (0, mount_op, cancellable);
            } else {
                yield location.mount_mountable (0, mount_op, cancellable);
            }
            file.is_mounted = true;
            query_info_async (file, file_info_available);
            load ();
        } catch (Error e) {
            warning ("mount_mountable failed: %s %s", e.message, file.uri);
        }
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
            var e = yield directory.enumerate_children_async (gio_attrs, 0, 0, cancellable);
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
                    if (!gof.is_hidden || Preferences.get_default ().pref_show_hidden_files)
                        file_loaded (gof);

                    //mutex.lock ();
                    files_count++;
                    //mutex.unlock ();
                }
            }
            file.exists = true;
            state = State.LOADED;
        } catch (Error err) {
            warning ("%s %s", err.message, file.uri);
            state = State.NOT_LOADED;
            if (err is IOError.NOT_FOUND || err is IOError.NOT_DIRECTORY)
                file.exists = false;
            if (err is IOError.NOT_MOUNTED) {
                file.is_mounted = false;
                /* try again this time it shoould be mounted */
                load ();
                return;
            }
        }

        //TODO send err code
        done_loading ();
    }

    public void add_to_hash_cache (GOF.File gof) {
        if (file_hash != null)
            file_hash.insert (gof.location, gof);
    }

    /* TODO move this to GOF.File */
    private delegate void func_query_info (GOF.File gof);

    private async void query_info_async (GOF.File gof, func_query_info? f = null) {
        try {
            gof.info = yield gof.location.query_info_async (gio_attrs, 
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
        if (gof.is_gone)
            return;
        gof.update ();
        if (!gof.is_hidden || Preferences.get_default ().pref_show_hidden_files) {
            file_changed (gof);
            gof.changed ();
        }
    }

    private void add_and_refresh (GOF.File gof) {
        if (gof.is_gone)
            return;
        if (gof.info == null)
            critical ("FILE INFO null");
        gof.update ();
        if (gof.info != null && (!gof.is_hidden || Preferences.get_default ().pref_show_hidden_files))
            file_added (gof);

        if (!gof.is_hidden && gof.is_folder ()) {
            /* add to sorted_dirs */
            sorted_dirs.insert_sorted (gof, GOF.File.compare_by_display_name);
        }
    }
    
    private void file_info_available (GOF.File gof) {
        gof.update ();
        gof.info_available ();
    }

    private void notify_file_changed (GOF.File gof) {
        query_info_async (gof, changed_and_refresh);
    }

    private void notify_file_added (GOF.File gof) {
        add_to_hash_cache (gof);
        query_info_async (gof, add_and_refresh);
    }

    private void notify_file_removed (GOF.File gof) {
        if (!gof.is_hidden || Preferences.get_default ().pref_show_hidden_files)
            file_deleted (gof);
        if (!gof.is_hidden && gof.is_folder ()) {
            /* remove from sorted_dirs */
            sorted_dirs.remove (gof);
        }
        gof.remove_from_caches ();
    }

    private void directory_changed (GLib.File _file, GLib.File? other_file, FileMonitorEvent event)
    {
        //GOF.File gof = GOF.File.get (_file);

        switch (event) {
        /*case FileMonitorEvent.ATTRIBUTE_CHANGED:*/
        case FileMonitorEvent.CHANGES_DONE_HINT:
            //message ("file changed %s", _file.get_uri ());
            //notify_file_changed (gof);
            MarlinFile.changes_queue_file_changed (_file);
            break;
        case FileMonitorEvent.CREATED:
            //message ("file added %s", _file.get_uri ());
            //notify_file_added (gof);
            MarlinFile.changes_queue_file_added (_file);
            break;            
        case FileMonitorEvent.DELETED:
            //message ("file deleted %s", _file.get_uri ());
            //notify_file_removed (gof);
            MarlinFile.changes_queue_file_removed (_file);
            break;
        }

        if (idle_consume_changes_id == 0)
            idle_consume_changes_id = Idle.add (() => {
                                                MarlinFile.changes_consume_changes (true);
                                                idle_consume_changes_id = 0;
                                                return false;
                                                });
    }

    public static void notify_files_changed (List<GLib.File> files)
    {
        foreach (var loc in files) {
            GOF.File gof = GOF.File.get (loc);
            Async? dir = cache_lookup (gof.directory);
            
            if (dir != null) 
                dir.notify_file_changed (gof);
        }
    }

    public static void notify_files_added (List<GLib.File> files)
    {
        foreach (var loc in files) {
            GOF.File gof = GOF.File.get (loc);
            Async? dir = cache_lookup (gof.directory);
            
            if (dir != null) 
                dir.notify_file_added (gof);
        }
    }

    public static void notify_files_removed (List<GLib.File> files)
    {
        foreach (var loc in files) {
            GOF.File gof = GOF.File.get (loc);
            Async? dir = cache_lookup (gof.directory);
            
            if (dir != null) {
                //message ("notify removed %s", gof.uri);
                dir.notify_file_removed (gof);
            }
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
        return from_gfile (gof.get_target_location ());
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

        if (file_hash != null)
            val = file_hash.remove (gof.location);

        return val;
    }

    /*private bool remove_directory_from_cache ()
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

        if (file_hash != null)
            file_hash_count = file_hash.size ();
        
        //debug ("is_empty hash sizes file: %u", file_hash_count);
        if (state == State.LOADED && file_hash_count == 0)
            return true;

        return false;
    }

    public unowned List<GOF.File>? get_sorted_dirs ()
    {
        if (state != State.LOADED)
            return null;
        if (sorted_dirs != null)
            return sorted_dirs;

        foreach (var gof in file_hash.get_values()) {
            if (gof.info != null && !gof.is_hidden && gof.is_folder ())
                sorted_dirs.prepend (gof); 
        }
        sorted_dirs.sort (GOF.File.compare_by_display_name);

        return sorted_dirs;
    }

    private bool thumbs_stop;
    private bool thumbs_thread_runing;
    private void *load_thumbnails_func ()
    {
        if (cancellable.is_cancelled () || file_hash == null)
            return null;

        thumbs_thread_runing = true;
        thumbs_stop = false;
        foreach (var gof in file_hash.get_values()) {
            if (cancellable.is_cancelled () || thumbs_stop) {
                thumbs_thread_runing = false;
                return null;
            }
            //if (gof.info != null && gof.flags == 1) {
            if (gof.info != null && gof.flags != 0) {
                gof.flags = 2; /* thumb ready */
                gof.pix_size = icon_size;
                gof.query_thumbnail_update ();
            }
        }
        thumbs_loaded ();
        thumbs_thread_runing = false;
        
        return null;
    }

    ~Async () {
        if(thumbs_thread_runing)
            th.join();
    }

    private int icon_size;
    unowned Thread<void*> th;
    public void threaded_load_thumbnails (int size)
    {
        try {
            icon_size = size;
            thumbs_stop = false;
            //unowned Thread<void*> th = Thread.create<void*> (load_thumbnails_func, false);
            th = Thread.create<void*> (load_thumbnails_func, true);
        } catch (ThreadError e) {
            stderr.printf ("%s\n", e.message);
            return;
        }
    }

    private uint timeout_thumbsq = 0;

    private bool queue_thumbs_timeout_cb ()
    {
        if (!thumbs_thread_runing) {
            threaded_load_thumbnails (icon_size);
            timeout_thumbsq = 0;
            return false;
        }
        return true;
    }

    public void queue_load_thumbnails (int size)
    {
        icon_size = size;

        if (timeout_thumbsq == 0) {
            if (thumbs_thread_runing)
                thumbs_stop = true;
            timeout_thumbsq = Timeout.add (40, queue_thumbs_timeout_cb);
        }
    }
}

