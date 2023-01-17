/***
    Copyright (c) 2016-2018 elementary LLC <https://elementary.io>

    Largely transcribed from marlin-thumbnailer
    Copyright (c) 2009-2011 Jannis Pohlmann <jannis@xfce.org>
    Originaly Written in gtk+: gtkcellrendererpixbuf

    Pantheon Files is free software; you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation; either version 2 of the
    License, or (at your option) any later version.

    Pantheon Files is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
    General Public License for more details.

    You should have received a copy of the GNU General Public
    License along with this program; see the Timeoutfile COPYING.  If not,
    write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1335 USA.

    Author(s):  Jeremy Wootten <jeremy@elementaryos.org>

***/

/**
 * WARNING: The source code in this file may do harm to animals. Dead kittens
 * are to be expected.
 *
 *
 * MarlinThumbnailer is a class for requesting thumbnails from org.xfce.tumbler.*
 * D-Bus services. This header contains an in-depth description of its design to make
 * it easier to understand why things are the way they are.
 *
 * Please note that all D-Bus calls are performed asynchronously.
 *
 *
 * When a request call is sent out, an internal request ID is created and
 * associated with the corresponding DBusGProxyCall via the request_call_mapping hash
 * table.
 *
 * The D-Bus reply handler then checks if there was an delivery error or
 * not. If the request method was sent successfully, the handle returned by the
 * D-Bus thumbnailer is associated bidirectionally with the internal request ID via
 * the request_handle_mapping and handle_request_mappings. In both cases, the
 * association of the internal request ID with the DBusGProxyCall is removed from
 * request_call_mapping.
 *
 * These hash tables play a major role in the Finished, Error and Ready
 * signal handlers.
 *
 *
 * Ready / Error
 * =============
 *
 * The Ready and Error signal handlers work exactly like Started except that
 * the Ready idle function sets the thumb state of the corresponding
 * GOFFile objects to _READY and the Error signal sets the state to _NONE.
 *
 *
 * Finished
 * ========
 *
 * The Finished signal handler looks up the internal request ID based on
 * the D-Bus thumbnailer handle. It then drops all corresponding information
 * from handle_request_mapping and request_handle_mapping.
 */


namespace Files {
    [DBus (name = "org.freedesktop.thumbnails.Thumbnailer1")]
    public interface ThumbnailerDaemon : GLib.DBusProxy {
        public signal void started (uint handle);
        public signal void finished (uint handle);
        public signal void ready (uint handle, string[] uris);
        public signal void error (uint handle, string[] failed_uris, int error_code, string message);

        public abstract async uint queue (string[] uris, string[] mime_types, string flavor,
                                          string scheduler, uint handle_to_unqueue) throws GLib.DBusError, GLib.IOError;
        public abstract async void dequeue (uint handle) throws GLib.DBusError, GLib.IOError;
        public abstract void get_supported (out string[] uri_schemes,
                                            out string[] mime_types) throws GLib.DBusError, GLib.IOError;
    }

    public class Thumbnailer : GLib.Object {

        enum IdleType {
            ERROR,
            READY,
            STARTED,
            FINISHED
        }

        struct Idle {
            uint id;
            IdleType type;
            string[] uris;
            uint handle;
        }

        struct UriList {
            string[] uris;
        }


        private static Thumbnailer? instance;
        private static Mutex thumbnailer_lock;
        private static GLib.HashTable<uint, uint> request_handle_mapping;
        private static GLib.HashTable<uint, uint> handle_request_mapping;
        private static GLib.HashTable<uint, UriList?> handle_uris_mapping;
        private static GLib.List<Idle?> idles;

        private ThumbnailerDaemon proxy;
        private string [] supported_schemes = null;
        private string [] supported_types = null;

        private uint last_request = 0;

        public signal void finished (uint request);

