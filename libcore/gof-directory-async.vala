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

private HashTable<GLib.File,GOF.Directory.Async> directory_cache;
private Mutex dir_cache_lock;

public class GOF.Directory.Async : Object {
    public GLib.File location;
    public GLib.File? selected_file = null;
    public GOF.File file;
    public int icon_size = 32;

    /* we're looking for particular path keywords like *\/icons* .icons ... */
    public bool uri_contain_keypath_icons;

    /* for auto-sizing Miller columns */
    public string longest_file_name = "";
    public bool track_longest_name = false;

    public enum State {
        NOT_LOADED,
        LOADING,
        LOADED
    }
    public State state = State.NOT_LOADED;

    private HashTable<GLib.File,GOF.File> file_hash;
    public uint files_count;

    public bool permission_denied = false;

    private Cancellable cancellable;
    private FileMonitor? monitor = null;

    private List<unowned GOF.File>? sorted_dirs = null;

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
    private bool monitor_blocked = false;

    private unowned string gio_attrs {
        get {
            if (scheme == "network" || scheme == "computer" || scheme == "smb")
                return "*";
            else
                return GOF.File.GIO_DEFAULT_ATTRIBUTES;
        }
    }

    private string scheme;
    public bool is_local;
    public bool is_trash;
    public bool has_mounts;
    public bool has_trash_dirs;
    public bool can_load;
    private bool _is_ready;
    public bool is_ready {
        get { return _is_ready;}
        private set {_is_ready = value;}
    }

    public bool is_cancelled {
        get { return cancellable.is_cancelled (); }
    }

    private Async (GLib.File _file) {
        location = _file;
        file = GOF.File.get (location);
        cancellable = new Cancellable ();
        state = State.NOT_LOADED;
        is_ready = false;
        can_load = true;

        scheme = location.get_uri_scheme ();
        is_trash = (scheme == "trash");
        is_local = is_trash || (scheme == "file");

        if (!prepare_directory ())
            return;

        assert (directory_cache != null);
        directory_cache.insert (location, this);

        this.add_toggle_ref ((ToggleNotify) toggle_ref_notify);
        this.unref ();

        debug ("created dir %s ref_count %u", this.file.uri, this.ref_count);
        file_hash = new HashTable<GLib.File,GOF.File> (GLib.File.hash, GLib.File.equal);
        uri_contain_keypath_icons = "/icons" in file.uri || "/.icons" in file.uri;
    }

    ~Async () {
        debug ("Async destruct");
    }

    /* This is also called when reloading the directory so that another attempt to connect to
     * the network is made */
    private bool prepare_directory () {
        if (!get_file_info ()) {
            is_ready = true;
            /* local uris are deemed loadable even if they do not exist
             * If they do not exist an opportunity will be given to create them */
            can_load = is_local;
            return false;
        }

        if (!file.is_folder () && !file.is_root_network_folder () && !try_parent ()) {
            is_ready = true;
            can_load = false;
            return false;
        }
        return true;
    }

    private bool try_parent () {
        if (file.is_connected) {
            GLib.File? parent = location.get_parent ();
            if (parent != null) {
                file = GOF.File.get (parent);
                selected_file = location.dup ();
                location = parent;
                if (get_file_info ())
                    return true;
            }
        }
        return false;
    }

    private bool get_file_info () {
        if (!is_local && !check_network ()) {
            return false;
        }

        if (!file.ensure_query_info()) {
            if (is_local || !file.is_connected)
                return false;
        }

        can_load = true;
        if (!is_local) {
            mount_mountable.begin ((obj,res) => {
                can_load = false;
                try {
                    mount_mountable.end (res);
                    can_load = true;
                } catch (Error e) {
                    debug ("mount_mountable failed: %s", e.message);

                    if (e is IOError.ALREADY_MOUNTED) {
                        can_load = true;
                    } else if (e is IOError.PERMISSION_DENIED ||
                               e is IOError.FAILED_HANDLED) {

                        permission_denied = true;
                    }
                }
                make_ready ();
            });
        } else
            make_ready ();

        var mounts = VolumeMonitor.get ().get_mounts ();
        has_mounts = (mounts != null);

        if (has_mounts)
            Preferences.get_default ().confirm_trash = true;
        else
            Preferences.get_default ().confirm_trash = false;

        return true;
    }

    public bool check_network () {
        var net_mon = GLib.NetworkMonitor.get_default ();
        var net_available = net_mon.get_network_available ();

        if (!net_available) {
            SocketConnectable? connectable = null;
            try {
                connectable = NetworkAddress.parse_uri (file.uri, 21);
            }
            catch (GLib.Error e) {}

            if (connectable != null) {
                try {
                    if (net_mon.can_reach (connectable))
                        return true;
                }
                catch (GLib.Error e) {}
            }

            return false;
        }

        return true;
    }

