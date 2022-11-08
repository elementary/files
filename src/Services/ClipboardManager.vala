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
        private GLib.List<Files.File> files = null;
        private bool files_cut = false;
        public bool files_linked {get; private set; default = false;}

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

        ~ClipboardManager () {
            release_pending_files ();
        }

        // /** If @file is null, returns whether there are ANY cut files
        //  * otherwise whether @file is amongst the cut files
        // **/
        public bool has_cut_file (Files.File? file) {
            return files_cut && (file == null || has_file (file));
        }

        public bool has_file (Files.File file) {
            return files != null && (files.find (file) != null);
        }

        public void copy_files (GLib.List<Files.File> files) {
            var data = FileUtils.make_string_from_file_list (files);
            if (data != "") {
                set_file_list (true, false, files);
                clipboard.set_text ("copy" + data);
            }
        }

        public void cut_files (GLib.List<Files.File> files) {
            var data = FileUtils.make_string_from_file_list (files);
            if (data != "") {
                set_file_list (false, false, files);
                clipboard.set_text ("cut" + data);
            }
        }

        public void copy_link_files (GLib.List<Files.File> files) {
            var data = FileUtils.make_string_from_file_list (files);
            if (data != "") {
                set_file_list (true, true, files);
                clipboard.set_text ("link" + data);
            }
        }

        public async void paste_files (GLib.File target_file, Gtk.Widget? widget = null) {
            unowned var cp = clipboard.get_content ();
            var content = Value (typeof (string));
            string text = "";
            try {
                if (cp.get_value (ref content)) {
                    text = content.get_string ();
                }
            } catch (Error e) {
                warning ("Error getting clipboard contents. %s", e.message);
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
                clear_clipboard ();
            }
        }

        public void clear_clipboard () {
            clipboard.set_content (null);
            release_pending_files ();
            files_cut = false;
            files_linked = false;
        }

        private void set_file_list (bool copy, bool link, GLib.List<Files.File> files_for_transfer) {
            release_pending_files ();
            files_cut = !copy;
            files_linked = link;

            /* setup the new file list */
            foreach (var file in files_for_transfer) {
                files.prepend (file);
                file.destroy.connect (on_file_destroyed);
            }
        }

        private void on_file_destroyed (Files.File file) {
            file.destroy.disconnect (on_file_destroyed);
            files.remove (file);
        }

        private void release_pending_files () {
            foreach (var file in this.files) {
                file.destroy.disconnect (on_file_destroyed);
            }

            files = null;
        }
    }
}
