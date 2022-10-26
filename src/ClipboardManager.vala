/***
    Copyright (c) 2016-2018 elementary LLC <https://elementary.io>

    Based on C code imported from Thunar
    Copyright (c) 2005-2006 Benedikt Meurer <benny@xfce.org>
    Copyright (c) 2009 Jannis Pohlmann <jannis@xfce.org>*

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
    write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
    Boston, MA 02110-1335 USA.

    Author(s):  Jeremy Wootten <jeremy@elementaryos.org>

***/

namespace Files {
    public class ClipboardManager : GLib.Object {
        private enum ClipboardTarget {
            GNOME_COPIED_FILES,
            PNG_IMAGE,
            UTF8_STRING
        }

        private static ClipboardManager manager;
        private Gdk.Clipboard clipboard;
        // private GLib.List<Files.File> files = null;
        // private bool files_cutted = false;
        // public bool files_linked {get; private set; default = false;}

        /** Returns TRUE if the contents of the clipboard can be pasted into a folder.
        **/
        // public bool can_paste {get; private set; default = false;}

        public signal void changed ();

        construct {
            clipboard = Gdk.Display.get_default ().get_clipboard ();
        }

        public static ClipboardManager? get_instance () {
            if (manager == null) {
                manager = new ClipboardManager ();
            }

            return manager;
        }

        // ~ClipboardManager () {
        //     release_pending_files ();
        // }

        // /** If @file is null, returns whether there are ANY cut files
        //  * otherwise whether @file is amongst the cut files
        // **/
        // public bool has_cutted_file (Files.File? file) {
        //     return files_cutted && (file == null || has_file (file));
        // }

        // public bool has_file (Files.File file) {
        //     return files != null && (files.find (file) != null);
        // }

        public void copy_files (GLib.List<Files.File> files) {
warning ("copy files");
            var data = FileUtils.make_string_from_file_list (files);
            if (data != "") {
                clipboard.set_text ("copy" + data);
            }

            warning ("data copied %s", data);
        }

        public void copy_link_files (GLib.List<Files.File> files) {
            // transfer_files (true, true, files);
        }

        public void cut_files (GLib.List<Files.File> files) {
            // transfer_files (false, false, files);
        }

        public async void paste_files (GLib.File target_file, Gtk.Widget? widget = null) {
            unowned var cp = clipboard.get_content ();
            Value content = new Value (typeof (string));
            string text = "";
            if (cp.get_value (ref content)) {
                text = content.get_string ();
            } else {
                return;
            }

            //TODO Rework DnD for Gtk4
            Gdk.DragAction? action = null;
            if (text.has_prefix ("copy")) {
                action = Gdk.DragAction.COPY;
                text = text.substring (4);
            } else if (text.has_prefix ("cut")) {
                action = Gdk.DragAction.MOVE;
                text = text.substring (3);
            } else if (text.has_prefix ("link")) {
                action = Gdk.DragAction.LINK;
                text = text.substring (4);
            } else {
                warning ("Invalid selection data in Files.ClipboardManager contents_received");
                return;
            }

            var file_list = FileUtils.files_from_uris (text);
            if (file_list != null) {
                try {
                    yield FileOperations.copy_move_link (file_list,
                                                         target_file,
                                                         action,
                                                         widget);
                } catch (Error e) {
                    warning ("Clipboard paste files error - %s", e.message);
                }
            }

            if (action != Gdk.DragAction.COPY) {
                clipboard.set_content (null);
            }
        }

        // private async void contents_received (Gdk.ContentProvider cp,
        //                                       GLib.File target_file,
        //                                       Gtk.Widget? widget = null) throws GLib.Error {
        //     /* check whether the retrieval worked */
        //     Value content = new Value (typeof (string));
        //     string text = "";
        //     if (cp.get_value (ref content)) {
        //         text = content.get_string ();
        //     } else {
        //         return;
        //     }

        //     //TODO Rework DnD for Gtk4
        //     Gdk.DragAction? action = null;
        //     if (text.has_prefix ("copy")) {
        //         action = Gdk.DragAction.COPY;
        //         text = text.substring (4);
        //     } else if (text.has_prefix ("cut")) {
        //         action = Gdk.DragAction.MOVE;
        //         text = text.substring (3);
        //     } else if (text.has_prefix ("link")) {
        //         action = Gdk.DragAction.LINK;
        //         text = text.substring (4);
        //     } else {
        //         warning ("Invalid selection data in Files.ClipboardManager contents_received");
        //         return;
        //     }

