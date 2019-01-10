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

[CCode (cprefix = "FM", lower_case_cprefix = "fm_", cheader_filename = "fm-list-model.h")]
namespace FM
{
    public class ListModel : GLib.Object, Gtk.TreeModel, Gtk.TreeDragDest, Gtk.TreeSortable
    {
        [CCode (cprefix = "FM_LIST_MODEL_", cheader_filename = "fm-list-model.h")]
        public enum ColumnID {
            FILE_COLUMN,
            COLOR,
            PIXBUF,
            FILENAME,
            SIZE,
            SCALE_FACTOR,
            TYPE,
            MODIFIED,
            NUM_COLUMNS
        }

        public bool load_subdirectory(Gtk.TreePath path, out GOF.Directory.Async dir);
        public bool unload_subdirectory(Gtk.TreeIter iter);
        public void add_file(GOF.File file, GOF.Directory.Async dir);
        public bool remove_file (GOF.File file, GOF.Directory.Async dir);
        public void file_changed (GOF.File file, GOF.Directory.Async dir);
        public unowned GOF.File? file_for_path (Gtk.TreePath path);
        public static GLib.Type get_type ();
        public bool get_first_iter_for_file (GOF.File file, out Gtk.TreeIter iter);
        public bool get_tree_iter_from_file (GOF.File file, GOF.Directory.Async directory, out Gtk.TreeIter iter);
        public bool get_directory_file (Gtk.TreePath path, out unowned GOF.Directory.Async directory, out unowned GOF.File file);
        public GOF.File? file_for_iter (Gtk.TreeIter iter);
        public void clear ();
        public void set_should_sort_directories_first (bool directories_first);
        public signal void subdirectory_unloaded (GOF.Directory.Async directory);
        public static string get_string_from_column_id (FM.ListModel.ColumnID id);
        public static FM.ListModel.ColumnID get_column_id_from_string (string colstr);
    }
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

[CCode (cprefix = "EelGtk", lower_case_cprefix = "eel_gtk_window_", cheader_filename = "eel-gtk-extensions.h")]
namespace EelGtk.Window {
    public string get_geometry_string (Gtk.Window win);
    public void set_initial_geometry_from_string (Gtk.Window win, string geometry, uint w, uint h, bool ignore_position, int left_offset, int top_offset);
}

[CCode (cprefix = "EelGtk", lower_case_cprefix = "eel_gtk_widget_", cheader_filename = "eel-gtk-extensions.h")]
namespace EelGtk.Widget {
    public Gdk.Screen get_screen ();
}

[CCode (cprefix = "Eel", lower_case_cprefix = "eel_")]
namespace Eel {
    [CCode (cheader_filename = "eel-string.h")]
    public string? str_double_underscores (string? str);
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

//    [CCode (cprefix = "MarlinConnectServer", lower_case_cprefix = "marlin_connect_server_")]
//    namespace ConnectServer {
//        [CCode (cheader_filename = "marlin-connect-server-dialog.h")]
//        public class Dialog : Gtk.Dialog {
//            public Dialog (Gtk.Window window);
//            public async bool display_location_async (GLib.File location) throws GLib.Error;
//            public async bool fill_details_async (GLib.MountOperation operation,
//                                                 string default_user,
//                                                 string default_domain,
//                                                 GLib.AskPasswordFlags flags);
//        }
//    }
}

[CCode (cprefix = "MarlinFile", lower_case_cprefix = "marlin_file_", cheader_filename = "marlin-file-changes-queue.h")]
namespace MarlinFile {
    public void changes_queue_file_added (GLib.File location);
    public void changes_queue_file_changed (GLib.File location);
    public void changes_queue_file_removed (GLib.File location);
    public void changes_queue_file_moved (GLib.File location);
    public void changes_consume_changes (bool consume_all);
}