    private void make_ready () {
        is_ready = true;
        unowned GLib.List? trash_dirs = null;
        file.mount = GOF.File.get_mount_at (location);

        if (file.mount != null) {
            file.is_mounted = true;
            trash_dirs = Marlin.FileOperations.get_trash_dirs_for_mount (file.mount);
            has_trash_dirs = (trash_dirs != null);
        } else
            has_trash_dirs = is_local;
    }

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

    public void clear_directory_info () {
        if (idle_consume_changes_id != 0) {
            Source.remove ((uint) idle_consume_changes_id);
            idle_consume_changes_id = 0;
        }

        if (file_hash != null)
            file_hash.remove_all ();

        monitor = null;
        sorted_dirs = null;
        files_count = 0;
        state = State.NOT_LOADED;
    }

    public delegate void GOFFileLoadedFunc (GOF.File file);

    /** Views call the following function with null parameter - file_loaded and done_loading
      * signals are emitted and cause the view and view container to update.
      *
      * LocationBar calls this function, with a callback, on its own Async instances in order
      * to perform filename completion.- Emitting a done_loaded signal in that case would cause
      * the premature ending of text entry.
     **/
    public void load (GOFFileLoadedFunc? file_loaded_func = null) {
        cancellable.reset ();
        longest_file_name = "";
        permission_denied = false;
        if (state == State.LOADING)
            return;

        if (state != State.LOADED) {

            list_directory.begin (file_loaded_func);

            if (file_loaded_func == null) {
                try {
                    monitor = location.monitor_directory (0);
                    monitor.rate_limit = 100;
                    monitor.changed.connect (directory_changed);
                } catch (IOError e) {
                    if (!(e is IOError.NOT_MOUNTED)) {
                        /* Will fail for remote filesystems - not an error */
                        debug ("directory monitor failed: %s %s", e.message, file.uri);
                    }
                }
            }
        } else {
            /* even if the directory is currently loading model_add_file manage duplicates */
            debug ("directory %s load cached files", file.uri);

            bool show_hidden = is_trash || Preferences.get_default ().pref_show_hidden_files;

            foreach (GOF.File gof in file_hash.get_values ()) {
                if (gof != null) {
                    if (gof.info != null && (!gof.is_hidden || show_hidden)) {
                        if (track_longest_name)
                            update_longest_file_name (gof);

                        if (file_loaded_func == null)
                            file_loaded (gof);
                        else
                            file_loaded_func (gof);
                    }
                }
            }

            if (file_loaded_func == null && !cancellable.is_cancelled ())
                done_loading ();
        }
    }

    public void block_monitor () {
        if (monitor != null && !monitor_blocked) {
            monitor_blocked = true;
            monitor.changed.disconnect (directory_changed);
        }
    }

    public void unblock_monitor () {
        if (monitor != null && monitor_blocked) {
            monitor_blocked = false;
            monitor.changed.connect (directory_changed);
        }
        if (!is_local)
            need_reload ();
    }

    private void update_longest_file_name (GOF.File gof) {
        if (longest_file_name.length < gof.basename.length)
            longest_file_name = gof.basename;
    }