        //     var file_list = FileUtils.files_from_uris (text);
        //     if (file_list != null) {
        //         try {
        //             yield FileOperations.copy_move_link (file_list,
        //                                                  target_file,
        //                                                  action,
        //                                                  widget);
        //         } catch (Error e) {
        //             throw e;
        //         }
        //     }

        //     /* clear the clipboard if it contained "cutted data"
        //      * (gtk_clipboard_clear takes care of not clearing
        //      * the selection if we don't own it)
        //      */
        //     if (action != Gdk.DragAction.COPY) {
        //         clipboard.set_content (null);
        //     }
        //     // /* check the contents of the clipboard again if either the Xserver or
        //     //  * our GTK+ version doesn't support the XFixes extension */
        //     // if (!clipboard.get_display ().supports_selection_notification ()) {
        //     //     owner_changed (null);
        //     // }
        // }

//         private void owner_changed (Gdk.Event? owner_change_event) {
// warning ("owner changed");
//             unowned var cp = clipboard.get_content ();
//             // clipboard.request_contents (Gdk.Atom.intern_static_string ("TARGETS"), (cb, sd) => {
//                 can_paste = false;
//                 // Gdk.Atom[] targets = null;

//                 // sd.get_targets (out targets);
//                 // var formats = cp.formats;

//                 //TODO Rework for ContentFormat
//                 // foreach (var target in targets) {
//                 //     if (target == x_special_gnome_copied_files) {
//                 //         can_paste = true;
//                 //         break;
//                 //     }
//                 // }

//                 /* notify listeners that we have a new clipboard state */
//                 changed ();
//                 notify_property ("can-paste");
//             // });
//         }

        /**
        //  * Sets the clipboard to contain @files_for_transfer and marks them to be copied
        //  * or moved according to @copy when the user pastes from the clipboard.
        // **/
        // private void transfer_files (bool copy, bool link, GLib.List<Files.File> files_for_transfer) {
        //     release_pending_files ();
        //     files_cutted = !copy;
        //     files_linked = link;

        //     /* setup the new file list */
        //     foreach (var file in files_for_transfer) {
        //         files.prepend (file);
        //         file.destroy.connect (on_file_destroyed);
        //     }

            // /* acquire the Clipboard ownership */
            // clipboard.set_with_owner (CLIPBOARD_TARGETS, get_callback, clear_callback, this);

            // /* Need to fake a "owner-change" event here if the Xserver doesn't support clipboard notification */
            // if (!clipboard.get_display ().supports_selection_notification ()) {
            //     owner_changed (null);
            // }
        // }

        // private void on_file_destroyed (Files.File file) {
        //     file.destroy.disconnect (on_file_destroyed);
        //     files.remove (file);
        // }

        // public static void get_callback (Gtk.Clipboard cb, Gdk.ContentProvider sd, uint target_info, void* parent) {
        //     var manager = parent as ClipboardManager;
        //     if (manager == null || manager.clipboard != cb) {
        //         return;
        //     }

        //     switch (target_info) {
        //         case ClipboardTarget.GNOME_COPIED_FILES: /* Pasting into a file handler */
        //             string prefix = manager.files_cutted ? "cut" : (manager.files_linked ? "link" : "copy");
        //             DndHandler.set_selection_data_from_file_list (sd,
        //                                                           manager.files,
        //                                                           prefix);
        //             break;

        //         case ClipboardTarget.PNG_IMAGE: /* Pasting into a (single) image handler */
        //             if (manager.files == null) {
        //                 break;
        //             }

        //             var filename = manager.files.data.location.get_path ();
        //             try {
        //                 var pixbuf = new Gdk.Pixbuf.from_file (filename);
        //                 sd.set_pixbuf (pixbuf);
        //             } catch (Error e) {
        //                 warning ("failed to get pixbuf from file %s ", filename);
        //             }

        //             break;

        //         case ClipboardTarget.UTF8_STRING: /* Pasting into a text handler */
        //             DndHandler.set_selection_text_from_file_list (sd, manager.files, "");
        //             break;
        //         default:
        //             break;
        //     }
        // }

        // public static void clear_callback (Gtk.Clipboard cb, void* parent) {
        //     var manager = (ClipboardManager)parent;
        //     if (manager == null || manager.clipboard != cb) {
        //         return;
        //     }

        //     manager.release_pending_files ();
        // }

        // private void release_pending_files () {
        //     foreach (var file in this.files) {
        //         file.destroy.disconnect (on_file_destroyed);
        //     }

        //     files = null;
        // }
    }
}
