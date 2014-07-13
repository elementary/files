public void marlin_toolbar_editor_dialog_show (Marlin.View.Window mvw);

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "marlin-global-preferences.h")]
namespace Preferences {
    public GLib.Settings settings;
    public GLib.Settings marlin_icon_view_settings;
    public GLib.Settings marlin_list_view_settings;
    public GLib.Settings marlin_column_view_settings;
    public GLib.Settings gnome_mouse_settings;
}

namespace FM {
    [CCode (cprefix = "FMDirectory", lower_case_cprefix = "fm_directory_")]
    namespace Directory {
        [CCode (cheader_filename = "fm-directory-view.h")]
        public class View : Gtk.ScrolledWindow {
            public View ();
            public string empty_message;
            //public void set_slot (GOF.Window.Slot slot);
            public void set_active (bool active);
            public bool active;
            public bool is_frozen ();
            public bool updates_frozen;
            public void dir_action_set_sensitive (string action_name, bool sensitive);
            //public void colorize_selection (int color);
            public void notify_selection_changed ();
            public unowned GLib.List<GOF.File> get_selection ();
            public void select_first_for_empty_selection ();
            public void merge_menus ();
            public void unmerge_menus ();
            public void update_menus ();
            public void zoom_in ();
            public void zoom_out ();
            public void zoom_normal ();
            public Marlin.ZoomLevel zoom_level;
            public unowned GLib.List<GLib.AppInfo>? get_open_with_apps ();
            public GLib.AppInfo? get_default_app ();
            public void select_glib_files (GLib.List files);
            public void set_select_added_files (bool select);
            public void set_selection_was_removed (bool was_removed);
            //public void column_add_location (GLib.File file);
            public void clear_model ();
            public unowned FM.ListModel get_model ();
            public virtual signal void add_file (GOF.File file, GOF.Directory.Async dir);
            public signal void sync_selection ();
            public signal void change_path (GLib.File location, Marlin.OpenFlag flag);
            public signal void trash_files (GLib.List<GLib.File> locations);
            public signal void delete_files (GLib.List<GLib.File> locations);
            public signal void restore_files (GLib.List<GOF.File> files);
            //public virtual signal void sync_selection ();
 
        }
    }
    [CCode (cprefix = "FMIcon", lower_case_cprefix = "fm_icon_")]
    namespace Icon {
        [CCode (cheader_filename = "fm-icon-view.h")]
        public class View : Directory.View {
            public View ();
            public static GLib.Type get_type ();
        }
    }
    [CCode (cprefix = "FMColumns", lower_case_cprefix = "fm_columns_")]
    namespace Columns {
        [CCode (cheader_filename = "fm-columns-view.h")]
        public class View : Directory.View {
            public View ();
            public static GLib.Type get_type ();
        }
    }
    [CCode (cprefix = "FMList", lower_case_cprefix = "fm_list_")]
    namespace List {
        [CCode (cheader_filename = "fm-list-view.h")]
        public class View : Directory.View {
            public View ();
            public static GLib.Type get_type ();
        }
    }
}
//[CCode (cprefix = "GOF", lower_case_cprefix = "gof_")]
//namespace GOF {
// [CCode (cprefix = "GOFWindow", lower_case_cprefix = "gof_window_")]
// namespace Window {
//  [CCode (cheader_filename = "gof-window-slot.h")]
//  public class Slot : GOF.AbstractSlot {
//   public Slot (GLib.File f, Gtk.Overlay ctab);
//   public void make_icon_view ();
//   public void make_list_view ();
//   public void make_compact_view ();
//   public void add_extra_widget(Gtk.Widget widget);
//   public Directory.Async directory;
//   public GLib.File location;
//   public Gtk.Widget view_box;
//   public Gtk.Overlay ctab;
//   public signal void active ();
//   public signal void inactive ();
//  }
// }
//}

namespace Marlin {
    [CCode (cheader_filename = "marlin-thumbnailer.h")]
    public class Thumbnailer : GLib.Object {
        public static Thumbnailer get();
        public bool queue_file (GOF.File file, int? request, bool large);
        public bool queue_files (GLib.List<GOF.File> files, int? request, bool large);

    }

