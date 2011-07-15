using Gtk;
using GLib;

public void marlin_toolbar_editor_dialog_show (Marlin.View.Window mvw);

namespace FM {
    [CCode (cprefix = "FMDirectory", lower_case_cprefix = "fm_directory_")]
    namespace Directory {
        [CCode (cheader_filename = "fm-directory-view.h")]
        public class View : Gtk.ScrolledWindow {
            public signal void colorize_selection (int color);
            public signal void sync_selection ();
            public void merge_menus ();
            public void unmerge_menus ();
            public void zoom_in ();
            public void zoom_out ();
            public void zoom_normal ();
        }
    }
}

namespace Marlin {
    [CCode (cheader_filename = "marlin-application.h")]
    public class Application : Gtk.Application {
        public Application ();
        public void create_window (string uri, Gdk.Screen screen);
        public void create_window_from_gfile (GLib.File location, Gdk.Screen screen);
        public void quit ();
    }
    [CCode (cprefix = "MarlinWindow", lower_case_cprefix = "marlin_window_")]
    namespace Window {
        [CCode (cheader_filename = "marlin-window-columns.h")]
        public class Columns : GLib.Object {
            public Columns (GLib.File f, Marlin.View.ViewContainer ctab);
            public void make_view ();
            public GOF.Window.Slot active_slot;
            /*public Directory.Async directory;
            public Widget get_view ();*/
        }
    }
    [CCode (cprefix = "MarlinPlaces", lower_case_cprefix = "marlin_places_")]
    namespace Places {
        [CCode (cheader_filename = "marlin-places-sidebar.h")]
        public class Sidebar : Gtk.ScrolledWindow {
            public Sidebar (Gtk.Widget window);
        }
    }
    [CCode (cprefix = "MarlinClipboard", lower_case_cprefix = "marlin_clipboard_")]
    namespace Clipboard {
        [CCode (cheader_filename = "marlin-clipboard-manager.h")]
        public class Manager : GLib.Object {
            public Manager.get_for_display (Gdk.Display display);
            public bool get_can_paste ();
            public bool has_cutted_files (GOF.File file);
            public void copy_files (GLib.List files);
            public void cut_files (GLib.List files);
            public void paste_files (GLib.File target, Gtk.Widget widget, GLib.List files, GLib.Closure new_file_closure);
        }
    }
    [CCode (cprefix = "MarlinFileOperations", lower_case_cprefix = "marlin_file_operations_")]
    namespace FileOperations {
        [CCode (cheader_filename = "marlin-file-operations.h")]
        public void new_folder(out Gtk.Widget parent_view, out Gdk.Point target_point, File file, void* callback, void* data_callback);
        [CCode (cheader_filename = "marlin-file-operations.h")]
        public void new_folder_with_name(out Gtk.Widget parent_view, out Gdk.Point target_point, File file, string name, void* callback, void* data_callback);
    }
}

