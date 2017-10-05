/***
    Copyright (C) 2011 Marlin Developers
                  2015-2017 elementary LLC (http://launchpad.net/elementary)

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, Inc.,, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Author: ammonkey <am.monkeyd@gmail.com>
            Jeremy Wootten <jeremy@elementaryos.org>
***/

private HashTable<GLib.File,GOF.Directory.Async> directory_cache;
private Mutex dir_cache_lock;

namespace GOF.Directory {

public class Async : Object {
    public delegate void GOFFileLoadedFunc (GOF.File file);

    private uint load_timeout_id = 0;
    private uint mount_timeout_id = 0;
    private const int CONNECT_SOCKET_TIMEOUT_SEC = 30;
    private const int ENUMERATE_TIMEOUT_SEC = 30;
    private const int QUERY_INFO_TIMEOUT_SEC = 20;
    private const int MOUNT_TIMEOUT_SEC = 60;

    private GOF.File? _file = null;
    public unowned GOF.File file {
        get {
            return _file;
        }

        private set {
            this.@ref (); /* Ensure stays alive */

            if (_file != null) {
                remove_dir_from_cache (this);
            }

            _file = value;
            add_dir_to_cache (this);

            this.unref ();
        }
    }

    public unowned GLib.File location {
        get {
            return file.location;
        }
    }

    public GLib.File? selected_file {get; private set;}

    public int icon_size = 32;

    /* we're looking for particular path keywords like *\/icons* .icons ... */
    public bool uri_contain_keypath_icons;

    /* for auto-sizing Miller columns */
    public string longest_file_name = "";
    public bool track_longest_name = false;

    public enum State {
        NOT_LOADED,
        LOADING,
        LOADED,
        TIMED_OUT
    }
    public State state {get; private set;}

    private HashTable<GLib.File,GOF.File> file_hash;
    public uint files_count {get; private set;}

    public bool permission_denied = false;
    public bool network_available = true;

    private Cancellable cancellable;
    private FileMonitor? monitor = null;
    private List<unowned GOF.File>? sorted_dirs = null;

    public signal void file_loaded (GOF.File file);
    public signal void file_added (GOF.File? file); /* null used to signal failed operation */
    public signal void file_changed (GOF.File file);
    public signal void file_deleted (GOF.File file);
    public signal void icon_changed (GOF.File file); /* Called directly by GOF.File - handled by AbstractDirectoryView
                                                        Gets emitted for any kind of file operation */

    public signal void done_loading ();
    public signal void thumbs_loaded ();
    public virtual signal void will_reload () {
        Idle.add (() => {
            reload ();
            return false;
        });
    }

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

    public string scheme {get; private set;}
    public bool is_local {get; private set;}
    public bool is_trash {get; private set;}
    public bool is_network {get; private set;}
    public bool is_recent {get; private set;}
    public bool is_no_info {get; private set;}
    public bool has_mounts {get; private set;}
    public bool has_trash_dirs {get; private set;}
    public bool can_load {get; private set;}
    public bool can_open_files {get; private set;}
    public bool can_stream_files {get; private set;}
    public bool allow_user_interaction {get; set; default = true;}

    private bool is_ready = false;

    public bool is_cancelled {
        get { return cancellable.is_cancelled (); }
    }

    public string last_error_message {get; private set; default = "";}

    public bool loaded_from_cache {get; private set; default = false;}

    private Async (GLib.File _file) {
        /* Ensure consistency between the file property and the key used for caching */
        var loc = get_cache_key (_file);
        file = GOF.File.get (loc);
        selected_file = null;

        cancellable = new Cancellable ();
        state = State.NOT_LOADED;
        can_load = false;

        scheme = location.get_uri_scheme ();
        is_trash = (scheme == "trash");
        is_recent = (scheme == "recent");
        is_no_info = ("cdda mtp ssh sftp afp dav davs".contains (scheme)); //Try lifting requirement for info on remote connections
        is_local = is_trash || is_recent || (scheme == "file");
        is_network = !is_local && ("ftp sftp afp dav davs".contains (scheme));
        can_open_files = !("mtp".contains (scheme));
        can_stream_files = !("ftp sftp mtp".contains (scheme));

        file_hash = new HashTable<GLib.File, GOF.File> (GLib.File.hash, GLib.File.equal);
    }

    ~Async () {
        debug ("Async destruct %s", file.uri);
        if (is_trash)
            disconnect_volume_monitor_signals ();
    }

