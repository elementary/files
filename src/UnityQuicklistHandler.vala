namespace Marlin {

    public class LauncherEntry {
        public Unity.LauncherEntry entry;
        public List<string> bookmark_quicklists;
        public List<string> progress_quicklists;
    }

    private QuicklistHandler quicklisthandler_singleton = null;

    public class QuicklistHandler : Object {

        private List<Marlin.LauncherEntry> launcher_entries = null;

        private QuicklistHandler () {
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
        }
        
        private void activate_bookmark_by_quicklist (Dbusmenu.Menuitem menu,
                                                     int timestamp,
                                                     Marlin.Bookmark bookmark) {
        }
        
        private void remove_bookmark_quicklists () {
        }
        
        private void update_bookmarks (Marlin.BookmarkList bookmarks) {
        }
        
        private void refresh_bookmarks (Marlin.BookmarkList bookmarks) {
        }
    }
}