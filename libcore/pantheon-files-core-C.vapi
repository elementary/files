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

namespace Files
{
    [CCode (cheader_filename = "fm-list-model.h", cname = "FMListModel", lower_case_cprefix="fm_list_model_")]
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
            NUM_COLUMNS;
            public unowned string to_string ();
            public static ColumnID from_string (string colstr);
        }

        [CCode (has_construct_function = false)]
        public ListModel ();
        [NoAccessorMethod]
        public bool has_child { get; set; }
        [NoAccessorMethod]
        public int size { get; set; }
        public bool load_subdirectory(Gtk.TreePath path, out Files.Directory.Async dir);
        public bool unload_subdirectory(Gtk.TreeIter iter);
        public void add_file(Files.File file, Files.Directory.Async dir);
        public bool remove_file (Files.File file, Files.Directory.Async dir);
        public void file_changed (Files.File file, Files.Directory.Async dir);
        public Files.File? file_for_path (Gtk.TreePath path);
        public bool get_first_iter_for_file (Files.File file, out Gtk.TreeIter iter);
        public bool get_tree_iter_from_file (Files.File file, Files.Directory.Async directory, out Gtk.TreeIter iter);
        public bool get_directory_file (Gtk.TreePath path, out unowned Files.Directory.Async directory, out unowned Files.File file);
        public uint get_length ();
        public Files.File? file_for_iter (Gtk.TreeIter iter);
        public void clear ();
        public void set_should_sort_directories_first (bool directories_first);
        public signal void subdirectory_unloaded (Files.Directory.Async directory);
    }
}


namespace Files {
    [CCode (lower_case_cprefix = "marlin_file_operations_", cname = "MarlinFileOperations")]
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
