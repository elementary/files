public void marlin_toolbar_editor_dialog_show (Marlin.View.Window mvw);

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "marlin-global-preferences.h")]
namespace Preferences {
    public GLib.Settings settings;
    public GLib.Settings marlin_icon_view_settings;
    public GLib.Settings marlin_list_view_settings;
    public GLib.Settings marlin_column_view_settings;
    public GLib.Settings gnome_mouse_settings;
}


namespace Marlin {
    [CCode (cheader_filename = "marlin-thumbnailer.h")]
    public class Thumbnailer : GLib.Object {
        public static Thumbnailer get();
        public bool queue_file (GOF.File file, out uint request, bool large);
        public bool queue_files (GLib.List<GOF.File> files, out uint request, bool large);
        public void dequeue (uint request);
    }

    [CCode (cprefix = "MarlinConnectServer", lower_case_cprefix = "marlin_connect_server_")]
    namespace ConnectServer {
        [CCode (cheader_filename = "marlin-connect-server-dialog.h")]
        public class Dialog : Gtk.Dialog {
            public Dialog (Gtk.Window window);
            public async bool display_location_async (GLib.File location) throws GLib.Error;
            public async bool fill_details_async (GLib.MountOperation operation,
                                                 string default_user,
                                                 string default_domain,
                                                 GLib.AskPasswordFlags flags);
        }
    }

    [CCode (cprefix = "MarlinClipboardManager", lower_case_cprefix = "marlin_clipboard_manager_", cheader_filename = "marlin-clipboard-manager.h")]

        public class ClipboardManager : GLib.Object {
            public ClipboardManager.get_for_display (Gdk.Display display);
            public bool get_can_paste ();
            public bool has_cutted_files (GOF.File file);
            public bool has_file (GOF.File file);
            public void copy_files (GLib.List files);
            public void cut_files (GLib.List files);
            public void paste_files (GLib.File target, Gtk.Widget widget, CopyCallBack? new_file_closure);
            public signal void changed ();
        }

    [CCode (cheader_filename = "marlin-file-utilities.h")]
    public void restore_files_from_trash (GLib.List<GOF.File> *files, Gtk.Window *parent_window);
    [CCode (cheader_filename = "marlin-file-utilities.h")]
    public void get_rename_region (string filename, out int start_offset, out int end_offset, bool select_all);

    [CCode (cheader_filename = "marlin-icon-renderer.h")]
    public class IconRenderer : Gtk.CellRenderer {
        public IconRenderer ();
    }    

    [CCode (cheader_filename = "marlin-enum-types.h")]
    public enum ZoomLevel {
        SMALLEST,
        SMALLER,
        SMALL,
        NORMAL,
        LARGE,
        LARGER,
        LARGEST,
        N_LEVELS
    }

    [CCode (cheader_filename = "marlin-enum-types.h")]
    public static Gtk.IconSize zoom_level_to_stock_icon_size (ZoomLevel zoom);
    [CCode (cheader_filename = "marlin-enum-types.h")]
    public static Marlin.IconSize zoom_level_to_icon_size (ZoomLevel zoom);

    [CCode (cheader_filename = "marlin-enum-types.h")]
    public enum IconSize {
        SMALLEST = 16,
        SMALLER = 24,
        SMALL = 32,
        NORMAL = 48,
        LARGE = 64,
        LARGER = 96,
        LARGEST = 128
    }

    [CCode (cheader_filename = "marlin-view-window.h")]
    public enum OpenFlag {
        DEFAULT,
        NEW_ROOT,
        NEW_TAB,
        NEW_WINDOW
    }

    [CCode (cheader_filename = "marlin-view-window.h")]
    public enum ViewMode {
        ICON,
        LIST,
        MILLER_COLUMNS,
        CURRENT,
        PREFERRED,
        INVALID
    }
}
