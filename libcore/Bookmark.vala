/***
 * Copyright (c)  1999, 2000 Eazel, Inc.
 * Copyright 2015 - 2023 elementary, Inc. <https://elementary.io>
 * SPDX-License-Identifier: GPL-3.0-or-later
***/

namespace Files {
    public class Bookmark : Object {
        public signal void contents_changed ();
        public signal void deleted ();

        public string custom_name { get; set; default = "";}

        public Files.File gof_file { get; construct; }

        public string basename {
            get { return gof_file.get_display_name (); }
        }

        public string uri {
            get {
                return gof_file.uri;
            }
        }

        private GLib.FileMonitor monitor;

        // Do not consider custom name when comparing bookmarks.  We only want one bookmark per URI.
        public static CompareFunc<Bookmark> compare_with = (a, b) => {
            return a.gof_file.location.equal (b.gof_file.location) ? 0 : 1;
        };

        public Bookmark (Files.File gof_file, string label = "") {
            Object (
                gof_file: gof_file,
                custom_name: label
            );
        }

        public Bookmark.from_uri (string uri, string label = "") {
            Object (
                gof_file: Files.File.get_by_uri (uri),
                custom_name: label
            );
        }

        construct {
            //Ensure correct icon is available
            gof_file.ensure_query_info ();
            connect_file ();
        }

        public Bookmark copy () {
            return new Bookmark (gof_file, this.custom_name);
        }

        public unowned GLib.File get_location () {
            return this.gof_file.location;
        }

        public string get_parse_name () {
            return this.get_location ().get_parse_name ();
        }

        public GLib.Icon get_icon () {
            if (gof_file.gicon != null) {
                return gof_file.gicon;
            } else {
                // Get minimal info to determine icon
                var ftype = gof_file.location.query_file_type (FileQueryInfoFlags.NONE);
                if (ftype == FileType.DIRECTORY) {
                    try {
                        var path = GLib.Filename.from_uri (uri);
                        var icon = gof_file.get_icon_user_special_dirs (path);
                        if (icon != null) {
                            return icon;
                        } else {
                            return new ThemedIcon.with_default_fallbacks ("folder");
                        }
                    } catch (Error e) {
                        debug (e.message);
                        return new ThemedIcon.with_default_fallbacks ("folder");
                    }
                } else if (ftype == FileType.MOUNTABLE) {
                    return new GLib.ThemedIcon.with_default_fallbacks ("folder-remote");
                } else {
                    try {
                        var info = gof_file.location.query_info (
                            FileAttribute.STANDARD_CONTENT_TYPE, FileQueryInfoFlags.NONE
                        );
                        return ContentType.get_icon (
                            info.get_attribute_string (FileAttribute.STANDARD_CONTENT_TYPE)
                        );
                    } catch (Error e) {
                        debug ("Unable to get icon for %s", gof_file.uri);
                    }
                }
            }

            return new ThemedIcon.with_default_fallbacks ("unknown");
        }

        public bool uri_known_not_to_exist () {
            if (!gof_file.location.is_native ()) {
                return false;
            }

            string path_name = gof_file.location.get_path ();
            return !GLib.FileUtils.test (path_name, GLib.FileTest.EXISTS);
        }

        private void file_changed_callback (GLib.File file,
                                            GLib.File? other_file,
                                            GLib.FileMonitorEvent event_type) {
            switch (event_type) {
                case GLib.FileMonitorEvent.DELETED:
                        disconnect_file ();
                        deleted ();
                    break;

                case GLib.FileMonitorEvent.MOVED:
                        contents_changed ();
                    break;

                default:
                    break;
            }
        }

        private void disconnect_file () {
            if (monitor != null) {
                monitor.cancel ();
                monitor = null;
            }
        }

        private void connect_file () {
            if (gof_file.location.is_native ()) {
                try {
                    monitor = (this.get_location ()).monitor_file (GLib.FileMonitorFlags.SEND_MOVED, null);
                    monitor.changed.connect (file_changed_callback);
                }
                catch (GLib.Error error) {
                    warning ("Error connecting file monitor %s", error.message);
                }
            }
        }
    }
}