    public void load_hiddens () {
        if (!can_load)
            return;

        if (state != State.LOADED) {
            load ();
        } else {
            foreach (GOF.File gof in file_hash.get_values ()) {
                if (gof != null && gof.is_hidden) {
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

    public async void mount_mountable () throws Error {
        /* TODO pass GtkWindow *parent to Gtk.MountOperation */
        var mount_op = new Gtk.MountOperation (null);
        yield location.mount_enclosing_volume (0, mount_op, cancellable);
    }

    private async void list_directory (GOFFileLoadedFunc? file_loaded_func = null) {
        if (!can_load) {
            state = State.NOT_LOADED;
            return;
        }

        file.exists = true;
        files_count = 0;
        state = State.LOADING;

        try {
            var e = yield this.location.enumerate_children_async (gio_attrs, 0, 0, cancellable);
            while (state == State.LOADING) {
                var files = yield e.next_files_async (200, 0, cancellable);
                if (files == null)
                    break;

                bool show_hidden = is_trash || Preferences.get_default ().pref_show_hidden_files;

                foreach (var file_info in files) {
                    GLib.File loc = location.get_child (file_info.get_name ());
                    GOF.File? gof = GOF.File.cache_lookup (loc);

                    if (gof == null)
                        gof = new GOF.File (loc, location);

                    gof.info = file_info;
                    gof.update ();

                    file_hash.insert (gof.location, gof);

                    if (!gof.is_hidden || show_hidden) {
                        if (track_longest_name)
                            update_longest_file_name (gof);

                        if (file_loaded_func == null)
                            file_loaded (gof);
                        else
                            file_loaded_func (gof);
                    }

                    files_count++;
                }
            }

            if (state == State.LOADING) {
                file.exists = true;
                state = State.LOADED;
            } else {
                warning ("WARNING load() has been called again before LOADING finished");
                return;
            }
        } catch (Error err) {
            warning ("Listing directory error: %s %s", err.message, file.uri);
            state = State.NOT_LOADED;

            if (err is IOError.NOT_FOUND || err is IOError.NOT_DIRECTORY)
                file.exists = false;
            else if (err is IOError.PERMISSION_DENIED)
                permission_denied = true;
            else if (err is IOError.NOT_MOUNTED)
                file.is_mounted = false;
        }

        if (file_loaded_func == null && !cancellable.is_cancelled ())
            done_loading ();
    }

    public GOF.File? file_hash_lookup_location (GLib.File? location) {
        if (location != null && location is GLib.File) {
            GOF.File? result = file_hash.lookup (location);
            return result;
        } else {
            return null;
        }
    }

    public void file_hash_add_file (GOF.File gof) {
        file_hash.insert (gof.location, gof);
    }

    public GOF.File file_cache_find_or_insert (GLib.File file,
        bool update_hash = false)
    {
        GOF.File? result = file_hash.lookup (file);

        if (result == null) {
            result = GOF.File.cache_lookup (file);

            if (result == null) {
                result = new GOF.File (file, location);
                file_hash.insert (file, result);
            }
            else if (update_hash)
                file_hash.insert (file, result);
        }

        return (!) result;
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
            debug ("query info failed, %s %s", err.message, gof.uri);
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

        if ((!gof.is_hidden || Preferences.get_default ().pref_show_hidden_files))
            file_added (gof);

        if (!gof.is_hidden && gof.is_folder ()) {
            /* add to sorted_dirs */
            if (sorted_dirs.find (gof) == null)
                sorted_dirs.insert_sorted (gof,
                    GOF.File.compare_by_display_name);
        }

        if (track_longest_name && gof.basename.length > longest_file_name.length) {
            longest_file_name = gof.basename;
            done_loading ();
        }
    }

    private void notify_file_changed (GOF.File gof) {
        query_info_async.begin (gof, changed_and_refresh);
    }

    private void notify_file_added (GOF.File gof) {
        query_info_async.begin (gof, add_and_refresh);
    }

    private void notify_file_removed (GOF.File gof) {
        if (!gof.is_hidden || Preferences.get_default ().pref_show_hidden_files)
            file_deleted (gof);

        if (!gof.is_hidden && gof.is_folder ()) {
            /* remove from sorted_dirs */

            /* Addendum note: GLib.List.remove() does not unreference objects.
               See: https://bugzilla.gnome.org/show_bug.cgi?id=624249
                    https://bugzilla.gnome.org/show_bug.cgi?id=532268

               The declaration of sorted_dirs has been changed to contain
               weak pointers as a temporary solution. */
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
        /* If view is frozen, store events for processing later */
        if (freeze_update) {
            if (list_fchanges_count < FCHANGES_MAX) {
                var fc = fchanges ();
                fc.file = _file;
                fc.event = event;
                list_fchanges.prepend (fc);
                list_fchanges_count++;
            }
            return;
        } else
            real_directory_changed (_file, other_file, event);
    }

    private void real_directory_changed (GLib.File _file, GLib.File? other_file, FileMonitorEvent event) {
        switch (event) {
        case FileMonitorEvent.CHANGES_DONE_HINT:
            MarlinFile.changes_queue_file_changed (_file);
            break;
        case FileMonitorEvent.CREATED:
            MarlinFile.changes_queue_file_added (_file);
            break;
        case FileMonitorEvent.DELETED:
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

                    /* do not autosize during multiple changes */
                    bool tln = track_longest_name;
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
            Async? dir = cache_lookup_parent (loc);

            if (dir != null) {
                GOF.File gof = dir.file_cache_find_or_insert (loc);
                dir.notify_file_changed (gof);
            }
        }
    }

    public static void notify_files_added (List<GLib.File> files) {
        foreach (var loc in files) {
            Async? dir = cache_lookup_parent (loc);

            if (dir != null) {
                GOF.File gof = dir.file_cache_find_or_insert (loc, true);
                dir.notify_file_added (gof);
            }
        }
    }

    public static void notify_files_removed (List<GLib.File> files) {
        List<Async> dirs = null;
        bool found;

        foreach (var loc in files) {
            Async? dir = cache_lookup_parent (loc);

            if (dir != null) {
                GOF.File gof = dir.file_cache_find_or_insert (loc);
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

    public static void notify_files_moved (List<GLib.Array<GLib.File>> files) {
        List<GLib.File> list_from = new List<GLib.File> ();
        List<GLib.File> list_to = new List<GLib.File> ();

        foreach (var pair in files) {
            GLib.File from = pair.index (0);
            GLib.File to = pair.index (1);

            list_from.append (from);
            list_to.append (to);
        }

        notify_files_removed (list_from);
        notify_files_added (list_to);
    }

    public static Async from_gfile (GLib.File file) {
        /* Note: cache_lookup creates directory_cache if necessary */
        Async?  dir = cache_lookup (file);
        if (dir != null && !dir.is_local)
                dir = null;

        return dir ?? new Async (file);
    }

    public static Async from_file (GOF.File gof) {
        return from_gfile (gof.get_target_location ());
    }

    public static void remove_file_from_cache (GOF.File gof) {
        Async? dir = cache_lookup (gof.directory);
        if (dir != null)
            dir.file_hash.remove (gof.location);
    }

    public static Async? cache_lookup (GLib.File? file) {
        Async? cached_dir = null;

        if (directory_cache == null) {
            directory_cache = new HashTable<GLib.File,GOF.Directory.Async> (GLib.File.hash, GLib.File.equal);
            dir_cache_lock = GLib.Mutex ();
            return null;
        }

        if (file == null)
            return null;

        dir_cache_lock.@lock ();
        cached_dir = directory_cache.lookup (file);

        if (cached_dir != null) {
            debug ("found cached dir %s", cached_dir.file.uri);
            if (cached_dir.file.info == null)
                cached_dir.file.query_update ();
        }
        dir_cache_lock.unlock ();

        return cached_dir;
    }

    public static Async? cache_lookup_parent (GLib.File file) {
        GLib.File? parent = file.get_parent ();
        return parent != null ? cache_lookup (parent) : cache_lookup (file);
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

    public bool is_loading () {
        return this.state == State.LOADING;
    }

    public bool is_loaded () {
        return this.state == State.LOADED;
    }

    public bool is_empty () {
        uint file_hash_count = 0;

        if (file_hash != null)
            file_hash_count = file_hash.size ();

        if (state == State.LOADED && file_hash_count == 0)
            return true;

        return false;
    }

    public unowned List<unowned GOF.File>? get_sorted_dirs () {
        if (state != State.LOADED)
            return null;

        if (sorted_dirs != null)
            return sorted_dirs;

        foreach (var gof in file_hash.get_values()) {
            if (!gof.is_hidden && gof.is_folder ())
                sorted_dirs.prepend (gof);
        }

        sorted_dirs.sort (GOF.File.compare_by_display_name);
        return sorted_dirs;
    }

    /* Thumbnail loading */
    private uint timeout_thumbsq = 0;
    private bool thumbs_stop;
    private bool thumbs_thread_running;

    private void *load_thumbnails_func () {
        return_val_if_fail (this is Async, null);
        /* Ensure only one thread loading thumbs for this directory */
        return_val_if_fail (!thumbs_thread_running, null);

        if (cancellable.is_cancelled () || file_hash == null) {
            this.unref ();
            return null;
        }
        thumbs_thread_running = true;
        thumbs_stop = false;

        GLib.List<unowned GOF.File> files = file_hash.get_values ();
        foreach (var gof in files) {
            if (cancellable.is_cancelled () || thumbs_stop)
                break;

            if (gof.info != null && gof.flags != GOF.File.ThumbState.UNKNOWN) {
                gof.flags = GOF.File.ThumbState.READY;
                gof.pix_size = icon_size;
                gof.query_thumbnail_update ();
            }
        }

        if (!cancellable.is_cancelled () && !thumbs_stop)
            thumbs_loaded ();

        thumbs_thread_running = false;
        this.unref ();
        return null;
    }

    private void threaded_load_thumbnails (int size) {
        try {
            icon_size = size;
            thumbs_stop = false;
            this.ref ();
            new Thread<void*>.try ("load_thumbnails_func", load_thumbnails_func);
        } catch (Error e) {
            critical ("Could not start loading thumbnails: %s", e.message);
        }
    }

    private bool queue_thumbs_timeout_cb () {
        /* Wait for thumbnail thread to stop then start a new thread */
        if (!thumbs_thread_running) {
            threaded_load_thumbnails (icon_size);
            timeout_thumbsq = 0;
            return false;
        }

        return true;
    }

    public void queue_load_thumbnails (int size) {
        if (!is_local)
            return;

        icon_size = size;
        if (this.state == State.LOADING)
            return;

        /* Do not interrupt loading thumbs at same size for this folder */
        if ((icon_size == size) && thumbs_thread_running)
            return;

        icon_size = size;
        thumbs_stop = true;

        /* Wait for thumbnail thread to stop then start a new thread */
        if (timeout_thumbsq != 0)
            GLib.Source.remove (timeout_thumbsq);

        timeout_thumbsq = Timeout.add (40, queue_thumbs_timeout_cb);
    }
}