        private Thumbnailer () {
            if (request_handle_mapping == null) {
                request_handle_mapping = new GLib.HashTable<uint, uint>.full (direct_hash, direct_equal, null, null);
                handle_request_mapping = new GLib.HashTable<uint, uint>.full (direct_hash, direct_equal, null,null);
                handle_uris_mapping = new GLib.HashTable<uint, UriList?>.full (direct_hash, direct_equal, null,null);
                thumbnailer_lock = Mutex ();
            }
        }

        private void init () {
            if (proxy == null) {
                try {
                    proxy = GLib.Bus.get_proxy_sync (GLib.BusType.SESSION,
                                                     "org.freedesktop.thumbnails.Thumbnailer1",
                                                     "/org/freedesktop/thumbnails/Thumbnailer1");
                }
                catch (GLib.Error e) {
                    critical ("Failed to connect to system thumbnailing service (tumbler): %s", e.message);
                    proxy = null;
                    return;
                }

                if (proxy != null) {
                    proxy.started.connect (on_proxy_started);
                    proxy.finished.connect (on_proxy_finished);
                    proxy.ready.connect (on_proxy_ready);
                    proxy.error.connect (on_proxy_error);
                }
            }
        }

        ~Thumbnailer () {
            thumbnailer_lock.@lock ();
            foreach (var idle in idles) {
                GLib.Source.remove (idle.id);
            }
            thumbnailer_lock.unlock ();
        }

        public new static Thumbnailer? @get () {
            if (instance == null) {
                instance = new Thumbnailer ();
                instance.init ();
            }

            return instance;
        }

        public bool queue_file (Files.File file, out int request, bool large) {
            GLib.List<Files.File> files = null;
            files.append (file);
            int this_request;
            bool success = queue_files (files, out this_request, large);
            request = this_request;
            return success;
        }

        public bool queue_files (GLib.List<Files.File> files, out int request, bool large) {
            request = -1;
            if (proxy == null) {
                return false;
            }

            GLib.List<Files.File> supported_files = null;

            uint file_count = 0;
            foreach (var file in files) {
                if (is_supported (file)) {
                    supported_files.prepend (file);
                    file.thumbstate = Files.File.ThumbState.LOADING;
                    file_count++;
                } else {
                    file.thumbstate = Files.File.ThumbState.NONE;
                }
            }

            if (file_count == 0) {
                return false;
            }

            var uris = new string[file_count];
            var mime_hints = new string[file_count];

            supported_files.reverse ();

            uint index = 0;
            foreach (var file in supported_files) {
                uris[index] = file.uri;
                mime_hints[index] = file.get_ftype ();
                index++;
            }

            uint this_request = ++last_request;
            var flavor = large ? "large" : "normal";
            var scheduler = "foreground";
            proxy.queue.begin (uris, mime_hints, flavor, scheduler, 0, (obj, res) => {
                try {
                    uint handle;
                    handle = proxy.queue.end (res);
                    request_handle_mapping.insert (this_request, handle);
                    handle_request_mapping.insert (handle, this_request);
                    // Save uris requested so we can check if any ignored (neither ready nor in error) when request finiahed.
                    // Arrays are not supported in HashTables so put into a boxed struct.
                    var uri_list = UriList () {
                        uris = uris
                    };
                    handle_uris_mapping.insert (handle, uri_list);
                } catch (GLib.Error e) {
                    warning ("Thumbnailer proxy request %u failed: %s", this_request, e.message);
                    foreach (var file in files) {
                        // Do not leave in LOADING state
                        file.thumbstate= Files.File.ThumbState.NONE;
                    }
                }
            });

            request = (int)this_request;
            return true;
        }

        public void dequeue (int request) {
            if (proxy == null) {
                return;
            }

            uint req = (uint)request;
            thumbnailer_lock.@lock ();
            uint handle = request_handle_mapping.lookup (req);
            thumbnailer_lock.unlock ();

            /* hash tables will be updated when "finished" signal received. Errors ignored */
            proxy.dequeue.begin (handle);
        }

