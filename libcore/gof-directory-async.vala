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

public HashTable<GLib.File,GOF.Directory.Async> directory_cache;

public class GOF.Directory.Async : Object {
    public GLib.File location;
    public GOF.File file;

    /* we're looking for particular path keywords like *\/icons* .icons ... */
    public bool uri_contain_keypath_icons;

    public string longest_file_name = ""; //for auto-sizing Miller columns
    public bool track_longest_name;

    public enum State {
        NOT_LOADED,
        LOADING,
        LOADED
    }
    public State state = State.NOT_LOADED;

    public HashTable<GLib.File,GOF.File> file_hash;

    public uint files_count = 0;

    public bool permission_denied = false;

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
    public signal void need_reload ();

    private uint idle_consume_changes_id = 0;
    private bool removed_from_cache;

    private unowned string gio_attrs {
        get {
            var scheme = location.get_uri_scheme ();
            if (scheme == "network" || scheme == "computer" || scheme == "smb")
                return "*";
            else
                return GOF.File.GIO_DEFAULT_ATTRIBUTES;
        }
    }

    public Async (GLib.File _file) {
        location = _file;
        file = GOF.File.get (location);
        file.exists = true;
        cancellable = new Cancellable ();
        track_longest_name = false;

        if (file.info == null)
            file.query_update ();
        file.info_available ();

        if (directory_cache != null)
           directory_cache.insert (location, this);

        //warning ("dir ref_count %u", this.ref_count);
        this.add_toggle_ref ((ToggleNotify) toggle_ref_notify);
        this.unref ();
        debug ("dir %s ref_count %u", this.file.uri, this.ref_count);
        file_hash = new HashTable<GLib.File,GOF.File> (GLib.File.hash, GLib.File.equal);

        uri_contain_keypath_icons = "/icons" in file.uri || "/.icons" in file.uri;
    }

    /*~Async () {
        warning ("Async finalize %s", this.file.uri);
    }*/

    private static void toggle_ref_notify (void* data, Object object, bool is_last) {
        return_if_fail (object != null && object is Object);

        if (is_last) {
            Async dir = (Async) object;
            debug ("Async toggle_ref_notify %s", dir.file.uri);

            if (!dir.removed_from_cache)
                dir.remove_dir_from_cache ();
            dir.remove_toggle_ref ((ToggleNotify) toggle_ref_notify);
        }
    }

    public void cancel () {
        cancellable.cancel ();
        /* remove any pending thumbnail generation */
        if (timeout_thumbsq != 0) {
            Source.remove (timeout_thumbsq);
            timeout_thumbsq = 0;
        }
    }

    private void clear_directory_info () {
        if (idle_consume_changes_id != 0) {
            Source.remove ((uint) idle_consume_changes_id);
            idle_consume_changes_id = 0;
        }
        monitor = null;
        sorted_dirs = null;
        file_hash.remove_all ();
        files_count = 0;
        state = 0;
    }

    public void load () {
        cancellable.reset ();
        longest_file_name = "";
        if (state != State.LOADED) {
            /* clear directory info if it's not fully loaded */
            if (state == State.LOADING)
                clear_directory_info ();
            if (!file.is_mounted) {
                mount_mountable.begin ();
                return;
            }

            list_directory.begin ();

            try {
                monitor = location.monitor_directory (0);
                monitor.changed.connect (directory_changed);
            } catch (IOError e) {
                if (!(e is IOError.NOT_MOUNTED)) {
                    warning ("directory monitor failed: %s %s", e.message, file.uri);
                }
            }
        } else {
            /* even if the directory is currently loading model_add_file manage duplicates */
            debug ("directory %s load cached files", file.uri);
            /* send again the info_available signal for reused directories */
            if (file.info != null)
                file.info_available ();

            bool show_hidden = Preferences.get_default ().pref_show_hidden_files;
            foreach (GOF.File gof in file_hash.get_values ()) {
                if (gof.info != null && (!gof.is_hidden || show_hidden)) {
                    if (track_longest_name)
                        update_longest_file_name (gof);

                    file_loaded (gof);
                }
            }
            done_loading ();
        }
    }

    private void update_longest_file_name (GOF.File gof) {
        if (longest_file_name.length < gof.basename.length)
            longest_file_name = gof.basename;
    }

    public void load_hiddens () {
        if (state != State.LOADED) {
            load ();
        } else {
            foreach (GOF.File gof in file_hash.get_values ()) {
                if (gof != null && gof.info != null && gof.is_hidden) {
                    if (track_longest_name)
                        update_longest_file_name (gof);

                    file_loaded (gof);
                }
            }
        }
        done_loading ();
    }

