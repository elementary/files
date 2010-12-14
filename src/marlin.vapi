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

[CCode (cprefix = "", lower_case_cprefix = "", cheader_filename = "marlin-global-preferences.h")]
namespace Preferences {
    public GLib.Settings settings;
    public string tags_colors[10];
}

public static uint action_new (GLib.Type type, string signal_name);
public void marlin_toolbar_editor_dialog_show (Marlin.View.Window mvw);

[CCode (cprefix = "Nautilus", lower_case_cprefix = "nautilus_")]
namespace Nautilus {
    [CCode (cheader_filename = "nautilus-icon-info.h")]
    public class IconInfo : GLib.Object{
        public static IconInfo lookup(GLib.Icon icon, int size);
        public Gdk.Pixbuf get_pixbuf_nodefault();
        public Gdk.Pixbuf get_pixbuf_at_size(int size);
    }
}

[CCode (cprefix = "GOF", lower_case_cprefix = "gof_")]
namespace GOF {
    [CCode (cprefix = "GOFWindow", lower_case_cprefix = "gof_window_")]
    namespace Window {
        [CCode (cheader_filename = "gof-window-slot.h")]
        public class Slot : GLib.Object {
            public Slot (GLib.File f, Marlin.View.ViewContainer ctab);
            public Directory.Async directory;
            public GLib.File location;
            public Widget view_box;
        }
    }

    [CCode (cprefix = "GOFFile", lower_case_cprefix = "gof_file_")]
    [CCode (cheader_filename = "gof-file.h")]
    public class File : GLib.Object {
        public File(GLib.FileInfo file_info, GLib.File dir);
        public GLib.File location;
        public GLib.Icon icon;
        public GLib.FileInfo info;
        public string name;
        public string format_size;
        public string color;
        public string formated_modified;
    }

    [CCode (cprefix = "GOFDirectoryAsync", lower_case_cprefix = "gof_directory_")]
    namespace Directory {
        [CCode (cheader_filename = "gof-directory-async.h")]
        public class Async : GLib.Object {
            public Async (GLib.File f);
            public void cancel ();
            public string get_uri ();
            public bool has_parent ();
            public GLib.File get_parent ();
        }
    }
}

namespace FM {
    [CCode (cprefix = "FMDirectory", lower_case_cprefix = "fm_directory_")]
    namespace Directory {
        [CCode (cheader_filename = "fm-directory-view.h")]
        public class View : Gtk.ScrolledWindow {
            public signal void colorize_selection (int color);
            public signal void sync_selection ();
        }
    }
}

namespace Marlin {
    [CCode (cprefix = "MarlinWindow", lower_case_cprefix = "marlin_window_")]
    namespace Window {
        [CCode (cheader_filename = "marlin-window-columns.h")]
        public class Columns : GLib.Object {
            public Columns (GLib.File f, Marlin.View.ViewContainer ctab);
            public GOF.Window.Slot active_slot;
            /*public Directory.Async directory;
            public Widget get_view ();*/
        }
    }
    [CCode (cprefix = "MarlinPlaces", lower_case_cprefix = "marlin_places_")]
    namespace Places {
        [CCode (cheader_filename = "marlin-places-sidebar.h")]
        public class Sidebar : Gtk.ScrolledWindow {
            public Sidebar (Gtk.Widget window);
        }
    }
}