    /** Views call the following function with null parameter - file_loaded and done_loading
      * signals are emitted and cause the view and view container to update.
      *
      * LocationBar calls this function, with a callback, on its own Async instances in order
      * to perform filename completion.- Emitting a done_loaded signal in that case would cause
      * the premature ending of text entry.
     **/
    public void init (GOFFileLoadedFunc? file_loaded_func = null) {
        if (state == State.LOADING) {
            debug ("Directory Init re-entered - already loading");
            return; /* Do not re-enter */
        }

        var previous_state = state;
        state = State.LOADING;

        loaded_from_cache = false;

        cancellable.cancel ();
        cancellable = new Cancellable ();

        /* If we already have a loaded file cache just list them */
        if (previous_state == State.LOADED) {
            list_cached_files (file_loaded_func);
        /* else fully initialise the directory */
        } else {
            prepare_directory.begin (file_loaded_func);
        }
        /* done_loaded signal is emitted when ready */
    }

    /* This is also called when reloading the directory so that another attempt to connect to
     * the network is made
     */
    private async void prepare_directory (GOFFileLoadedFunc? file_loaded_func) {
        debug ("Preparing directory for loading");
        /* Force info to be refreshed - the GOF.File may have been created already by another part of the program
         * that did not ensure the correct info Aync purposes, and retrieved from cache (bug 1511307).
         */
        file.info = null;
        bool success = yield get_file_info ();

        if (success) {
            if (!is_no_info && !file.is_folder () && !file.is_root_network_folder ()) {
                debug ("Trying to load a non-folder - finding parent");
                var parent = file.is_connected ? location.get_parent () : null;
                if (parent != null) {
                    file = GOF.File.get (parent);
                    selected_file = location.dup ();
                    success = yield get_file_info ();
                } else {
                    debug ("Parent is null for file %s", file.uri);
                    success = false;
                }
            }
        }

        if (success) {
            file.update ();
        }

        debug ("success %s; enclosing mount %s", success.to_string (), file.mount != null ? file.mount.get_name () : "null");
        yield make_ready (is_no_info || success, file_loaded_func); /* Only place that should call this function */
    }

    /*** Returns false if should be able to get info but were unable to ***/
    private async bool get_file_info () {
        debug ("get_file_info");

        if (is_network && !yield check_network ()) {
            debug ("No network found");
            file.is_connected = false;
            return false;
        }

        /* is_network flag fails to detect remote folders mapped to a local uri through fstab, so treat
         * all folders as potentially remote (and disconnected) */

        if (!yield try_query_info ()) { /* may already be mounted */
            debug ("try query info failed - trying to mount");

            if (yield mount_mountable ()) {
            /* Previously mounted Samba servers still appear mounted even if disconnected
             * e.g. by unplugging the network cable.  So the following function can block for
             * a long time; we therefore use a timeout */
                debug ("successful mount %s", file.uri);
                file.is_mounted = true;
                return (yield try_query_info ()) || is_no_info;
            } else {
                debug ("failed mount %s", file.uri);
                return false;
            }
        } else {
            return true;
        }
    }

    private async bool try_query_info () {
        debug ("try_query_info");
        cancellable = new Cancellable ();
        bool querying = true;
        assert (load_timeout_id == 0);
        load_timeout_id = Timeout.add_seconds (QUERY_INFO_TIMEOUT_SEC, () => {
            if (querying) {
                debug ("Cancelled after timeout in query info async %s", file.uri);
                cancellable.cancel ();
                last_error_message = "Timed out while querying file info";
            }
            load_timeout_id = 0;
            return false;
        });

        bool success = yield query_info_async (file, null, cancellable);
        querying = false;
        cancel_timeout (ref load_timeout_id);
        if (cancellable.is_cancelled ()) {
            debug ("Failed to get info - timed out and cancelled");
            file.is_connected = false;
            return false;
        }

        if (success) {
            debug ("got file info - updating");
            file.update ();
            debug ("success %s; enclosing mount %s", success.to_string (), file.mount != null ? file.mount.get_name () : "null");
            return true;
        } else {
            debug ("Failed to get file info for %s", file.uri);
            return false;
        }
    }

