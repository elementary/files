[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "config.h")]
namespace Config {
    public const string GETTEXT_PACKAGE;
    public const string PIXMAP_DIR;
    public const string UI_DIR;
    public const string PACKAGE_VERSION;
    public const string VERSION;
    public const string GNOMELOCALEDIR;
    public const string PLUGIN_DIR;
    public const string TESTDATA_DIR;
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
            TYPE,
            MODIFIED,
            NUM_COLUMNS
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
        public GOF.File? file_for_iter (Gtk.TreeIter iter);
        public void clear ();
        public signal void subdirectory_unloaded (GOF.Directory.Async directory);
    }
}


namespace Marlin {
    [CCode (cprefix = "MarlinFileOperations", lower_case_cprefix = "marlin_file_operations_", cheader_filename = "marlin-file-operations.h")]
    namespace FileOperations {
        static void new_folder(Gtk.Widget? parent_view, Gdk.Point? target_point, GLib.File file,Marlin.CreateCallback? create_callback = null, void* data_callback = null);
        static void mount_volume (Gtk.Window? parent_window, GLib.Volume volume, bool allow_autorun);
        static void mount_volume_full (Gtk.Window? parent_window, GLib.Volume volume, bool allow_autorun, Marlin.MountCallback? mount_callback, GLib.Object? callback_data_object);
        static void unmount_mount_full (Gtk.Window? parent_window, GLib.Mount mount, bool eject, bool check_trash, Marlin.UnmountCallback? unmount_callback, void* callback_data);
        static void trash_or_delete (GLib.List<GLib.File> locations, Gtk.Window window, DeleteCallback? callback = null, void* callback_data = null);
        static void @delete (GLib.List<GLib.File> locations, Gtk.Window window, DeleteCallback? callback = null, void* callback_data = null);
        static bool has_trash_files (GLib.Mount mount);
        static unowned GLib.List<unowned GLib.File> get_trash_dirs_for_mount (GLib.Mount mount);
        static void empty_trash (Gtk.Widget? widget);
        static void empty_trash_for_mount (Gtk.Widget? widget, GLib.Mount mount);
        static void copy_move_link (GLib.List<GLib.File> files, void* relative_item_points, GLib.File target_dir, Gdk.DragAction copy_action, Gtk.Widget? parent_view = null, GLib.Callback? done_callback = null, void* done_callback_data = null);
        static void new_file (Gtk.Widget parent_view, Gdk.Point? target_point, string parent_dir, string? target_filename, string? initial_contents, int length, Marlin.CreateCallback? create_callback = null, void* done_callback_data = null);
        static void new_file_from_template (Gtk.Widget parent_view, Gdk.Point? target_point, GLib.File parent_dir, string? target_filename, GLib.File template, Marlin.CreateCallback? create_callback = null, void* done_callback_data = null);
    }
    [CCode (cheader_filename = "marlin-file-operations.h", has_target = false)]
    public delegate void MountCallback (GLib.Volume volume, void* callback_data_object);
    [CCode (cheader_filename = "marlin-file-operations.h", has_target = false)]
    public delegate void UnmountCallback (void* callback_data);
    [CCode (cheader_filename = "marlin-file-operations.h", has_target = false)]
    public delegate void CreateCallback (GLib.File? new_file, void* callback_data);
    [CCode (cheader_filename = "marlin-file-operations.h", has_target = false)]
    public delegate void CopyCallback (GLib.HashTable<GLib.File, void*>? debuting_uris, void* pointer);
    [CCode (cheader_filename = "marlin-file-operations.h", has_target = false)]
    public delegate void DeleteCallback (bool user_cancel, void* callback_data);

    [CCode (cprefix = "Marlin", lower_case_cprefix = "marlin_dialogs_", cheader_filename = "eel-stock-dialogs.h")]
    namespace Dialogs {
        public void show_error (void* data, GLib.Error? error, string format_string, ...);
    }
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
    [CCode (cheader_filename = "eel-gtk-extensions.h")]
    public void pop_up_context_menu (Gtk.Menu menu, int16 offset_x, int16 offset_y, Gdk.EventButton event);

