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
            NUM_COLUMNS;
            public unowned string to_string ();
            public static ColumnID from_string (string colstr);
        }

        public bool load_subdirectory(Gtk.TreePath path, out GOF.Directory.Async dir);
        public bool unload_subdirectory(Gtk.TreeIter iter);
        public void add_file(GOF.File file, GOF.Directory.Async dir);
        public bool remove_file (GOF.File file, GOF.Directory.Async dir);
        public void file_changed (GOF.File file, GOF.Directory.Async dir);
        public GOF.File? file_for_path (Gtk.TreePath path);
        public static GLib.Type get_type ();
        public bool get_first_iter_for_file (GOF.File file, out Gtk.TreeIter iter);
        public bool get_tree_iter_from_file (GOF.File file, GOF.Directory.Async directory, out Gtk.TreeIter iter);
        public bool get_directory_file (Gtk.TreePath path, out unowned GOF.Directory.Async directory, out unowned GOF.File file);
        public uint get_length ();
        public GOF.File? file_for_iter (Gtk.TreeIter iter);
        public void clear ();
        public void set_should_sort_directories_first (bool directories_first);
        public signal void subdirectory_unloaded (GOF.Directory.Async directory);
    }
}


namespace Marlin {
    [CCode (lower_case_cprefix = "marlin_file_operations_")]
    namespace FileOperations {
        [CCode (cheader_filename = "marlin-file-operations.h")]
        static async GLib.File? new_folder (Gtk.Widget? parent_view, Gdk.Point? target_point, GLib.File file, GLib.Cancellable? cancellable = null) throws GLib.Error;
        [CCode (cheader_filename = "marlin-file-operations.h")]
        static async bool @delete (GLib.List<GLib.File> locations, Gtk.Window window, bool try_trash, GLib.Cancellable? cancellable = null) throws GLib.Error;
        [CCode (cheader_filename = "marlin-file-operations.h")]
        static async bool copy_move_link (GLib.List<GLib.File> files, GLib.Array<Gdk.Point>? relative_item_points, GLib.File target_dir, Gdk.DragAction copy_action, Gtk.Widget? parent_view = null, GLib.Cancellable? cancellable = null) throws GLib.Error;
        [CCode (cheader_filename = "marlin-file-operations.h")]
        static async GLib.File? new_file (Gtk.Widget parent_view, Gdk.Point? target_point, string parent_dir, string? target_filename, string? initial_contents, int length, GLib.Cancellable? cancellable = null) throws GLib.Error;
        [CCode (cheader_filename = "marlin-file-operations.h")]
        static async GLib.File? new_file_from_template (Gtk.Widget parent_view, Gdk.Point? target_point, GLib.File parent_dir, string? target_filename, GLib.File template, GLib.Cancellable? cancellable = null) throws GLib.Error;
    }
}