    private async bool mount_mountable () {
        debug ("mount_mountable");
        bool res = false;
        Gtk.MountOperation? mount_op = null;
        cancellable = new Cancellable ();

        try {
            bool mounting = true;
            bool asking_password = false;
            assert (mount_timeout_id == 0);

            mount_timeout_id = Timeout.add_seconds (MOUNT_TIMEOUT_SEC, () => {
                if (mounting && !asking_password) {
                    mount_timeout_id = 0;
                    debug ("Cancelled after timeout in mount mountable %s", file.uri);
                    last_error_message = ("Timed out when trying to mount %s").printf (file.uri);
                    state = State.TIMED_OUT;
                    cancellable.cancel ();

                    return false;
                } else {
                    return true;
                }
            });

            if (allow_user_interaction) {
                mount_op = new Gtk.MountOperation (null);

                mount_op.ask_password.connect (() => {
                    debug ("Asking for password");
                    asking_password = true;
                });

                mount_op.reply.connect (() => {
                    debug ("Password dialog finished");
                    asking_password = false;
                });
            }

            debug ("mounting ....");
            res =yield location.mount_enclosing_volume (GLib.MountMountFlags.NONE, mount_op, cancellable);
        } catch (Error e) {
            last_error_message = e.message;
            if (e is IOError.ALREADY_MOUNTED) {
                debug ("Already mounted %s", file.uri);
                file.is_connected = true;
                res = true;
            } else if (e is IOError.NOT_FOUND) {
                debug ("Enclosing mount not found %s (may be remote share)", file.uri);
                /* Do not fail loading at this point - may still load */
                try {
                    yield location.mount_mountable (GLib.MountMountFlags.NONE, mount_op, cancellable);
                    res = true;
                } catch (GLib.Error e2) {
                    last_error_message = e2.message;
                    debug ("Unable to mount mountable");
                    res = false;
                }

            } else {
                file.is_connected = false;
                file.is_mounted = false;
                debug ("Setting mount null 1");
                file.mount = null;
                debug ("Mount_mountable failed: %s", e.message);
                if (e is IOError.PERMISSION_DENIED || e is IOError.FAILED_HANDLED) {
                    permission_denied = true;
                }
            }
        } finally {
            cancel_timeout (ref mount_timeout_id);
        }

        debug ("success %s; enclosing mount %s", res.to_string (), file.mount != null ? file.mount.get_name () : "null");
        return res;
    }

    public async bool check_network () {
        debug ("check network");
        var net_mon = GLib.NetworkMonitor.get_default ();
        network_available = net_mon.get_network_available ();

        bool success = false;

        if (network_available) {
            if (!file.is_mounted) {
                debug ("Network is available");
                if (scheme != "smb") {
                    try {
                        /* Try to connect for real.  */
                        var scl = new SocketClient ();
                        scl.set_timeout (CONNECT_SOCKET_TIMEOUT_SEC);
                        scl.set_tls (PF.FileUtils.get_is_tls_for_protocol (scheme));
                        debug ("Trying to connect to connectable");
                        var sc = yield scl.connect_to_uri_async (file.uri, PF.FileUtils.get_default_port_for_protocol (scheme), cancellable);
                        success = (sc != null && sc.is_connected ());
                        debug ("Socketclient is %s", sc == null ? "null" : (sc.is_connected () ? "connected" : "not connected"));
                    } catch (GLib.Error e) {
                        last_error_message = e.message;
                        warning ("Error: could not connect to connectable %s - %s", file.uri, e.message);
                        return false;
                    }
                } else {
                    success = true;
                }
            } else {
                debug ("File is already mounted - not reconnecting");
                success = true;
            }
        } else {
            warning ("No network available");
        }


        debug ("Attempt to connect to %s %s", file.uri, success ? "succeeded" : "failed");
        return success;
    }