    [CCode (cheader_filename = "marlin-dnd.h")]
    public static Gdk.DragAction drag_drop_action_ask (Gtk.Widget widget, Gdk.DragAction possible_actions);

// [CCode (cprefix = "MarlinWindow", lower_case_cprefix = "marlin_window_")]
// namespace Window {
//  [CCode (cheader_filename = "marlin-window-columns.h")]
//  public class Columns : GOF.AbstractSlot {
//   //public Columns (GLib.File f, Marlin.View.ViewContainer ctab);
//   public Columns (GLib.File f, Gtk.Overlay ctab);
//   public void make_view ();
//   public GOF.Window.Slot active_slot;
//   public string? get_root_uri ();
//   public string? get_tip_uri ();
//   public unowned GOF.Window.Slot get_last_slot ();
//   public int preferred_column_width;
//   public int total_width;
//   public int handle_size;
//   public Gtk.Widget colpane;
//   public GLib.List<GOF.Window.Slot> slot;
//   /*public Directory.Async directory;
//   public Widget get_view ();*/
//  }
// }

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
        public void new_folder(Gtk.Widget? parent_view, Gdk.Point? target_point, GLib.File file, void* callback, void* data_callback);
        [CCode (cheader_filename = "marlin-file-operations.h")]
        public void new_folder_with_name(Gtk.Widget? parent_view, Gdk.Point? target_point, GLib.File file, string name, void* callback, void* data_callback);
        [CCode (cheader_filename = "marlin-file-operations.h")]
        public void new_folder_with_name_recursive(Gtk.Widget? parent_view, Gdk.Point? target_point, GLib.File file, string name, void* callback, void* data_callback);
        [CCode (cheader_filename = "marlin-file-operations.h")]
        public void mount_volume (Gtk.Window? parent_window, GLib.Volume volume, bool allow_autorun);
        [CCode (cheader_filename = "marlin-file-operations.h")]
        public void mount_volume_full (Gtk.Window? parent_window, GLib.Volume volume, bool allow_autorun, Marlin.MountCallback? mount_callback, GLib.Object? callback_data_object);
        [CCode (cheader_filename = "marlin-file-operations.h")]
        public void unmount_mount_full (Gtk.Window? parent_window, GLib.Mount mount, bool eject, bool check_trash, Marlin.UnmountCallback? unmount_callback, void* callback_data);
        [CCode (cheader_filename = "marlin-file-operations.h")]
        public void trash_or_delete (GLib.List<GLib.File> locations, Gtk.Window window, void* callback, void* callback_data);
        [CCode (cheader_filename = "marlin-file-operations.h")]
        public void @delete (GLib.List<GLib.File> locations, Gtk.Window window, void* callback, void* callback_data);
    }
    [CCode (cheader_filename = "marlin-file-operations.h", has_target = false)]
    public delegate void MountCallback (GLib.Volume volume, void* callback_data_object);
    [CCode (cheader_filename = "marlin-file-operations.h", has_target = false)]
    public delegate void UnmountCallback (void* callback_data);

    [CCode (cheader_filename = "marlin-file-utilities.h")]
    public void restore_files_from_trash (GLib.List<GOF.File> *files, Gtk.Window *parent_window);
    [CCode (cheader_filename = "marlin-file-utilities.h")]
    public void get_rename_region (string filename, out int start_offset, out int end_offset, bool select_all);

    [CCode (cheader_filename = "marlin-icon-renderer.h")]
    public class IconRenderer : Gtk.CellRenderer {
        public IconRenderer ();
        public File drop_file;
    }
    [CCode (cheader_filename = "marlin-text-renderer.h")]
    public class TextRenderer : Gtk.CellRenderer {
        public TextRenderer ();
        public Pango.Layout layout;
        public Gtk.Widget widget;
        bool text_static;
        string text;
        string background;
        int char_width;
        int char_height;
        Pango.WrapMode wrap_mode;
        int wrap_width;
        bool follow_state;
        int focus_width;
        Marlin.ZoomLevel zoom_level;
        Gtk.Widget entry;
        bool entry_menu_active;
        int entry_menu_popdown_timer_id;
        public signal void edited (string path, string text);
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
    public enum IconSize {
        SMALLEST = 16,
        SMALLER = 24,
        SMALL = 32,
        NORMAL = 48,
        LARGE = 64,
        LARGER = 96,
        LARGEST = 128
    }

    [CCode (cheader_filename = "marlin-enum-types.h")]
    public Gtk.IconSize zoom_level_to_stock_icon_size (ZoomLevel zoom);
    [CCode (cheader_filename = "marlin-enum-types.h")]
    public Marlin.IconSize zoom_level_to_icon_size (ZoomLevel zoom);

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
        MILLER,
        CURRENT,
        PREFERRED,
        INVALID
    }
 
}