    [CCode (cheader_filename = "eel-stock-dialogs.h")]
    public unowned Gtk.Dialog show_warning_dialog (string primary_text, string secondary_text, Gtk.Window? parent);
    [CCode (cheader_filename = "eel-stock-dialogs.h")]
    public unowned Gtk.Dialog show_error_dialog (string primary_text, string secondary_text, Gtk.Window? parent);

    [CCode (cheader_filename = "eel-fcts.h")]
    public string? get_date_as_string (uint64 d, string format);
    [CCode (cheader_filename = "eel-fcts.h")]
    public GLib.List? get_user_names ();
    [CCode (cheader_filename = "eel-fcts.h")]
    public bool get_user_id_from_user_name (string *user_name, out int uid);
    [CCode (cheader_filename = "eel-fcts.h")]
    public string? get_real_user_home ();
    [CCode (cheader_filename = "eel-fcts.h")]
    public bool get_group_id_from_group_name (string *group_name, out int gid);
    [CCode (cheader_filename = "eel-fcts.h")]
    public bool get_id_from_digit_string (string digit_str, out int id);
    [CCode (cheader_filename = "eel-fcts.h")]
    public string format_size (uint64 size);

    [CCode (cheader_filename = "eel-string.h")]
    public string? str_double_underscores (string? str);
}

[CCode (cprefix = "Marlin", lower_case_cprefix = "marlin_")]
namespace Marlin
{
    [CCode (cheader_filename = "marlin-file-utilities.h")]
    public string get_accel_map_file ();

    [CCode (cheader_filename = "marlin-undostack-manager.h")]
    public struct UndoMenuData {
        string undo_label;
        string undo_description;
        string redo_label;
        string redo_description;
    }

    [CCode (cheader_filename = "marlin-undostack-manager.h")]
    public delegate void UndoFinishCallback (void *data);

    [CCode (cheader_filename = "marlin-undostack-manager.h")]
    public class UndoManager : GLib.Object
    {
        public static unowned UndoManager instance ();

        public signal void request_menu_update (UndoMenuData data);

        public void undo (Gtk.Widget widget, UndoFinishCallback? cb);
        public void redo (Gtk.Widget widget, UndoFinishCallback? cb);
        public void add_rename_action (GLib.File renamed_file, string original_name);
    }

    [CCode (cheader_filename = "marlin-progress-info.h")]
    public class Progress.Info : GLib.Object {
        public Info ();
        public signal void changed ();
        public signal void started ();
        public signal void finished ();
        public signal void progress_changed ();
        public void cancel ();
        public string get_title ();
        public string get_status ();
        public string get_details ();
        public double get_progress ();
        public double get_current ();
        public double get_total ();
        public bool get_is_finished ();
        public bool get_is_paused ();
        public GLib.Cancellable get_cancellable ();
    }

    [CCode (cheader_filename = "marlin-progress-info-manager.h")]
    public class Progress.InfoManager : GLib.Object {
        public InfoManager ();
        public signal void new_progress_info (Progress.Info info);
        public void add_new_info (Progress.Info info);
        public unowned GLib.List<Progress.Info> get_all_infos ();
    }
}

[CCode (cprefix = "MarlinFile", lower_case_cprefix = "marlin_file_", cheader_filename = "marlin-file-changes-queue.h")]
namespace MarlinFile {
    public void changes_queue_file_added (GLib.File location);
    public void changes_queue_file_changed (GLib.File location);
    public void changes_queue_file_removed (GLib.File location);
    public void changes_queue_file_moved (GLib.File location);
    public void changes_consume_changes (bool consume_all);
}

[CCode (cprefix = "GOF", lower_case_cprefix = "gof_", ref_function = "gof_file_ref", unref_function = "gof_file_unref")]
namespace GOF {