    private async void make_ready (bool ready, GOFFileLoadedFunc? file_loaded_func = null) {
        debug ("make ready");
        can_load = ready;

        if (!can_load) {
            debug ("Cannot load %s.  Connected %s, Mounted %s, Exists %s", file.uri,
                                                                           file.is_connected.to_string (),
                                                                           file.is_mounted.to_string (),
                                                                           file.exists.to_string ());
            after_loading (file_loaded_func);
            /* Remove unloadable directories from cache */
            Async.remove_dir_from_cache (this);
            return;
        }

        if (!is_ready) {
            /* This must only be run once for each Async */
            is_ready = true;

            /* Already in cache. Now add toggle ref. */
            this.add_toggle_ref ((ToggleNotify) toggle_ref_notify);
            this.unref (); /* Make the toggle ref the only ref */
        }

        /* The following can run on reloading */
        if (file.mount != null) {
            debug ("Directory has mount point");
            unowned GLib.List? trash_dirs = null;
            trash_dirs = Marlin.FileOperations.get_trash_dirs_for_mount (file.mount);
            has_trash_dirs = (trash_dirs != null);
        } else {
            has_trash_dirs = is_local;
        }

        /* Do not use root trash_dirs (Move to the Rubbish Bin option will not be shown) */
        has_trash_dirs = has_trash_dirs && (Posix.getuid () != 0);

        set_confirm_trash ();

        if (can_load) {
            uri_contain_keypath_icons = "/icons" in file.uri || "/.icons" in file.uri;

            if (file_loaded_func == null && is_local) {
                try {
                    monitor = location.monitor_directory (0);
                    monitor.rate_limit = 100;
                    monitor.changed.connect (directory_changed);
                } catch (IOError e) {
                    last_error_message = e.message;
                    if (!(e is IOError.NOT_MOUNTED)) {
                        /* Will fail for remote filesystems - not an error */
                        debug ("directory monitor failed: %s %s", e.message, file.uri);
                    }
                }
            }


            if (is_trash) {
                connect_volume_monitor_signals ();
            }
        }

        yield list_directory_async (file_loaded_func);
    }

    private void set_confirm_trash () {
        bool to_confirm = true;
        if (is_trash) {
            to_confirm = false;
            var mounts = VolumeMonitor.get ().get_mounts ();
            if (mounts != null) {
                foreach (GLib.Mount m in mounts) {
                    to_confirm |= (m.can_eject () && Marlin.FileOperations.has_trash_files (m));
                }
            }
        }
        Preferences.get_default ().confirm_trash = to_confirm;
    }

    private void connect_volume_monitor_signals () {
        var vm = VolumeMonitor.get();
        vm.mount_changed.connect (on_mount_changed);
        vm.mount_added.connect (on_mount_changed);
    }
    private void disconnect_volume_monitor_signals () {
        var vm = VolumeMonitor.get();
        vm.mount_changed.disconnect (on_mount_changed);
        vm.mount_added.disconnect (on_mount_changed);
    }

    private void on_mount_changed (GLib.VolumeMonitor vm, GLib.Mount mount) {
        if (state == State.LOADED) {
            will_reload (); // Prepare slots for a reload but do not propagate
        }
    }

    private static void toggle_ref_notify (void* data, Object object, bool is_last) {
        return_if_fail (object != null && object is Object);

        if (is_last) {
            Async dir = (Async) object;
            debug ("Async is last toggle_ref_notify %s", dir.file.uri);

            if (!dir.removed_from_cache) {
                dir.@ref (); /* Add back ref removed when cached so toggle ref not removed */
                remove_dir_from_cache (dir);
            }

            dir.remove_toggle_ref ((ToggleNotify) toggle_ref_notify);
        }
    }

    public void cancel () {
        /* This should only be called when closing reloading the view.
         * It will cancel initialisation of the directory */
        cancellable.cancel ();
        cancel_timeouts ();
    }


    public void reload () {
        if (state != State.LOADED) {
            warning ("Too rapid reload");
            return; /* Do not re-enter */
        }

        if (state == State.TIMED_OUT && file.is_mounted) {
            debug ("Unmounting because of timeout");
            cancellable.cancel ();
            cancellable = new Cancellable ();
            file.location.unmount_mountable (GLib.MountUnmountFlags.FORCE, cancellable);
            file.mount = null;
            file.is_mounted = false;
        }

        clear_directory_info ();
        init ();
    }

    /** Called in preparation for a reload **/
    private void clear_directory_info () {
        if (state == State.LOADING) {
            return; /* Do not re-enter */
        }

        cancel ();
        file_hash.remove_all ();
        sorted_dirs = null;
        files_count = 0;
        can_load = false;
        state = State.NOT_LOADED;
        loaded_from_cache = false;
        /* Do not change @is_ready to false - we do not want to
         * perform caching amd adding toggle ref again  */

        /* These will be reconnected if directory still (or now) loadable */
        if (monitor != null) {
            monitor.changed.disconnect (directory_changed);
            monitor = null;
        }

        if (is_trash) {
            disconnect_volume_monitor_signals ();
        }
    }

