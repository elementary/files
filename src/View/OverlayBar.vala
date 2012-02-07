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

using Gtk;

namespace Marlin.View {
    public class OverlayBar : Box {

        public Label status;
        private Marlin.View.Window window;

        private bool _showbar;
        public bool showbar {
            set {
                _showbar = value;
                visible = count > 0 && value;
            }
            get {
                return _showbar;
            }
        }

        public OverlayBar (Marlin.View.Window win) 
        {
            window = win;

            status = new Label (null);
            status.set_ellipsize (Pango.EllipsizeMode.END);
            status.set_margin_top (1);
            status.set_margin_bottom (1);
            status.set_margin_left (5);
            status.set_margin_right (5);
            add (status);
            status.show ();

            set_halign (Align.END);
            set_valign (Align.END);

            //cancellable = new Cancellable ();

            set_default_style ();

            window.selection_changed.connect (update);
            window.item_hovered.connect (update_hovered);
        }

        public override void parent_set (Gtk.Widget? old_parent)
        {
            Widget parent = get_parent ();

            if (old_parent != null)
                old_parent.enter_notify_event.disconnect (enter_notify_callback);
            if (parent != null)
                parent.enter_notify_event.connect (enter_notify_callback);
        }

        public override bool draw (Cairo.Context cr)
        {
            var ctx = get_style_context ();
            render_background (ctx, cr, 0, 0, get_allocated_width (), get_allocated_height ());
            render_frame (ctx, cr, 0, 0, get_allocated_width (), get_allocated_height ());

            return base.draw (cr);
        }

        private void set_default_style ()
        {
            var provider = new Gtk.CssProvider();
            try {
                provider.load_from_data ("""MarlinViewOverlayBar {
                                         background-color: #cecfcd;
                                         border-radius: 2 2 0 0;
                                         border-style: solid;
                                         border-width: 1;
                                         border-color: darker (#cecfcd);
                                         border-bottom-color: @transparent;
                                         
                                         -unico-border-gradient: none;
                                         }""", -1);

                get_style_context ().add_provider (provider, 600);
            } catch (Error e) {
                stderr.printf("Error style context add_provider: %s\n", e.message);
            }

        }

        private bool enter_notify_callback (Gdk.EventCrossing event)
        {
            message ("enter_notify_event");
            if (get_halign () == Align.START)
                set_halign (Align.END);
            else
                set_halign (Align.START);
            return false;
        }

        private uint count = 0;
        private uint folders_count = 0;
        private uint files_count = 0;
        private uint64 files_size = 0;
        private GOF.File? goffile = null;
        //private unowned GLib.List<GOF.File>? last_selection = null;

        private void update (GLib.List<GOF.File>? files = null) 
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
                status.set_label ("");
            }
        }

        private void update_status () 
        {
            if (count == 1) {
                if (!goffile.is_folder ()) {
                    status.set_label ("%s - %s (%s)".printf (goffile.info.get_name (), goffile.formated_type, goffile.format_size));
                } else {
                    status.set_label ("%s - %s".printf (goffile.info.get_name (), goffile.formated_type));

                }
            } else {
                string str = null;
                if (folders_count > 1) {
                    str = "%u folders".printf (folders_count);
                    /*if (sub_folders_count > 0)
                      str += " (containing %u items)".printf (sub_count);
                      else
                      str += " (%s)".printf (format_size_for_display ((int64) sub_files_size));*/
                    if (files_count > 0)
                        str += " and %u other items (%s) selected".printf (files_count, format_size_for_display ((int64) files_size));
                    else
                        str += " selected";
                } else if (folders_count == 1) {
                    str = "%u folder".printf (folders_count);
                    /*if (sub_folders_count > 0)
                      str += " (containing %u items)".printf (sub_count);
                      else
                      str += " (%s)".printf (format_size_for_display ((int64) sub_files_size));*/
                    if (files_count > 0)
                        str += " and %u other items (%s) selected".printf (files_count, format_size_for_display ((int64) files_size));
                    else
                        str += " selected";
                } else {
                    str = "%u items selected (%s)".printf (count, format_size_for_display ((int64) files_size));
                }

                status.set_label (str);

            }
        }

        private void scan_list (GLib.List<GOF.File> files) 
        {
            /*sub_files_size = 0;
              sub_count = 0;
              sub_folders_count = 0;
              cancellable.reset ();*/

            foreach (var gof in files) {
                if (gof.is_folder ()) {
                    //if (gof.info.get_file_type () == FileType.DIRECTORY) {
                    folders_count++;
                    //scan_folder (gof.location);
                } else {
                    files_count++;
                    files_size += gof.size;
                }
                count++;
                }
            }

            /*private Cancellable cancellable;
              private uint64 sub_files_size = 0;
              private uint sub_count = 0;
              private uint sub_folders_count = 0;

              private async void scan_folder (File directory)
              {
              var attrs = FILE_ATTRIBUTE_STANDARD_NAME + "," + FILE_ATTRIBUTE_STANDARD_TYPE + "," + FILE_ATTRIBUTE_STANDARD_SIZE;

              try {
              var e = yield directory.enumerate_children_async (attrs, FileQueryInfoFlags.NOFOLLOW_SYMLINKS, Priority.LOW, cancellable);

              while (true) {
              var files = yield e.next_files_async (1024, Priority.LOW, cancellable);
              if (files == null)
              break;

              foreach (var f in files)
              {
              if (f.get_file_type () == FileType.DIRECTORY) {
              sub_folders_count++;
              } else {
              sub_files_size += f.get_size();
              }
              sub_count++;
              }
              }
              update_status ();
              } catch (Error err) {
              warning ("%s", err.message);
              }
              }*/

        }
    }
