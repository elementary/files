namespace Marlin {

    public class LauncherEntry {
        public Unity.LauncherEntry entry;
        public List<string> bookmark_quicklists = null;
        public List<string> progress_quicklists = null;
    }

    private QuicklistHandler quicklisthandler_singleton = null;

    public class QuicklistHandler : Object {

        private List<Marlin.LauncherEntry> launcher_entries = null;

        private QuicklistHandler () {
            this.entry_add ("pantheon-files.desktop");
            
            if (this.launcher_entries.length () == 0)
                critical ("Couldn't find a valid Unity launcher entry.");
            else {
                var bookmarks = new Marlin.BookmarkList ();
                /* Recreate dynamic part of menu if bookmark list changes */
                bookmarks.contents_changed.connect (refresh_bookmarks);
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
                
                /* Ensure dynamic quicklist exist */
                Dbusmenu.Menuitem ql = unity_lentry.quicklist;
                
                if (ql == null) {
                    ql = new Dbusmenu.Menuitem ();
                    unity_lentry.quicklist = ql;
                }
            }
        }
        
        private void activate_bookmark_by_quicklist (Dbusmenu.Menuitem menu,
                                                     int timestamp,
                                                     Marlin.Bookmark bookmark) {
            File location = bookmark.get_location ();
            Marlin.Application.get ().create_window (location, Gdk.Screen.get_default ());
        }
        
        private void remove_bookmark_quicklists () {
            
        }
        
        private void update_bookmarks (Marlin.BookmarkList bookmarks) {
        }
        
        private void refresh_bookmarks (Marlin.BookmarkList bookmarks) {
        }
    }
}
