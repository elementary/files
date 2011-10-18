using Gtk;
using GLib;

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "config.h")]
namespace Config {
    //public const string GETTEXT_PACKAGE;
    public const string PIXMAP_DIR;
    public const string UI_DIR;
    public const string VERSION;
    /*public const string PACKAGE_NAME;
      public const string PACKAGE_VERSION;
      public const string VERSION;*/
}

[CCode (cprefix = "FM", lower_case_cprefix = "fm_", cheader_filename = "fm-list-model.h")]
namespace FM
{
    public class ListModel : Object, Gtk.TreeModel, Gtk.TreeDragDest, Gtk.TreeSortable
    {
        public bool load_subdirectory(Gtk.TreePath path, out GOF.Directory.Async dir);
        public void add_file(GOF.File file, GOF.Directory.Async dir);
        public GOF.File file_for_path(Gtk.TreePath path);
    }
}

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "marlin-global-preferences.h")]
namespace Preferences {
    public GLib.Settings settings;
    public GLib.Settings marlin_icon_view_settings;
    public string tags_colors[10];
}

[CCode (cprefix = "MarlinFileOperations", lower_case_cprefix = "marlin_file_operations_", cheader_filename = "marlin-file-operations.h")]
namespace Marlin.FileOperations {
    static void empty_trash(Gtk.Widget widget);
}

/*[CCode (cprefix = "MarlinTrashMonitor", lower_case_cprefix = "marlin_trash_monitor_", cheader_filename = "marlin-trash-monitor.h")]
namespace Marlin.TrashMonitor {
    static bool is_empty ();
}*/


public static uint action_new (GLib.Type type, string signal_name);

[CCode (cprefix = "EelGtk", lower_case_cprefix = "eel_gtk_window_", cheader_filename = "eel-gtk-extensions.h")]
namespace EelGtk.Window {
    public string get_geometry_string (Gtk.Window win);
    public void set_initial_geometry_from_string (Gtk.Window win, string geometry, uint w, uint h, bool ignore_position);
}
[CCode (cprefix = "Eel", lower_case_cprefix = "eel_", cheader_filename = "eel-gtk-extensions.h")]
namespace Eel {
    public void pop_up_context_menu (Gtk.Menu menu, int16 offset_x, int16 offset_y, Gdk.EventButton event);
}

[CCode (cprefix = "Eel", lower_case_cprefix = "eel_", cheader_filename = "eel-fcts.h")]
namespace Eel {
    public string? get_date_as_string (uint64 d, string format);
}

[CCode (cprefix = "Nautilus", lower_case_cprefix = "nautilus_")]
namespace Nautilus {
    [CCode (cheader_filename = "nautilus-icon-info.h")]
    public class IconInfo : GLib.Object{
        public static IconInfo lookup(GLib.Icon icon, int size);
        public Gdk.Pixbuf get_pixbuf_nodefault();
        public Gdk.Pixbuf get_pixbuf_at_size(int size);
    }
}

[CCode (cprefix = "Marlin", lower_case_cprefix = "marlin_")]
namespace Marlin
{
    [CCode (cheader_filename = "marlin-abstract-sidebar.h")]
    public abstract class AbstractSidebar : Gtk.ScrolledWindow
    {
        public void add_extra_item(string text);
    }
    [CCode (cheader_filename = "marlin-trash-monitor.h")]
    public abstract class TrashMonitor : Object
    {
        public static TrashMonitor get();
        public static bool is_empty ();

        public signal void trash_state_changed (bool new_state);
    }
}

[CCode (cprefix = "GOF", lower_case_cprefix = "gof_")]
namespace GOF {

    [CCode (cheader_filename = "gof-file.h")]
    public class File : GLib.Object {
        public File(GLib.File location, GLib.File dir);
        public static File get(GLib.File location);
        public bool launch_with(Gdk.Screen screen, AppInfo app);
        public GLib.File location;
        public GLib.Icon? icon;
        public GLib.FileInfo? info;
        public string name;
        public string uri;
        public string format_size;
        public string color;
        public string formated_modified;
        public string formated_type;
        public string ftype;
        public Gdk.Pixbuf pix;
        public string trash_orig_path;

        public bool is_directory;
        public bool is_symlink();
        public bool is_trashed();
        public bool link_known_target;
        public string thumbnail_path;
        public string get_formated_time (string attr);
        public Nautilus.IconInfo get_icon (int size, FileIconFlags flags);
        public Gdk.Pixbuf get_icon_pixbuf (int size, bool forced_size, FileIconFlags flags);

        public bool is_mounted;
        public bool exists;
        public void update_icon (int size);
        public bool can_set_permissions ();
    }

    [CCode (cprefix = "GOFDirectory", lower_case_cprefix = "gof_directory_")]
    namespace Directory {
        [CCode (cheader_filename = "gof-directory-async.h")]
        public class Async : GLib.Object {
            public GLib.File location;
            public GOF.File file;
            public bool loading;
            public bool exists;
            public bool loaded;
            //public HashTable<GLib.File,GOF.File> file_hash;
            public HashTable file_hash;
            public HashTable hidden_file_hash;

            public Async (GLib.File f);
            public Async.from_file (GOF.File f);
            public Async.from_gfile (GLib.File f);
            public bool load ();
            public void cancel ();
            public string get_uri ();
            public bool has_parent ();
            public GLib.File get_parent ();
            
            public signal void file_loaded (GOF.File file);
            public signal void file_added (GOF.File file);
            public signal void file_changed (GOF.File file);
            public signal void file_deleted (GOF.File file);
            public signal void done_loading ();
            public signal void info_available ();
        }
    }
    [CCode (cheader_filename = "gof-file.h")]
    public enum FileIconFlags
    {
        NONE,
        USE_THUMBNAILS
    }
}

[CCode (cprefix = "GOF", lower_case_cprefix = "gof_")]
namespace GOF {
    [CCode (cheader_filename = "gof-abstract-slot.h")]
    public class AbstractSlot : GLib.Object {
        public void add_extra_widget(Gtk.Widget widget);
    }
}

