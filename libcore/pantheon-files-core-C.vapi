using GLib;

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "config.h")]
namespace Config {
    public const string GETTEXT_PACKAGE;
    public const string UI_DIR;
    public const string VERSION;
    public const string PLUGIN_DIR;
    public const string TESTDATA_DIR;
    public const string APP_NAME;
    public const string TERMINAL_NAME;
}

namespace Marlin {
    [CCode (lower_case_cprefix = "marlin_file_operations_")]
    namespace FileOperations {
        [CCode (cheader_filename = "marlin-file-operations.h")]
        static async GLib.File? new_folder (Gtk.Widget? parent_view, GLib.File file, GLib.Cancellable? cancellable = null) throws GLib.Error;
        [CCode (cheader_filename = "marlin-file-operations.h")]
        static async bool @delete (GLib.List<GLib.File> locations, Gtk.Window window, bool try_trash, GLib.Cancellable? cancellable = null) throws GLib.Error;
        [CCode (cheader_filename = "marlin-file-operations.h")]
        static async bool copy_move_link (GLib.List<GLib.File> files, GLib.File target_dir, Gdk.DragAction copy_action, Gtk.Widget? parent_view = null, GLib.Cancellable? cancellable = null) throws GLib.Error;
        [CCode (cheader_filename = "marlin-file-operations.h")]
        static async GLib.File? new_file (Gtk.Widget parent_view, string parent_dir, string? target_filename, string? initial_contents, int length, GLib.Cancellable? cancellable = null) throws GLib.Error;
        [CCode (cheader_filename = "marlin-file-operations.h")]
        static async GLib.File? new_file_from_template (Gtk.Widget parent_view, GLib.File parent_dir, string? target_filename, GLib.File template, GLib.Cancellable? cancellable = null) throws GLib.Error;
    }
}