    [CCode (cheader_filename = "gof-file.h")]
    public class File : GLib.Object {
        [CCode (cheader_filename = "gof-file.h")]
        public enum ThumbState {
            UNKNOWN,
            NONE,
            READY,
            LOADING
        }
        public signal void changed ();
        public signal void info_available ();
        public signal void icon_changed ();
        public signal void destroy ();

        public const string GIO_DEFAULT_ATTRIBUTES;

        public File(GLib.File location, GLib.File? dir);
        public static GOF.File @get(GLib.File location);
        public static GOF.File? get_by_uri (string uri);
        public static GOF.File? get_by_commandline_arg (string arg);
        public static File cache_lookup (GLib.File file);
        public static void list_free (GLib.List<GOF.File> files);
        public static GLib.Mount? get_mount_at (GLib.File location);

        public void remove_from_caches ();
        public bool is_gone;
        public GLib.File location;
        public GLib.File target_location;
        public GLib.File directory; /* parent directory location */
        public GLib.Icon? icon;
        public GLib.List<string>? emblems_list;
        public GLib.FileInfo? info;
        public string basename;
        public string uri;
        public uint64 size;
        public string format_size;
        public int color;
        public string formated_modified;
        public string formated_type;
        public string tagstype;
        public Gdk.Pixbuf? pix;
        public int pix_size;
        public int width;
        public int height;
        public int sort_column_id;
        public Gtk.SortType sort_order;

        public GLib.FileType file_type;
        public bool is_hidden;
        public bool is_directory;
        public bool is_desktop;
        public bool is_expanded;
        public void set_expanded (bool expanded);
        public bool is_folder();
        public bool is_symlink();
        public bool is_trashed();
        public bool is_readable ();
        public bool is_writable ();
        public bool is_executable ();
        public bool is_mountable ();
        public bool link_known_target;
        public bool is_smb_share ();
        public bool is_smb_server ();
        public uint flags;

        public unowned string get_display_name ();
        public unowned GLib.File get_target_location ();
        public string get_symlink_target ();
        public unowned string? get_ftype ();
        public string? get_formated_time (string attr);
        public Gdk.Pixbuf get_icon_pixbuf (int size, bool forced_size, FileIconFlags flags);
        public void get_folder_icon_from_uri_or_path ();
        public Marlin.IconInfo get_icon (int size, FileIconFlags flags);

        public bool is_mounted;
        public bool exists;

        public int uid;
        public int gid;
        public string owner;
        public string group;
        public bool has_permissions;
        public uint32 permissions;

        public void update ();
        public void update_type ();
        public void update_icon (int size);
        public void update_desktop_file ();
        public void query_update ();
        public void query_thumbnail_update ();
        public bool ensure_query_info ();
        public unowned string? get_thumbnail_path();
        public bool can_set_owner ();
        public bool can_set_group ();
        public bool can_set_permissions ();
        public bool can_unmount ();
        public GLib.Mount? mount;
        public string get_permissions_as_string ();

        public GLib.List? get_settable_group_names ();
        public static int compare_by_display_name (File file1, File file2);

        public bool is_remote_uri_scheme ();
        public bool is_root_network_folder ();
        public bool is_network_uri_scheme ();
        public bool is_smb_uri_scheme ();
        public bool is_recent_uri_scheme ();
        public bool is_connected;

        public string get_display_target_uri ();

        public GLib.AppInfo get_default_handler ();

        public static string list_to_string (GLib.List<GOF.File> list, out long len);

        public bool execute (Gdk.Screen screen, GLib.List<GLib.File>? files, out GLib.Error error);

        public GOF.File @ref ();
        public GOF.File unref ();
    }

    [CCode (cheader_filename = "gof-file.h", has_target = false)]
    public delegate void FileOperationCallback (GOF.File file, GLib.File? result_location, GLib.Error? error, void* callback_data);

    [CCode (cheader_filename = "gof-file.h")]
    public enum FileIconFlags
    {
        NONE,
        USE_THUMBNAILS
    }
}

