/*
 * Copyright (C) 2012 ammonkey <am.monkeyd@gmail.com>
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
 */

namespace Marlin.View {

    public class OverlayBar : Granite.Widgets.OverlayBar {
        private Marlin.View.Window window;

        const int IMAGE_LOADER_BUFFER_SIZE = 8192;
        const string[] SKIP_IMAGES = {"image/svg+xml", "image/tiff"};
        Cancellable? image_cancellable = null;
        bool image_size_loaded = false;

        private bool _showbar;
        public bool showbar {
            set {
                _showbar = value;
                visible = value && count > 0;
            }
            get {
                return _showbar;
            }
        }

        public OverlayBar (Marlin.View.Window win, Gtk.Overlay overlay)
        {
            base (overlay);

            window = win;

            window.selection_changed.connect (update);
            window.item_hovered.connect (update_hovered);

            hide.connect (() => {
                /* when we're hiding, we no longer want to search for image size */
                if (image_cancellable != null)
                    image_cancellable.cancel ();
            });
        }

        private uint count = 0;
        private uint folders_count = 0;
        private uint files_count = 0;
        private uint64 files_size = 0;
        private GOF.File? goffile = null;
        //private unowned GLib.List<GOF.File>? last_selection = null;

        public void update (GLib.List<GOF.File>? files = null)
        {
            //last_selection = files;
            real_update (files);
        }

        private void update_hovered (GOF.File? file)
        {
            if (file != null) {
                GLib.List<GOF.File> list = null;
                list.prepend (file);
                real_update (list);
            } else {
                GOF.Window.Slot slot = window.current_tab.slot;
                if (slot != null) {
                    unowned List<GOF.File> list = ((FM.Directory.View) slot.view_box).get_selection ();
                    real_update (list);
                }
            }
        }

        private void real_update (GLib.List<GOF.File>? files = null)
        {
            count = 0;
            folders_count = 0;
            files_count = 0;
            files_size = 0;

            /* cancel any pending subfolder scan */
            //cancellable.cancel ();
            if (files != null) {
                visible = showbar;

                /* list contain only one element */
                if (files.next == null) {
                    goffile = files.data;
                }
                scan_list (files);
                update_status ();

            } else {
                visible = false;
                status = "";
            }
        }

        private void update_status ()
        {
            /* if we're still collecting image info, cancel */
            if (image_cancellable != null) {
                image_cancellable.cancel ();
                image_cancellable = null;
            }

            if (count == 1) {
                if (goffile.is_network_uri_scheme ()) {
                    status = goffile.get_display_target_uri ();
                } else if (!goffile.is_folder ()) {

                    /* if we have an image, see if we can get its resolution */
                    var type = goffile.get_ftype ();
                    if (type.substring (0, 6) == "image/" && !(type in SKIP_IMAGES)) {
                        load_resolution.begin (goffile);
                    }

                    status = "%s (%s)".printf (goffile.formated_type, goffile.format_size);
                } else {
                    status = "%s - %s".printf (goffile.info.get_name (), goffile.formated_type);

                }
            } else {
                string str = null;
                if (folders_count > 1) {
                    str = _("%u folders").printf (folders_count);
                    /*if (sub_folders_count > 0)
                      str += " (containing %u items)".printf (sub_count);
                      else
                      str += " (%s)".printf (format_size ((int64) sub_files_size));*/
                    if (files_count > 0)
                        str += ngettext (_(" and %u other item (%s) selected").printf (files_count, format_size ((int64) files_size)),
                                         _(" and %u other items (%s) selected").printf (files_count, format_size ((int64) files_size)),
                                         files_count);
                    else
                        str += _(" selected");
                } else if (folders_count == 1) {
                    str = _("%u folder").printf (folders_count);
                    /*if (sub_folders_count > 0)
                      str += " (containing %u items)".printf (sub_count);
                      else
                      str += " (%s)".printf (format_size ((int64) sub_files_size));*/
                    if (files_count > 0)
                        str += ngettext (_(" and %u other item (%s) selected").printf (files_count, format_size ((int64) files_size)),
                                         _(" and %u other items (%s) selected").printf (files_count, format_size ((int64) files_size)),
                                         files_count);
                    else
                        str += _(" selected");
                } else {
                    str = _("%u items selected (%s)").printf (count, format_size ((int64) files_size));
                }

                status = str;

            }
        }

        private void scan_list (List<GOF.File> files)
        {
            foreach (var gof in files) {
                if (gof.is_folder ()) {
                    folders_count++;
                    //scan_folder (gof.location);
                } else {
                    files_count++;
                    files_size += gof.size;
                }
                count++;
            }
        }

        /* code is mostly ported from nautilus' src/nautilus-image-properties.c */
        private async void load_resolution (GOF.File gofile)
        {
            var file = goffile.location;
            image_size_loaded = false;
            image_cancellable = new Cancellable ();

            try {
                var stream = yield file.read_async (0, image_cancellable);
                if (stream == null)
                    error ("Could not read image file's size data");
                var loader = new Gdk.PixbufLoader.with_mime_type (goffile.get_ftype ());

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
            } catch (Error e) { warning (e.message); }
        }

        private async void read_image_stream (Gdk.PixbufLoader loader, FileInputStream stream, Cancellable cancellable)
        {
            if (image_size_loaded)
                return;

            var buffer = new uint8[IMAGE_LOADER_BUFFER_SIZE];

            try {
                var read = yield stream.read_async (buffer, 0, cancellable);

                if (read > 0 && loader.write (buffer) && !image_size_loaded) {
                    yield read_image_stream (loader, stream, cancellable);
                    return;
                }

                image_size_loaded = true;
                loader.close ();
                loader = null;
                stream.close ();
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
    }
}