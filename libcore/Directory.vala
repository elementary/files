/***
    Copyright (C) 2011 Marlin Developers
                  2015-2018 elementary LLC <https://elementary.io>

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

public class Files.Directory : Object {
    private static HashTable<unowned GLib.File, Files.Directory?> directory_cache;
    private static Mutex dir_cache_lock;

    static construct {
        directory_cache = new HashTable<unowned GLib.File, Files.Directory?> (GLib.File.hash, GLib.File.equal);
        dir_cache_lock = GLib.Mutex ();
    }

    public delegate void FileLoadedFunc (Files.File file);
    public delegate void DoneLoadingFunc ();

    private uint load_timeout_id = 0;
    private uint mount_timeout_id = 0;
    private const int CONNECT_SOCKET_TIMEOUT_SEC = 30;
    private const int ENUMERATE_TIMEOUT_SEC = 30;
    private const int QUERY_INFO_TIMEOUT_SEC = 20;
    private const int MOUNT_TIMEOUT_SEC = 60;

    public GLib.File creation_key { get; construct; }
    public GLib.File location { get; private set; }
    public GLib.File? selected_file { get; private set; }
    public Files.File file { get; private set construct; }
    public int icon_size = 32;

    public enum State {
        NOT_LOADED,
        LOADING,
        LOADED,
        TIMED_OUT
    }

    public State state { get; private set; }

    private HashTable<GLib.File,Files.File> file_hash;
    public uint displayed_files_count {get; private set;}

    public bool permission_denied = false;
    public bool network_available = true;

    private Cancellable cancellable;
    private FileMonitor? monitor = null;
    private List<unowned Files.File>? sorted_dirs = null;

    //Signals listened to by client Slots
    public signal void file_changed (Files.File file);
    public signal void file_deleted (Files.File file);
    public signal void done_loading ();
    public signal void will_reload (); // Do not call directly

    private uint idle_consume_changes_id = 0;
    private bool removed_from_cache;
    private bool monitor_blocked = false;

    private unowned string gio_attrs {
        get {
            if (scheme == "network" || scheme == "computer" || scheme == "smb") {
                return "*";
            } else {
                return Files.File.GIO_DEFAULT_ATTRIBUTES;
            }
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
    public bool allow_user_interaction {get; set; default = true;}

    private bool is_ready = false;

    public bool is_cancelled {
        get { return cancellable.is_cancelled (); }
    }

    public string last_error_message {get; private set; default = "";}

    public bool loaded_from_cache {get; private set; default = false;}

    // New Directories can only be created via these two static methods
    public static Directory from_gfile (GLib.File file) {
        /* Ensure uri is correctly escaped and has scheme */
        var escaped_uri = FileUtils.escape_uri (file.get_uri ());
        var scheme = Uri.parse_scheme (escaped_uri);
        if (scheme == null) {
            scheme = Files.ROOT_FS_URI;
            escaped_uri = scheme + escaped_uri;
        }

        var gfile = GLib.File.new_for_uri (escaped_uri);
        var creation_key = gfile;
        /* Avoid adding a new Directory that will be a duplicate of an existing one, when called
         * with non-folder location. */
        if (gfile.query_exists () && gfile.is_native () && gfile.has_parent (null)) {
            var ftype = gfile.query_file_type (0, null);
            if (ftype != FileType.DIRECTORY) {
                creation_key = gfile.get_parent ();
            }
        }

        var dir = cache_lookup (creation_key);
        /* Both local and non-local files can be cached */
        if (dir == null) {
            dir = new Directory (creation_key);
            // Cache immediately to avoid possible creation of duplicates
            lock (directory_cache) {
                directory_cache.insert (creation_key, dir);
            }
        }

        /* If the original file was not a folder, ensure that it will be
         * selected in the loaded view*/
        if (!creation_key.equal (gfile)) {
            dir.selected_file = file;
        }

        return dir;
    }

    private Directory (GLib.File _file) {
        Object (
            creation_key: _file
        );

        assert (creation_key != null);
        location = _file;
        file = Files.File.get (location);
        selected_file = null;

        cancellable = new Cancellable ();
        state = State.NOT_LOADED;
        can_load = false;

        scheme = location.get_uri_scheme ();
        is_trash = FileUtils.location_is_in_trash (location);
        is_recent = (scheme == "recent");
        //Try lifting requirement for info on remote connections
        //TODO Not sure whether the afc protocol (i-phone) is appropriate here. Safer to assume it is.
        is_no_info = ("cdda mtp gphoto2 ssh sftp afp afc dav davs".contains (scheme));
        is_local = is_trash || is_recent || (scheme == "file");
        is_network = !is_local && ("smb ftp sftp afp dav davs".contains (scheme));

        file_hash = new HashTable<GLib.File, Files.File> (GLib.File.hash, GLib.File.equal);

        if (is_recent) {
            Files.Preferences.get_default ().notify["remember-history"].connect (() => {
                schedule_reload ();
            });

            schedule_reload ();
        }
    }

    ~Directory () {
        debug ("Directory destruct %s", file.uri);
        if (is_trash) {
            disconnect_volume_monitor_signals ();
        }
    }

    /** Views call the following function with null parameter - file_added and done_loading
      * signals are emitted and cause the view and view container to update.
      *
      * LocationBar calls this function, with a callback, on its own Directory instances in order
      * to perform filename completion.- Emitting a done_loaded signal in that case would cause
      * the premature ending of text entry.
     **/
    public async bool init (FileLoadedFunc? file_loaded_func = null, DoneLoadingFunc? done_loading_func = null) {
        if (state == State.LOADING) {
            debug ("Directory Init re-entered - already loading");
            return false; /* Do not re-enter */
        }

        var previous_state = state;
        loaded_from_cache = false;

        cancellable.cancel ();
        cancellable = new Cancellable ();

        /* If we already have a loaded file cache just list them */
        if (previous_state == State.LOADED) {
            // list_cached_files (file_loaded_func);
            list_cached_files (file_loaded_func, done_loading_func);
        /* else fully initialise the directory */
        } else {
            state = State.LOADING;
            yield prepare_directory (file_loaded_func, done_loading_func);
        }
        /* done_loaded signal is emitted when ready */
        return true;
    }

    /* This is also called when reloading the directory so that another attempt to connect to
     * the network is made
     */
    private async void prepare_directory (FileLoadedFunc? file_loaded_func, DoneLoadingFunc? done_loading_func) {
        debug ("Preparing directory for loading");
        /* Force info to be refreshed - the Files.File may have been created already by another part of the program
         * that did not ensure the correct info Aync purposes, and retrieved from cache (bug 1511307).
         */
        file.info = null;
        bool success = yield get_file_info ();

        if (success) {
            if (!is_no_info && !file.is_folder () && !file.is_root_network_folder ()) {
                critical ("Trying to load a non-folder - finding parent");
                var parent = file.is_connected ? location.get_parent () : null;
                if (parent != null) {
                    file = Files.File.get (parent);
                    selected_file = location;
                    location = parent;
                    success = yield get_file_info ();
                } else {
                    warning ("Parent is null for file %s", file.uri);
                    success = false;
                }
            }
        }

        if (success) {
            file.update ();
        }

        debug (
            "is connected %s, success %s; enclosing mount %s",
            file.is_connected.to_string (),
            success.to_string (),
            file.mount != null ? file.mount.get_name () : "null"
        );

        /* Only place that should call make_ready function */
        yield make_ready (is_no_info || success, file_loaded_func, done_loading_func); /* Only place that should call this function */
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
            return GLib.Source.REMOVE;
        });

        bool success = yield query_info_async (file, cancellable);
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
            debug ("success %s; enclosing mount %s", success.to_string (),
                                                     file.mount != null ? file.mount.get_name () : "null");
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

                    return GLib.Source.REMOVE;
                } else {
                    return GLib.Source.CONTINUE;
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

            debug ("mounting…");
            res = yield location.mount_enclosing_volume (GLib.MountMountFlags.NONE, mount_op, cancellable);
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

        debug ("success %s; enclosing mount %s", res.to_string (),
                                                 file.mount != null ? file.mount.get_name () : "null");
        return res;
    }

    public async bool check_network () {
        debug ("check network");
        unowned var net_mon = GLib.NetworkMonitor.get_default ();
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
                        scl.set_tls (FileUtils.get_is_tls_for_protocol (scheme));
                        debug ("Trying to connect to connectable");
                        var default_port = FileUtils.get_default_port_for_protocol (scheme);
                        var sc = yield scl.connect_to_uri_async (file.uri, default_port, cancellable);
                        success = (sc != null && sc.is_connected ());
                        debug ("Socketclient is %s",
                                sc == null ? "null" : (sc.is_connected () ? "connected" : "not connected"));

                    } catch (GLib.Error e) {
                        last_error_message = e.message;
                        warning ("Error: could not connect to connectable %s: %s", file.uri, e.message);
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

    private async void make_ready (bool ready, FileLoadedFunc? file_loaded_func, DoneLoadingFunc? done_loading_func) {
        debug ("make ready");
        can_load = ready;

        if (is_recent) {
            if (!Files.Preferences.get_default ().remember_history) {
                state = State.NOT_LOADED;
                can_load = false;
            }
        }

        if (!can_load) {
            debug ("Cannot load %s.  Connected %s, Mounted %s, Exists %s", file.uri,
                                                                           file.is_connected.to_string (),
                                                                           file.is_mounted.to_string (),
                                                                           file.exists.to_string ());
            directory_cache.remove (creation_key);
            is_ready = false;
            after_loading (done_loading_func);
            return;
        }

        if (!is_ready) {
            is_ready = true;

            // Do not add toggle until cached
            lock (directory_cache) {
                // Creation key will normally be the final location but check anyway.
                if (!(creation_key.equal (location))) {
                    warning ("creation key %s differs from final location %s", creation_key.get_uri (), location.get_uri ());
                    directory_cache.remove (creation_key);
                }

                if (directory_cache.lookup (location) == null) {
                    directory_cache.insert (location, this);
                    // Replace the cache reference with a toggle ref
                    this.add_toggle_ref ((ToggleNotify) toggle_ref_notify);
                    this.unref ();
                }
            }
        }

        /* The following can run on reloading */
        if (file.mount != null) {
            debug ("Directory has mount point");
            var trash_dirs = Files.FileOperations.get_trash_dirs_for_mount (file.mount);
            has_trash_dirs = (trash_dirs != null);
        } else {
            has_trash_dirs = is_local;
        }

        /* Do not use root trash_dirs (Move to the Rubbish Bin option will not be shown) */
        has_trash_dirs = has_trash_dirs && (Posix.getuid () != 0);

        set_confirm_trash ();

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

        yield list_directory_async (file_loaded_func, done_loading_func);
    }

    private void set_confirm_trash () {
        bool to_confirm = true;
        if (is_trash) {
            to_confirm = false;
            var mounts = VolumeMonitor.get ().get_mounts ();
            if (mounts != null) {
                foreach (unowned var m in mounts) {
                    to_confirm |= (m.can_eject () && Files.FileOperations.has_trash_files (m));
                }
            }
        }
        Preferences.get_default ().confirm_trash = to_confirm;
    }

    private void connect_volume_monitor_signals () {
        var vm = VolumeMonitor.get ();
        vm.mount_changed.connect (on_mount_changed);
        vm.mount_added.connect (on_mount_changed);
    }
    private void disconnect_volume_monitor_signals () {
        var vm = VolumeMonitor.get ();
        vm.mount_changed.disconnect (on_mount_changed);
        vm.mount_added.disconnect (on_mount_changed);
    }

    private void on_mount_changed (GLib.VolumeMonitor vm, GLib.Mount mount) {
        if (state == State.LOADED) {
            schedule_reload ();
        }
    }

    private static void toggle_ref_notify (void* data, Object object, bool is_last) {
        // unowned Directory dir = (Directory) object;
        if (is_last) {
            var dir = (Directory) object; // Adds a reference temporarily
            // Replace the toggle ref with a normal ref before removing from cache
            dir.remove_toggle_ref ((ToggleNotify) toggle_ref_notify);
            if (!dir.removed_from_cache) {
                Directory.remove_dir_from_cache (dir);
            }
        }
    }

    public void cancel () {
        /* This should only be called when closing the view -
         * it will cancel initialisation of the directory */
        cancellable.cancel ();
        cancel_timeouts ();
    }

    uint reload_timeout_id = 0;
    public void schedule_reload () {
        will_reload (); // Signal client slots to prepare
        if (reload_timeout_id > 0) {
            warning ("Reload request received too rapidly");
            return;
        }

        debug ("Reload - state is %s", state.to_string ());
        if (state == State.TIMED_OUT && file.is_mounted) {
            debug ("Unmounting because of timeout");
            cancellable.cancel ();
            cancellable = new Cancellable ();
            file.location.unmount_mountable_with_operation.begin (
                GLib.MountUnmountFlags.FORCE,
                null,
                cancellable
            );
            file.mount = null;
            file.is_mounted = false;
        }

        reload_timeout_id = Timeout.add (100, () => {
            clear_directory_info ();
            init.begin ();
            reload_timeout_id = 0;
            return GLib.Source.REMOVE;
        });
    }

    /** Called in preparation for a reload **/
    private void clear_directory_info () {
        if (state == State.LOADING) {
            return; /* Do not re-enter */
        }

        cancel ();
        file_hash.remove_all ();
        monitor = null;
        sorted_dirs = null;
        displayed_files_count = 0;
        can_load = false;
        state = State.NOT_LOADED;
        loaded_from_cache = false;
        /* Do not change @is_ready to false - we do not want to
         * perform caching amd adding toggle ref again  */

        /* These will be reconnected if directory still (or now) loadable */
        if (monitor != null) {
            monitor.changed.disconnect (directory_changed);
        }

        if (is_trash) {
            disconnect_volume_monitor_signals ();
        }
    }

    // private void list_cached_files (FileLoadedFunc? file_loaded_func) {
    private void list_cached_files (FileLoadedFunc? file_loaded_func, DoneLoadingFunc? done_loading_func) {
        debug ("list cached files");
        if (state != State.LOADED) {
            critical ("list cached files called in %s state - not expected to happen", state.to_string ());
            return;
        }

        state = State.LOADING;
        displayed_files_count = 0;
        foreach (unowned Files.File gof in file_hash.get_values ()) {
            if (gof != null) {
                after_load_file (gof, file_loaded_func);
            }
        }

        state = State.LOADED;
        loaded_from_cache = true;

        after_loading (done_loading_func);
    }

    private async void list_directory_async (FileLoadedFunc? file_loaded_func, DoneLoadingFunc? done_loading_func) {
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
        permission_denied = false;
        can_load = true;
        displayed_files_count = 0;
        state = State.LOADING;

        try {
            var e = yield this.location.enumerate_children_async (gio_attrs, 0, Priority.HIGH, cancellable);
            debug ("Obtained file enumerator for location %s", location.get_uri ());

            Files.File? gof;
            GLib.File loc;
            while (!cancellable.is_cancelled ()) {
                try {
                    /* This may hang for a long time if the connection was closed but is still mounted so we
                     * impose a time limit */
                    load_timeout_id = Timeout.add_seconds_full (GLib.Priority.LOW, ENUMERATE_TIMEOUT_SEC, () => {
                        warning ("Load timeout expired");
                        state = State.TIMED_OUT;
                        load_timeout_id = 0;
                        cancellable.cancel ();
                        load_timeout_id = 0;
                        return GLib.Source.REMOVE;
                    });

                    var files = yield e.next_files_async (1000, GLib.FileQueryInfoFlags.NOFOLLOW_SYMLINKS, cancellable);
                    cancel_timeout (ref load_timeout_id);

                    if (files == null) {
                        break;
                    } else {
                        foreach (unowned var file_info in files) {
                            loc = location.get_child (file_info.get_name ());
                            assert (loc != null);
                            gof = Files.File.cache_lookup (loc);

                            if (gof == null) {
                                gof = new Files.File (loc, location); /*does not add to GOF file cache */
                            }

                            gof.info = file_info;
                            gof.update ();

                            file_hash.insert (gof.location, gof);
                            after_load_file (gof, file_loaded_func);
                        }
                    }
                } catch (Error e) {
                    if (!(state == State.TIMED_OUT)) {
                        last_error_message = e.message;
                    } else {
                        last_error_message = _("Server did not respond within time limit");
                    }
                    warning ("Error reported by next_files_async: %s", e.message);
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
            after_loading (done_loading_func);
        }
    }

    private void after_load_file (Files.File gof, FileLoadedFunc? file_loaded_func) {
        displayed_files_count++;

        if (file_loaded_func == null) {
            file_added (gof, true);
        } else {
            file_loaded_func (gof);
        }
    }

    private void after_loading (DoneLoadingFunc? done_loading_func) {
        /* If loading failed reset */
        debug ("after loading state is %s", state.to_string ());
        if (state == State.LOADING || state == State.TIMED_OUT) {
            state = State.TIMED_OUT; /* else clear directory info will fail */
            can_load = false;
        }

        if (state != State.LOADED) {
            clear_directory_info ();
        }

        if (done_loading_func == null) {
            done_loading ();
        } else {
            done_loading_func ();
        }
        //It is up to each view to update file expanded count as needed;
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

    public List<unowned Files.File> get_files () {
        return file_hash.get_values ();
    }

    public void update_files () {
        foreach (unowned Files.File gof in file_hash.get_values ()) {
            if (gof != null && gof.info != null) {
                gof.update ();
            }
        }
    }

    public void update_desktop_files () {
        foreach (unowned Files.File gof in file_hash.get_values ()) {
            if (gof != null && gof.info != null && gof.is_desktop) {
                gof.update_desktop_file ();
            }
        }
    }

    public Files.File? file_hash_lookup_location (GLib.File? location) {
        if (location != null && location is GLib.File) {
            Files.File? result = file_hash.lookup (location);
            /* Although file_hash.lookup returns an unowned value, Vala will add a reference
             * as the return value is owned.  This matches the behaviour of Files.File.cache_lookup */
            return result;
        } else {
            return null;
        }
    }

    public void file_hash_add_file (Files.File gof) { /* called directly by Files.File */
        file_hash.insert (gof.location, gof);
    }

    public Files.File file_cache_find_or_insert (GLib.File file, bool update_hash = false) {
        Files.File? result = file_hash.lookup (file);
        /* Although file_hash.lookup returns an unowned value, Vala will add a reference
         * as the return value is owned.  This matches the behaviour of Files.File.cache_lookup */
        if (result == null) {
            result = Files.File.cache_lookup (file);

            if (result == null) {
                result = new Files.File (file, location);
                file_hash.insert (file, result);
            } else if (update_hash) {
                file_hash.insert (file, result);
            }
        }

        result.is_gone = false;
        return (!) result;
    }

    /**TODO** move this to Files.File */
    private delegate void func_query_info (Files.File gof);

    private async bool query_info_async (Files.File gof, Cancellable? cancellable = null) {
        gof.info = null;
        try {
            gof.info = yield gof.location.query_info_async (gio_attrs,
                                                            FileQueryInfoFlags.NONE,
                                                            Priority.DEFAULT,
                                                            cancellable);
        } catch (Error err) {
            last_error_message = err.message;
            debug ("query info failed, %s %s", err.message, gof.uri);
            if (err is IOError.NOT_FOUND) {
                gof.exists = false;
            }
        }

        return gof.info != null;
    }

    public void changed_and_refresh (Files.File file) {
        if (file.thumbstate == Files.File.ThumbState.LOADED) {
            file.thumbstate = Files.File.ThumbState.UNKNOWN;
        }
        var tp = file.get_thumbnail_path ();
        // cannot tell what has changed so force update of thumbnail in cache
        if (tp != null) {
            IconInfo.remove_cache (tp);
        }

        file.update ();
        // Signal views to update
        file_changed (file);
    }

    private void add_and_refresh (Files.File gof, bool is_internal) {
        if (gof.info == null) {
            critical ("FILE INFO null");
        }

        gof.update ();
        file_added (gof, is_internal);

        if (!gof.is_hidden && gof.is_folder ()) {
            /* add to sorted_dirs */
            if (sorted_dirs.find (gof) == null) {
                sorted_dirs.insert_sorted (gof,
                    Files.File.compare_by_display_name);
            }
        }
    }

    private void notify_file_changed (Files.File gof) {
        query_info_async.begin (gof, null, () => {
            changed_and_refresh (gof);
        });
    }

    private void notify_file_added (Files.File gof, bool is_internal) {
        query_info_async.begin (gof, null, () => {
            add_and_refresh (gof, is_internal);
        });
    }

    private void notify_file_removed (Files.File gof) {
        remove_file_from_cache (gof);
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
        if (gof.is_folder ()) {
            (GLib.Application.get_default ()).activate_action (
                "folder-deleted",
                new Variant ("s", gof.uri)
            );
        }
    }

    private struct FChanges {
        GLib.File file;
        FileMonitorEvent event;
    }
    private List <FChanges?> list_fchanges = null;
    private uint list_fchanges_count = 0;
    /* number of monitored changes to store after that simply reload the dir */
    private const uint FCHANGES_MAX = 20;

    private void directory_changed (GLib.File _file, GLib.File? other_file, FileMonitorEvent event) {
        /* If view is frozen, store events for processing later */
        if (freeze_update) {
            if (list_fchanges_count < FCHANGES_MAX) {
                var fc = FChanges ();
                fc.file = _file;
                fc.event = event;
                list_fchanges.prepend (fc);
                list_fchanges_count++;
            }
            return;
        } else {
            real_directory_changed (_file, other_file, event);
        }
    }

    // We do not monitor MOVED events as these are also associated with CREATED and DELETED events
    private void real_directory_changed (GLib.File _file, GLib.File? other_file, FileMonitorEvent event) {
        switch (event) {
        case FileMonitorEvent.CREATED:
            Files.FileChanges.queue_file_added (_file, false);
            break;
        case FileMonitorEvent.DELETED:
            Files.FileChanges.queue_file_removed (_file);
            break;
        case FileMonitorEvent.CHANGES_DONE_HINT: /* test  last to avoid unnecessary action when file renamed */
        case FileMonitorEvent.ATTRIBUTE_CHANGED:
            Files.FileChanges.queue_file_changed (_file);
            break;
        default:
            break;
        }

        if (idle_consume_changes_id == 0) {
            /* Insert delay to avoid race between gof.rename () finishing and consume changes -
             * If consume changes called too soon can corrupt the view.
             * TODO: Have Files.Directory.Directory control renaming.
             */
            idle_consume_changes_id = Timeout.add (10, () => {
                Files.FileChanges.consume_changes (true);
                idle_consume_changes_id = 0;
                return GLib.Source.REMOVE;
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
                    schedule_reload ();
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
        foreach (unowned var loc in files) {
            assert (loc != null);
            Directory? parent_dir = cache_lookup_parent (loc);
            Files.File? gof = null;
            if (parent_dir != null) {
                gof = parent_dir.file_cache_find_or_insert (loc);
                parent_dir.notify_file_changed (gof);
            }

            /* Has a background directory been changed (e.g. properties)? If so notify the view(s)*/
            Directory? dir = cache_lookup (loc);
            if (dir != null) {
                dir.notify_file_changed (dir.file);
            }
        }
    }

    public static void notify_changes_added (List<Files.FileChanges.Change> changes) {
        foreach (unowned var change in changes) {
            unowned var loc = change.from;
            Directory? dir = cache_lookup_parent (loc);

            if (dir != null) {
                Files.File gof = dir.file_cache_find_or_insert (loc, true);
                dir.notify_file_added (gof, change.is_internal);
            }
        }
    }

    // Only call in relation to internal file operations
    public static void notify_files_added_internally (List<GLib.File> files) {
        foreach (unowned var loc in files) {
            Directory? dir = cache_lookup_parent (loc);

            if (dir != null &&
                dir.file_hash_lookup_location (loc) == null) { // Avoid duplicate signals

                Files.File gof = dir.file_cache_find_or_insert (loc, true);
                dir.notify_file_added (gof, true);
            }
        }
    }

    public static void notify_files_removed (List<GLib.File> files) {
        List<Directory> dirs = null;
        bool found;

        foreach (unowned var loc in files) {
            if (loc == null) {
                continue;
            }

            Directory? dir = cache_lookup_parent (loc);

            if (dir != null) {
                Files.File gof = dir.file_cache_find_or_insert (loc);
                dir.notify_file_removed (gof);
                found = false;

                foreach (var d in dirs) {
                    if (d == dir) {
                        found = true;
                        break;
                    }
                }

                if (!found) {
                    dirs.prepend (dir);
                }
            } else {
                dir = cache_lookup (loc);
                if (dir != null) {
                    dir.file_deleted (dir.file);
                }
            }
        }
    }

    //Only called internally as FileMonitorEvent.MOVED events not handled
    public static void notify_files_moved (List<GLib.Array<GLib.File>> files) {
        var list_from = new List<GLib.File> ();
        var list_to = new List<GLib.File> ();

        foreach (unowned var pair in files) {
            unowned GLib.File from = pair.index (0);
            unowned GLib.File to = pair.index (1);

            list_from.prepend (from);
            list_to.prepend (to);
        }

        notify_files_removed (list_from);
        notify_files_added_internally (list_to);
    }

    public static Directory from_file (Files.File gof) {
        return from_gfile (gof.get_target_location ());
    }

    private static void remove_file_from_cache (Files.File gof) {
        Directory? dir = cache_lookup (gof.directory);
        if (dir != null) {
            dir.file_hash.remove (gof.location);
        }
    }

    /* Files.Directory.directory_cache related functions */
    public static Directory? cache_lookup (GLib.File file) {
        // Cache may be null on startup. Static construct only runs when first
        // Directory is constructed
        if (directory_cache == null) {
            return null;
        }

        var cached_dir = directory_cache.lookup (file);
        if (cached_dir != null) {
            if (cached_dir is Directory && cached_dir.file != null) {
                if (cached_dir.file.info == null && cached_dir.can_load) {
                    cached_dir.file.query_update (); /* This is synchronous and causes blocking */
                }
            } else {
                warning ("Invalid directory found in cache key %s, removing", file.get_basename ());
                if (cached_dir.file == null) {
                    warning ("cached dir file is null");
                    warning ("creation key %s", cached_dir.creation_key.get_basename ());
                }
                cached_dir = null;
                lock (directory_cache) {
                    directory_cache.remove (file);
                }
            }
        } else {
            debug ("Dir %s not in cache", file.get_uri ());
        }

        return cached_dir;
    }

    public static Directory? cache_lookup_parent (GLib.File file) {
        GLib.File? parent = file.get_parent ();
        return parent != null ? cache_lookup (parent) : cache_lookup (file);
    }

    public static bool remove_dir_from_cache (Directory dir) {
        assert_nonnull (dir);
        debug ("remove dir from cache %s", dir.creation_key.get_basename () );
        lock (directory_cache) {
            if ((directory_cache.lookup (dir.location) != null) ||
                (directory_cache.lookup (dir.creation_key) != null)) {

                directory_cache.remove (dir.location);
                directory_cache.remove (dir.creation_key);
                dir.removed_from_cache = true;
                return true;
            }
        }

        return false;
    }

    public static bool purge_dir_from_cache (Directory dir) {
        var removed = Directory.remove_dir_from_cache (dir);
        /* We have to remove the dir's subfolders from cache too */
        if (removed) {
            foreach (unowned var gfile in dir.file_hash.get_keys ()) {
                assert (gfile != null);
                var d = cache_lookup (gfile);
                if (d != null) {
                    Directory.remove_dir_from_cache (d);
                }
            }
        }

        return removed;
    }

    // For testing only
    public static void empty_dir_cache () {
        Files.Directory.directory_cache.remove_all ();
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
        return (state != State.LOADED || file_hash.size () == 0);
    }

    public unowned List<unowned Files.File>? get_sorted_dirs () {
        if (state != State.LOADED) { /* Can happen if pathbar tries to load unloadable directory */
            return null;
        }

        if (sorted_dirs != null) {
            return sorted_dirs;
        }

        foreach (unowned var gof in file_hash.get_values ()) { /* returns owned values */
            if (!gof.is_hidden && (gof.is_folder () || gof.is_smb_server ())) {
                sorted_dirs.prepend (gof);
            }
        }

        sorted_dirs.sort (Files.File.compare_by_display_name);
        return sorted_dirs;
    }

    private void cancel_timeouts () {
        cancel_timeout (ref idle_consume_changes_id);
        cancel_timeout (ref load_timeout_id);
        cancel_timeout (ref mount_timeout_id);
        cancel_timeout (ref reload_timeout_id);
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
