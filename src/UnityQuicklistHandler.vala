namespace Marlin {

    public class LauncherEntry : Object {
        public Unity.LauncherEntry entry;
        public List<Dbusmenu.Menuitem> bookmark_quicklists = null;
        public List<Dbusmenu.Menuitem> progress_quicklists = null;
    }

    private QuicklistHandler quicklisthandler_singleton = null;

    public class QuicklistHandler : Object {

        private List<Marlin.LauncherEntry> launcher_entries = null;

        private QuicklistHandler () {
            this.entry_add ("pantheon-files.desktop");

            if (this.launcher_entries.length () == 0)
                error ("Couldn't find a valid Unity launcher entry.");
            else {
                var bookmarks = new Marlin.BookmarkList ();

                bookmarks.contents_changed.connect (() => {
                    debug ("Refreshing Unity dynamic bookmarks.");
                    this.remove_bookmark_quicklists ();
                    this.load_bookmarks (bookmarks);
                });
            }
        }

        public static unowned QuicklistHandler get_singleton () {
            if (quicklisthandler_singleton == null)
                quicklisthandler_singleton = new QuicklistHandler ();

            return quicklisthandler_singleton;
        }

        public unowned List<Marlin.LauncherEntry> get_launcher_entries () {
            return this.launcher_entries;
        }

        public static Unity.LauncherEntry get_launcher_entry (List<Marlin.LauncherEntry> list) {
            return list.data.entry;
        }

        private void entry_add (string entry_id) {
            var unity_lentry = Unity.LauncherEntry.get_for_desktop_id (entry_id);

            if (unity_lentry != null) {
                var marlin_lentry = new Marlin.LauncherEntry ();
                marlin_lentry.entry = unity_lentry;

                this.launcher_entries.prepend (marlin_lentry);

                /* Ensure dynamic quicklist exists */
                Dbusmenu.Menuitem ql = unity_lentry.quicklist;

                if (ql == null) {
                    ql = new Dbusmenu.Menuitem ();
                    unity_lentry.quicklist = ql;
                }
            }
        }

        private void remove_bookmark_quicklists () {
            foreach (var marlin_lentry in this.launcher_entries) {
                var unity_lentry = marlin_lentry.entry;
                Dbusmenu.Menuitem ql = unity_lentry.quicklist;

                if (ql == null)
                    break;

                foreach (var menuitem in marlin_lentry.bookmark_quicklists) {
                    ql.child_delete (menuitem);
                }
                
                //TODO: Delete all items in quicklist.
                marlin_lentry.bookmark_quicklists = null;
            }
        }

        private void load_bookmarks (Marlin.BookmarkList bookmarks) {
            var bookmark_count = bookmarks.length ();
            for (int index = 0; index < bookmark_count; index++) {
                var bookmark = bookmarks.item_at (index);

                if (bookmark.uri_known_not_to_exist ())
                    continue;

                foreach (var marlin_lentry in this.launcher_entries) {
                    var unity_lentry = marlin_lentry.entry;
                    Dbusmenu.Menuitem ql = unity_lentry.quicklist;
                    var menuitem = new Dbusmenu.Menuitem ();

                    menuitem.property_set ("label", bookmark.get_name ());
                    menuitem.item_activated.connect (() => {
                        var location = bookmark.get_location ();
                        Marlin.Application.get ().create_window (location, Gdk.Screen.get_default ());
                    });

                    ql.child_add_position (menuitem, index);
                    marlin_lentry.bookmark_quicklists.prepend (menuitem);
                }
            }
        }
    }
}
