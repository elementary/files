/***
    Copyright (c) 2016 elementary LLC (http://launchpad.net/elementary)

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
    License along with this program; see the file COPYING.  If not,
    write to the Free Software Foundation, Inc., 59 Temple Place - Suite 330,
    Boston, MA 02111-1307, USA.

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


namespace Marlin {
    [DBus (name = "org.freedesktop.thumbnails.Thumbnailer1")]
    public interface ThumbnailerDaemon : GLib.DBusProxy {
        public signal void started (uint handle);
        public signal void finished (uint handle);
        public signal void ready (uint handle, string[] uris);
        public signal void error (uint handle, string[] failed_uris, int error_code, string message);

        public abstract async uint queue (string[] uris, string[] mime_types, string flavor,
                                          string scheduler, uint handle_to_unqueue) throws IOError;
//~         public abstract async bool queue (string[] uris, string[] mime_types, string flavor,
//~                                           string scheduler, uint handle_to_unqueue, out uint handle) throws IOError;
        public abstract async void dequeue (uint handle) throws IOError;
        public abstract void get_supported (out string[] uri_schemes, out string[] mime_types) throws IOError;
//~         public abstract async get_schedulers (out string[] schedulers) throws IOError;
//~         public abstract async get_flavors (out string[] flavors) throws IOError;
    }

    public class Thumbnailer : GLib.Object {

        enum IdleType {
            ERROR,
            READY,
            STARTED
        }

        struct Idle {
            uint id;
            IdleType type;
            string[] uris;
//~             void* request;
        }

//~         struct Item {
//~             GOF.File file;
//~             string mime_hint;
//~         }

        private static ThumbnailerDaemon proxy;
        private static Thumbnailer? instance;

        private Mutex thumbnailer_lock;

        private string [] supported_schemes = null;
        private string [] supported_types = null;

        private GLib.HashTable<uint, uint> handle_request_mapping;
        private GLib.HashTable<uint, uint> request_handle_mapping;
//~         private GLib.HashTable<uint, uint> request_call_mapping;

        private GLib.List<Idle?> idles;

        private uint last_request = 0;

        public bool has_proxy = false;

        private Thumbnailer () {
            if (proxy == null) {
                try {
                    proxy = GLib.Bus.get_proxy_sync (GLib.BusType.SESSION,
                                                     "org.freedesktop.thumbnails.Thumbnailer1",
                                                     "/org/freedesktop/thumbnails/Thumbnailer1");
                }
                catch (GLib.Error e) {
                    critical ("Failed to connect to system thumbnailing service (tumbler) - %s", e.message);
                    proxy = null;
                    return;
                }

                request_handle_mapping = new GLib.HashTable<uint, uint> (direct_hash, direct_equal); /* use default direct comparison functions */
                handle_request_mapping = new GLib.HashTable<uint, uint> (direct_hash, direct_equal); /* use default direct comparison functions */

                proxy.started.connect (on_proxy_started);
                proxy.finished.connect (on_proxy_finished);
                proxy.ready.connect (on_proxy_ready);
                proxy.error.connect (on_proxy_error);

                thumbnailer_lock = Mutex ();

                assert (request_handle_mapping != null);
                message ("NEW THUMBNAILER");
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
            if (instance == null || !instance.has_proxy) {
                instance =  new Thumbnailer ();
            }
            return instance;
        }

        public bool queue_file (GOF.File file, out uint request, bool large) {
            GLib.List<GOF.File> files = null;
            files.append (file);
            uint this_request = 0;
            bool success = queue_files (files, out this_request, large);
            request = this_request;
            return success;
        }

        public bool queue_files (GLib.List<GOF.File> files, out uint request, bool large) {
message ("queue files");
            request = 0;
            if (proxy == null) {
message ("no proxy");
                return false;
            }

            GLib.List<GOF.File> supported_files = null;

            uint file_count = 0;
            foreach (var file in files) {
                if (is_supported (file)) {
                    supported_files.prepend (file);
                    file.flags = GOF.File.ThumbState.LOADING;
                    file_count++;
                } else {
message ("%s not supported", file.uri);
                    file.flags = GOF.File.ThumbState.NONE;
                }
            }

            if (file_count == 0) {
message ("no supported files");
                return false;
            }

            var uris = new string[file_count];
            var mime_hints = new string[file_count];

            supported_files.reverse ();

            uint index = 0;
            foreach (var file in supported_files) {
message ("adding uri %s", file.uri);
                uris[index] = file.uri;
message ("adding ftype %s", file.get_ftype ());
                mime_hints[index] = file.get_ftype ();
                index++;
            }
//~             uris[index] = null;
//~             mime_hints[index] = null;

            var this_request = ++last_request;
            var flavor = large ? "large" : "normal";
            var scheduler = "foreground";
message ("begin queue call");
            assert (request_handle_mapping != null);
            proxy.queue.begin (uris, mime_hints, flavor, scheduler, 0, (obj, res) => {
                try {
message ("end queue call");
                    uint handle = 0;
                    handle = proxy.queue.end (res);
//~                     proxy.queue.end (res, out handle);
                    if (handle > 0) {
message ("got handle %u", handle);
                        this.request_handle_mapping.insert (this_request, handle);
                        this.handle_request_mapping.insert (handle, this_request);
                    } else {
                        warning ("No handle returned from proxy call Queue");
                    }
                } catch (GLib.Error e) {
                    warning ("Thumbnailer proxy request %u failed - %s", this_request, e.message);
                }
            });

            request = this_request;
            return true;
        }

        public void dequeue (uint request) {
            if (proxy == null) {
                return;
            }

            thumbnailer_lock.@lock ();

            var handle = request_handle_mapping.lookup (request);

            proxy.dequeue (handle);
            handle_request_mapping.remove (handle);
            request_handle_mapping.remove (request);

            thumbnailer_lock.unlock ();
        }

        private bool is_supported (GOF.File file) {
            /* TODO cache supported combinations */
            var ftype = file.get_ftype ();
            if (proxy == null || ftype == null) {
warning ("null proxy or content type");
                return false;
            }
            bool supported = false;

            thumbnailer_lock.@lock ();

            if (supported_schemes == null) {
                try {
                    proxy.get_supported (out supported_schemes, out supported_types);
                } catch (GLib.Error e) {
                    warning ("Thumbnailer failed to get supported file list");
                    return false;
                }
            }
            if (supported_schemes != null && supported_types != null) {
                uint index = 0;
                foreach (string scheme in supported_schemes) {
                    if (file.location.has_uri_scheme (scheme) &&
                       GLib.ContentType.is_a (ftype, supported_types[index])) {
message ("%s is supported type for %s", ftype, scheme);
                        supported = true;
                        break;
                    }
                    index++;
                }
            } else {
                warning ("No supported schemes or types returned by proxy");
            }

            thumbnailer_lock.unlock ();

            return supported;
        }

        private void on_proxy_error (uint handle, string[] failed_uris,
                                     int error_code, string msg) {

message ("proxy error %s", msg);

            var request = handle_request_mapping.lookup (handle);

            if (request > 0) {
                var idle = Idle ();
                idle.type = IdleType.ERROR;
                idle.uris = GLib.strdupv (failed_uris);
                idles.prepend (idle);

                /* TODO batch up errors? */
                idle.id = GLib.Idle.add_full (GLib.Priority.LOW, () => {
                    handle_error_idle (idle);
                    return false;
                });
            } else {
                warning ("Failed to get matching handle");
            }
        }


        private void on_proxy_started (uint handle) {
message ("started %u", handle);
        }

        private void on_proxy_ready (uint handle, string[] ready_uris) {
message ("ready handle %u", handle);
            if (ready_uris != null) {
                var idle = Idle ();
                idle.type = IdleType.READY;
                idle.uris = GLib.strdupv (ready_uris);
                idles.prepend (idle);

                /* TODO batch up errors? */
                idle.id = GLib.Idle.add_full (GLib.Priority.LOW, () => {
                    handle_ready_idle (idle);
                    return false;
                });
            } else {
                warning ("no ready uris");
            }
        }

        private void on_proxy_finished (uint handle) {
message ("finished handle %u", handle);
            var request = handle_request_mapping.lookup (handle);
            request_handle_mapping.remove (request);
            handle_request_mapping.remove (handle);
        }

//~         private void queue_async_reply (uint handle) {

//~         }

//~         private uint queue_async (string[] uris, string[] mime_hints, bool large) {

//~         }

        private void handle_error_idle (Idle error_idle) {
message ("handle error idle");
            foreach (string uri in error_idle.uris) {
                var goffile = GOF.File.get_by_uri (uri);
                if (goffile != null && goffile.flags != GOF.File.ThumbState.READY) {
                    goffile.flags = GOF.File.ThumbState.NONE;
                }
            }

            thumbnailer_lock.@lock ();
            idles.remove (error_idle);
            thumbnailer_lock.unlock ();
        }

        private void handle_ready_idle (Idle ready_idle) {
message ("handle ready idle");
            foreach (string uri in ready_idle.uris) {
                var goffile = GOF.File.get_by_uri (uri);
                goffile.flags = GOF.File.ThumbState.READY;
            }

            thumbnailer_lock.@lock ();
            idles.remove (ready_idle);
            thumbnailer_lock.unlock ();
        }
    }

}
