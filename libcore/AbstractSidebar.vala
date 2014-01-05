namespace Marlin {
    public abstract class AbstractSidebar : Gtk.ScrolledWindow {
        public enum Column {
            NAME,
            URI,
            DRIVE,
            VOLUME,
            MOUNT,
            ROW_TYPE,
            ICON,
            INDEX,
            EJECT,
            NO_EJECT,
            BOOKMARK,
            TOOLTIP,
            EJECT_ICON,
            FREE_SPACE,
            DISK_SIZE,
            COUNT
        }

        protected Gtk.TreeStore store;

        protected void init () {
            store = new Gtk.TreeStore (((int)Column.COUNT),
                                        typeof (string),            /* name */
                                        typeof (string),            /* uri */
                                        typeof (Drive),
                                        typeof (Volume),
                                        typeof (Mount),
                                        typeof (int),               /* row type*/
                                        typeof (Icon),              /* Primary icon */
                                        typeof (uint),              /* index*/
                                        typeof (bool),              /* eject */
                                        typeof (bool),              /* no eject */
                                        typeof (bool),              /* is bookmark */
                                        typeof (string),            /* tool tip */
                                        typeof (Icon),              /* Action icon (e.g. eject button) */
                                        typeof (uint64),            /* Free space */
                                        typeof (uint64)             /* For disks, total size */
                                        );
        }

        public void add_extra_item (string text) {
            Gtk.TreeIter iter;
            store.append (out iter, null);
            store.set (iter,
                       Column.ICON, null,
                       Column.NAME, text,
                       Column.URI, "test://",
                       -1);
        }
    }
}