    private void list_cached_files (GOFFileLoadedFunc? file_loaded_func = null) {
        debug ("list cached files");

        state = State.LOADING;
        bool show_hidden = is_trash || Preferences.get_default ().show_hidden_files;
        foreach (GOF.File gof in file_hash.get_values ()) {
            if (gof != null) {
                after_load_file (gof, show_hidden, file_loaded_func);
            }
        }

        state = State.LOADED;
        loaded_from_cache = true;

        after_loading (file_loaded_func);
    }

    private async void list_directory_async (GOFFileLoadedFunc? file_loaded_func) {
        debug ("list directory async");
        /* Should only be called after creation and if reloaded */
        if (!is_ready || file_hash.size () > 0) {
            critical ("(Re)load directory called when not cleared");
            return;
        }

        if (!can_load) {
            critical ("load called when cannot load - not expected to happen");
            return;
        }

        if (state == State.LOADED) {
            critical ("load called when already loaded - not expected to happen");
            return;
        }
        if (load_timeout_id > 0) {
            critical ("load called when timeout already running - not expected to happen");
            return;
        }

        cancellable = new Cancellable ();
        longest_file_name = "";
        permission_denied = false;
        can_load = true;
        files_count = 0;
        state = State.LOADING;
        bool show_hidden = is_trash || Preferences.get_default ().show_hidden_files;
        bool server_responding = false;

        try {
            /* This may hang for a long time if the connection was closed but is still mounted so we
             * impose a time limit */
            load_timeout_id = Timeout.add_seconds (ENUMERATE_TIMEOUT_SEC, () => {
                if (server_responding) {
                    return true;
                } else {
                    debug ("Load timeout expired");
                    state = State.TIMED_OUT;
                    last_error_message = _("Server did not respond within time limit");
                    load_timeout_id = 0;
                    cancellable.cancel ();

                    return false;
                }
            });

            var e = yield this.location.enumerate_children_async (gio_attrs, 0, Priority.HIGH, cancellable);
            debug ("Obtained file enumerator for location %s", location.get_uri ());

            while (!cancellable.is_cancelled ()) {
                try {
                    server_responding = false;
                    var files = yield e.next_files_async (200, GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, cancellable);
                    server_responding = true;

                    if (files == null) {
                        break;
                    } else {
                        foreach (var file_info in files) {
                            var key = Async.get_cache_key (location.get_child (file_info.get_name ()));
                            var gof = new GOF.File (key, this.location); /*does not add to GOF file cache */

                            gof.info = file_info;
                            gof.update ();

                            file_hash.insert (key, gof);
                            after_load_file (gof, show_hidden, file_loaded_func);
                            files_count++;
                        }
                    }
                } catch (Error e) {
                    last_error_message = e.message;
                    warning ("Error reported by next_files_async - %s", e.message);
                }
            }
            /* Load as many files as we can get info for */
            if (!(cancellable.is_cancelled ())) {
                state = State.LOADED;
            }
        } catch (Error err) {
            warning ("Listing directory error: %s, %s %s", last_error_message, err.message, file.uri);
            can_load = false;
            if (err is IOError.NOT_FOUND || err is IOError.NOT_DIRECTORY) {
                file.exists = false;
            } else if (err is IOError.PERMISSION_DENIED) {
                permission_denied = true;
            } else if (err is IOError.NOT_MOUNTED) {
                file.mount = null;
                file.is_mounted = false;
            }
        } finally {
            cancel_timeout (ref load_timeout_id);
            loaded_from_cache = false;
            after_loading (file_loaded_func);
        }
    }

    private void after_load_file (GOF.File gof, bool show_hidden, GOFFileLoadedFunc? file_loaded_func) {
        if (!gof.is_hidden || show_hidden) {
            if (track_longest_name)
                update_longest_file_name (gof);

            if (file_loaded_func == null) {
                file_loaded (gof);
            } else
                file_loaded_func (gof);
        }
    }