        private bool is_supported (Files.File file) {
            /* TODO cache supported combinations */
            var ftype = file.get_ftype ();
            if (proxy == null || ftype == null) {
                return false;
            }

            bool supported = false;
            if (supported_schemes == null) {
                try {
                    proxy.get_supported (out supported_schemes, out supported_types);
                } catch (GLib.Error e) {
                    debug ("Thumbnailer failed to get supported file list");
                    return false;
                }
            }

            if (supported_schemes != null && supported_types != null) {
                uint index = 0;
                foreach (string scheme in supported_schemes) {
                    if (file.location.has_uri_scheme (scheme) &&
                       GLib.ContentType.is_a (ftype, supported_types[index])) {
                        supported = true;
                        break;
                    }
                    index++;
                }
            } else {
                debug ("No supported schemes or types returned by proxy");
            }

            return supported;
        }

        private static void on_proxy_error (uint handle, string[] failed_uris,
                                     int error_code, string msg) {

            var idle = Idle ();
            idle.type = IdleType.ERROR;
            idle.uris = GLib.strdupv (failed_uris);
            idles.prepend (idle);

            /* TODO batch up errors? */
            idle.id = GLib.Idle.add_full (GLib.Priority.LOW, () => {
                handle_error_idle (idle);
                return GLib.Source.REMOVE;
            });
        }


        private static void on_proxy_started (uint handle) {
            debug ("started %u", handle);
        }

        private static void on_proxy_ready (uint handle, string[] ready_uris) {
            if (ready_uris != null) {
                var idle = Idle ();
                idle.type = IdleType.READY;
                idle.uris = GLib.strdupv (ready_uris);
                idle.handle = handle;

                idles.prepend (idle);

                /* TODO batch up errors? */
                idle.id = GLib.Idle.add_full (GLib.Priority.HIGH, () => {
                    handle_ready_idle (idle);
                    return GLib.Source.REMOVE;
                });
            } else {
                warning ("no ready uris");
            }
        }

        private static void on_proxy_finished (uint handle) {
            var idle = Idle ();
            idle.type = IdleType.FINISHED;
            idle.handle = handle;
            idles.prepend (idle);

            /* TODO batch up errors? */
            idle.id = GLib.Idle.add_full (GLib.Priority.LOW, () => {
                handle_finished_idle (idle);
                return GLib.Source.REMOVE;
            });
        }

        private static void handle_error_idle (Idle error_idle) {
            foreach (string uri in error_idle.uris) {
                update_file_thumbstate (uri, Files.File.ThumbState.NONE);
            }

            thumbnailer_lock.@lock ();
            idles.remove (error_idle);
            thumbnailer_lock.unlock ();
        }

        private static void handle_ready_idle (Idle ready_idle) {
            foreach (string uri in ready_idle.uris) {
                update_file_thumbstate (uri, Files.File.ThumbState.READY);
            }

            thumbnailer_lock.@lock ();
            idles.remove (ready_idle);
            thumbnailer_lock.unlock ();
        }

        private static void handle_finished_idle (Idle finished_idle) {
            var handle = finished_idle.handle;
            unowned var uri_list = handle_uris_mapping.lookup (handle);
            foreach (var uri in uri_list.uris) {
                var goffile = Files.File.get_by_uri (uri);
                if (goffile.thumbstate == Files.File.ThumbState.LOADING) {
                    goffile.thumbstate = Files.File.ThumbState.NONE;
                }
            }

            thumbnailer_lock.@lock ();
            uint request = handle_request_mapping.lookup (handle);
            request_handle_mapping.remove (request);
            handle_request_mapping.remove (handle);
            thumbnailer_lock.unlock ();
            Thumbnailer.@get ().finished (request);
        }

        private static void update_file_thumbstate (string uri, Files.File.ThumbState state) {
            var goffile = Files.File.get_by_uri (uri);
            if (goffile != null) {
                goffile.thumbstate = state;
                goffile.update_gicon_and_paintable ();
                // Signal fileitem widgets to update
                goffile.icon_changed ();
            }
        }
    }
}
