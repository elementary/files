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
    [CCode (cprefix = "MarlinFileOperations", lower_case_cprefix = "marlin_file_operations_", cheader_filename = "marlin-file-operations.h")]
    namespace FileOperations {
        static void new_folder(Gtk.Widget? parent_view, Gdk.Point? target_point, GLib.File file,Marlin.CreateCallback? create_callback = null);
        static void mount_volume (GLib.Volume volume, Gtk.Window? parent_window = null);
        static async void mount_volume_full (GLib.Volume volume, Gtk.Window? parent_window = null) throws GLib.Error;
        static void trash_or_delete (GLib.List<GLib.File> locations, Gtk.Window window, DeleteCallback? callback = null);
        static void @delete (GLib.List<GLib.File> locations, Gtk.Window window, DeleteCallback? callback = null);
        static bool has_trash_files (GLib.Mount mount);
        static GLib.List<GLib.File> get_trash_dirs_for_mount (GLib.Mount mount);
        static void empty_trash (Gtk.Widget? widget);
        static void empty_trash_for_mount (Gtk.Widget? widget, GLib.Mount mount);
        static void copy_move_link (GLib.List<GLib.File> files, GLib.Array<Gdk.Point>? relative_item_points, GLib.File target_dir, Gdk.DragAction copy_action, Gtk.Widget? parent_view = null, CopyCallback? done_callback = null);
        static void new_file (Gtk.Widget parent_view, Gdk.Point? target_point, string parent_dir, string? target_filename, string? initial_contents, int length, Marlin.CreateCallback? create_callback = null);
        static void new_file_from_template (Gtk.Widget parent_view, Gdk.Point? target_point, GLib.File parent_dir, string? target_filename, GLib.File template, Marlin.CreateCallback? create_callback = null);
    }

    [CCode (cheader_filename = "marlin-file-operations.h")]
    public delegate void CreateCallback (GLib.File? new_file);
    [CCode (cheader_filename = "marlin-file-operations.h")]
    public delegate void DeleteCallback (bool user_cancel);
    [CCode (cname="GCallback")]
    public delegate void CopyCallback ();
}

[CCode (cprefix = "Marlin", lower_case_cprefix = "marlin_")]
namespace Marlin
{
    [CCode (cheader_filename = "marlin-undostack-manager.h")]
    public struct UndoMenuData {
        string undo_label;
        string undo_description;
        string redo_label;
        string redo_description;
    }

    [CCode (cheader_filename = "marlin-undostack-manager.h")]
    public delegate void UndoFinishCallback ();

    [CCode (cheader_filename = "marlin-undostack-manager.h")]
    public class UndoManager : GLib.Object
    {
        public static unowned UndoManager instance ();

        public signal void request_menu_update (UndoMenuData data);

        public void undo (Gtk.Widget widget, UndoFinishCallback? cb);
        public void redo (Gtk.Widget widget, UndoFinishCallback? cb);
        public void add_rename_action (GLib.File renamed_file, string original_name);
    }
}