    private void after_loading (GOFFileLoadedFunc? file_loaded_func) {
        /* If loading failed reset */
        debug ("after loading state is %s", state.to_string ());
        if (state == State.LOADING || state == State.TIMED_OUT) {
            state = State.TIMED_OUT; /* else clear directory info will fail */
            can_load = false;
        }

        if (state != State.LOADED) {
            clear_directory_info ();
        }

        if (file_loaded_func == null) {
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
    }

    private void update_longest_file_name (GOF.File gof) {
        if (longest_file_name.length < gof.basename.length)
            longest_file_name = gof.basename;
    }

    public void load_hiddens () {
        if (!can_load) {
            return;
        }
        if (state != State.LOADED) {
            list_directory_async.begin (null);
        } else {
            list_cached_files ();
        }
    }

    public void update_files () {
        foreach (GOF.File gof in file_hash.get_values ()) {
            if (gof != null && gof.info != null
                && (!gof.is_hidden || Preferences.get_default ().show_hidden_files))

                gof.update ();
        }
    }

    public void update_desktop_files () {
        foreach (GOF.File gof in file_hash.get_values ()) {

            if (gof != null && gof.info != null &&
                (!gof.is_hidden || Preferences.get_default ().show_hidden_files) &&
                gof.is_desktop) {

                gof.update_desktop_file ();
            }
        }
    }

    /** Use to look up cache if not sure @location is in correct form for key **/
    public GOF.File? file_hash_lookup_location (GLib.File? location) {
        if (location != null && location is GLib.File) {
            GOF.File? result = file_hash.lookup (Async.get_cache_key (location));
            /* Although file_hash.lookup returns an unowned value, Vala will add a reference
             * as the return value is owned.  This matches the behaviour of GOF.File.cache_lookup */
            return result;
        } else {
            return null;
        }
    }

    public void file_hash_add_file (GOF.File gof) { /* called directly by GOF.File */
        file_hash.insert (gof.location, gof);
    }

    /** Either return an existing GOF.File from cache or, if @update_hash is true,create a new one
      * and insert into cache.  Otherwise return null
     **/
    public GOF.File? file_cache_find_or_insert (GLib.File loc, bool update_hash = false) {
        assert (loc != null);
        var key = Async.get_cache_key (loc);
        unowned GOF.File? result = file_hash.lookup (key);

        if (result == null && update_hash) {
            var gof = new GOF.File (key, this.location);
            file_hash.insert (key, gof);
            return gof;
        } else {
            return result; /* Vala will add a reference if necessary */
        }
    }

    /**TODO** move this to GOF.File */
    private delegate void func_query_info (GOF.File gof);

    private async bool query_info_async (GOF.File gof, func_query_info? f = null, Cancellable? cancellable = null) {
        gof.info = null;
        try {
            gof.info = yield gof.location.query_info_async (gio_attrs,
                                                            FileQueryInfoFlags.NONE,
                                                            Priority.DEFAULT,
                                                            cancellable);
            if (f != null) {
                f (gof);
            }
        } catch (Error err) {
            last_error_message = err.message;
            debug ("query info failed, %s %s", err.message, gof.uri);
            if (err is IOError.NOT_FOUND) {
                gof.exists = false;
            }
        }
        return gof.info != null;
    }

    private void changed_and_refresh (GOF.File gof) {
        if (gof.is_gone) {
            critical ("File marked as gone when refreshing change");
            return;
        }

        gof.update ();

        if (!gof.is_hidden || Preferences.get_default ().show_hidden_files) {
            file_changed (gof);
            gof.changed ();
        }
    }

    private void add_and_refresh (GOF.File gof) {
        if (gof.is_gone) {
            critical ("Add and refresh file which is gone");
            return;
        }

        if (gof.info == null) {
            critical ("FILE INFO null");
        }

        gof.update ();

        if ((!gof.is_hidden || Preferences.get_default ().show_hidden_files)) {
            file_added (gof);
        }

        if (!gof.is_hidden && gof.is_folder ()) {
            /* add to sorted_dirs */
            if (sorted_dirs.find (gof) == null) {
                sorted_dirs.insert_sorted (gof,
                    GOF.File.compare_by_display_name);
            }
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
        /* gof.location should be in cache key form */
        if (file_hash.lookup (gof.location) == null) {
            return;
        }

        file_hash.remove (gof.location);

        if (!gof.is_hidden || Preferences.get_default ().show_hidden_files) {
            file_deleted (gof);
        }

        if (!gof.is_hidden && gof.is_folder ()) {
            /* remove from sorted_dirs */

            /* Addendum note: GLib.List.remove() does not unreference objects.
               See: https://bugzilla.gnome.org/show_bug.cgi?id=624249
                    https://bugzilla.gnome.org/show_bug.cgi?id=532268

               The declaration of sorted_dirs has been changed to contain
               weak pointers as a temporary solution. */
            sorted_dirs.remove (gof);
        }
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
        case FileMonitorEvent.CREATED:
            MarlinFile.changes_queue_file_added (_file);
            break;
        case FileMonitorEvent.DELETED:
            MarlinFile.changes_queue_file_removed (_file);
            break;
        case FileMonitorEvent.CHANGES_DONE_HINT: /* test  last to avoid unnecessary action when file renamed */
        case FileMonitorEvent.ATTRIBUTE_CHANGED:
            MarlinFile.changes_queue_file_changed (_file);
            break;
        }

        if (idle_consume_changes_id == 0) {
            /* Insert delay to avoid race between gof.rename () finishing and consume changes -
             * If consume changes called too soon can corrupt the view.
             * TODO: Have GOF.Directory.Async control renaming.
             */
            idle_consume_changes_id = Timeout.add (10, () => {
                MarlinFile.changes_consume_changes (true);
                idle_consume_changes_id = 0;
                return false;
            });
        }
    }

    private bool _freeze_update;
    public bool freeze_update {
        get {
            return _freeze_update;
        }

        set {
            _freeze_update = value;

            if (!value && can_load) {
                if (list_fchanges_count >= FCHANGES_MAX) {
                    will_reload (); // Prepare slots for a reload but do not propagate
                } else if (list_fchanges_count > 0) {
                    list_fchanges.reverse ();
                    foreach (var fchange in list_fchanges) {
                        real_directory_changed (fchange.file, null, fchange.event);
                    }
                }
            }

            list_fchanges_count = 0;
            list_fchanges = null;
        }
    }

    public static void notify_files_changed (List<GLib.File> files) {
        foreach (var loc in files) {
            assert (loc != null);
            Async? parent_dir = cache_lookup_parent (loc);
            GOF.File? gof = null;

            if (parent_dir != null) {
                gof = parent_dir.file_cache_find_or_insert (loc);
                if (gof != null) {
                    parent_dir.notify_file_changed (gof);
                }
            }

            /* Has a background directory been changed (e.g. properties)? If so notify the view(s)*/
            Async? dir = cache_lookup (loc);

            if (dir != null) {
                dir.notify_file_changed (dir.file);
            }
        }
    }

    public static void notify_files_added (List<GLib.File> files) {
        foreach (var loc in files) {
            unowned Async? dir = cache_lookup_parent (loc);

            if (dir != null) {
                GOF.File gof = dir.file_cache_find_or_insert (loc, true);
                dir.notify_file_added (gof);
            }
        }
    }

    public static void notify_files_removed (List<GLib.File> files) {
        List<Async> dirs = null;
        bool already_in_dirs = false;

        foreach (var loc in files) {
            if (loc == null) {
                continue;
            }

            unowned Async? dir = cache_lookup_parent (loc); /* Will use correct key */

            if (dir != null) {
                GOF.File gof = dir.file_cache_find_or_insert (loc); /* Will use correct key */
                already_in_dirs = false;

                if (gof != null) {
                    dir.notify_file_removed (gof);

                    foreach (var d in dirs) {
                        if (d == dir) {
                            already_in_dirs = true;
                            break;
                        }
                    }
                }

                if (!already_in_dirs) {
                    dirs.prepend (dir);
                }
            } else {
                dir = cache_lookup (loc); /* Will use correct key */

                if (dir != null) {
                    /* Signal itself deleted. Objects holding reference to dir should all drop them causing dir to be removed from cache.  */
                    dir.file_deleted (dir.file);
                }
            }
        }

        foreach (var d in dirs) {
            if (d.track_longest_name) {
                d.list_cached_files ();
            }
        }
    }

    public static void notify_files_moved (List<GLib.Array<GLib.File>> files) {
        List<GLib.File> list_from = new List<GLib.File> ();
        List<GLib.File> list_to = new List<GLib.File> ();

        foreach (var pair in files) {
            GLib.File from = pair.index (0);
            GLib.File to = pair.index (1);

            list_from.prepend (from);
            list_to.prepend (to);
        }

        /* For local files notify_files_removed and notify_file_added also get called via the FileMonitor so
         * we have to make sure these functions can cope with duplicate calls. */
        if (list_from != null && list_to != null) {
            notify_files_removed (list_from);
            notify_files_added (list_to);
        }
    }

    public static Async from_file (GOF.File gof) {
        return from_gfile (gof.get_target_location ());
    }

    public static Async from_gfile (GLib.File file) {
        assert (file != null);
        /* Note: cache_lookup creates directory_cache if necessary */
         unowned Async?  cached_dir = cache_lookup (file);
        /* Both local and non-local directories can be cached */
        if (cached_dir == null) {
            var new_dir = new Async (file); /* Will add to directory cache */
            /* Added to cache early to prevent race when creating duplicate tabs */
            /* Will be removed from cache if dir fails to load */
            /* Toggle ref added when loaded */
            return new_dir;
        }

        return cached_dir; /* Vala will add a reference if required. */
    }

    private static GLib.File get_cache_key (GLib.File file) {
        /* Ensure lookup key is same as originally used to insert */
        var escaped_uri = PF.FileUtils.escape_uri (file.get_uri ());
        var _scheme = Uri.parse_scheme (escaped_uri);

        if (_scheme == null) {
            _scheme = Marlin.ROOT_FS_URI;
            escaped_uri = _scheme + escaped_uri;
        }

        return GLib.File.new_for_uri (escaped_uri);
     }

    /* TODO remove this - GOF.File cache should be managed only by Async */
    public static void remove_file_from_cache (GOF.File gof) {
        assert (gof != null);
        Async? dir = cache_lookup (gof.directory);
        if (dir != null)
            dir.file_hash.remove (gof.location);
    }

    public static unowned Async? cache_lookup (GLib.File? file) {
        unowned Async? cached_dir = null;

        if (directory_cache == null) {
            directory_cache = new HashTable<GLib.File,GOF.Directory.Async> (GLib.File.hash, GLib.File.equal);
            dir_cache_lock = GLib.Mutex ();
            return null;
        }

        if (file == null) {
            critical ("Null file received in Async cache_lookup");
            return null;
        }

        var key = Async.get_cache_key (file);
        dir_cache_lock.@lock ();
        cached_dir = directory_cache.lookup (key);
        dir_cache_lock.unlock ();

        if ((cached_dir != null) &&
            (cached_dir is Async && cached_dir.file != null) &&
            (cached_dir.file.info == null && cached_dir.can_load)) {

            warning ("updating cached file info");
            cached_dir.file.query_update ();  /* This is synchronous and causes blocking */
        }

        return cached_dir;
    }

    /** Returns parent Async if in cache else return null.
     **/
    public static unowned Async? cache_lookup_parent (GLib.File file) {
        if (file == null) {
            critical ("Null file submitted to cache lookup parent");
            return null;
        }

        GLib.File? parent = file.get_parent ();
        return parent != null ? cache_lookup (parent) : null;
    }

    public static bool remove_dir_from_cache (Async dir) {
        dir.removed_from_cache = true;

        dir_cache_lock.@lock ();
        var result = directory_cache.remove (dir.location);
        dir_cache_lock.unlock ();

        return result;
    }

    public static void add_dir_to_cache (Async dir) {
        dir.removed_from_cache = false;

        dir_cache_lock.@lock ();
        directory_cache.insert (dir.location, dir);
        dir_cache_lock.unlock ();
    }

    public static bool purge_dir_from_cache (Async dir) {
        var removed = remove_dir_from_cache (dir);
        /* We have to remove the dir's subfolders from cache too */
        if (removed) {
            foreach (var gfile in dir.file_hash.get_keys ()) {
                assert (gfile != null);
                var sub_dir = Async.cache_lookup (gfile);
                if (sub_dir != null)
                    Async.remove_dir_from_cache (sub_dir);
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

    public bool has_timed_out () {
        return this.state == State.TIMED_OUT;
    }

    public bool is_empty () {
        /* only return true when loaded to avoid temporary appearance of empty message while loading */
        return (state == State.LOADED && file_hash.size () == 0);
    }

    public unowned List<GOF.File>? get_sorted_dirs () {
        if (state != State.LOADED) { /* Can happen if pathbar tries to load unloadable directory */
            return null;
        }

        if (sorted_dirs != null)
            return sorted_dirs;

        foreach (var gof in file_hash.get_values()) { /* returns owned values */
            if (!gof.is_hidden && (gof.is_folder () || gof.is_smb_server ())) {
                sorted_dirs.prepend (gof);
            }
        }

        sorted_dirs.sort (GOF.File.compare_by_display_name);
        return sorted_dirs;
    }

    private void cancel_timeouts () {
        cancel_timeout (ref idle_consume_changes_id);
        cancel_timeout (ref load_timeout_id);
        cancel_timeout (ref mount_timeout_id);
    }

    private bool cancel_timeout (ref uint id) {
        if (id > 0) {
            Source.remove (id);
            id = 0;
            return true;
        } else {
            return false;
        }
    }
}
}