    public void update_desktop_files () {
        foreach (GOF.File gof in file_hash.get_values ()) {
            if (gof != null && gof.info != null
                && (!gof.is_hidden || Preferences.get_default ().pref_show_hidden_files)
                && gof.is_desktop)
                gof.update_desktop_file ();
        }
    }

    private async void mount_mountable () {
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
            yield query_info_async (file, file_info_available);
            load ();
        } catch (Error e) {
            warning ("mount_mountable failed: %s %s", e.message, file.uri);
        }
    }

    private async void list_directory () {
        file.exists = true;
        files_count = 0;
        state = State.LOADING;

        debug ("list directory %s", file.uri);
        try {
            var e = yield this.location.enumerate_children_async (gio_attrs, 0, 0, cancellable);
            while (true) {
                var files = yield e.next_files_async (200, 0, cancellable);
                if (files == null)
                    break;

                bool show_hidden =  Preferences.get_default ().pref_show_hidden_files;

                foreach (var file_info in files) {
                    GLib.File loc = location.get_child ((string) file_info.get_name ());
                    GOF.File gof = GOF.File.cache_lookup (loc);

                    if (gof == null)
                        gof = new GOF.File (loc, location);

                    gof.info = file_info;
                    gof.update ();

                    add_to_hash_cache (gof);

                    if (!gof.is_hidden || show_hidden) {
                        if (track_longest_name)
                            update_longest_file_name (gof);

                        file_loaded (gof);
                    }

                    files_count++;
                }
            }

            file.exists = true;
            state = State.LOADED;
        } catch (Error err) {
            warning ("%s %s", err.message, file.uri);
            state = State.NOT_LOADED;

            if (err is IOError.NOT_FOUND || err is IOError.NOT_DIRECTORY)
                file.exists = false;

            if (err is IOError.PERMISSION_DENIED)
                permission_denied = true;

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

        if (track_longest_name && gof.basename.length > longest_file_name.length) {
            longest_file_name = gof.basename;
            done_loading ();
        }
    }

    private void file_info_available (GOF.File gof) {
        gof.update ();
        gof.info_available ();
    }

    private void notify_file_changed (GOF.File gof) {
        query_info_async.begin (gof, changed_and_refresh);
    }

    private void notify_file_added (GOF.File gof) {
        add_to_hash_cache (gof);
        query_info_async.begin (gof, add_and_refresh);
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

    private struct fchanges {
        GLib.File           file;
        FileMonitorEvent    event;
    }
    private List <fchanges?> list_fchanges = null;
    private uint list_fchanges_count = 0;
    /* number of monitored changes to store after that simply reload the dir */
    private const uint FCHANGES_MAX = 20;

    private void directory_changed (GLib.File _file, GLib.File? other_file, FileMonitorEvent event) {
        //GOF.File gof = GOF.File.get (_file);
        if (freeze_update) {
            if (list_fchanges_count < FCHANGES_MAX) {
                var fc = fchanges ();
                fc.file = _file;
                fc.event = event;
                list_fchanges.prepend (fc);
                list_fchanges_count++;
            }

            return;
        }

        real_directory_changed (_file, other_file, event);
    }

    private void real_directory_changed (GLib.File _file, GLib.File? other_file, FileMonitorEvent event) {
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

    private bool _freeze_update;
    public bool freeze_update {
        get {
            return _freeze_update;
        }
        set {
            _freeze_update = value;
            if (!value) {
                if (list_fchanges_count >= FCHANGES_MAX) {
                    need_reload ();
                } else {
                    list_fchanges.reverse ();

                    bool tln = track_longest_name;
                    /* do not autosize during multiple changes */
                    track_longest_name = false;

                    foreach (var fchange in list_fchanges)
                        real_directory_changed (fchange.file, null, fchange.event);

                    if (tln) {
                        track_longest_name = true;
                        load ();
                    }
                }
            }

            list_fchanges_count = 0;
            list_fchanges = null;
        }
    }

    public static void notify_files_changed (List<GLib.File> files) {
        foreach (var loc in files) {
            GOF.File gof = GOF.File.get (loc);
            Async? dir = cache_lookup (gof.directory);

            if (dir != null)
                dir.notify_file_changed (gof);
        }
    }

    public static void notify_files_added (List<GLib.File> files) {
        foreach (var loc in files) {
            GOF.File gof = GOF.File.get (loc);
            Async? dir = cache_lookup (gof.directory);

            if (dir != null)
                dir.notify_file_added (gof);
        }
    }

    public static void notify_files_removed (List<GLib.File> files) {
        List<Async> dirs = null;
        bool found;

        foreach (var loc in files) {
            GOF.File gof = GOF.File.get (loc);
            Async? dir = cache_lookup (gof.directory);

            if (dir != null) {
                dir.notify_file_removed (gof);
                found = false;

                foreach (var d in dirs) {
                    if (d == dir)
                        found = true;
                }

                if (!found)
                    dirs.append (dir);
            }
        }

        foreach (var d in dirs) {
            if (d.track_longest_name)
                d.load ();
        }
    }

    public static Async from_gfile (GLib.File file) {
        Async dir;

        dir = cache_lookup (file);
        if (dir == null)
            dir = new Async (file);

        return dir;
    }

    public static Async from_file (GOF.File gof) {
        return from_gfile (gof.get_target_location ());
    }

    public static Async? cache_lookup (GLib.File *file) {
        Async? cached_dir = null;

        if (directory_cache == null)
            directory_cache = new HashTable<GLib.File,GOF.Directory.Async> (GLib.File.hash, GLib.File.equal);

        if (directory_cache != null)
            cached_dir = directory_cache.lookup (file);

        if (cached_dir != null) {
            debug ("found cached dir %s\n", cached_dir.file.uri);
            if (cached_dir.file.info == null)
                cached_dir.file.query_update ();
        }

        return cached_dir;
    }

    public bool remove_from_cache (GOF.File gof) {
        bool val = false;

        if (file_hash != null)
            val = file_hash.remove (gof.location);

        return val;
    }

    public bool remove_dir_from_cache () {
        /* we got to increment the dir ref to remove the toggle_ref */
        this.ref ();

        removed_from_cache = true;
        return directory_cache.remove (location);
    }

    public bool purge_dir_from_cache () {
        var removed = remove_dir_from_cache ();

        /* We have to remove the dir's subfolders from cache too */
        if (removed) {
            foreach (var gfile in file_hash.get_keys ()) {
                var dir = cache_lookup (gfile);
                if (dir != null)
                    dir.remove_dir_from_cache ();
            }
        }

        return removed;
    }

    public bool has_parent () {
        return (file.directory != null);
    }

    public GLib.File get_parent () {
        return file.directory;
    }

    public bool is_empty () {
        uint file_hash_count = 0;

        if (file_hash != null)
            file_hash_count = file_hash.size ();

        //debug ("is_empty hash sizes file: %u", file_hash_count);
        if (state == State.LOADED && file_hash_count == 0)
            return true;

        return false;
    }

    public unowned List<GOF.File>? get_sorted_dirs () {
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
    private void *load_thumbnails_func () {
        return_val_if_fail (this is Async, null);
        if (cancellable.is_cancelled () || file_hash == null) {
            this.unref ();
            return null;
        }

        thumbs_thread_runing = true;
        thumbs_stop = false;

        foreach (var gof in file_hash.get_values ()) {
            if (cancellable.is_cancelled () || thumbs_stop) {
                thumbs_thread_runing = false;
                this.unref ();
                return null;
            }

            if (gof.info != null && gof.flags != GOF.File.ThumbState.UNKNOWN) {
                gof.flags = GOF.File.ThumbState.READY;
                gof.pix_size = icon_size;
                gof.query_thumbnail_update ();
            }
        }

        thumbs_loaded ();
        thumbs_thread_runing = false;

        this.unref ();
        return null;
    }

    public int icon_size;
    public void threaded_load_thumbnails (int size) {
        try {
            icon_size = size;
            thumbs_stop = false;
            this.ref ();
            new Thread<void*>.try ("load_thumbnails_func", load_thumbnails_func);
        } catch (Error e) {
            critical ("Could not start loading thumbnails: %s", e.message);
            return;
        }
    }

    private uint timeout_thumbsq = 0;

    private bool queue_thumbs_timeout_cb () {
        if (!thumbs_thread_runing) {
            threaded_load_thumbnails (icon_size);
            timeout_thumbsq = 0;
            return false;
        }
        return true;
    }

    public void queue_load_thumbnails (int size) {
        icon_size = size;

        if (thumbs_thread_runing)
            thumbs_stop = true;
        if (timeout_thumbsq == 0) {
            timeout_thumbsq = Timeout.add (40, queue_thumbs_timeout_cb);
        }
    }
}
