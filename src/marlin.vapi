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
}

public static uint action_new (GLib.Type type, string signal_name);
public void marlin_toolbar_editor_dialog_show (Marlin.View.Window mvw);

[CCode (cprefix = "GOF", lower_case_cprefix = "gof_")]
namespace GOF {
	[CCode (cprefix = "GOFWindow", lower_case_cprefix = "gof_window_")]
	namespace Window {
		[CCode (cheader_filename = "gof-window-slot.h")]
		public class Slot : GLib.Object {
			public Slot (GLib.File f, Marlin.View.ViewContainer ctab);
			/*public Operation (int a1, int b1);
			public int addition ();*/
                        public Directory.Async directory;
                        public GLib.File location;
                        public Widget view_box;
                        public Widget get_view ();
		}
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
	[CCode (cheader_filename = "gof-file.h")]
	public class File : GLib.Object {
            public File (GLib.FileInfo file_info, GLib.File dir);
            public string color;
        }
}

namespace FM {
	[CCode (cprefix = "FMDirectory", lower_case_cprefix = "fm_directory_")]
	namespace Directory {
		[CCode (cheader_filename = "fm-directory-view.h")]
		public class View : Gtk.ScrolledWindow {
                        public void colorize_selection (int color);
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
}

