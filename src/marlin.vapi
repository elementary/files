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

    [CCode (cheader_filename = "marlin-file-utilities.h")]
    public void get_rename_region (string filename, out int start_offset, out int end_offset, bool select_all);

    [CCode (cheader_filename = "marlin-icon-renderer.h")]
    public class IconRenderer : Gtk.CellRenderer {
        public IconRenderer ();
        public uint get_helper_size ();
    }
}
