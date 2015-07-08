/***
    Copyright (C) 2012 ammonkey <am.monkeyd@gmail.com>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

***/

namespace Marlin.View {

    public class OverlayBar : Granite.Widgets.OverlayBar {
        private Marlin.View.Window window;

        const int IMAGE_LOADER_BUFFER_SIZE = 8192;
        const int STATUS_UPDATE_DELAY = 200;
        const string[] SKIP_IMAGES = {"image/svg+xml", "image/tiff"};
        Cancellable? image_cancellable = null;
        bool image_size_loaded = false;
        private uint folders_count = 0;
        private uint files_count = 0;
        private uint64 files_size = 0;
        private GOF.File? goffile = null;
        private GLib.List<unowned GOF.File>? selected_files = null;
        private uint8 [] buffer;
        private GLib.FileInputStream? stream;
        private Gdk.PixbufLoader loader;
        private uint update_timeout_id = 0;

        public bool showbar = false;

        public OverlayBar (Marlin.View.Window win, Gtk.Overlay overlay) {
            base (overlay); /* this adds the overlaybar to the overlay (ViewContainer) */

            buffer = new uint8[IMAGE_LOADER_BUFFER_SIZE];
            status = "";

            window = win;
            window.selection_changed.connect (on_selection_changed);

            hide.connect (() => {
                /* when we're hiding, we no longer want to search for image size */
                if (image_cancellable != null)
                    image_cancellable.cancel ();
            });
        }

        private void on_selection_changed (GLib.List<GOF.File>? files = null) {
            if (files != null)
                selected_files = files.copy ();
            else
                selected_files = null;

            real_update (selected_files);
        }

        public void reset_selection () {
            selected_files = null;
        }

        public void update_hovered (GOF.File? file) {
            if (!showbar)
                return;

            cancel_update ();
            visible = false;

            update_timeout_id = GLib.Timeout.add_full (GLib.Priority.LOW, STATUS_UPDATE_DELAY, () => {
                GLib.List<GOF.File> list = null;
                if (file != null) {
                    bool matched = false;
                    if (selected_files != null) {
                        selected_files.@foreach ((f) => {
                            if (f == file)
                                matched = true;
                        });
                    }

                    if (matched)
                        real_update (selected_files);
                    else {
                        list.prepend (file);
                        real_update (list);
                    }
                } else 
                    real_update (null);

                update_timeout_id = 0;
                return false;
            });
        }

        public void cancel_update () {
            if (update_timeout_id > 0) {
                GLib.Source.remove (update_timeout_id);
                update_timeout_id = 0;
            }
        }

       private void real_update (GLib.List<GOF.File>? files) {
            goffile = null;
            folders_count = 0;
            files_count = 0;
            files_size = 0;
            status = "";

            if (files != null) {
                if (files.data != null) {
                    if (files.next == null)
                        /* list contain only one element */
                        goffile = files.first ().data;
                    else
                        scan_list (files);

                    status = update_status ();
                }
            }

            visible = showbar && (status.length > 0);
        }

        private string update_status () {
            /* if we're still collecting image info, cancel */
            if (image_cancellable != null) {
                image_cancellable.cancel ();
                image_cancellable = null;
            }

            string str = "";

            if (goffile != null) { /* a single file is hovered or selected */
                if (goffile.is_network_uri_scheme ()) {
                    str = goffile.get_display_target_uri ();
                } else if (!goffile.is_folder ()) {
                    /* if we have an image, see if we can get its resolution */
                    string? type = goffile.get_ftype ();
                    if (type != null && type.substring (0, 6) == "image/" && !(type in SKIP_IMAGES)) {
                        load_resolution.begin (goffile);
                    }
                    str = "%s (%s)".printf (goffile.formated_type, format_size ((int64) PropertiesWindow.file_real_size (goffile)));
                } else {
                    str = "%s - %s".printf (goffile.info.get_name (), goffile.formated_type);
                }
            } else { /* hovering over multiple selection */
                if (folders_count > 1) {
                    str = _("%u folders").printf (folders_count);
                    if (files_count > 0)
                        str += ngettext (_(" and %u other item (%s) selected").printf (files_count, format_size ((int64) files_size)),
                                         _(" and %u other items (%s) selected").printf (files_count, format_size ((int64) files_size)),
                                         files_count);
                    else
                        str += _(" selected");
                } else if (folders_count == 1) {
                    str = _("%u folder").printf (folders_count);
                    if (files_count > 0)
                        str += ngettext (_(" and %u other item (%s) selected").printf (files_count, format_size ((int64) files_size)),
                                         _(" and %u other items (%s) selected").printf (files_count, format_size ((int64) files_size)),
                                         files_count);
                    else
                        str += _(" selected");
                } else /* folder_count = 0 and files_count > 0 */
                    str = _("%u items selected (%s)").printf (files_count, format_size ((int64) files_size));
            }

            return str;
        }

        private void scan_list (GLib.List<GOF.File>? files) {
            if (files == null)
                return;

            foreach (var gof in files) {
                if (gof.is_folder ()) {
                    folders_count++;
                } else {
                    files_count++;
                    files_size += PropertiesWindow.file_real_size (gof);
                }
            }
        }

        /* code is mostly ported from nautilus' src/nautilus-image-properties.c */
        private async void load_resolution (GOF.File goffile) {
            var file = goffile.location;
            image_size_loaded = false;
            image_cancellable = new Cancellable ();

            try {
                stream = yield file.read_async (0, image_cancellable);
                if (stream == null)
                    error ("Could not read image file's size data");
                loader = new Gdk.PixbufLoader.with_mime_type (goffile.get_ftype ());

                loader.size_prepared.connect ((width, height) => {
                    image_size_loaded = true;
                    status = "%s (%s — %i × %i)".printf (goffile.formated_type, goffile.format_size, width, height);
                });

                /* Gdk wants us to always close the loader, so we are nice to it */
                image_cancellable.cancelled.connect (() => {
                    try {
                        loader.close ();
                        stream.close ();
                    } catch (Error e) {}
                });

                yield read_image_stream (loader, stream, image_cancellable);
            } catch (Error e) { debug (e.message); }
        }


        private async void read_image_stream (Gdk.PixbufLoader loader, FileInputStream stream, Cancellable cancellable)
        {
            ssize_t read = 1;
            while (!image_size_loaded  && read > 0) {
                try {
                    read = yield stream.read_async (buffer, 0, cancellable);
                    loader.write (buffer);
                    
                } catch (IOError e) {
                    if (!(e is IOError.CANCELLED))
                        warning (e.message);
                } catch (Gdk.PixbufError e) {
                    /* errors while loading are expected, we only need to know the size */
                } catch (FileError e) {
                    warning (e.message);
                } catch (Error e) {
                    warning (e.message);
                }
            }
            image_cancellable.cancelled ();
        }
    }
}
