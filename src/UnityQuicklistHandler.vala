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
    
        public static QuicklistHandler get_singleton () {
            return new QuicklistHandler ();
        }
        
        public unowned List<Marlin.LauncherEntry> get_launcher_entries () {
            return this.launcher_entries;
        }
        
        public static Unity.LauncherEntry get_launcher_entry (List<Marlin.LauncherEntry> list) {
            return list.data.entry;
        }
    }
}