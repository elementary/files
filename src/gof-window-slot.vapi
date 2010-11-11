using Gtk;
using GLib;

[CCode (cprefix = "GOF", lower_case_cprefix = "gof_")]
namespace GOF {
	[CCode (cprefix = "GOFWindow", lower_case_cprefix = "gof_window_")]
	namespace Window {
		[CCode (cheader_filename = "gof-window-slot.h")]
		public class Slot : GLib.Object {
			public Slot (File f, Marlin.View.ViewContainer ctab);
			/*public Operation (int a1, int b1);
			public int addition ();*/
                        public Directory.Async directory;
                        public Widget get_view ();
		}
	}

	[CCode (cprefix = "GOFDirectoryAsync", lower_case_cprefix = "gof_directory_")]
	namespace Directory {
		[CCode (cheader_filename = "gof-directory-async.h")]
		public class Async : GLib.Object {
			public Async (File f);
                        public string get_uri ();
                        public bool has_parent ();
                        public File get_parent ();
                         
                }
        }
}

